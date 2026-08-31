---
type: skill
title: triage-notifications learned preferences
status: active
created: 2026-01-01
---

# Learned preferences — triage-notifications

Read by [`SKILL.md`](SKILL.md) step 2 before categorizing. Two sections with different power:

- **Rules** are applied on every run. They exist only from the operator's explicit feedback —
  each entry records the rule, the date added, and provenance (a short quote or paraphrase of
  what the operator said). A rule may demote matching items to Likely noise or promote them to
  Needs my action. Demoted items still appear as collapsed one-liners — never silently
  dropped.
- **Candidates** are agent-observed patterns. They are never applied — their only permitted
  effect is a "suggested rule?" question at the end of a briefing. A candidate becomes a
  rule only when the operator explicitly says yes.

## Rules

None yet. Rules are added only from the operator's explicit feedback — never invented.

<!-- Fictional example entry:
- Demote to Likely noise: `subscribed` PRs in example-org/legacy-app titled "Staging
  deployment …". Added 2026-01-01. Provenance: the operator — "those staging deploy PRs
  are pure noise, collapse them."
-->

## Candidates (not yet rules)

None yet.
