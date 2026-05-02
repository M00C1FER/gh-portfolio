# Reference Projects

Studied during the [senior-review-2026-05-02](https://github.com/M00C1FER/gh-portfolio/issues) improvement pass.
Each entry notes one **concrete pattern** adopted or considered for gh-portfolio.

---

## 1. dlvhdr/gh-dash — multi-repo GitHub terminal dashboard
- **URL:** https://github.com/dlvhdr/gh-dash
- **Stars:** ~11 500 · **Lang:** Go · **License:** MIT
- **Pattern noted:** YAML-based per-section repo config (`sections: [repo: owner/name, filters: ...]`).
  Each section maps to exactly one query, and the tool fans those queries out in parallel.
  *Applied:* gh-portfolio's `status` command now supports `--json` output so callers can pipe into
  downstream tools the same way gh-dash pipes its query results into rendering layers.

## 2. bats-core/bats-core — Bash Automated Testing System
- **URL:** https://github.com/bats-core/bats-core
- **Stars:** ~6 000 · **Lang:** Shell · **License:** MIT
- **Pattern noted:** `@test "description" { ... }` blocks with TAP output, `run` helper captures
  stdout+exit-code cleanly, `assert_output` helpers eliminate ad-hoc `[[ ... ]]` checks.
  *Applied:* The existing smoke-test suite (`tests/test_gh-portfolio.sh`) is a natural migration
  candidate; bats gives TAP-format output compatible with CI reporters without requiring a language
  runtime. Listed as v0.5 roadmap item to avoid scope creep in this pass.

## 3. rubensworks/git-multi-repo.sh — lightweight Bash fan-out pattern
- **URL:** https://github.com/rubensworks/git-multi-repo.sh
- **Stars:** ~3 · **Lang:** Bash · **License:** MIT
- **Pattern noted:** Reads a flat text file of repo paths and runs a single user-supplied command
  in each, using `pushd/popd` and collecting per-repo exit codes into a summary line.
  *Applied:* Confirmed that gh-portfolio's `read_repos | while IFS=` loop is the right idiomatic
  pattern; the summary-per-repo `printf` alignment in `bump` follows the same convention.

## 4. myzkey/awesome-gh-extensions — gh CLI extension catalogue
- **URL:** https://github.com/myzkey/awesome-gh-extensions
- **Stars:** ~50 · **Lang:** Markdown · **License:** MIT
- **Pattern noted:** Well-maintained gh extensions all ship a `completions/` directory alongside
  `bin/` with one `<name>.bash` and one `<name>.zsh` file, referenced from `gh completion` docs.
  *Applied:* Added `completions/gh-portfolio.bash` and `completions/gh-portfolio.zsh` in this pass.

## 5. cli/cli (GitHub CLI) — structured JSON output convention
- **URL:** https://github.com/cli/cli
- **Stars:** ~38 000 · **Lang:** Go · **License:** MIT
- **Pattern noted:** Every read-oriented command exposes `--json <fields>` + `--jq <expr>` +
  `--template <tmpl>` so scripted callers never need to parse human-readable table output.
  *Applied:* `gh-portfolio status --json` now emits a JSON array of repo objects, matching the
  field names gh itself uses (`name`, `stargazers_count`, `forks_count`, `open_issues_count`,
  `last_ci`, `url`) so callers can pipe directly into `gh`-aware jq filters.
