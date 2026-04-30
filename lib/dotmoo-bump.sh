# shellcheck shell=bash
# dotmoo bump — fan out `flowtag --next-version` across configured repos.
# Read-only by default; pass `--apply` to actually write changelogs.

cmd_bump() {
    local apply=0
    [ "${1:-}" = "--apply" ] && apply=1

    if ! command -v flowtag >/dev/null 2>&1; then
        echo "[dotmoo] flowtag not on PATH (install: https://github.com/M00C1FER/flowtag)" >&2
        return 2
    fi

    local owner; owner="$(read_default_owner)"
    local repos; repos="$(read_repos)"
    [ -z "$repos" ] && { echo "[dotmoo] no repos configured" >&2; return 2; }

    local clones_root="${DOTMOO_CLONES:-$HOME/.dotmoo/clones}"
    mkdir -p "$clones_root"

    while IFS= read -r repo; do
        [ -z "$repo" ] && continue
        local local_path="$clones_root/$repo"
        if [ ! -d "$local_path/.git" ]; then
            echo "[dotmoo] cloning $owner/$repo …"
            gh repo clone "$owner/$repo" "$local_path" -- -q || continue
        fi
        ( cd "$local_path" && git fetch -q --tags )
        local kind nv
        kind="$(cd "$local_path" && flowtag --bump 2>/dev/null || echo unknown)"
        nv="$(cd "$local_path" && flowtag --next-version 2>/dev/null || echo unknown)"
        printf "%-26s bump=%-6s next=%s\n" "$repo" "$kind" "$nv"
        if [ "$apply" -eq 1 ] && [ "$kind" != "none" ] && [ "$kind" != "unknown" ]; then
            ( cd "$local_path" && flowtag --write-changelog ) || true
        fi
    done <<< "$repos"
}
