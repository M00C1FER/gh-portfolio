# bash completion for gh-portfolio
# Source this file or drop it in /etc/bash_completion.d/
#
#   # one-shot (current session only):
#   source completions/gh-portfolio.bash
#
#   # permanent (user):
#   echo 'source /usr/local/share/gh-portfolio/completions/gh-portfolio.bash' >> ~/.bashrc

_gh_portfolio_repos() {
    local config="${GH_PORTFOLIO_CONFIG:-$HOME/.gh-portfolio/portfolio.toml}"
    if [ -f "$config" ]; then
        awk '
            /^[[:space:]]*repos[[:space:]]*=[[:space:]]*\[/ { in_arr=1; next }
            in_arr && /\]/ { in_arr=0; next }
            in_arr {
                gsub(/[ \t",]/, "")
                gsub(/#.*/, "")
                if (length($0) > 0) print $0
            }
        ' "$config"
    fi
}

_gh_portfolio() {
    local cur prev words cword
    _init_completion 2>/dev/null || {
        COMPREPLY=()
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        words=("${COMP_WORDS[@]}")
        cword="$COMP_CWORD"
    }

    local subcommands="status bump audit summary cycle list config version help"

    if [ "$cword" -eq 1 ]; then
        # Complete subcommand
        mapfile -t COMPREPLY < <(compgen -W "$subcommands" -- "$cur")
        return 0
    fi

    local subcmd="${words[1]}"
    case "$subcmd" in
        status)
            mapfile -t COMPREPLY < <(compgen -W "--json" -- "$cur")
            ;;
        bump)
            mapfile -t COMPREPLY < <(compgen -W "--apply" -- "$cur")
            ;;
        audit)
            if [ "$cword" -eq 2 ]; then
                local owner repo_list=""
                owner="$(awk -F'=' '/^[[:space:]]*default_owner[[:space:]]*=/{v=$2; gsub(/^[ \t"]+|[ \t"]+$/,"",v); print v; exit}' \
                    "${GH_PORTFOLIO_CONFIG:-$HOME/.gh-portfolio/portfolio.toml}" 2>/dev/null)"
                while IFS= read -r r; do
                    [ -n "$r" ] && repo_list="$repo_list ${owner:+$owner/}$r"
                done < <(_gh_portfolio_repos)
                mapfile -t COMPREPLY < <(compgen -W "--all $repo_list" -- "$cur")
            fi
            ;;
        summary)
            if [ "$cword" -eq 2 ]; then
                local owner repo_list=""
                owner="$(awk -F'=' '/^[[:space:]]*default_owner[[:space:]]*=/{v=$2; gsub(/^[ \t"]+|[ \t"]+$/,"",v); print v; exit}' \
                    "${GH_PORTFOLIO_CONFIG:-$HOME/.gh-portfolio/portfolio.toml}" 2>/dev/null)"
                while IFS= read -r r; do
                    [ -n "$r" ] && repo_list="$repo_list ${owner:+$owner/}$r"
                done < <(_gh_portfolio_repos)
                mapfile -t COMPREPLY < <(compgen -W "$repo_list" -- "$cur")
            elif [ "$prev" = "--mode" ]; then
                mapfile -t COMPREPLY < <(compgen -W "merge squash rebase vote" -- "$cur")
            else
                mapfile -t COMPREPLY < <(compgen -W "--mode" -- "$cur")
            fi
            ;;
        cycle)
            if [ "$cword" -eq 2 ]; then
                local owner repo_list=""
                owner="$(awk -F'=' '/^[[:space:]]*default_owner[[:space:]]*=/{v=$2; gsub(/^[ \t"]+|[ \t"]+$/,"",v); print v; exit}' \
                    "${GH_PORTFOLIO_CONFIG:-$HOME/.gh-portfolio/portfolio.toml}" 2>/dev/null)"
                while IFS= read -r r; do
                    [ -n "$r" ] && repo_list="$repo_list ${owner:+$owner/}$r"
                done < <(_gh_portfolio_repos)
                mapfile -t COMPREPLY < <(compgen -W "$repo_list" -- "$cur")
            fi
            ;;
    esac
    return 0
}

complete -F _gh_portfolio gh-portfolio
