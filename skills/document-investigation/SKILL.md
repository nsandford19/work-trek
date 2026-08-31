---
name: document-investigation
description: Turn a completed diagnosis into durable memory — write the findings document, extract general knowledge, create follow-up issues, link both ways and close the investigation issue. Use when an investigation reaches a conclusion, when asked to "write up what we found", or when a root cause has been identified and should not be lost.
---

# Skill: document-investigation

Promote a conclusion into durable memory. Run this **when there is a conclusion** — until then,
issue comments are the right place for working notes.

## 1. Confirm there is something to promote

Test against the promotion bar ([`../../agent/MEMORY_POLICY.md`](../../agent/MEMORY_POLICY.md) §3).
Promote if it explains surprising behaviour, resolves something that has now happened twice,
contains a non-trivial command or procedure, or documents infrastructure.

**Do not promote** narration of what was done, or anything rediscoverable in two minutes. If it
fails the bar, leave the findings as an issue comment and say so — that is a correct outcome.

### Inconclusive?

Do not write a document. Set the issue to `status:waiting` and comment **what was ruled out**:

```bash
gh issue edit 42 -R nsandford19/work-trek --remove-label status:in-progress --add-label status:waiting
gh issue comment 42 -R nsandford19/work-trek --body "Paused. Ruled out: <A> (because ...), <B> (because ...). Next: <...>"
```

## 2. Decide where it goes

Narrowest scope where it is still true:

| Content | Location |
| --- | --- |
| How *my* system misbehaved | `projects/<p>/investigations/<slug>.md` |
| A diagnosis not tied to one project | `investigations/<slug>.md` |
| A general truth about a technology | `knowledge/<area>/<slug>.md` |
| A repeatable fix | also a runbook: `runbooks/<slug>.md` |

Often **two** documents: the incident stays in `investigations/`, the general fact goes to
`knowledge/`, and they link to each other. Splitting matters — a general truth buried in an
incident write-up will not be found next time.

## 3. Gather the evidence from the issue

```bash
gh issue view 42 -R nsandford19/work-trek --comments
```

The comment thread is the raw material. The document is the distilled answer — do not paste the
thread into it.

## 4. Write the document

```bash
cp templates/investigation.md investigations/<slug>.md
```

Fill it in, delete the instruction block and every `<...>` placeholder. Non-negotiables:

- **Title states the finding as a claim**, not a topic. This is the retrieval surface.
- **Answer first.** Root cause in the opening paragraph, evidence after.
- **Verbatim commands and error text.** The highest-value searchable content here — the next
  search will be the error string.
- **`## Ruled out`** — what was tested and eliminated. Stops the next attempt re-treading.
- **Scope stated**: versions, host, cluster, machine. A finding without scope is a trap.
- **`issues: [42]`** in front matter.
- Separate the **fix** from the **root cause**; if the fix is a workaround, say so.

## 5. Create follow-up issues

Work discovered during the investigation becomes issues **now** — discovered work that is not
captured is lost work. Use [`capture-work`](../capture-work/SKILL.md), with `Source: #42` in each
body. Its duplicate check greps the issue cache before calling the API
([`../../agent/OPERATING_SYSTEM.md`](../../agent/OPERATING_SYSTEM.md) §3).

## 6. Link both ways

The document lists the issue in `issues:` front matter. The issue gets the document:

```bash
gh issue comment 42 -R nsandford19/work-trek --body "Findings: investigations/<slug>.md

Root cause: <one line>. Follow-ups: #45, #46."
```

## 7. Index it

Add a row to the directory's `README.md` — `investigations/README.md`, `knowledge/README.md`, or
the project's. **In the same commit.** An unindexed document is one nobody finds.

## 8. Commit

```bash
git add investigations/<slug>.md investigations/README.md
git commit -m "docs(project): add <topic> investigation"
```

Two documents means two commits: `docs(project): add <topic> investigation` and
`docs(memory): document <the general fact>`.

## 9. Close the issue — ask first

```bash
gh issue edit 42 -R nsandford19/work-trek --remove-label status:in-progress
gh issue close 42 -R nsandford19/work-trek --reason completed
```

**Ask before closing.** Closing is the value-capture moment; skipping the steps above loses the
knowledge permanently.

## 10. Note the next action

If anything remains, leave it as a comment on the follow-up issue. That comment is what lets a
different agent on a different machine resume cleanly — the highest-value 30 seconds of the
session.
