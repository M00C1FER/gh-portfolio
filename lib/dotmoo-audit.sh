# shellcheck shell=bash
# dotmoo audit — run triple-review on a PR (or all open PRs in --all mode).

cmd_audit() {
    local target="${1:-}"
    if [ -z "$target" ]; then
        echo "Usage: dotmoo audit owner/repo#42" >&2
        echo "       dotmoo audit --all       (every open PR across configured repos)" >&2
        return 2
    fi
    if ! command -v triple-review >/dev/null 2>&1; then
        echo "[dotmoo] triple-review not on PATH (install: https://github.com/M00C1FER/triple-review)" >&2
        return 2
    fi

    if [ "$target" = "--all" ]; then
        local owner; owner="$(read_default_owner)"
        local repos; repos="$(read_repos)"
        while IFS= read -r repo; do
            [ -z "$repo" ] && continue
            local prs
            prs="$(gh pr list --repo "$owner/$repo" --state open --json number -q '.[].number' 2>/dev/null || true)"
            while IFS= read -r n; do
                [ -z "$n" ] && continue
                echo "==== $owner/$repo#$n ===="
                gh pr diff "$n" --repo "$owner/$repo" \
                    | (cd /tmp && cat > "/tmp/pr-$$.diff" && triple-review --falsify "/tmp/pr-$$.diff") || true
                rm -f "/tmp/pr-$$.diff"
            done <<< "$prs"
        done <<< "$repos"
        return 0
    fi

    # Single PR: owner/repo#42
    local repo pr
    repo="${target%#*}"; pr="${target##*#}"
    if [ -z "$repo" ] || [ -z "$pr" ] || [ "$repo" = "$pr" ]; then
        echo "[dotmoo] expected owner/repo#N, got: $target" >&2
        return 2
    fi
    local diff_file
    diff_file="$(mktemp -t dotmoo-audit-XXXXXX.diff)"
    gh pr diff "$pr" --repo "$repo" > "$diff_file"
    triple-review --falsify "$diff_file"
    rm -f "$diff_file"
}
