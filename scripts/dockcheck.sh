#!/usr/bin/env bash
set -euo pipefail

# Standalone container health checker for DocoCD-managed stacks.
#
# Works unchanged on the server (local docker socket) and from a laptop
# (`DOCKER_HOST=ssh://server ./dockcheck.sh`). Declarations are fetched at
# runtime from the public repo rather than read from disk so the script has
# zero dependency on having the repo checked out anywhere — drop it on any
# host with `docker` and `curl` and it works.

# Base raw-content URL for the public repo. Override to point at a fork or
# branch when needed.
REPO_RAW_URL="${REPO_RAW_URL:-https://raw.githubusercontent.com/DiegoHeer/gitops-homelab/main}"
REPO_RAW_URL="${REPO_RAW_URL%/}"

# ANSI color codes
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
BOLD='\033[1m'
RESET='\033[0m'

# Column widths
STACK_W=20
CONTAINER_W=28
STATUS_W=16

# Crash-loop thresholds: container is considered crash-looping if it's running
# with more than this many restarts AND the last restart was within this many
# seconds.
CRASH_LOOP_RESTARTS=3
CRASH_LOOP_WINDOW_SECONDS=600

fetch() {
    local path="$1"
    local url="$REPO_RAW_URL/$path"
    if ! curl --fail --silent --show-error --location "$url"; then
        echo "Error: failed to fetch $url" >&2
        echo "Check network connectivity and REPO_RAW_URL." >&2
        return 2
    fi
}

# Discover all container_name entries across every managed stack.
# Output: sorted lines of "stack|container". Returns non-zero on fetch failure
# or when the stack registry can't be parsed.
discover_containers() {
    local doco_cd_yml stacks stack compose_path compose_yml matches raw
    doco_cd_yml=$(fetch .doco-cd.yml) || return 2
    stacks=$(echo "$doco_cd_yml" \
        | awk '/^name:[[:space:]]+/ {print $2}' \
        | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/")
    if [ -z "$stacks" ]; then
        echo "Error: no 'name:' entries found in $REPO_RAW_URL/.doco-cd.yml" >&2
        return 2
    fi
    stacks+=$'\n'"gitops"

    raw=""
    while IFS= read -r stack; do
        [ -n "$stack" ] || continue
        if [ "$stack" = "gitops" ]; then
            compose_path="bootstrap/gitops/docker-compose.yaml"
        else
            compose_path="services/$stack/docker-compose.yaml"
        fi
        compose_yml=$(fetch "$compose_path") || return 2
        matches=$(echo "$compose_yml" \
            | awk -v stack="$stack" \
                '/^[[:space:]]+container_name:[[:space:]]+/ {print stack "|" $2}' \
            | sed -e 's/|"\(.*\)"$/|\1/' -e "s/|'\(.*\)'$/|\1/")
        if [ -z "$matches" ]; then
            echo "Warning: no container_name entries for stack '$stack' in $compose_path" >&2
            continue
        fi
        raw+="$matches"$'\n'
    done <<< "$stacks"

    echo "$raw" | sort -u | awk 'NF'
}

# Classify a single container's status.
# Output: one of healthy, unhealthy, starting, crash-loop, inactive, missing.
get_status() {
    local container="$1"
    local inspect_out

    if ! inspect_out=$(docker inspect \
        --format '{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}|{{.RestartCount}}|{{.State.StartedAt}}' \
        "$container" 2>/dev/null); then
        echo "missing"
        return
    fi

    local state health restart_count started_at
    IFS='|' read -r state health restart_count started_at <<< "$inspect_out"

    if [[ "$state" == "running" ]]; then
        # Crash-loop takes precedence over health state — a container that
        # restarts every few seconds may briefly report healthy between
        # restarts. Narrow false-positive: a long-lived container with old
        # cumulative restarts that gets manually started within the window
        # will misread as crash-loop until the window lapses.
        if [[ "$restart_count" -gt "$CRASH_LOOP_RESTARTS" ]]; then
            local started_epoch now_epoch
            if started_epoch=$(date -d "$started_at" +%s 2>/dev/null); then
                now_epoch=$(date -u +%s)
                if (( now_epoch - started_epoch < CRASH_LOOP_WINDOW_SECONDS )); then
                    echo "crash-loop"
                    return
                fi
            fi
        fi
        case "$health" in
            healthy|none) echo "healthy" ;;
            unhealthy)    echo "unhealthy" ;;
            starting)     echo "starting" ;;
            *)            echo "healthy" ;;
        esac
    elif [[ "$state" == "exited" || "$state" == "stopped" || "$state" == "created" ]]; then
        echo "inactive"
    else
        echo "$state"
    fi
}

status_color() {
    case "$1" in
        healthy)  echo "$GREEN" ;;
        starting) echo "$YELLOW" ;;
        *)        echo "$RED" ;;
    esac
}

print_header() {
    printf "${BOLD}%-${STACK_W}s %-${CONTAINER_W}s %-${STATUS_W}s${RESET}\n" "Stack" "Container" "Status"
    print_separator
}

print_separator() {
    printf "%-${STACK_W}s %-${CONTAINER_W}s %-${STATUS_W}s\n" \
        "$(printf '─%.0s' $(seq 1 $((STACK_W - 1))))" \
        "$(printf '─%.0s' $(seq 1 $((CONTAINER_W - 1))))" \
        "$(printf '─%.0s' $(seq 1 $((STATUS_W - 1))))"
}

main() {
    local containers
    if ! containers="$(discover_containers)"; then
        exit 2
    fi

    if [[ -z "$containers" ]]; then
        echo "No containers discovered. Check that $REPO_RAW_URL/.doco-cd.yml is reachable" >&2
        echo "and that the referenced compose files declare container_name entries." >&2
        exit 2
    fi

    print_header

    local prev_stack=""
    local healthy_count=0 problem_count=0
    while IFS='|' read -r stack container; do
        [[ -n "$stack" && -n "$container" ]] || continue
        if [[ -n "$prev_stack" && "$stack" != "$prev_stack" ]]; then
            print_separator
        fi
        prev_stack="$stack"

        local status color
        status="$(get_status "$container")"
        color="$(status_color "$status")"
        printf "%-${STACK_W}s %-${CONTAINER_W}s ${color}● %-${STATUS_W}s${RESET}\n" "$stack" "$container" "$status"

        if [[ "$status" == "healthy" ]]; then
            healthy_count=$((healthy_count + 1))
        else
            problem_count=$((problem_count + 1))
        fi
    done <<< "$containers"

    echo
    local problem_word="problems"
    [[ "$problem_count" -eq 1 ]] && problem_word="problem"
    printf "%d healthy, %d %s\n" "$healthy_count" "$problem_count" "$problem_word"

    [[ "$problem_count" -eq 0 ]] || exit 1
}

main
