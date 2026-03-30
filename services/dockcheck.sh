#!/usr/bin/env bash
set -euo pipefail

# Resolve the services directory relative to this script
SERVICES_DIR="$(cd "$(dirname "$0")" && pwd)"

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

# Discover all container_name entries from docker-compose files, paired with their stack name.
# Output: sorted lines of "stack|container"
discover_containers() {
    for compose_file in "$SERVICES_DIR"/*/docker-compose.yaml; do
        [ -f "$compose_file" ] || continue
        stack="$(basename "$(dirname "$compose_file")")"
        grep -E '^\s+container_name:\s+' "$compose_file" \
            | awk -v stack="$stack" '{print stack "|" $2}'
    done | sort
}

# Get the status of a single container.
# Output: one of healthy, unhealthy, starting, running, inactive, nonexistent, or raw state
get_status() {
    local container="$1"
    local inspect_out

    if ! inspect_out=$(docker inspect --format '{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container" 2>/dev/null); then
        echo "nonexistent"
        return
    fi

    local state="${inspect_out%%|*}"
    local health="${inspect_out##*|}"

    if [[ "$state" == "running" ]]; then
        case "$health" in
            healthy)  echo "healthy" ;;
            unhealthy) echo "unhealthy" ;;
            starting) echo "starting" ;;
            *)        echo "running" ;;
        esac
    elif [[ "$state" == "exited" || "$state" == "stopped" || "$state" == "created" ]]; then
        echo "inactive"
    else
        echo "$state"
    fi
}

# Map a status to its color code
status_color() {
    case "$1" in
        healthy|running) echo "$GREEN" ;;
        starting)        echo "$YELLOW" ;;
        unhealthy|inactive|nonexistent) echo "$RED" ;;
        *) echo "$RED" ;;
    esac
}

# Print the table header
print_header() {
    printf "${BOLD}%-${STACK_W}s %-${CONTAINER_W}s %-${STATUS_W}s${RESET}\n" "Stack" "Container" "Status"
    printf "%-${STACK_W}s %-${CONTAINER_W}s %-${STATUS_W}s\n" \
        "$(printf '─%.0s' $(seq 1 $((STACK_W - 1))))" \
        "$(printf '─%.0s' $(seq 1 $((CONTAINER_W - 1))))" \
        "$(printf '─%.0s' $(seq 1 $((STATUS_W - 1))))"
}

# Main
main() {
    local containers
    containers="$(discover_containers)"

    if [[ -z "$containers" ]]; then
        echo "No containers found in $SERVICES_DIR/*/docker-compose.yaml"
        exit 1
    fi

    print_header

    local prev_stack=""
    while IFS='|' read -r stack container; do
        if [[ -n "$prev_stack" && "$stack" != "$prev_stack" ]]; then
            printf "%-${STACK_W}s %-${CONTAINER_W}s %-${STATUS_W}s\n" \
                "$(printf '─%.0s' $(seq 1 $((STACK_W - 1))))" \
                "$(printf '─%.0s' $(seq 1 $((CONTAINER_W - 1))))" \
                "$(printf '─%.0s' $(seq 1 $((STATUS_W - 1))))"
        fi
        prev_stack="$stack"

        local status
        status="$(get_status "$container")"
        local color
        color="$(status_color "$status")"
        printf "%-${STACK_W}s %-${CONTAINER_W}s ${color}● %-${STATUS_W}s${RESET}\n" "$stack" "$container" "$status"
    done <<< "$containers"
}

main
