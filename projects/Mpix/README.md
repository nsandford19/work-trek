---
type: project
title: Mpix — the Mpix consumer product and its supporting services
status: active
created: 2026-08-31
last_verified: 2026-08-31
repositories: [Millers-IT/mpix-3, Millers-IT/Mpix.Com.Core, Millers-IT/Mpix.Create]
areas: [software-development, web]
tags: [mpix]
---

# Project: Mpix

## Purpose

Durable context for the Mpix product family — the customer-facing Mpix web app, its core
services, and the visual project design/inspection tooling. Spans several repositories; the
live work lives in issues, and this directory holds what outlives any single issue.

## Current shape

| Piece | Where |
| --- | --- |
| Mpix 3.0 web app + APIs (Nx monorepo) | `Millers-IT/mpix-3` |
| Core Mpix.Com services (API core, search, YARP gateway) | `Millers-IT/Mpix.Com.Core` |
| Visual design/inspection before print | `Millers-IT/Mpix.Create` |

## Live work

**Never list tasks or status here** — issues are the only source of truth:

```bash
gh issue list -R nsandford19/work-trek --state open --label project:Mpix
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

- Repositories:
  [`../../repositories/mpix-3.yaml`](../../repositories/mpix-3.yaml),
  [`../../repositories/Mpix.Com.Core.yaml`](../../repositories/Mpix.Com.Core.yaml),
  [`../../repositories/Mpix.Create.yaml`](../../repositories/Mpix.Create.yaml)
- Decisions: `decisions/`
- Investigations: `investigations/`
- Runbooks: `runbooks/` —
  [`add-a-new-product.md`](runbooks/add-a-new-product.md): the end-to-end checklist for
  launching a product (Squidex `DefProduct` + `PageProduct`, CMSKey pricing, sitemap,
  headers in all three repos)
