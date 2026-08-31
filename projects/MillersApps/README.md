---
type: project
title: MillersApps — internal web apps for Production, CS, Accounting, and Developers
status: active
created: 2026-08-31
last_verified: 2026-08-31
repositories: [Millers-IT/MillersApps]
areas: [software-development]
tags: [millers, internal-tools]
---

# Project: MillersApps

## Purpose

A collection of web-based applications and tools that support Millers Production, Customer
Service, Accounting, and Developer workflows. Durable context for the `MillersApps` codebase
lives here; the live work lives in issues.

## Current shape

| Piece | Where |
| --- | --- |
| ASP.NET server | `Millers-IT/MillersApps` |
| Angular client (`ClientApp`) | `Millers-IT/MillersApps` |
| Container build | `Millers-IT/MillersApps` (`Dockerfile`) |

## Live work

**Never list tasks or status here** — issues are the only source of truth:

```bash
gh issue list -R nsandford19/work-trek --state open --label project:MillersApps
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

- Repository: [`../../repositories/MillersApps.yaml`](../../repositories/MillersApps.yaml)
- Decisions: `decisions/`
- Investigations: `investigations/`
- Runbooks: `runbooks/`
