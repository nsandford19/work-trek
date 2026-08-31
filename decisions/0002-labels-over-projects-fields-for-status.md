---
type: decision
title: Labels, not GitHub Projects fields, are canonical for type, status and priority
status: active
created: 2026-08-10
areas: [ai, personal-tools]
tags: [github-issues, github-projects, gh-cli, labels]
issues: []
---

# 0002 — Labels, not Projects fields, are canonical for type, status and priority

## Context

Given [ADR 0001](0001-github-issues-as-task-control-plane.md), issue attributes must be
represented somehow. GitHub offers four mechanisms: **issue types**, **Projects v2 custom
fields**, **labels**, and **milestones**.

Conventional advice — and the original brief for this system — prefers Projects custom fields
for status, because single-select fields enforce one value and produce a board.

Two facts, verified on 2026-08-10, change the calculus:

1. **Native issue types are organization-only.** On a personal control-plane repository,
   `GET /repos/.../issues/types` returns 404. Not available at any price.
2. **`gh issue list` cannot filter or display Projects field values.** Reading them requires a
   GraphQL query against `ProjectV2`, and `gh project` additionally needs scopes the current
   token lacks (`gh project list` fails with `missing required scopes [read:project]`).

The decisive question is *who reads this most often*. It is not a human looking at a board —
it is an agent running `gh` at the start of every session.

## Decision

**Labels are canonical** for type, status, priority, area, project, and gating:

```
type:{initiative,task,investigation,research,bug,decision,maintenance}   exactly 1
status:{inbox,ready,in-progress,blocked,waiting,review}                  exactly 1 while open
p{0,1,2,3}                                                               exactly 1
area:*                                                                   0..n
project:*                                                                0..1
needs:*                                                                  0..n
```

With three supporting decisions:

- **Done and Cancelled are not labels.** They are native state: closed with `state_reason`
  `completed` or `not_planned`. `status:*` therefore exists only on open issues.
- **Milestones are unused.** One-per-issue and date-oriented; initiatives nest and have no
  dates. Sub-issues model hierarchy better. Reserved for a genuine time-box if one appears.
- **A Projects board may exist as a human view only.** No agent or skill reads any Projects
  field. It would be a rendering of label state.

## Alternatives considered

| Alternative | Why not |
| --- | --- |
| **Projects single-select for status** | The agent read path becomes a GraphQL document instead of `--label status:blocked`: more tokens, more ways to get it wrong, and needs a scope the token does not have. Broken on day one. |
| **Native issue types for type** | Unavailable (404, personal account). |
| **Milestones for initiatives** | One milestone per issue and built around due dates; cannot nest. Would create a second, weaker hierarchy competing with sub-issues. |
| **Labels *and* Projects fields, kept in sync** | Two copies of one fact — precisely the failure ADR 0001 exists to prevent. |
| **Status encoded in the issue title** (`[WIP] ...`) | Unfilterable, hand-edited, and corrupts search. |

## Reasoning

1. **The read path dominates.** "What's blocked?" runs many times a day:
   `gh issue list --label status:blocked` versus a paginated GraphQL query. One flag wins.
2. **Zero extra scopes.** Works with the token that already exists.
3. **Visible by default.** Labels appear in ordinary `gh issue list` output, so an agent sees
   state without a second call.
4. **Portable.** Labels exist on every GitHub repo regardless of owner type or plan — the
   design survives moving the repo.
5. **Cheap to change.** Labels are strings; `gh label create`/`edit` is instant, with no
   schema migration.

## Consequences

**Good**

- Every operational query is a one-line `gh` command, documented in
  [`../agent/TASK_POLICY.md`](../agent/TASK_POLICY.md) §3.
- No dependency on Projects, scopes, or GraphQL.
- Same behaviour from Claude, Codex, and Antigravity, since it is all plain CLI.

**Bad, and accepted**

- **No platform enforcement of "exactly one".** An issue can carry two `status:*` labels.
  Mitigations: skills always remove-then-add; the validation workflow flags issues with zero
  or multiple `status:*`/`type:*`/priority labels; agents fix violations on sight.
- **No kanban board by default.** Accepted — a board is optional and can be added without
  changing anything, since it derives from labels.
- **Label list is longer** (~25 labels). Grouped by prefix, which keeps it navigable.
- **Status labels can drift** from reality. Mitigated structurally: readiness is *recomputed*
  from `Blocked by:` lines rather than trusted, so a stale `status:blocked` self-heals
  (see [`../agent/TASK_POLICY.md`](../agent/TASK_POLICY.md) §4 step 3).

## Revisit if

- GitHub extends issue types to personal accounts, **or** the repo moves to an organization →
  adopt native types and retire `type:*`.
- `gh issue list` gains Projects field filtering → reconsider status, but only if it removes
  the GraphQL requirement entirely.

## Related

- [ADR 0001](0001-github-issues-as-task-control-plane.md)
- [`../.github/labels.yml`](../.github/labels.yml) — the canonical label definitions
