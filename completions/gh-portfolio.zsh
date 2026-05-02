#compdef gh-portfolio
# zsh completion for gh-portfolio
# Drop in a directory on $fpath, e.g. /usr/local/share/zsh/site-functions/
# or source directly:
#
#   source completions/gh-portfolio.zsh
#
# Permanent (user):
#   echo 'fpath=($(brew --prefix)/share/gh-portfolio/completions $fpath)' >> ~/.zshrc
#   autoload -Uz compinit && compinit

_gh_portfolio_repos() {
    local config="${GH_PORTFOLIO_CONFIG:-$HOME/.gh-portfolio/portfolio.toml}"
    local repos=()
    if [[ -f "$config" ]]; then
        while IFS= read -r line; do
            repos+=("$line")
        done < <(awk '
            /^[[:space:]]*repos[[:space:]]*=[[:space:]]*\[/ { in_arr=1; next }
            in_arr && /\]/ { in_arr=0; next }
            in_arr {
                gsub(/[ \t",]/, "")
                gsub(/#.*/, "")
                if (length($0) > 0) print $0
            }
        ' "$config")
    fi
    echo "${repos[@]}"
}

_gh_portfolio_owner() {
    local config="${GH_PORTFOLIO_CONFIG:-$HOME/.gh-portfolio/portfolio.toml}"
    awk -F'=' '/^[[:space:]]*default_owner[[:space:]]*=/{v=$2; gsub(/^[ \t"]+|[ \t"]+$/,"",v); print v; exit}' \
        "$config" 2>/dev/null
}

_gh_portfolio() {
    local state line
    typeset -A opt_args

    _arguments -C \
        '1: :->subcmd' \
        '*: :->args' && return 0

    case "$state" in
        subcmd)
            local subcommands=(
                'status:table of CI/stars/issues across configured repos'
                'bump:fan-out flowtag --next-version across repos'
                'audit:run triple-review on a PR or all open PRs'
                'summary:run pr-summary-mesh on a single PR'
                'cycle:full chain: gatecheck → triple-review → pr-summary-mesh → flowtag'
                'list:print configured repo list'
                'config:print resolved config + path'
                'version:print gh-portfolio version'
                'help:print usage'
            )
            _describe 'subcommand' subcommands
            ;;
        args)
            local subcmd="${line[1]}"
            case "$subcmd" in
                status)
                    _arguments '--json[emit JSON array instead of table]'
                    ;;
                bump)
                    _arguments '--apply[actually write changelogs (default is dry-run)]'
                    ;;
                audit)
                    local owner repos target_list=()
                    owner="$(_gh_portfolio_owner)"
                    while IFS= read -r r; do
                        [[ -n "$r" ]] && target_list+=("${owner:+$owner/}$r")
                    done < <(_gh_portfolio_repos)
                    _arguments \
                        '--all[audit every open PR across configured repos]' \
                        "1: :(${target_list[*]})"
                    ;;
                summary)
                    local owner target_list=()
                    owner="$(_gh_portfolio_owner)"
                    while IFS= read -r r; do
                        [[ -n "$r" ]] && target_list+=("${owner:+$owner/}$r")
                    done < <(_gh_portfolio_repos)
                    _arguments \
                        "1: :(${target_list[*]})" \
                        '--mode[merge mode]:mode:(merge squash rebase vote)'
                    ;;
                cycle)
                    local owner target_list=()
                    owner="$(_gh_portfolio_owner)"
                    while IFS= read -r r; do
                        [[ -n "$r" ]] && target_list+=("${owner:+$owner/}$r")
                    done < <(_gh_portfolio_repos)
                    _arguments "1: :(${target_list[*]})"
                    ;;
            esac
            ;;
    esac
}

_gh_portfolio "$@"
