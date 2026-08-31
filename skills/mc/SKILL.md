---
name: mc
description: Run the right mc (Work Trek CLI) command for a tooling request without the operator having to remember the command surface. Use when asked to run mc, check the setup or environment ("doctor", "is everything set up?"), validate the repo, build the dashboard, sync labels or skill stubs, scan for repositories, refresh or backfill work-history ledgers, set up the global agent pointers ("onboard"), install the shared Claude Code status line, or resolve which machine or checkout something is on.
---

# Skill: mc

`mc` (short for Work Trek) is the optional accelerator in `bin/`. This skill maps
what the operator asks for to the command to run — the operator should never need to memorise these.

## 1. How to invoke it

```powershell
./bin/mc.ps1 <command>        # Windows, or anywhere with pwsh
```

```bash
./bin/mc <command>            # Linux / WSL / macOS shim (delegates to pwsh)
```

Run from the Work Trek clone. From another directory, use the full path to the
clone's `bin/mc.ps1`. If `pwsh` is missing or the script fails, **do not stop**: every
command has a raw `gh`/`rg` equivalent in
[`agent/OPERATING_SYSTEM.md`](../../agent/OPERATING_SYSTEM.md) §7.

## 2. What the operator says → what to run

| The operator says (roughly) | Run |
| --- | --- |
| "What should I work on?" | `mc next` — then follow [`whats-next`](../whats-next/SKILL.md) for the full answer |
| "Work on issue 42" / "where does 42 live?" | `mc issue 42` — then follow [`start-work`](../start-work/SKILL.md) |
| "Is everything set up?" / "check my environment" | `mc doctor` |
| "Which machine is this?" / "what are its constraints?" | `mc machine` |
| "Validate the repo" / before committing registry or memory changes | `mc validate` |
| "What repos are on this machine?" / "find unregistered repos" | `mc repo scan` (proposes only — never writes the registry) |
| "Build/refresh the dashboard" | `mc dashboard` → `reports/generated/dashboard.html` (gitignored) |
| "Refresh the issue cache" / cheap keyword → issue-number lookups | `mc issues cache` → `reports/generated/issues.md` (gitignored), then `rg` it; GitHub stays canonical ([`agent/TASK_POLICY.md`](../../agent/TASK_POLICY.md) §3) |
| "Refresh the work history" / "backfill history for repo X" | `mc history sync <owner/repo>` (new repo) or `mc history sync --all` (refresh covered repos) → year ledgers in `reports/history/<name>/`; then update the period narratives ([`reports/history/README.md`](../../reports/history/README.md)) |
| "Push the label set to GitHub" | `mc labels sync --dry-run`, review, then `mc labels sync` |
| "Point my other repos at Work Trek" | `mc onboard --dry-run`, review, then `mc onboard` |
| "Set up my status line" / "why does this machine look different in Claude Code?" | `mc statusline --dry-run`, review, then `mc statusline` — installs [`tooling/claude/statusline-command.sh`](../../tooling/claude/README.md) into `~/.claude` |
| After editing anything in `skills/` | `mc skills sync` — regenerates `.claude/skills/` stubs |
| New machine / fresh clone | `./bin/bootstrap.ps1` (or `./bin/bootstrap.sh`) — not an `mc` subcommand |

`mc help` (or any unknown command) prints the live usage text if this table looks stale.

## 3. Judgement calls

- **Read-only, run freely:** `doctor`, `machine`, `next`, `issue`, `validate`, `repo scan`,
  `dashboard`, `issues cache`, and any `--dry-run`.
- **Ask or show a dry run first:** `labels sync` (mutates GitHub labels), `onboard`
  (writes to `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md` — it also
  prompts per file itself), and `statusline` (writes `~/.claude/statusline-command.sh` and
  `.statusLine` in `~/.claude/settings.json` — it backs both up and prompts per file, and
  only `--yes` skips the prompts).
- `mc skills sync` writes only generated stubs inside this repo; run it whenever canonical
  skills changed, and commit the stubs with the skill change.
- `mc history sync` writes only generated ledgers under `reports/history/`; safe to re-run
  (it converges). Commit the ledgers, and update narratives for any period that changed.
- Machine identity: `MC_MACHINE` overrides the hostname for a session
  (`$env:MC_MACHINE = '<id>'` / `export MC_MACHINE=<id>`). Never guess an identity.
- If a command reports a problem, fix the cause or surface it — never report the task
  itself as blocked because the accelerator broke.
