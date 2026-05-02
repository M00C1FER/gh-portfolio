# gh-portfolio

> **The portfolio operator: one command, many repos.** Pure Bash CLI that wraps `gh` + `jq` for fleet operations across an entire GitHub portfolio. Status table across all repos, fan-out semver bumps, batch PR audits, full review-summarize-release chains in one shot. No compiler, no venv, no toolchain — just `bash 4+`, `gh`, and a 50-line config.

[![CI](https://github.com/M00C1FER/gh-portfolio/actions/workflows/ci.yml/badge.svg)](https://github.com/M00C1FER/gh-portfolio/actions)
![Bash](https://img.shields.io/badge/bash-4+-black)
![License](https://img.shields.io/badge/license-MIT-green)

## What this is, exactly

Other tools (`maxbeizer/gh-fleet`, `qskkk/git-fleet`, `mu-repo`, `meta`) handle multi-repo *git* operations. **gh-portfolio handles multi-repo *AI-tooling* operations** — chain `kingfisher` → `mesh-review` → `release-please` across an entire portfolio with one invocation. It's the conductor for the rest of your dev-tool stack, not a replacement for any one tool in it.

## What it does

Fans common operations out across every repo in your portfolio:

| Subcommand | Purpose |
|---|---|
| `gh-portfolio status` | Table of CI / stars / forks / issues / last-commit across every repo |
| `gh-portfolio status --json` | Same data as a JSON array (pipe into `jq`, CI steps, dashboards) |
| `gh-portfolio bump [--apply]` | Run `flowtag --next-version` across every repo with new commits |
| `gh-portfolio audit owner/repo#42` | Run `triple-review` on a single PR's diff |
| `gh-portfolio audit --all` | Run `triple-review` on every open PR across every repo |
| `gh-portfolio summary owner/repo#42` | Run `pr-summary-mesh` on a single PR |
| `gh-portfolio cycle owner/repo#42` | Full chain: gatecheck → triple-review → pr-summary-mesh → flowtag |
| `gh-portfolio list` | Print configured repo list |
| `gh-portfolio config` | Print resolved config + path |
| `gh-portfolio version` | Print version |

## Why Bash here

The load characteristic is **glue + composition**. Each subcommand wraps `gh api` + `jq` in 5–30 lines. Three reasons Bash is the right tool:

1. **Pure composition** — `gh` already does 95% of the work. Bash's role is "loop over repos and call gh"; that's classic shell scripting territory.
2. **Zero build step** — install is `cp gh-portfolio /usr/local/bin`. No compiler, no venv, no toolchain.
3. **Discoverable internals** — every subcommand lives in `lib/gh-portfolio-<verb>.sh` as readable shell. Fork and customize without learning a new language.

A Python version would add a 50 MB venv for what's a 30-line script. A Go version would compile a binary that re-implements `gh` calls. Both are wrong for this load.

## Quick start

```bash
git clone https://github.com/M00C1FER/gh-portfolio.git
sudo cp gh-portfolio/bin/gh-portfolio /usr/local/bin/
sudo cp -r gh-portfolio/lib /usr/local/share/gh-portfolio/
export GH_PORTFOLIO_LIB=/usr/local/share/gh-portfolio

gh-portfolio version            # creates ~/.gh-portfolio/portfolio.toml on first run
$EDITOR ~/.gh-portfolio/portfolio.toml   # add your repos
gh-portfolio status
```

(Or use the install wizard: `bash <(curl -fsSL https://raw.githubusercontent.com/M00C1FER/gh-portfolio/main/install.sh)`)

## Configuration

`~/.gh-portfolio/portfolio.toml`:

```toml
[portfolio]
default_owner = "your-handle"
repos = [
    "polite-fetch",
    "mcp-citation-research",
    "triple-review",
    "memory-tool-conformance",
    "recon-orchestrator",
    "flowtag",
    "pr-summary-mesh",
    "gatecheck",
    "gh-portfolio",
]
```

The TOML reader is intentionally minimal (`awk`-based) so gh-portfolio doesn't need an external TOML parser.

## How it composes with the rest of the portfolio

`gh-portfolio cycle owner/repo#42` runs the full PR check sequence:

```mermaid
flowchart LR
    A[gh pr diff] --> B[gatecheck]
    B --> C[triple-review]
    C --> D[pr-summary-mesh]
    D --> E[flowtag]
    B -->|secret found| F[abort]
    C -->|critical issue| F
```

Each tool is independent — `gh-portfolio` just orchestrates. If a tool isn't installed, `gh-portfolio cycle` warns and continues with the rest. Best-effort by design.

## Cross-platform

| OS | Shell | Status |
|---|---|---|
| Debian 13 / Ubuntu 22.04+ | bash 4+ | ✅ tested |
| WSL2 (Ubuntu / Debian) | bash 4+ | ✅ tested |
| Fedora / RHEL | bash 4+ | ✅ should work (relies only on POSIX `awk`/`sed`) |
| Arch / Alpine | bash 4+ | ✅ should work |
| macOS | bash 5+ (`brew install bash`) | ✅ should work; default macOS bash 3.2 won't suffice |
| Windows native | n/a | use WSL2 or Git Bash |

Required tools: `bash 4+`, `gh`, `jq` (optional but enables prettier output for some commands), `git`.

## Comparison vs alternatives

| Tool | Lang | Build needed | Multi-repo | Custom subcommands |
|---|---|:-:|:-:|:-:|
| `gh` (alone) | Go | ✅ | partial | ❌ |
| `mu-repo` | Python | ✅ (pip) | ✅ | ❌ |
| `meta` | Node | ✅ (npm) | ✅ | ✅ via JSON config |
| **`gh-portfolio`** | **Bash** | **❌ (just cp)** | **✅** | **✅ via lib/* drop-ins** |

## Shell completions

Bash and zsh completion scripts live in `completions/`.

**Bash** — add to `~/.bashrc` (or drop in `/etc/bash_completion.d/`):
```bash
source /usr/local/share/gh-portfolio/completions/gh-portfolio.bash
```

**Zsh** — add the directory to `$fpath` before calling `compinit`:
```zsh
fpath=(/usr/local/share/gh-portfolio/completions $fpath)
autoload -Uz compinit && compinit
```

Both scripts read `~/.gh-portfolio/portfolio.toml` to suggest `owner/repo#N` targets for
`audit`, `summary`, and `cycle` without a network call.

## Testing

```bash
bash tests/test_gh-portfolio.sh
```

13 smoke tests cover: config bootstrap, repo list parsing (multi-line, single-line, mixed TOML layouts), owner readback, unknown-command exit, help output, empty/malformed TOML, gh-not-on-PATH, jq-not-on-PATH, legacy dotmoo config migration, and `status --json` flag parsing. Tests run against an isolated `$HOME` so they don't touch a real config.

## Roadmap

- v0.2: `gh-portfolio init <repo>` — scaffold a new repo with the portfolio's CI + structure
- v0.3: `gh-portfolio release <repo>` — automated tag-and-publish chain (uses flowtag + gh)
- v0.4: `gh-portfolio dashboard` — TUI live view via `tput`/`watch`
- v0.5: migrate smoke tests to bats-core for TAP output and richer assertions

## License

MIT.
