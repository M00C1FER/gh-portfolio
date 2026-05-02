# shellcheck shell=bash
# gh-portfolio status — table of CI/stars/issues for every configured repo.
# Options:
#   --json   emit a JSON array instead of the human-readable table

cmd_status() {
    local json_mode=0
    if [ "${1:-}" = "--json" ]; then
        json_mode=1
        shift
    fi

    local owner repos
    owner="$(read_default_owner)"
    if [ -z "$owner" ]; then
        echo "[gh-portfolio] set [portfolio].default_owner in $GH_PORTFOLIO_CONFIG" >&2
        return 2
    fi
    repos="$(read_repos)"
    if [ -z "$repos" ]; then
        echo "[gh-portfolio] no repos configured in $GH_PORTFOLIO_CONFIG" >&2
        return 2
    fi

    if [ "$json_mode" -eq 1 ]; then
        local first=1
        printf '[\n'
        while IFS= read -r repo; do
            [ -z "$repo" ] && continue
            local meta ci_status stars forks issues url
            meta="$(gh api "repos/$owner/$repo" 2>/dev/null || echo '')"
            if [ -z "$meta" ]; then
                stars=0; forks=0; issues=0; ci_status="not_found"
            else
                stars="$(printf '%s' "$meta" | jq -r '.stargazers_count // 0' 2>/dev/null)"
                forks="$(printf '%s' "$meta" | jq -r '.forks_count // 0' 2>/dev/null)"
                issues="$(printf '%s' "$meta" | jq -r '.open_issues_count // 0' 2>/dev/null)"
                ci_status="$(gh run list --repo "$owner/$repo" --limit 1 --json conclusion \
                    -q 'if length == 0 then "no_runs" else (.[0].conclusion // "no_runs") end' \
                    2>/dev/null || echo "no_runs")"
                [ -z "$ci_status" ] && ci_status="no_runs"
            fi
            url="https://github.com/$owner/$repo"
            [ "$first" -eq 1 ] || printf ',\n'
            first=0
            printf '  {"name":"%s","stargazers_count":%s,"forks_count":%s,"open_issues_count":%s,"last_ci":"%s","url":"%s"}' \
                "$repo" "${stars:-0}" "${forks:-0}" "${issues:-0}" "$ci_status" "$url"
        done <<< "$repos"
        printf '\n]\n'
        return 0
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
        stars="$(printf '%s' "$meta" | jq -r '.stargazers_count // 0' 2>/dev/null)"
        forks="$(printf '%s' "$meta" | jq -r '.forks_count // 0' 2>/dev/null)"
        issues="$(printf '%s' "$meta" | jq -r '.open_issues_count // 0' 2>/dev/null)"
        url="https://github.com/$owner/$repo"
        ci_status="$(gh run list --repo "$owner/$repo" --limit 1 --json conclusion \
            -q 'if length == 0 then "(no runs)" else (.[0].conclusion // "(no runs)") end' \
            2>/dev/null || echo "")"
        [ -z "$ci_status" ] && ci_status="(no runs)"
        printf "%-26s %-7s %-7s %-7s %-12s %s\n" \
            "$repo" "${stars:-0}" "${forks:-0}" "${issues:-0}" "$ci_status" "$url"
    done <<< "$repos"
}
