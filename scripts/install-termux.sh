#!/usr/bin/env bash
# scripts/install-termux.sh — install gh-portfolio on Termux (Android, arm64).
#
# Usage (from a Termux session):
#   bash <(curl -fsSL https://raw.githubusercontent.com/M00C1FER/gh-portfolio/main/scripts/install-termux.sh)
#
# Requirements:
#   - Termux (com.termux) with the bootstrap packages already installed
#   - Internet access for pkg commands
#
# What this does:
#   1. Installs runtime deps: bash, gh, jq, git
#   2. Clones gh-portfolio into ~/.local/share/gh-portfolio-src
#   3. Installs the launcher into ~/bin/gh-portfolio
#   4. Patches the launcher to find lib/ at the install path
#   5. Creates ~/.gh-portfolio/portfolio.toml if absent
#
# Caveats:
#   - Termux's HOME is /data/data/com.termux/files/home. The config path
#     (~/.gh-portfolio/portfolio.toml) resolves correctly there because $HOME
#     is already set by Termux.
#   - 'sudo' is not available in Termux; we install into ~/bin (Termux adds
#     this to $PATH automatically via ~/.bashrc / the Termux PATH).
#   - If you see "cannot execute binary file" for gh, ensure you installed the
#     arm64 build (pkg install gh pulls the correct arch).

set -euo pipefail

# ── Helpers ──────────────────────────────────────────────────────────────────
say()  { printf "\033[1m%s\033[0m\n" "$1"; }
ok()   { printf "  \033[32m✓\033[0m %s\n" "$1"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$1"; }
fail() { printf "  \033[31m✗\033[0m %s\n" "$1" >&2; exit 1; }

# Termux guard: ~/bin is the user-writable bin dir; ~/usr/bin also works.
BIN_DIR="${HOME}/bin"
LIB_DIR="${HOME}/.local/share/gh-portfolio"
SRC_DIR="${HOME}/.local/share/gh-portfolio-src"

# ── Step 1: Verify we're in Termux ───────────────────────────────────────────
if [ -z "${TERMUX_VERSION:-}" ] && [ ! -d "/data/data/com.termux" ]; then
    warn "TERMUX_VERSION not set and /data/data/com.termux not found."
    warn "This script is intended for Termux. Proceeding anyway…"
fi

say "gh-portfolio — Termux install"

# ── Step 2: Install deps via pkg ─────────────────────────────────────────────
say ""
say "Step 1/4: Installing runtime dependencies (bash, gh, jq, git)"
pkg install -y bash gh jq git
ok "deps installed"

# ── Step 3: Clone / update gh-portfolio ──────────────────────────────────────
say ""
say "Step 2/4: Cloning gh-portfolio"
if [ -d "$SRC_DIR/.git" ]; then
    ( cd "$SRC_DIR" && git pull -q )
    ok "updated $SRC_DIR"
else
    git clone -q https://github.com/M00C1FER/gh-portfolio.git "$SRC_DIR"
    ok "cloned → $SRC_DIR"
fi

# ── Step 4: Install files ─────────────────────────────────────────────────────
say ""
say "Step 3/4: Installing launcher and libraries"
mkdir -p "$BIN_DIR" "$LIB_DIR/lib"
cp "$SRC_DIR/bin/gh-portfolio" "$BIN_DIR/gh-portfolio"
cp -r "$SRC_DIR/lib/." "$LIB_DIR/lib/"
chmod +x "$BIN_DIR/gh-portfolio"
# Patch the lib path so the launcher always finds lib/, regardless of cwd.
sed -i "s|^GH_PORTFOLIO_LIB=.*|GH_PORTFOLIO_LIB=\"\${GH_PORTFOLIO_LIB:-$LIB_DIR/lib}\"|" \
    "$BIN_DIR/gh-portfolio"
ok "installed → $BIN_DIR/gh-portfolio"

# ── Step 5: Bootstrap config ──────────────────────────────────────────────────
say ""
say "Step 4/4: Bootstrapping config"
if [ ! -f "${HOME}/.gh-portfolio/portfolio.toml" ]; then
    "$BIN_DIR/gh-portfolio" version >/dev/null   # triggers ensure_config
fi
ok "config at ~/.gh-portfolio/portfolio.toml"

# ── Done ──────────────────────────────────────────────────────────────────────
say ""
say "Installation complete!"
printf "  Version: %s\n" "$("$BIN_DIR/gh-portfolio" version)"
printf "\nNext steps:\n"
printf "  1. Authenticate:  gh auth login\n"
printf "  2. Edit config:   \$EDITOR ~/.gh-portfolio/portfolio.toml\n"
printf "  3. Check status:  gh-portfolio status\n"
printf "\nIf ~/bin is not in \$PATH, add to ~/.bashrc:\n"
printf "  export PATH=\"\$HOME/bin:\$PATH\"\n"
