# shellcheck shell=bash
# gh-portfolio cycle — full chain on a single PR:
#   gatecheck (secret scan) → triple-review (issue gate) → pr-summary-mesh (narrative) → flowtag (release readiness)
# Each step is best-effort; missing tools are skipped with a warning, so partial
# installs still produce useful output.

cmd_cycle() {
    local target="${1:-}"
    if [ -z "$target" ]; then
        echo "Usage: gh-portfolio cycle owner/repo#42" >&2
        return 2
    fi
    local repo="${target%#*}"; local pr="${target##*#}"
    if [ -z "$repo" ] || [ -z "$pr" ] || [ "$repo" = "$pr" ]; then
        echo "[gh-portfolio] expected owner/repo#N" >&2
        return 2
    fi

    if ! [[ "$pr" =~ ^[0-9]+$ ]]; then
        echo "[gh-portfolio] error: PR number must be an integer, got: '$pr'" >&2; return 2
    fi

    local diff_file; diff_file="$(mktemp -t gh-portfolio-cycle-XXXXXX.diff)"
    # EXIT trap is a safety net for abnormal exits (signal, set -e).
    # We also clean up explicitly before returning because diff_file is a
    # local variable and goes out of scope before the trap fires on normal exit.
    # shellcheck disable=SC2064  # intentional: diff_file must expand now to capture the path
    trap 'rm -f "'"$diff_file"'"' EXIT
    gh pr diff "$pr" --repo "$repo" > "$diff_file"

    echo "==== gatecheck (secret scan) ===="
    if command -v gatecheck >/dev/null 2>&1; then
        gatecheck < "$diff_file" || echo "[gh-portfolio] gatecheck flagged findings"
    else
        echo "[gh-portfolio] gatecheck not installed; skipping"
    fi

    echo
    echo "==== triple-review (issue gate) ===="
    if command -v triple-review >/dev/null 2>&1; then
        triple-review --falsify "$diff_file" || true
    else
        echo "[gh-portfolio] triple-review not installed; skipping"
    fi

    echo
    echo "==== pr-summary-mesh (narrative) ===="
    if command -v pr-summary-mesh >/dev/null 2>&1; then
        pr-summary-mesh --diff-file "$diff_file" --mode merge || true
    else
        echo "[gh-portfolio] pr-summary-mesh not installed; skipping"
    fi

    echo
    echo "==== flowtag (release readiness) ===="
    if command -v flowtag >/dev/null 2>&1; then
        local local_path="${GH_PORTFOLIO_CLONES:-$HOME/.gh-portfolio/clones}/${repo##*/}"
        if [ -d "$local_path/.git" ]; then
            (cd "$local_path" && flowtag --bump 2>/dev/null || echo "(no bump)")
        else
            echo "[gh-portfolio] no local clone of $repo (run gh-portfolio bump first)"
        fi
    else
        echo "[gh-portfolio] flowtag not installed; skipping"
    fi

    # Explicit cleanup — diff_file is local and out of scope when EXIT fires
    # on a normal return, so we remove it here as well.
    rm -f "$diff_file"
}
