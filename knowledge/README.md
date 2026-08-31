---
type: policy
title: Knowledge index
status: active
created: 2026-08-10
---

# Knowledge

Cross-project durable facts: how a technology actually behaves, what surprised us, the
non-obvious command, the recurring gotcha. Organised by area, matching the `area:*` issue
labels.

**Knowledge vs project context:** how a *technology* behaves in general lives here; how *my
specific system* is built lives in [`../projects/`](../projects/README.md). A fact about my
cluster filed as a general truth will mislead someone later.

## Areas

| Area | Entries |
| --- | --- |
| `software-development/` | — |
| `infrastructure/` | — |
| `devops/` | — |
| `kubernetes/` | — |
| `databases/` | — |
| `security/` | — |
| `networking/` | — |
| `ai/` | — |
| `personal-tools/` | — |

Directories are created on first use — no empty placeholders.

## Entries

| Entry | Area | Verified |
| --- | --- | --- |
| [Example: a database engine that installs as a named instance breaks default-instance connection strings](example-named-instance-breaks-connection-strings.md.example) | databases | (fictional example) |

The single `.example` file above is a fictional worked example of a knowledge entry —
delete it once you have written a real one.

---

## Writing an entry

Use [`../templates/knowledge.md`](../templates/knowledge.md). File as
`knowledge/<area>/<slug>.md`.

**Title it as a claim, not a topic.** "SQL Express installs as a named instance, breaking
default-instance connection strings" beats "SQL Express notes". Titles are what `rg` and a
scanning agent match on, so a good title is half the retrieval system.

Include verbatim error text and exact commands — those are the highest-value searchable
content in the repository.

`last_verified:` is required here, because knowledge decays. Bump it whenever you rely on an
entry and confirm it still holds:

```
docs(memory): re-verify <topic>
```

Then add a row to the table above and commit:

```
docs(memory): document <the claim>
```

## The bar

Do not write an entry for something rediscoverable in under two minutes, or for a copy of
upstream documentation. Link the docs and record only the part that surprised you. Full
criteria: [`../agent/MEMORY_POLICY.md`](../agent/MEMORY_POLICY.md) §3.

## When an entry is wrong

Mark it `status: obsolete` and add a `## Correction` section stating what is actually true.
**Do not delete it** — a recorded wrong conclusion stops the same wrong conclusion being
reached twice.
