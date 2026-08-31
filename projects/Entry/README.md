---
type: project
title: Entry — container for Entry-related projects
status: active
created: 2026-08-31
last_verified: 2026-08-31
repositories: [Millers-IT/Entry]
areas: [software-development]
tags: [millers]
---

# Project: Entry

## Purpose

Durable context for the `Entry` codebase — a repository housing the Entry-related projects.
The live work lives in issues; this directory holds what outlives any single issue.

## Current shape

| Piece | Where |
| --- | --- |
| Entry projects | `Millers-IT/Entry` |

## Live work

**Never list tasks or status here** — issues are the only source of truth:

```bash
gh issue list -R nsandford19/work-trek --state open --label project:Entry
```

## Key decisions

| ADR | Decision |
| --- | --- |
| _(none yet)_ | |

## Conventions

**Scope: `project`** — overrides organization and personal defaults; overridden by repository
and machine scope. Only rules that are true *because of this project*.

- _(none recorded yet)_

## Related

- Repository: [`../../repositories/Entry.yaml`](../../repositories/Entry.yaml)
- Decisions: `decisions/`
- Investigations: `investigations/`
- Runbooks: `runbooks/`
