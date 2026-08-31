---
type: decision
title: GitHub Issues are the single task control plane
status: active
created: 2026-08-10
areas: [ai, personal-tools]
tags: [github-issues, agent-memory, single-source-of-truth]
issues: []
---

# 0001 — GitHub Issues are the single task control plane

## Context

Work Trek must let several AI agents — Claude Code, Codex, Antigravity CLI — on several
machines behave like one persistent engineering brain. That requires shared external state for
"what work exists and what is its state".

The obvious alternative is Markdown task files in the repository (`tasks.md`, `current.md`,
per-project checklists). It is tempting because it is local, greppable, and needs no network.

But the specific failure it produces is well known and fatal: a GitHub issue says *In
Progress*, `tasks.md` says *Pending*, `current.md` says *Blocked*. Once state is duplicated,
every consumer must guess which copy is right, and the system stops being trustworthy — which
is the only property that matters for a memory system.

## Decision

**GitHub Issues in `nsandford19/work-trek` are the sole source of truth for work
state, for all projects and all source repositories.** Markdown in this repository holds
durable knowledge only, and never task state.

Concretely:

- Work exists as an issue, or it does not exist.
- Status, priority, type, and area are labels on that issue (see
  [ADR 0002](0002-labels-over-projects-fields-for-status.md)).
- Completion is native GitHub state: closed with `state_reason` of `completed` or
  `not_planned`.
- Working notes go in issue comments; only conclusions are promoted to Markdown.
- Markdown may **link** to issues, and issue bodies may link to Markdown — but neither
  restates the other's content.

## Alternatives considered

| Alternative | Why not |
| --- | --- |
| **Markdown task files** | Guarantees divergent state. Also no server-side merge: two machines editing the same file conflict, whereas issues cannot conflict at all. |
| **A dedicated tracker** (Jira, Linear, Todoist) | Better UIs, but adds an integration surface, an auth story, and a second place to look. GitHub is already where the code and the CLI are. |
| **A custom task database** (SQLite, JSON store) | Would need sync, migrations, and tooling on every machine — reinventing what Issues provides free, worse. |
| **GitHub Projects as the primary store** | Projects is a *view* layer; its items still resolve to issues. Its fields are also unreadable via `gh issue list` — see ADR 0002. |
| **Issues in each source repository** | Splits work across many repos, so "what should I work on?" needs N queries and cross-repo dependencies become unrepresentable. One control plane, referencing repositories by registry entry, is simpler. |

## Reasoning

1. **State cannot diverge** when there is one copy, and issues are server-side, so they are
   identical on every machine with no sync step.
2. **Concurrency is free.** Multi-machine conflicts vanish for the only thing that changes
   daily.
3. **`gh` is already installed and authenticated** on the operator's machines. No new dependency.
4. **History comes free** — issue timelines record who changed what and when, permanently.
5. **Relationships are native**: sub-issues, cross-references, and search.
6. **Agent-neutral.** Any agent that can run a shell can read and write it. No vendor memory
   feature is involved, which is the core interoperability requirement.

## Consequences

**Good**

- One query answers "what is blocked?" — reliably, from any agent, on any machine.
- No sync code, no schema migrations, no databases.
- Durable Markdown stays clean: it accumulates knowledge, not stale status.

**Bad, and accepted**

- **Requires network and `gh` auth** to know current work state. Mitigation: durable memory is
  fully offline-readable, so "what happened with X?" still works on a plane; only live state
  needs connectivity.
- **Work state is not in Git history.** Mitigation: issue timelines are themselves durable,
  and conclusions get promoted into Git.
- **Depends on GitHub as a vendor.** Accepted: it already hosts the code, and issues are
  exportable via API if that ever changes.
- **Capture friction** — creating an issue is heavier than typing a line in a file.
  Mitigation: the [`capture-work`](../skills/capture-work/SKILL.md) skill makes it one step,
  and `status:inbox` allows capture without triage. This is the real adoption risk.

## Related

- [ADR 0002](0002-labels-over-projects-fields-for-status.md) — how state is represented
- [`../agent/TASK_POLICY.md`](../agent/TASK_POLICY.md) — the taxonomy and `gh` recipes
- [`../ARCHITECTURE.md`](../ARCHITECTURE.md) §3 — canonical sources of truth
