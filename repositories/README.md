---
type: policy
title: Source repository registry
status: active
created: 2026-08-10
---

# Repositories

One YAML file per source-code repository the operator works on, wherever it lives. This is what lets
an agent answer:

- *Which repository contains the cleanup job?* → `rg -i "cleanup" repositories/`
- *Which machine has repository X checked out?* → `repositories/X.yaml` → `machines:`
- *Where is it on this machine?* → `machines.<current-machine>.path`
- *Which tasks can I do on this laptop?* → only work whose repository is available here
- *What tasks relate to repository X?* → exact `Repository:` issue metadata, with
  `project:` as the fallback for older issues

It also carries **repository scope** conventions, which override project, organization, and
personal defaults (see [`../agent/OPERATING_SYSTEM.md`](../agent/OPERATING_SYSTEM.md) §2).

## Registered repositories

| Repository | Purpose | Project | Available on |
| --- | --- | --- | --- |
| Millers-IT/Entry | Container repo for Entry-related projects | Entry | PNOELLES |
| Millers-IT/IdentityServer | Customized Solliance IdentityServer (auth) | — | PNOELLES |
| Millers-IT/mapi | Millers API solution | — | PNOELLES |
| Millers-IT/MillersApps | Web apps for Production/CS/Accounting/Devs | MillersApps | PNOELLES |
| Millers-IT/MillersLab.com | Millers website (www.millerslab.com) | — | PNOELLES |
| Millers-IT/MillersWorkflows | Argo Workflows + RabbitMQ workflow system | — | PNOELLES |
| Millers-IT/mpix-3 | Mpix 3.0 Nx monorepo (web + APIs) | Mpix | PNOELLES |
| Millers-IT/Mpix.Com.Core | Core Mpix.Com services (API, search, YARP) | Mpix | PNOELLES |
| MillersProfessionalImaging/Mpix.Com | Legacy Mpix.com storefront (WebForms + Angular) | Mpix | PNOELLES |
| Millers-IT/Mpix.Create | Visual project design/inspection before print | Mpix | PNOELLES |
| Millers-IT/MpixContext | Mpix/Millers runtime, plugins, shared models | — | PNOELLES |
| Millers-IT/MpixEntry | Mpix Entry solution | — | PNOELLES |
| nsandford19/mppm | Git-based AI personal project manager | — | PNOELLES |
| nsandford19/work-trek | Personal engineering OS / control plane (this repo) | — | PNOELLES |

A fictional worked example of the schema ships as
[`my-service.yaml.example`](my-service.yaml.example); the `.example` suffix keeps it out
of path resolution and validation. Copy it, drop the suffix, and edit.

---

## The rule that matters most

**Never assume a repository exists on every machine.** A machine absent from `machines:`
simply does not have it checked out. When work needs a repository that is missing locally, say
so and name the machine that has it — do not offer a path that will not resolve.

## Registration is intentional

`mc repo scan` finds Git repositories under the current machine's `dev_roots` and *proposes*
entries. It never writes this registry. Auto-registering everything a scanner finds would fill
it with vendored clones, experiments, and throwaways, and bury the entries that matter.

Register a repository when it has durable relevance: real work happens there, or a future
agent will need to find it.

---

## Schema

```yaml
repository: example-org/my-service   # REQUIRED — owner/name, or a local-only identifier
host: github.com                    # REQUIRED — github.com | ado | gitlab | local
description: One line saying what it is.   # REQUIRED
status: active                      # REQUIRED — active | archived | deprecated
primary_branch: main                # REQUIRED
last_verified: 2026-08-10           # REQUIRED

purpose: 'Slightly longer why-it-exists, as a single quoted string.'   # optional
technologies: [dotnet, sqlserver, kubernetes]
areas: [software-development, databases]

project: dns-automation             # optional — links to projects/<name>/
related_repositories: [example-org/infrastructure]
related_systems: ['SQL Server: sql-prod-01', 'Elasticsearch: es-prod']

# Local paths per machine. A machine that is absent does NOT have this checked out.
machines:
  example-laptop:
    path: 'C:\dev\my-service'
  linux-dev:
    path: /home/user/repos/my-service

docs:                               # important documentation, in-repo or external
  - 'docs/architecture.md — service design'

# REPOSITORY SCOPE — overrides project, organization and personal conventions.
conventions:
  - 'Tabs, not spaces — legacy codebase, do not reformat.'

notes:                              # agent notes: gotchas, build quirks, where things are
  - 'Integration tests need a local SQL instance; see runbooks/.'
```

### Field notes

- **`repository`** is the canonical identity and should match the filename (`owner/name` →
  `name.yaml`). For a repository with no remote, use `local/<name>` and set `host: local`.
- **`project`** is the bridge to durable context and to `project:*` issue labels. One
  repository maps to at most one project; a project may span several repositories.
- **Issue `Repository:` metadata** is the precise work-to-source edge. It wins over
  `project:` because one project may span several repositories.
- **`machines`** is the availability map — the single most load-bearing field here.
- **`conventions`** are for rules true *because of this repository*. Do not put personal
  style preferences here; they belong in
  [`../agent/PREFERENCES.md`](../agent/PREFERENCES.md).
- **`notes`** is where hard-won practical detail goes — the build quirk, the required local
  service, the directory that looks dead but is not.
- **`related_systems`** names infrastructure. Names and hostnames are fine; **credentials
  never are** — record a pointer instead (a 1Password
  secret reference: `secret: op://<vault>/<item>/<field>`). See
  [`../agent/SECURITY_POLICY.md`](../agent/SECURITY_POLICY.md).

### YAML dialect

Same constrained subset as the machine registry — documented in
[`../machines/README.md`](../machines/README.md#yaml-dialect) and enforced by `mc validate`.
Single-quote Windows paths.

---

## Adding an entry

```bash
mc repo scan                                   # proposes entries for this machine
cp repositories/my-service.yaml.example repositories/<name>.yaml   # then edit
mc validate
```

Add a row to the table above, then commit:

```
chore(registry): add <name>
chore(registry): add laptop paths for <name>     # when a second machine gets it
```

## When a repository moves or dies

- **Moved on a machine** → update that machine's `path`.
- **No longer checked out somewhere** → remove that machine from `machines:`.
- **Renamed** → rename the file and update `repository:`; note the old name in `notes:` so old
  issue references still lead somewhere.
- **Archived** → `status: archived`, keep the file. Old issues and ADRs reference it, and
  deleting it orphans them.
