#!/usr/bin/env bats
# bats-core smoke tests for gh-portfolio.
# Run:  bats tests/test_gh-portfolio.bats
# Deps: bats-core >= 1.2  (apt install bats / brew install bats-core / apk add bats)
#
# Tests run against an isolated $HOME so they never touch a real config.

GH_PORTFOLIO="${BATS_TEST_DIRNAME}/../bin/gh-portfolio"
export GH_PORTFOLIO_LIB="${BATS_TEST_DIRNAME}/../lib"

setup() {
    _test_home="$(mktemp -d)"
    export HOME="$_test_home"
    export GH_PORTFOLIO_CONFIG="$HOME/.gh-portfolio/portfolio.toml"

    # Stub dirs for restricted-PATH tests.
    _stub_no_gh="$_test_home/stub_no_gh"
    _stub_no_jq="$_test_home/stub_no_jq"
    _stub_owner_guard="$_test_home/stub_owner_guard"

    mkdir -p "$_stub_no_gh" "$_stub_no_jq" "$_stub_owner_guard"

    # stub_no_gh: bash + fake jq + infra utils (mkdir/cat for ensure_config), no gh
    ln -sf "$(command -v bash)"  "$_stub_no_gh/bash"
    ln -sf "$(command -v mkdir)" "$_stub_no_gh/mkdir"
    ln -sf "$(command -v cat)"   "$_stub_no_gh/cat"
    printf '#!/bin/sh\n' > "$_stub_no_gh/jq"; chmod +x "$_stub_no_gh/jq"

    # stub_no_jq: bash + fake gh + infra utils, no jq
    ln -sf "$(command -v bash)"  "$_stub_no_jq/bash"
    ln -sf "$(command -v mkdir)" "$_stub_no_jq/mkdir"
    ln -sf "$(command -v cat)"   "$_stub_no_jq/cat"
    printf '#!/bin/sh\nexec true\n' > "$_stub_no_jq/gh"; chmod +x "$_stub_no_jq/gh"

    # stub_owner_guard: bash + no-op gh/jq + real awk/sed/mkdir/cat for TOML reader
    ln -sf "$(command -v bash)"  "$_stub_owner_guard/bash"
    ln -sf "$(command -v awk)"   "$_stub_owner_guard/awk"
    ln -sf "$(command -v sed)"   "$_stub_owner_guard/sed"
    ln -sf "$(command -v mkdir)" "$_stub_owner_guard/mkdir"
    ln -sf "$(command -v cat)"   "$_stub_owner_guard/cat"
    printf '#!/bin/sh\nexec true\n' > "$_stub_owner_guard/gh"; chmod +x "$_stub_owner_guard/gh"
    printf '#!/bin/sh\nexec true\n' > "$_stub_owner_guard/jq"; chmod +x "$_stub_owner_guard/jq"
}

teardown() {
    rm -rf "$_test_home"
}

# Helper: write config file (creates the parent dir if needed)
_write_config() {
    mkdir -p "$(dirname "$GH_PORTFOLIO_CONFIG")"
    cat > "$GH_PORTFOLIO_CONFIG"
}

# -- 1. version + config bootstrap --------------------------------------------
@test "version command prints version and bootstraps config" {
    [ ! -f "$GH_PORTFOLIO_CONFIG" ]
    run "$GH_PORTFOLIO" version
    [ "$status" -eq 0 ]
    [[ "$output" == *"gh-portfolio "* ]]
    [ -f "$GH_PORTFOLIO_CONFIG" ]
}

# -- 2. list reads repos from multi-line TOML ---------------------------------
@test "list reads repos from multi-line TOML" {
    _write_config <<'EOF'
[portfolio]
default_owner = "octocat"
repos = [
    "hello-world",
    "spoon-knife",
]
EOF
    run "$GH_PORTFOLIO" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"hello-world"* ]]
    [[ "$output" == *"spoon-knife"* ]]
}

# -- 3. config prints owner ---------------------------------------------------
@test "config prints default_owner" {
    _write_config <<'EOF'
[portfolio]
default_owner = "octocat"
repos = []
EOF
    run "$GH_PORTFOLIO" config
    [ "$status" -eq 0 ]
    [[ "$output" == *"default_owner: octocat"* ]]
}

# -- 4. TOML array - single-line layout ---------------------------------------
@test "list reads repos from single-line TOML array" {
    _write_config <<'EOF'
[portfolio]
default_owner = "octocat"
repos = [ "alpha", "bravo" ]
EOF
    run "$GH_PORTFOLIO" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"alpha"* ]]
    [[ "$output" == *"bravo"* ]]
}

# -- 5. TOML array - mixed layout ---------------------------------------------
@test "list reads repos from mixed TOML array layout" {
    _write_config <<'EOF'
[portfolio]
default_owner = "octocat"
repos = [ "first",
    "second",
    "third" ]
EOF
    run "$GH_PORTFOLIO" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"first"* ]]
    [[ "$output" == *"second"* ]]
    [[ "$output" == *"third"* ]]
}

# -- 6. unknown command exits non-zero ----------------------------------------
@test "unknown command exits non-zero" {
    run "$GH_PORTFOLIO" no-such-command
    [ "$status" -ne 0 ]
}

# -- 7. help works ------------------------------------------------------------
@test "help mentions gh-portfolio" {
    run "$GH_PORTFOLIO" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"gh-portfolio"* ]]
}

# -- 8. empty portfolio.toml --------------------------------------------------
@test "empty repos array produces no list output" {
    _write_config <<'EOF'
[portfolio]
default_owner = ""
repos = []
EOF
    run "$GH_PORTFOLIO" list
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# -- 9. malformed TOML (no repos key) - list returns empty --------------------
@test "missing repos key in TOML produces no list output" {
    _write_config <<'EOF'
[portfolio]
default_owner = "octocat"
EOF
    run "$GH_PORTFOLIO" list
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# -- 10. gh-not-on-PATH - status must exit 2 with a message ------------------
@test "status exits 2 with message when gh is absent" {
    # Pre-create config so ensure_config returns early (avoids needing more
    # system utilities in the restricted PATH).
    _write_config <<'EOF'
[portfolio]
default_owner = "octocat"
repos = [ "some-repo" ]
EOF
    run env PATH="$_stub_no_gh" "$GH_PORTFOLIO" status
    [ "$status" -eq 2 ]
    [[ "$output" == *"'gh'"* ]]
}

# -- 11. jq-not-on-PATH - status must exit 2 with a message ------------------
@test "status exits 2 with message when jq is absent" {
    _write_config <<'EOF'
[portfolio]
default_owner = "octocat"
repos = [ "some-repo" ]
EOF
    run env PATH="$_stub_no_jq" "$GH_PORTFOLIO" status
    [ "$status" -eq 2 ]
    [[ "$output" == *"'jq'"* ]]
}

# -- 12. legacy dotmoo config migration ---------------------------------------
@test "legacy dotmoo config is migrated on first run" {
    rm -f "$GH_PORTFOLIO_CONFIG"
    mkdir -p "$HOME/.dotmoo"
    cat > "$HOME/.dotmoo/portfolio.toml" <<'EOF'
[portfolio]
default_owner = "legacy-owner"
repos = [ "migrated-repo" ]
EOF
    run "$GH_PORTFOLIO" version
    [ "$status" -eq 0 ]
    [[ "$output" == *"migrat"* ]]
    [ -f "$GH_PORTFOLIO_CONFIG" ]
    run "$GH_PORTFOLIO" list
    [[ "$output" == *"migrated-repo"* ]]
    rm -f "$HOME/.dotmoo/portfolio.toml"
}

# -- 13. status --json owner-unset guard --------------------------------------
@test "status --json exits non-zero and mentions default_owner when owner is unset" {
    _write_config <<'EOF'
[portfolio]
default_owner = ""
repos = [ "some-repo" ]
EOF
    # Use a controlled PATH with stub gh/jq + real awk/sed/mkdir/cat so the
    # owner guard in cmd_status fires before any network call, on any platform.
    run env PATH="$_stub_owner_guard" "$GH_PORTFOLIO" status --json
    [ "$status" -ne 0 ]
    [[ "$output" == *"default_owner"* ]]
}
