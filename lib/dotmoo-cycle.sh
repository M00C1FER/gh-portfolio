# shellcheck shell=bash
# dotmoo cycle — full chain on a single PR:
#   gatecheck (secret scan) → triple-review (issue gate) → pr-summary-mesh (narrative) → flowtag (release readiness)
# Each step is best-effort; missing tools are skipped with a warning, so partial
# installs still produce useful output.

cmd_cycle() {
    local target="${1:-}"
    if [ -z "$target" ]; then
        echo "Usage: dotmoo cycle owner/repo#42" >&2
        return 2
    fi
    local repo="${target%#*}"; local pr="${target##*#}"
    if [ -z "$repo" ] || [ -z "$pr" ] || [ "$repo" = "$pr" ]; then
        echo "[dotmoo] expected owner/repo#N" >&2
        return 2
    fi

    if ! [[ "$pr" =~ ^[0-9]+$ ]]; then
        echo "[dotmoo] error: PR number must be an integer, got: '$pr'" >&2; return 2
    fi

    local diff_file; diff_file="$(mktemp -t dotmoo-cycle-XXXXXX.diff)"
    trap 'rm -f "$diff_file"' EXIT
    gh pr diff "$pr" --repo "$repo" > "$diff_file"

    echo "==== gatecheck (secret scan) ===="
    if command -v gatecheck >/dev/null 2>&1; then
        gatecheck < "$diff_file" || echo "[dotmoo] gatecheck flagged findings"
    else
        echo "[dotmoo] gatecheck not installed; skipping"
    fi

    echo
    echo "==== triple-review (issue gate) ===="
    if command -v triple-review >/dev/null 2>&1; then
        triple-review --falsify "$diff_file" || true
    else
        echo "[dotmoo] triple-review not installed; skipping"
    fi

    echo
    echo "==== pr-summary-mesh (narrative) ===="
    if command -v pr-summary-mesh >/dev/null 2>&1; then
        pr-summary-mesh --diff-file "$diff_file" --mode merge || true
    else
        echo "[dotmoo] pr-summary-mesh not installed; skipping"
    fi

    echo
    echo "==== flowtag (release readiness) ===="
    if command -v flowtag >/dev/null 2>&1; then
        local local_path="${DOTMOO_CLONES:-$HOME/.dotmoo/clones}/${repo##*/}"
        if [ -d "$local_path/.git" ]; then
            (cd "$local_path" && flowtag --bump 2>/dev/null || echo "(no bump)")
        else
            echo "[dotmoo] no local clone of $repo (run dotmoo bump first)"
        fi
    else
        echo "[dotmoo] flowtag not installed; skipping"
    fi

}
