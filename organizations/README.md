---
type: policy
title: Organizations index
status: active
created: 2026-01-01
---

# Organizations

One Markdown file per organization whose conventions cut across several projects and
repositories: naming schemes (host prefixes, cluster and environment names), ownership
maps ("which repository owns which production system"), and any rule that is true because
of the organization rather than a single project.

Organization scope sits between project and personal in the precedence order — see
[`../agent/OPERATING_SYSTEM.md`](../agent/OPERATING_SYSTEM.md) §2. Narrower scopes
(machine, repository, project) override anything written here.

## Files

| Organization | Covers |
| --- | --- |
| *(none yet — add `<name>.md` when an org-wide convention needs a home)* | |

## What belongs here

- Naming conventions: what a hostname prefix means, how clusters/environments are named.
- Ownership: which repository or team owns which system, namespace, or production concern.
- Org-wide engineering rules that are not project-specific.

## What does not

- Task state (GitHub Issues), secrets (pointers only — see
  [`../agent/SECURITY_POLICY.md`](../agent/SECURITY_POLICY.md)), or anything true of only
  one project or repository — put those at their narrower scope.
