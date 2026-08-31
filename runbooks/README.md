---
type: policy
title: Runbooks index
status: active
created: 2026-08-10
---

# Runbooks

Repeatable procedures: the steps, in order, with the exact commands. Cross-cutting runbooks
live here; project-specific ones in `projects/<name>/runbooks/`.

A runbook exists so that a procedure derived once at 2am does not have to be derived again.

## Cross-cutting runbooks

| Runbook | Areas | Verified |
| --- | --- | --- |
| *(none yet — the table grows as procedures are captured)* | | | |

---

## When to write one

When a procedure is **repeatable, non-obvious, and consequential**. All three:

- *repeatable* — it will be done again;
- *non-obvious* — reconstructing it takes more than a couple of minutes;
- *consequential* — doing it wrong costs real time or causes damage.

Not for one-offs (leave those in issue comments), and not for things any competent engineer
does from memory.

## What a good runbook contains

Use [`../templates/runbook.md`](../templates/runbook.md).

- **Preconditions** — what must be true before starting, and how to check.
- **Which machine and which shell.** PowerShell and Bash are not interchangeable.
- **Numbered steps with copy-pasteable commands.** No prose where a command belongs.
- **Expected output** for the steps where "did that work?" is a real question.
- **Verification** — how to prove it worked, not just that it ran.
- **Rollback** — what to do when step 4 fails. This is the part people skip and later need.
- **Secret pointers, never secrets** — `secret: op://<vault>/<item>/<field>` (a 1Password secret reference).
  See [`../agent/SECURITY_POLICY.md`](../agent/SECURITY_POLICY.md).

## Verification decay

`last_verified:` is **required** for runbooks. A runbook is the most dangerous kind of stale
document: it will be followed literally, on a real system, probably under pressure.

Bump `last_verified:` every time you follow it successfully:

```
docs(memory): re-verify <procedure> runbook
```

If a step has changed, fix it in the same session. If the procedure no longer applies, mark the
runbook `status: obsolete` and say what replaced it — do not leave it looking current.

## Runbook vs investigation vs knowledge

- **runbook** — *how to do* something.
- **investigation** — *why* something happened.
- **knowledge** — *what is true* about a technology.

An investigation that produces a repeatable fix should produce a runbook too, and link to it.

## Committing

```
docs(runbook): add <procedure>
docs(runbook): fix step 3 of <procedure>
```
