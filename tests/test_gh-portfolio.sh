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

# 7. empty portfolio.toml — list returns empty, config shows blank owner
cat > "$GH_PORTFOLIO_CONFIG" <<EOF
[portfolio]
default_owner = ""
repos = []
EOF
out="$("$GH_PORTFOLIO" list)"
[ -z "$out" ] || fail "empty repos should produce no output, got: $out"
out="$("$GH_PORTFOLIO" config)"
[[ "$out" == *"default_owner: "* ]] || fail "config should print blank owner: $out"
pass "empty portfolio.toml"

# 8. malformed TOML (no repos key) — list returns empty, does not crash
cat > "$GH_PORTFOLIO_CONFIG" <<EOF
[portfolio]
default_owner = "octocat"
EOF
out="$("$GH_PORTFOLIO" list)"
[ -z "$out" ] || fail "missing repos key should produce no output, got: $out"
pass "malformed TOML (missing repos key)"

# 9. gh-not-on-PATH — status must exit 2 with a message
mkdir -p "$_test_home/bin"
# The shebang is `#!/usr/bin/env bash`; /usr/bin/env needs `bash` on PATH even
# when PATH is restricted to the fake dir. The symlink satisfies that lookup.
# gh is intentionally absent — that's what this test verifies.
ln -sf "$(command -v bash)" "$_test_home/bin/bash"
printf '#!/bin/sh\n' > "$_test_home/bin/jq"; chmod +x "$_test_home/bin/jq"
err=""
if err="$(PATH="$_test_home/bin" "$GH_PORTFOLIO" status 2>&1)"; then
    fail "status should fail when gh absent"
fi
[[ "$err" == *"'gh'"* ]] || fail "error should mention gh: $err"
pass "gh-not-on-PATH rejected"

# 10. jq-not-on-PATH — status must exit 2 with a message
mkdir -p "$_test_home/bin2"
# Same bash symlink rationale as test 9. jq is intentionally absent.
ln -sf "$(command -v bash)" "$_test_home/bin2/bash"
printf '#!/bin/sh\nexec true\n' > "$_test_home/bin2/gh"; chmod +x "$_test_home/bin2/gh"
err=""
if err="$(PATH="$_test_home/bin2" "$GH_PORTFOLIO" status 2>&1)"; then
    fail "status should fail when jq absent"
fi
[[ "$err" == *"'jq'"* ]] || fail "error should mention jq: $err"
pass "jq-not-on-PATH rejected"

# 12. legacy dotmoo config migration
rm -f "$GH_PORTFOLIO_CONFIG"
mkdir -p "$HOME/.dotmoo"
cat > "$HOME/.dotmoo/portfolio.toml" <<EOF
[portfolio]
default_owner = "legacy-owner"
repos = [ "migrated-repo" ]
EOF
err="$("$GH_PORTFOLIO" version 2>&1)"
[[ "$err" == *"migrat"* ]] || fail "migration message expected: $err"
[ -f "$GH_PORTFOLIO_CONFIG" ] || fail "config should be created via migration"
out="$("$GH_PORTFOLIO" list)"
[[ "$out" == *"migrated-repo"* ]] || fail "migrated repo not found: $out"
rm -f "$HOME/.dotmoo/portfolio.toml"
pass "legacy dotmoo config migration"

# 13. status --json rejects when owner unset (flag parsing tested without network)
# Use a controlled PATH with stub gh+jq so this test works on any platform
# (including minimal containers where the real gh may not be installed).
# awk and sed are system utilities needed by the TOML reader; symlink the real ones.
mkdir -p "$_test_home/bin13"
ln -sf "$(command -v bash)" "$_test_home/bin13/bash"
ln -sf "$(command -v awk)"  "$_test_home/bin13/awk"
ln -sf "$(command -v sed)"  "$_test_home/bin13/sed"
printf '#!/bin/sh\ntrue\n' > "$_test_home/bin13/gh";  chmod +x "$_test_home/bin13/gh"
printf '#!/bin/sh\ntrue\n' > "$_test_home/bin13/jq";  chmod +x "$_test_home/bin13/jq"
cat > "$GH_PORTFOLIO_CONFIG" <<EOF
[portfolio]
default_owner = ""
repos = [ "some-repo" ]
EOF
err=""
if err="$(PATH="$_test_home/bin13" "$GH_PORTFOLIO" status --json 2>&1)"; then
    fail "status --json should fail when owner unset"
fi
[[ "$err" == *"default_owner"* ]] || fail "status --json should mention default_owner: $err"
pass "status --json flag parsed (owner-unset guard fires correctly)"

echo "=== all smoke tests passed ==="
