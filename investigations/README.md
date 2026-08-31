---
type: policy
title: Investigations index
status: active
created: 2026-08-10
---

# Investigations

Durable results of diagnostic work that **spans projects** or concerns general technology
behaviour. Project-specific findings live in `projects/<name>/investigations/`.

An investigation answers *"why is this happening?"*. The issue is the process; the document
here is the conclusion.

## Cross-cutting investigations

| Investigation | Areas | Status | Verified |
| --- | --- | --- | --- |
| *(none yet — the table grows as investigations conclude)* | | | |

---

## The workflow

Full procedure: [`../skills/document-investigation`](../skills/document-investigation/SKILL.md).

1. Create an issue, `type:investigation`, whose **title states the question**.
2. Record the environment — versions, hosts, cluster, machine. A finding without its scope is
   a trap.
3. Collect evidence as **issue comments**: commands run, verbatim output, verbatim errors.
   Comments are free, timestamped, and produce no commit noise.
4. Test hypotheses; comment the result of each, including the ones that were wrong.
5. When conclusive, write the findings document (here, or in the project) using
   [`../templates/investigation.md`](../templates/investigation.md).
6. Create follow-up issues for any work discovered, with `Source: #N` in the body.
7. Link both ways: the document lists the issue in `issues:` front matter; the issue body links
   the document.
8. Close the issue as `completed` (ask first).

### Inconclusive is a valid outcome

If you run out of time or evidence, set the issue to `status:waiting` and comment **what was
ruled out**. That is the second-most valuable output after an answer — it stops the next
attempt re-treading the same ground. Do not write a findings document for a non-finding;
the issue comments are enough until there is a conclusion.

## What makes a good findings document

- **Lead with the answer.** Root cause first, evidence after.
- **Include verbatim error text and exact commands.** These are the highest-value searchable
  content in this repository — future `rg` queries will be the error string.
- **Record what you ruled out**, not only what you found.
- **State the scope explicitly**: versions, environment, which machine, which cluster.
- **Separate the fix from the root cause.** A workaround that hides a cause should say so.

## Investigation vs research vs knowledge

- **investigation** — looks *inward* at something already happening in my systems.
- **research** — looks *outward* at options not yet chosen. Output is an ADR or a knowledge note.
- **knowledge** — a general technology fact, independent of any incident.

If an investigation uncovers a general truth about a technology, put the general part in
[`../knowledge/`](../knowledge/README.md) and keep the incident-specific part here, linked.

## Committing

```
docs(project): add <topic> investigation
docs(memory): document <the general finding>
```
