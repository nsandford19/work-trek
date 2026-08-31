---
type: investigation
title: <State the finding as a claim, not a topic>
status: active
created: <YYYY-MM-DD>
last_verified: <YYYY-MM-DD>
project: <project-name or remove>
repositories: [<owner/name> or remove]
machines: [<machine-id> or remove]
areas: [<area>]
tags: [<tag>]
issues: [<investigation issue number>]
---

# <Title as a claim>

> Delete this quote block and every `<...>` placeholder before committing.
> File as `investigations/<slug>.md` (general) or
> `projects/<p>/investigations/<slug>.md` (project-specific).
> Only write this document once there is a conclusion — until then, issue comments are enough.

## Question

What was being investigated, in one or two sentences. Copy it from the issue title.

## Answer

**The root cause, stated plainly, in the first paragraph.** Lead with it — a future agent
should get the answer without reading the evidence.

If there is a fix, name it here and say whether it addresses the cause or only the symptom.

## Environment

Scope the finding, or it becomes a trap later.

| | |
| --- | --- |
| Machine | `<machine-id>` |
| System / cluster / host | `<...>` |
| Versions | `<...>` |
| Date observed | `<YYYY-MM-DD>` |

## Evidence

The commands run and their **verbatim** output. Error strings recorded exactly are the
highest-value searchable content in this repository — a future `rg` query will be the error
text.

```console
$ <command>
<verbatim output>
```

## Ruled out

What was tested and found not to be the cause, and how that was established. This is the
second-most valuable section, because it stops the next attempt re-treading the same ground.

- `<hypothesis>` — ruled out because `<...>`

## Follow-ups

Work discovered during the investigation. These are **issues**, not a checklist here.

- #<n> — `<title>`

## Related

- Investigation issue: #<n>
- General technology fact extracted to: `knowledge/<area>/<slug>.md`
- Runbook produced: `runbooks/<slug>.md`
- Decision this forced: `decisions/NNNN-<slug>.md`
