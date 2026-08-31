---
type: policy
title: Projects index
status: active
created: 2026-08-10
---

# Projects

A **project** is a durable area of work with its own context: purpose, architecture,
decisions, findings, and procedures. Projects are long-lived; the work inside them is
GitHub Issues.

Every project has a matching `project:<name>` issue label, so a project's live work is always
one query away:

```bash
gh issue list -R nsandford19/work-trek --state open --label project:work-trek
```

## Active projects

| Project | Purpose | Repositories | Issues |
| --- | --- | --- | --- |
| [`example-project`](example-project/README.md) | Fictional worked example — replace with your first real project | `my-service` (fictional) | `--label project:example-project` |

`example-project/` is a clearly-fictional placeholder demonstrating the layout. Delete it
(and its `project:example-project` label in [`.github/labels.yml`](../.github/labels.yml))
once you have a real project.

## Archived projects

None yet. Archived projects keep their directory — old issues and ADRs point at them.

---

## What belongs in a project directory

```
projects/<name>/
├── README.md          Purpose, current shape, conventions, links. START HERE.
├── architecture.md    How the system is built (optional)
├── decisions/         Project-scoped ADRs (NNNN-slug.md)
├── investigations/    Project-scoped findings
└── runbooks/          Project-scoped procedures
```

**Never put progress, status, or task lists in project Markdown.** That is what issues are
for, and two copies of the truth is the failure mode this whole system is built to avoid.

The project `README.md` should stay under roughly one screen. It is a hub, not a document —
it links outward. If it is growing, split content into `architecture.md`, a runbook, or a
knowledge note.

### Project vs knowledge

- *How **my** system is built and why* → `projects/<name>/`
- *How a **technology** behaves in general* → [`../knowledge/`](../knowledge/README.md)

Put a document at the narrowest scope where it is still true.

---

## Creating a project

```bash
mkdir -p projects/<name>/{decisions,investigations,runbooks}
cp templates/project-README.md projects/<name>/README.md   # then edit
gh label create -R nsandford19/work-trek "project:<name>" --description "Project: <name>" --color D4C5F9
```

Also append the new `project:<name>` label to [`.github/labels.yml`](../.github/labels.yml) —
it is the canonical label list — and run `mc labels sync`.

Add a row to the table above, then commit:

```
docs(project): add <name>
```

Create a project when work in an area is recurring and needs context that outlives a single
issue. A one-off task does not need a project — it just needs an issue.
