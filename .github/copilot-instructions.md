# Copilot Coding Agent — Instructions

## Project context

`gh-portfolio` — Portfolio operator for multi-repo GitHub fleets. Pure Bash over gh + jq: one command to view status, bump versions, audit pull requests, and chain release workflows across every repo.

## Coding rules

- Bash 4+; `set -euo pipefail` at the top of every script.
- `shellcheck` clean.
- Quote all variable expansions: `"$var"` not `$var`.
- Use `local` for function-scoped variables.
- Prefer `gh` + `jq` over hand-rolled API calls.
- No new dependencies beyond gh, jq, curl, standard POSIX utilities.

## Tests

- Bats (`bats-core`) for any new function with non-trivial logic.
- Tests run via `bats tests/` from repo root.
- Smoke test for end-to-end commands: stub the gh API where needed.

## File naming

- kebab-case for scripts; `.sh` extension.
- Subcommands as separate scripts under `commands/` if they grow beyond ~50 lines.

## Don't touch

- `.github/workflows/` unless the issue says so.
- The existing CLI flag surface — additions ok, removals/renames not.

## Acceptance signal

A PR is ready for review when:
1. `shellcheck` clean on all changed scripts.
2. `bats tests/` passes.
3. README documents any new subcommand or flag.
