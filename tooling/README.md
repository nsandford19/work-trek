---
type: policy
title: Machine tooling assets
status: active
created: 2026-08-16
---

# Tooling

Configuration assets that belong on **every machine**, kept here so onboarding a new one
reproduces the same environment instead of re-deriving it.

Unlike `bin/` (scripts that run *inside* this repository), everything here is a file that
gets **installed into a tool's own configuration directory** — `~/.claude`, and whatever
else earns a subdirectory later.

| Directory | Installs into | Installer |
| --- | --- | --- |
| [`claude/`](claude/README.md) | `~/.claude` | `./bin/mc.ps1 statusline` |

Rules for anything added here:

- **The repo copy is canonical.** Edit the file here, then re-run the installer. A machine
  that edits its installed copy loses the change on the next install — and every other
  machine never sees it.
- **Installers are idempotent, ask-first, and back up what they replace.** They touch the
  user's own configuration files; nothing may be clobbered silently.
- **Never a secret.** These files are committed. Tokens and credentials stay where
  `AGENTS.md` hard rule 2 puts them: in the password manager, referenced by pointer.
- **Machine-agnostic.** No hardcoded home directories, hostnames or absolute paths — the
  same bytes have to work on Windows, WSL, Linux and macOS.
