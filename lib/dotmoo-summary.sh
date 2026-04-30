# shellcheck shell=bash
# dotmoo summary — run pr-summary-mesh on a single PR.

cmd_summary() {
    local target="${1:-}"
    if [ -z "$target" ]; then
        echo "Usage: dotmoo summary owner/repo#42 [--mode merge|vote]" >&2
        return 2
    fi
    if ! command -v pr-summary-mesh >/dev/null 2>&1; then
        echo "[dotmoo] pr-summary-mesh not on PATH (install: https://github.com/M00C1FER/pr-summary-mesh)" >&2
        return 2
    fi
    shift
    local mode="merge"
    if [ "${1:-}" = "--mode" ] && [ -n "${2:-}" ]; then
        mode="$2"
    fi
    pr-summary-mesh --pr "$target" --mode "$mode"
}
