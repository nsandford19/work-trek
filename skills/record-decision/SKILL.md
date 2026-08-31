---
name: record-decision
description: Capture an architectural or technical decision as an ADR so the reasoning survives. Use when a choice has been made that constrains future work, when asked "record why we chose this" or "write an ADR", or when a type:decision issue is ready to be resolved.
---

# Skill: record-decision

Write down *why*, so a future engineer or agent does not undo a deliberate choice believing it
was an accident.

## 1. Does this deserve an ADR?

**The test:** *would a competent engineer six months from now be tempted to undo this without
knowing why it was chosen?*

Write one when the choice constrains future work, was contested, had a credible alternative,
will look wrong without its context, or is expensive to reverse.

**Do not** write one for reversible or obvious choices. A repository full of trivial ADRs is one
nobody reads — which costs you the ADRs that matter. If it fails the test, say so and leave the
reasoning in an issue comment instead.

## 2. Scope and number

| Blast radius | Location |
| --- | --- |
| Affects several projects, or the system itself | `decisions/NNNN-<slug>.md` |
| Affects one project only | `projects/<p>/decisions/NNNN-<slug>.md` |

```bash
ls decisions/            # next free number, zero-padded to 4
```

Numbers are per-directory, sequential, and **never reused** — not even for a superseded
decision.

## 3. Write it

```bash
cp templates/decision.md decisions/NNNN-<slug>.md
```

Title it as a **statement** — "Use X for Y", not "Choosing a Y". Delete the instruction block
and every `<...>` placeholder.

The four sections that carry the value:

- **Context** — what forced a decision, including the facts that turned out decisive. Enough
  that the reasoning makes sense to someone with no memory of today.
- **Alternatives considered** — a table, each with a *specific* reason it lost. An ADR with no
  credible alternatives is usually not a decision worth recording.
- **Consequences → Bad, and accepted** — the most important section. Be honest. An ADR listing
  only benefits reads as advocacy and gets ignored, and the accepted costs are exactly the
  symptoms that will later tempt someone to reverse it.
- **Revisit if** — the conditions that would justify changing this. Turns a tombstone into
  something actionable.

Reference decisive facts (measurements, verified constraints, platform limits) rather than
preference alone. If a fact was verified, consider a `knowledge/` note too, and link it.

## 4. Index it

Add a row to `decisions/README.md` (or the project's) — **in the same commit**.

## 5. Link the issue

If a `type:decision` issue drove this: put its number in `issues:` front matter, then comment
on the issue with the ADR path.

```bash
gh issue comment 57 -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --body "Decided: decisions/0004-<slug>.md — <the decision in one line>."
```

## 6. Commit

```bash
git add decisions/NNNN-<slug>.md decisions/README.md
git commit -m "docs(decision): record <the decision>"
```

## 7. Close the decision issue — ask first

```bash
gh issue edit 57 -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --remove-label status:in-progress
gh issue close 57 -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --reason completed
```

**Then unblock the work that was waiting on it.** This is the step most often forgotten, and it
is the whole point of tracking decisions as issues:

```bash
gh issue list -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --state open --label status:blocked --json number,title,body   # find 'Blocked by: #57'
gh issue edit 43 -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --remove-label status:blocked --add-label status:ready
```

## Superseding an existing ADR

**Never edit the original conclusion** — the old reasoning is the value.

1. Write the new ADR; in its Context, say what changed (new information, or new circumstances).
2. In the old one: `status: superseded` and `superseded_by: decisions/NNNN-<slug>.md`.
3. Leave both rows in the index so the sequence stays visible.

```bash
git commit -m "docs(decision): supersede NNNN with MMMM (<what changed>)"
```

Use `status: obsolete` instead when the decision no longer applies at all because the system it
governed is gone.
