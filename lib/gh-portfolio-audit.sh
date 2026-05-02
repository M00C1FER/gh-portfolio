# shellcheck shell=bash
# gh-portfolio audit — run triple-review on a PR (or all open PRs in --all mode).

cmd_audit() {
    local target="${1:-}"
    if [ -z "$target" ]; then
        echo "Usage: gh-portfolio audit owner/repo#42" >&2
        echo "       gh-portfolio audit --all       (every open PR across configured repos)" >&2
        return 2
    fi
    if ! command -v triple-review >/dev/null 2>&1; then
        echo "[gh-portfolio] triple-review not on PATH (install: https://github.com/M00C1FER/triple-review)" >&2
        return 2
    fi

    # Track every temp file we create so we can clean them up explicitly.
    # We still register an EXIT trap as a safety net for abnormal exits
    # (signal, set -e mid-loop), but we also rm files explicitly before
    # returning so they are cleaned up even when the function exits normally
    # (at which point local variables are already out of scope for the trap).
    local -a __tmpfiles=()
    # shellcheck disable=SC2064  # intentional: trap fires while __tmpfiles is still in scope on abnormal exit
    trap 'for __tf in "${__tmpfiles[@]+"${__tmpfiles[@]}"}"; do rm -f "$__tf"; done' EXIT

    if [ "$target" = "--all" ]; then
        local owner; owner="$(read_default_owner)"
        if [ -z "$owner" ]; then
            echo "[gh-portfolio] error: default_owner not set. Edit $GH_PORTFOLIO_CONFIG and set default_owner." >&2
            return 2
        fi
        local repos; repos="$(read_repos)"
        while IFS= read -r repo; do
            [ -z "$repo" ] && continue
            local prs
            prs="$(gh pr list --repo "$owner/$repo" --state open --json number -q '.[].number' 2>/dev/null || true)"
            while IFS= read -r n; do
                [ -z "$n" ] && continue
                echo "==== $owner/$repo#$n ===="
                local diff_file
                diff_file="$(mktemp -t gh-portfolio-audit-XXXXXX.diff)"
                __tmpfiles+=("$diff_file")
                if gh pr diff "$n" --repo "$owner/$repo" > "$diff_file"; then
                    triple-review --falsify "$diff_file" || true
                fi
            done <<< "$prs"
        done <<< "$repos"
        # Explicit cleanup — local array goes out of scope after return so the
        # EXIT trap cannot reach these files on a normal exit.
        for __tf in "${__tmpfiles[@]+"${__tmpfiles[@]}"}"; do rm -f "$__tf"; done
        return 0
    fi

    # Single PR: owner/repo#42
    local repo pr
    repo="${target%#*}"; pr="${target##*#}"
    if [ -z "$repo" ] || [ -z "$pr" ] || [ "$repo" = "$pr" ]; then
        echo "[gh-portfolio] expected owner/repo#N, got: $target" >&2
        return 2
    fi
    if ! [[ "$pr" =~ ^[0-9]+$ ]]; then
        echo "[gh-portfolio] error: PR number must be an integer, got: '$pr'" >&2; return 2
    fi
    local diff_file
    diff_file="$(mktemp -t gh-portfolio-audit-XXXXXX.diff)"
    __tmpfiles+=("$diff_file")
    gh pr diff "$pr" --repo "$repo" > "$diff_file"
    triple-review --falsify "$diff_file"
    # Explicit cleanup — see comment above.
    rm -f "$diff_file"
}
