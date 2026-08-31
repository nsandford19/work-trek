---
type: policy
title: Decisions index (ADRs)
status: active
created: 2026-08-10
---

# Decisions

Architecture Decision Records for choices that **cut across projects**. Project-local
decisions live in `projects/<name>/decisions/`.

An ADR captures *why*, so that a future engineer — or agent — does not undo a deliberate
choice believing it was an accident.

## Cross-cutting ADRs

| # | Decision | Status | Date |
| --- | --- | --- | --- |
| [0001](0001-github-issues-as-task-control-plane.md) | GitHub Issues are the task control plane | active | 2026-08-10 |
| [0002](0002-labels-over-projects-fields-for-status.md) | Labels, not Projects fields, are canonical for status | active | 2026-08-10 |
| [0003](0003-machine-identity-via-hostname-map.md) | Machine identity resolves via hostname map with env override | active | 2026-08-10 |
| [0004](0004-qmd-as-memory-retrieval-driver.md) | qmd is the primary retrieval driver for durable memory; rg is the fallback | active | 2026-08-11 |

---

## When to write one

**The test:** *would a competent engineer six months from now be tempted to undo this without
knowing why it was chosen?* If yes, write the ADR.

Write one when a choice:

- constrains future work,
- was contested, or had a credible alternative,
- will look wrong without its context,
- or is expensive to reverse.

**Do not** write one for reversible or obvious choices. A repository full of trivial ADRs is a
repository nobody reads — which costs you the ones that matter.

## How

```bash
cp templates/decision.md decisions/NNNN-<slug>.md      # next free number, zero-padded
```

Numbers are global within a directory and never reused, even if a decision is later
superseded. Add a row above, then commit:

```
docs(decision): record <the decision>
```

## Superseding

Never edit the original conclusion — the old reasoning is the value. Instead:

1. In the old ADR: `status: superseded` and `superseded_by: decisions/NNNN-....md`.
2. In the new ADR: link back and say what changed — new information, or new circumstances.
3. Leave both rows in the table so the sequence is visible.

`status: obsolete` is for a decision that no longer applies at all (the system it governed is
gone), rather than one replaced by a better answer.

## Decision issues vs ADRs

They are different artefacts and both exist:

- a `type:decision` **issue** is the *deciding* — open work, discussion, alternatives;
- an **ADR** is the *decided* — the durable record.

Close the issue when the ADR is committed, and link them: the ADR lists the issue in
`issues:` front matter, the issue body links the ADR.
