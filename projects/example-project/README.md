---
type: project
title: Example project — a fictional worked example of project context
status: active
created: 2026-01-01
last_verified: 2026-01-01
repositories: [example-org/my-service]
areas: [software-development]
tags: [example]
---

# Project: example-project

> **FICTIONAL EXAMPLE.** This directory demonstrates the project layout with entirely
> made-up content. Delete it — together with the `project:example-project` label in
> `.github/labels.yml` — once you have created a real project from
> [`templates/project-README.md`](../../templates/project-README.md).

## Purpose

`my-service` is a fictional order-processing API. This project holds its durable context:
why it is shaped the way it is, and the procedures around it. "Healthy" means orders clear
the queue in under a minute.

## Current shape

| Piece | Where |
| --- | --- |
| REST API | `example-org/my-service` |
| Nightly reconciliation job | `example-org/my-service` (`jobs/reconcile`) |

## Live work

**Never list tasks or status here** — issues are the only source of truth:

```bash
gh issue list -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --state open --label project:example-project
```

## Conventions

**Scope: `project`** — overrides organization and personal defaults; overridden by
repository and machine scope.

- All timestamps in the API are UTC — the reconciliation job depends on it.

## Systems and access

- Orders database — `secret: op://Example/OrdersDB/app-user/password`

## Related

- Repositories: [`../../repositories/my-service.yaml.example`](../../repositories/my-service.yaml.example)
