#!/usr/bin/env bash
set -euo pipefail

# Standalone container health checker for DocoCD-managed stacks. Runs on the
# home server (local docker) or any other host on the network (auto-tunnels
# via ssh://$SERVER_SSH_ALIAS). Stack list and compose files are fetched from
# the public repo at runtime — no repo clone needed on the host.

REPO_RAW_URL="${REPO_RAW_URL:-https://raw.githubusercontent.com/DiegoHeer/gitops-homelab/main}"
REPO_RAW_URL="${REPO_RAW_URL%/}"
SERVER_HOSTNAME="${SERVER_HOSTNAME:-home}"
SERVER_SSH_ALIAS="${SERVER_SSH_ALIAS:-server}"
if [ -z "${DOCKER_HOST:-}" ] && [ "$(hostname)" != "$SERVER_HOSTNAME" ]; then
    export DOCKER_HOST="ssh://$SERVER_SSH_ALIAS"
fi

CRASH_LOOP_RESTARTS=3
CRASH_LOOP_WINDOW_SECONDS=600

GREEN=$'\033[32m'; RED=$'\033[31m'; YELLOW=$'\033[33m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
STACK_W=20; CONTAINER_W=28; STATUS_W=16

fetch() {
    local url="$REPO_RAW_URL/$1"
    curl --fail --silent --show-error --location "$url" || {
        echo "Error: failed to fetch $url" >&2
        return 2
    }
}

# Emit sorted stack|container lines. Fetches .doco-cd.yml sequentially
# (needed to learn the stack list), then parallel-fetches every compose file
# in one curl call.
discover_containers() {
    local doco_cd_yml stacks stack tmpdir path matches
    doco_cd_yml=$(fetch .doco-cd.yml) || return 2
    stacks=$(echo "$doco_cd_yml" \
        | awk '/^name:[[:space:]]+/ { gsub(/["'\'']/, "", $2); print $2 }')
    [ -n "$stacks" ] || {
        echo "Error: no 'name:' entries in $REPO_RAW_URL/.doco-cd.yml" >&2
        return 2
    }
    stacks+=$'\n'"gitops"

    tmpdir=$(mktemp -d)
    # shellcheck disable=SC2064  # expand tmpdir now, not at trap time
    trap "rm -rf '$tmpdir'" RETURN

    local curl_args=(--fail --silent --show-error --location --parallel)
    while IFS= read -r stack; do
        [ -n "$stack" ] || continue
        if [ "$stack" = "gitops" ]; then
            path="bootstrap/gitops/docker-compose.yaml"
        else
            path="services/$stack/docker-compose.yaml"
        fi
        curl_args+=(-o "$tmpdir/$stack" "$REPO_RAW_URL/$path")
    done <<< "$stacks"

    curl "${curl_args[@]}" || {
        echo "Error: one or more compose files failed to fetch from $REPO_RAW_URL" >&2
        return 2
    }

    while IFS= read -r stack; do
        [ -n "$stack" ] || continue
        matches=$(awk -v stack="$stack" \
            '/^[[:space:]]+container_name:[[:space:]]+/ { gsub(/["'\'']/, "", $2); print stack "|" $2 }' \
            "$tmpdir/$stack")
        if [ -z "$matches" ]; then
            echo "Warning: no container_name entries for stack '$stack'" >&2
        else
            echo "$matches"
        fi
    done <<< "$stacks" | sort -u
}

# One batched docker inspect across every container name. Emit name|status
# lines. Containers absent from docker simply produce no output line — the
# caller maps that to "missing".
classify() {
    local now name state health restart started started_epoch status
    now=$(date -u +%s)
    docker inspect \
        --format '{{.Name}}|{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}|{{.RestartCount}}|{{.State.StartedAt}}' \
        "$@" 2>/dev/null \
    | while IFS='|' read -r name state health restart started; do
        [ -n "$name" ] || continue
        name="${name#/}"
        if [ "$state" != "running" ]; then
            case "$state" in
                exited|stopped|created) status="inactive" ;;
                *)                      status="$state" ;;
            esac
        # Crash-loop takes precedence over health — a container that restarts
        # every few seconds may briefly report healthy. Known false-positive:
        # a long-lived container whose cumulative restart count exceeds the
        # threshold and is manually restarted within the window will misread
        # as crash-loop until the window lapses.
        elif [ "$restart" -gt "$CRASH_LOOP_RESTARTS" ] \
            && started_epoch=$(date -d "$started" +%s 2>/dev/null) \
            && (( now - started_epoch < CRASH_LOOP_WINDOW_SECONDS )); then
            status="crash-loop"
        else
            case "$health" in
                unhealthy|starting) status="$health" ;;
                *)                  status="healthy" ;;
            esac
        fi
        echo "$name|$status"
    done
}

main() {
    local containers
    containers=$(discover_containers) || exit 2
    [ -n "$containers" ] || {
        echo "No containers discovered from $REPO_RAW_URL" >&2
        exit 2
    }

    local -a names=()
    local stack container status color
    while IFS='|' read -r _ container; do
        [ -n "$container" ] && names+=("$container")
    done <<< "$containers"

    local -A status_by_name=()
    while IFS='|' read -r name status; do
        status_by_name["$name"]="$status"
    done < <(classify "${names[@]}")

    # If docker inspect returned nothing at all, the daemon is unreachable —
    # without this hint every row would render as "missing".
    if [ "${#status_by_name[@]}" -eq 0 ] && [ "${#names[@]}" -gt 0 ]; then
        echo "Error: docker daemon not reachable (DOCKER_HOST=${DOCKER_HOST:-<local>})." >&2
        echo "Check connectivity and that docker is running on the target host." >&2
        exit 2
    fi

    local sep
    sep=$(printf "%-${STACK_W}s %-${CONTAINER_W}s %-${STATUS_W}s" \
        "$(printf '─%.0s' $(seq 1 $((STACK_W - 1))))" \
        "$(printf '─%.0s' $(seq 1 $((CONTAINER_W - 1))))" \
        "$(printf '─%.0s' $(seq 1 $((STATUS_W - 1))))")

    printf "${BOLD}%-${STACK_W}s %-${CONTAINER_W}s %-${STATUS_W}s${RESET}\n" "Stack" "Container" "Status"
    echo "$sep"

    local prev_stack="" healthy_count=0 problem_count=0
    while IFS='|' read -r stack container; do
        [ -n "$stack" ] && [ -n "$container" ] || continue
        if [ -n "$prev_stack" ] && [ "$stack" != "$prev_stack" ]; then
            echo "$sep"
        fi
        prev_stack="$stack"
        status="${status_by_name[$container]:-missing}"
        case "$status" in
            healthy)  color="$GREEN" ;;
            starting) color="$YELLOW" ;;
            *)        color="$RED" ;;
        esac
        printf "%-${STACK_W}s %-${CONTAINER_W}s ${color}● %-${STATUS_W}s${RESET}\n" \
            "$stack" "$container" "$status"
        if [ "$status" = "healthy" ]; then
            healthy_count=$((healthy_count + 1))
        else
            problem_count=$((problem_count + 1))
        fi
    done <<< "$containers"

    echo
    local word=problems
    [ "$problem_count" = 1 ] && word=problem
    printf "%d healthy, %d %s\n" "$healthy_count" "$problem_count" "$word"

    [ "$problem_count" -eq 0 ] || exit 1
}

main
