#!/usr/bin/env bash
# dotmoo — interactive install wizard.
set -euo pipefail

if [ -t 1 ]; then C_BOLD="$(tput bold)"; C_RESET="$(tput sgr0)"; C_GREEN="$(tput setaf 2)"; C_YELLOW="$(tput setaf 3)"; C_RED="$(tput setaf 1)"; else C_BOLD=""; C_RESET=""; C_GREEN=""; C_YELLOW=""; C_RED=""; fi
say()  { printf "%s%s%s\n" "$C_BOLD" "$1" "$C_RESET"; }
info() { printf "  %s\n" "$1"; }
ok()   { printf "  %s✓%s %s\n" "$C_GREEN" "$C_RESET" "$1"; }
warn() { printf "  %s!%s %s\n" "$C_YELLOW" "$C_RESET" "$1"; }
fail() { printf "  %s✗%s %s\n" "$C_RED" "$C_RESET" "$1" >&2; exit 1; }
prompt_yn() { local q="$1" def="${2:-y}" ans; if [ "$def" = "y" ]; then read -r -p "  $q [Y/n]: " ans; ans="${ans:-y}"; else read -r -p "  $q [y/N]: " ans; ans="${ans:-n}"; fi; [[ "$ans" =~ ^[Yy] ]]; }
prompt_default() { read -r -p "  $1 [$2]: " ans; echo "${ans:-$2}"; }

detect_os() { OS_ID=unknown; OS_LIKE=""; OS_VERSION=""; OS_WSL=0; [ -f /etc/os-release ] && { . /etc/os-release; OS_ID="${ID:-}"; OS_LIKE="${ID_LIKE:-}"; OS_VERSION="${VERSION_ID:-}"; }; [ "$(uname)" = "Darwin" ] && OS_ID=macos; grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null && OS_WSL=1 || true; }
pkg_install() {
    case "$OS_ID" in
        debian|ubuntu) sudo apt-get update -qq && sudo apt-get install -y "$@";;
        fedora|rhel|centos) sudo dnf install -y "$@";;
        arch|manjaro) sudo pacman -S --noconfirm "$@";;
        alpine) sudo apk add --no-cache "$@";;
        opensuse*|sles) sudo zypper install -y "$@";;
        macos) brew install "$@";;
        *) warn "unknown OS — install manually: $*"; return 1;;
    esac
}

main() {
    say "dotmoo — install wizard (pure Bash, no compiler needed)"
    detect_os
    info "OS: ${OS_ID}${OS_VERSION:+ $OS_VERSION}$([ "$OS_WSL" = 1 ] && echo ' (WSL2)')"

    say ""; say "Step 1/4: Required tools"
    if ! command -v gh >/dev/null; then
        warn "gh CLI not found"
        if prompt_yn "Install gh via system package manager?" y; then
            case "$OS_ID" in
                debian|ubuntu)
                    # GitHub's apt repo is required for current gh
                    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
                    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
                    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
                    sudo apt-get update -qq && sudo apt-get install -y gh;;
                fedora|rhel|centos) sudo dnf install -y gh;;
                arch|manjaro) sudo pacman -S --noconfirm github-cli;;
                alpine) sudo apk add --no-cache github-cli;;
                opensuse*|sles) sudo zypper install -y gh;;
                macos) brew install gh;;
                *) fail "install gh manually: https://cli.github.com/";;
            esac
        else fail "gh CLI required"; fi
    fi
    ok "gh: $(gh --version | head -1)"
    command -v jq >/dev/null || pkg_install jq || warn "jq optional — install for prettier output"
    command -v git >/dev/null || pkg_install git || fail "git required"

    say ""; say "Step 2/4: Install dotmoo files"
    local BIN_DIR LIB_DIR
    BIN_DIR="$(prompt_default "Binary directory (must be in \$PATH)" "$HOME/.local/bin")"
    LIB_DIR="$(prompt_default "Library directory" "$HOME/.local/share/dotmoo")"
    mkdir -p "$BIN_DIR" "$LIB_DIR/lib"
    local INSTALL_HOME="$HOME/.local/share/dotmoo-src"
    if [ -d "$INSTALL_HOME/.git" ]; then ( cd "$INSTALL_HOME" && git pull -q ); else git clone -q https://github.com/M00C1FER/dotmoo.git "$INSTALL_HOME"; fi
    cp "$INSTALL_HOME/bin/dotmoo" "$BIN_DIR/dotmoo"
    cp -r "$INSTALL_HOME/lib/." "$LIB_DIR/lib/"
    chmod +x "$BIN_DIR/dotmoo"
    # Patch the launcher to know where lib lives, regardless of how it was invoked
    sed -i.bak "s|^DOTMOO_LIB=.*|DOTMOO_LIB=\"\${DOTMOO_LIB:-$LIB_DIR/lib}\"|" "$BIN_DIR/dotmoo"
    rm -f "$BIN_DIR/dotmoo.bak"
    ok "installed → $BIN_DIR/dotmoo"

    say ""; say "Step 3/4: Configure portfolio.toml"
    local owner repos_in
    owner="$(prompt_default "Default GitHub owner/org" "$(gh api user -q .login 2>/dev/null || echo '')")"
    repos_in="$(prompt_default "Repos (comma-separated; leave empty to edit later)" "")"
    mkdir -p "$HOME/.dotmoo"
    {
        echo "[portfolio]"
        echo "default_owner = \"$owner\""
        echo "repos = ["
        if [ -n "$repos_in" ]; then
            IFS=',' read -ra arr <<< "$repos_in"
            for r in "${arr[@]}"; do echo "    \"$(echo "$r" | xargs)\","; done
        else
            echo "    # add repo names here"
        fi
        echo "]"
    } > "$HOME/.dotmoo/portfolio.toml"
    ok "wrote $HOME/.dotmoo/portfolio.toml"

    say ""; say "Step 4/4: Verify"
    "$BIN_DIR/dotmoo" version
    info ""
    info "Try: dotmoo status"
}
main "$@"
