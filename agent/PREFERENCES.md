---
type: policy
title: Personal engineering preferences (scope: personal)
status: active
created: 2026-01-01
last_verified: 2026-01-01
---

# Personal Preferences

**Scope: `personal` — the lowest precedence.** Anything in `organizations/`,
`projects/*/README.md` (`## Conventions`), `repositories/*.yaml` (`conventions:`), or
`machines/*.yaml` (`constraints:`) overrides what is here. See
[`OPERATING_SYSTEM.md`](OPERATING_SYSTEM.md) §2.

> **TEMPLATE NOTE — replace the examples below with your own.** This file starts almost
> empty on purpose. It should contain only preferences the operator has actually stated or
> that were directly observed. Inventing plausible-sounding preferences is worse than
> having none — an agent would confidently apply rules the operator never chose. It grows
> as real preferences surface, one line at a time.
>
> **Agents: ask before adding to this file.** A preference mentioned once in conversation
> is not policy. Confirm, then write it, then commit it with `docs(policy):`.

---

## Confirmed

> The three entries below are **fictional examples** showing the level of specificity that
> works well. Delete them and record your own.

### Example — Git workflow (fictional)

- **Never commit directly to `main`.** Check the current branch at the start of a task; if
  on a default branch, create a feature branch first and open a PR.
- Prefer a new commit over amending an existing one.

### Example — Environment (fictional)

- Primary OS: Windows 11; also uses Linux / WSL. Shells: **PowerShell 7** primary, **Bash**
  also used. They take different syntax — do not mix them.
- **On Windows, do not run commands or scripts through Git Bash, Cygwin, or MSYS2.** Use
  **PowerShell 7**, or **WSL bash** when a genuine Linux shell is wanted (`wsl -- <cmd>`).
  Check WSL availability once per machine (`wsl -l -v`) and record it in `tools:` in
  `machines/*.yaml`. Git Bash remains installed as a Git dependency; that is not a reason
  to script against it. A POSIX-emulation layer is a last resort — only when neither
  PowerShell nor WSL can do the job, and say why in the same breath. (Bootstrap backs this
  up by installing `Microsoft.Coreutils` on Windows — so GNU-style `head`/`sort`/`wc` work
  in pwsh without a bash layer — and ends its run with a loud warning while it is missing.)
- Work repositories on this machine live under `~/dev/`.

### Example — Working style (fictional)

- Prefers a small system used daily over an impressive one that becomes maintenance work.
- Wants assumptions challenged rather than instructions followed blindly — when a design
  is flawed, say so and explain the tradeoff.

---

## Not yet established

Left blank on purpose. Fill in from real, confirmed decisions — ideally when the same
choice has been made three or more times (see [`MEMORY_POLICY.md`](MEMORY_POLICY.md) §8).

- **Coding conventions** — naming, formatting, file layout, per language.
- **Architecture preferences** — patterns favoured and avoided, and why.
- **Testing philosophy** — what deserves a test, what coverage means here, unit vs integration balance.
- **Infrastructure conventions** — naming schemes, environment layout, deployment style.
- **Preferred libraries and tools**, and deliberate replacements.
- **Explicit dislikes** — the highest-value section in this file once populated. A recorded
  "never do X, because Y" prevents more wasted work than any positive preference.
- **Recurring decisions** — choices made the same way often enough to become a default.
- **Lessons learned** from previous projects that should change future approaches.
