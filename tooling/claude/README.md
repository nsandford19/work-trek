---
type: policy
title: Claude Code status line
status: active
created: 2026-08-16
---

# Claude Code status line

[`statusline-command.sh`](statusline-command.sh) is the status line Claude Code prints
under the prompt. It lives here so every machine shows the same one.

```
Claude Opus 5 │ ✍️ 34% │ work-trek (main*) │ ⏱ 12m │ ● high

current ●●●○○○○○○○  28% ⟳ 4:15pm
weekly  ●●●●●●○○○○  61% ⟳ aug 19, 9:00am
```

- **line 1** — model, context window used, current directory with git branch (`*` when
  dirty), session length, and the configured effort level. A `⚡` prefix appears when the
  session was started with `--dangerously-skip-permissions`.
- **line 2+** — 5-hour, weekly and (when enabled) extra-usage meters with reset times.
  These come from the status line payload on stdin; when the payload has no rate limits
  the script falls back to the OAuth usage endpoint, cached for 60s in
  `/tmp/claude/statusline-usage-cache.json`.

## Install on a machine

```powershell
./bin/mc.ps1 statusline           # asks before each write
./bin/mc.ps1 statusline --dry-run # show what would change
./bin/mc.ps1 statusline --yes     # no prompts (bootstrap uses this)
```

It copies this file to `~/.claude/statusline-command.sh` and sets `.statusLine` in
`~/.claude/settings.json` to `bash "<that path>"`, leaving every other setting alone. Both
files are backed up to `<name>.mc-backup-<timestamp>` before being replaced, and the whole
command is idempotent — re-running it when nothing changed writes nothing. Step 7 of
`./bin/bootstrap.ps1` offers it during onboarding.

Without pwsh, do the same two things by hand:

```bash
cp tooling/claude/statusline-command.sh ~/.claude/statusline-command.sh
# then in ~/.claude/settings.json:
#   "statusLine": { "type": "command", "command": "bash \"$HOME/.claude/statusline-command.sh\"" }
```

The new line appears in the next Claude Code session.

## Requirements

`bash` and `jq`. On Windows that means Git Bash (`git-bash` ships one) or running Claude
Code inside WSL; `mc statusline` warns when either is missing rather than installing a
line that prints nothing. `curl` is only needed for the rate-limit fallback — without it
the meters simply disappear when the payload omits them.

## Changing it

Edit **this** copy, never `~/.claude/statusline-command.sh`, then re-run
`./bin/mc.ps1 statusline` here and on the other machines. If a machine already has local
edits worth keeping, copy them back first:

```bash
cp ~/.claude/statusline-command.sh tooling/claude/statusline-command.sh
```

then review the diff and commit — that is what makes the change reach every machine.
