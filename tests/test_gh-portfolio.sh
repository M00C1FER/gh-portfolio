#!/usr/bin/env bash
# Smoke tests for gh-portfolio — runs against a temp HOME so it doesn't touch real config.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
GH_PORTFOLIO="$ROOT/bin/gh-portfolio"

_test_home="$(mktemp -d)"
export HOME="$_test_home"
trap 'rm -rf "$_test_home"' EXIT
export GH_PORTFOLIO_CONFIG="$HOME/.gh-portfolio/portfolio.toml"
export GH_PORTFOLIO_LIB="$ROOT/lib"

pass() { echo "  PASS  $1"; }
fail() { echo "  FAIL  $1"; exit 1; }

echo "=== gh-portfolio smoke tests ==="

# 1. autocreate config on first run (any command triggers ensure_config)
[ ! -f "$GH_PORTFOLIO_CONFIG" ] || fail "config should not exist before first run"
out="$("$GH_PORTFOLIO" version)"
[[ "$out" == *"gh-portfolio "* ]] || fail "version output: $out"
[ -f "$GH_PORTFOLIO_CONFIG" ] || fail "config should be created on first run"
pass "version + config bootstrap"

# 2. config readback with seeded values
cat > "$GH_PORTFOLIO_CONFIG" <<EOF
[portfolio]
default_owner = "octocat"
repos = [
    "hello-world",
    "spoon-knife",
]
EOF
out="$("$GH_PORTFOLIO" list)"
[[ "$out" == *"hello-world"* ]] || fail "list missing hello-world: $out"
[[ "$out" == *"spoon-knife"* ]] || fail "list missing spoon-knife: $out"
pass "list reads repos"

out="$("$GH_PORTFOLIO" config)"
[[ "$out" == *"default_owner: octocat"* ]] || fail "config missing owner: $out"
pass "config prints owner"

# 3. TOML array — single-line layout
cat > "$GH_PORTFOLIO_CONFIG" <<EOF
[portfolio]
default_owner = "octocat"
repos = [ "alpha", "bravo" ]
EOF
out="$("$GH_PORTFOLIO" list)"
[[ "$out" == *"alpha"* ]] || fail "single-line TOML missed alpha: $out"
[[ "$out" == *"bravo"* ]] || fail "single-line TOML missed bravo: $out"
pass "TOML array — single line"

# 4. TOML array — mixed layout (first item on opener line)
cat > "$GH_PORTFOLIO_CONFIG" <<EOF
[portfolio]
default_owner = "octocat"
repos = [ "first",
    "second",
    "third" ]
EOF
out="$("$GH_PORTFOLIO" list)"
[[ "$out" == *"first"* ]] || fail "mixed TOML missed first: $out"
[[ "$out" == *"second"* ]] || fail "mixed TOML missed second: $out"
[[ "$out" == *"third"* ]] || fail "mixed TOML missed third: $out"
pass "TOML array — mixed layout"

# 5. unknown command exits 2
if "$GH_PORTFOLIO" no-such-command >/dev/null 2>&1; then
    fail "unknown command should exit non-zero"
fi
pass "unknown command rejected"

# 6. help works without args
out="$("$GH_PORTFOLIO" help)"
[[ "$out" == *"gh-portfolio"* ]] || fail "help should mention gh-portfolio: $out"
pass "help"

echo "=== all smoke tests passed ==="
