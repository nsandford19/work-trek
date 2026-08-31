---
type: project
title: <Project name> — <one-line purpose>
status: active
created: <YYYY-MM-DD>
last_verified: <YYYY-MM-DD>
repositories: [<owner/name>]
areas: [<area>]
tags: [<tag>]
---

# Project: <name>

> Delete this quote block and every `<...>` placeholder before committing.
> File as `projects/<name>/README.md`. Create the `project:<name>` label too:
> `gh label create -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} "project:<name>" --description "Project: <name>" --color D4C5F9`
>
> **Keep this under one screen.** It is a hub, not a document — it links outward. If it grows,
> split into `architecture.md`, a runbook, or a knowledge note.

## Purpose

What this project is for and why it exists. One short paragraph. Include what "done" or
"healthy" looks like, if that is meaningful.

## Current shape

How the pieces fit together — enough for an agent to orient. Link to `architecture.md` for
detail rather than expanding here.

| Piece | Where |
| --- | --- |
| `<component>` | `<repository or system>` |

## Live work

**Never list tasks or status here** — issues are the only source of truth:

```bash
gh issue list -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --state open --label project:<name>
```

## Key decisions

| ADR | Decision |
| --- | --- |
| [NNNN](decisions/NNNN-<slug>.md) | `<the decision>` |

## Conventions

**Scope: `project`** — overrides organization and personal defaults; overridden by repository
and machine scope. Only rules that are true *because of this project*. Generic style
preferences belong in `agent/PREFERENCES.md`.

- `<convention, and briefly why>`

## Systems and access

Hosts, clusters, databases, and endpoints an agent needs to know about. **Pointers to
credentials, never credentials:**

- `<system>` — `secret: op://<vault>/<item>/<field>`

## Known risks

| Risk | Watch for |
| --- | --- |
| `<risk>` | `<the observable early signal>` |

## Related

- Repositories: [`../../repositories/<name>.yaml`](../../repositories/<name>.yaml)
- Investigations: `investigations/`
- Runbooks: `runbooks/`
