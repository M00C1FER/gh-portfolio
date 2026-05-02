# shellcheck shell=bash
# gh-portfolio summary — run pr-summary-mesh on a single PR.

cmd_summary() {
    local target="${1:-}"
    if [ -z "$target" ]; then
        echo "Usage: gh-portfolio summary owner/repo#42 [--mode merge|vote]" >&2
        return 2
    fi
    if ! command -v pr-summary-mesh >/dev/null 2>&1; then
        echo "[gh-portfolio] pr-summary-mesh not on PATH (install: https://github.com/M00C1FER/pr-summary-mesh)" >&2
        return 2
    fi
    shift
    local mode="merge"
    if [ "${1:-}" = "--mode" ] && [ -n "${2:-}" ]; then
        case "$2" in
            merge|squash|rebase|vote) mode="$2";;
            *) echo "[gh-portfolio] error: unknown --mode '$2' (valid: merge, squash, rebase, vote)" >&2; return 2;;
        esac
    fi
    pr-summary-mesh --pr "$target" --mode "$mode"
}
