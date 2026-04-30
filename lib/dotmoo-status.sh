# shellcheck shell=bash
# dotmoo status — table of CI/stars/issues for every configured repo.

cmd_status() {
    local owner repos
    owner="$(read_default_owner)"
    if [ -z "$owner" ]; then
        echo "[dotmoo] set [portfolio].default_owner in $DOTMOO_CONFIG" >&2
        return 2
    fi
    repos="$(read_repos)"
    if [ -z "$repos" ]; then
        echo "[dotmoo] no repos configured in $DOTMOO_CONFIG" >&2
        return 2
    fi

    printf "%-26s %-7s %-7s %-7s %-12s %s\n" "REPO" "STARS" "FORKS" "ISSUES" "LAST CI" "URL"
    printf "%-26s %-7s %-7s %-7s %-12s %s\n" "----" "-----" "-----" "------" "-------" "---"
    while IFS= read -r repo; do
        [ -z "$repo" ] && continue
        local meta ci_status
        meta="$(gh api "repos/$owner/$repo" 2>/dev/null || echo '')"
        if [ -z "$meta" ]; then
            printf "%-26s %s\n" "$repo" "(not found)"
            continue
        fi
        local stars forks issues url
        stars="$(printf '%s' "$meta" | sed -n 's/.*"stargazers_count":[[:space:]]*\([0-9]*\).*/\1/p' | head -1)"
        forks="$(printf '%s' "$meta" | sed -n 's/.*"forks_count":[[:space:]]*\([0-9]*\).*/\1/p' | head -1)"
        issues="$(printf '%s' "$meta" | sed -n 's/.*"open_issues_count":[[:space:]]*\([0-9]*\).*/\1/p' | head -1)"
        url="https://github.com/$owner/$repo"
        ci_status="$(gh run list --repo "$owner/$repo" --limit 1 --json conclusion -q '.[0].conclusion' 2>/dev/null || echo "")"
        [ -z "$ci_status" ] && ci_status="(no runs)"
        printf "%-26s %-7s %-7s %-7s %-12s %s\n" \
            "$repo" "${stars:-0}" "${forks:-0}" "${issues:-0}" "$ci_status" "$url"
    done <<< "$repos"
}
