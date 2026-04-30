#!/usr/bin/env bash
# Smoke tests for dotmoo — runs against a temp HOME so it doesn't touch real config.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
DOTMOO="$ROOT/bin/dotmoo"

export HOME="$(mktemp -d)"
export DOTMOO_CONFIG="$HOME/.dotmoo/portfolio.toml"
export DOTMOO_LIB="$ROOT/lib"

pass() { echo "  PASS  $1"; }
fail() { echo "  FAIL  $1"; exit 1; }

echo "=== dotmoo smoke tests ==="

# 1. autocreate config on first run (any command triggers ensure_config)
[ ! -f "$DOTMOO_CONFIG" ] || fail "config should not exist before first run"
out="$("$DOTMOO" version)"
[[ "$out" == *"dotmoo "* ]] || fail "version output: $out"
[ -f "$DOTMOO_CONFIG" ] || fail "config should be created on first run"
pass "version + config bootstrap"

# 3. config readback with seeded values
cat > "$DOTMOO_CONFIG" <<EOF
[portfolio]
default_owner = "octocat"
repos = [
    "hello-world",
    "spoon-knife",
]
EOF
out="$("$DOTMOO" list)"
[[ "$out" == *"hello-world"* ]] || fail "list missing hello-world: $out"
[[ "$out" == *"spoon-knife"* ]] || fail "list missing spoon-knife: $out"
pass "list reads repos"

out="$("$DOTMOO" config)"
[[ "$out" == *"default_owner: octocat"* ]] || fail "config missing owner: $out"
pass "config prints owner"

# 4. TOML array — single-line layout
cat > "$DOTMOO_CONFIG" <<EOF
[portfolio]
default_owner = "octocat"
repos = [ "alpha", "bravo" ]
EOF
out="$("$DOTMOO" list)"
[[ "$out" == *"alpha"* ]] || fail "single-line TOML missed alpha: $out"
[[ "$out" == *"bravo"* ]] || fail "single-line TOML missed bravo: $out"
pass "TOML array — single line"

# 4b. TOML array — mixed layout (first item on opener line)
cat > "$DOTMOO_CONFIG" <<EOF
[portfolio]
default_owner = "octocat"
repos = [ "first",
    "second",
    "third" ]
EOF
out="$("$DOTMOO" list)"
[[ "$out" == *"first"* ]] || fail "mixed TOML missed first: $out"
[[ "$out" == *"second"* ]] || fail "mixed TOML missed second: $out"
[[ "$out" == *"third"* ]] || fail "mixed TOML missed third: $out"
pass "TOML array — mixed layout"

# 5. unknown command exits 2
if "$DOTMOO" no-such-command >/dev/null 2>&1; then
    fail "unknown command should exit non-zero"
fi
pass "unknown command rejected"

# 5. help works without args
out="$("$DOTMOO" help)"
[[ "$out" == *"dotmoo"* ]] || fail "help should mention dotmoo: $out"
pass "help"

echo "=== all smoke tests passed ==="
