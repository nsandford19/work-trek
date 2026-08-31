---
type: policy
title: Templates
status: active
created: 2026-08-10
---

# Templates

Copy, rename, fill in, delete the placeholders.

| Template | Copy to | For |
| --- | --- | --- |
| [`project-README.md`](project-README.md) | `projects/<name>/README.md` | A new project |
| [`investigation.md`](investigation.md) | `investigations/<slug>.md` or `projects/<p>/investigations/<slug>.md` | The result of diagnostic work |
| [`decision.md`](decision.md) | `decisions/NNNN-<slug>.md` or `projects/<p>/decisions/NNNN-<slug>.md` | An ADR |
| [`knowledge.md`](knowledge.md) | `knowledge/<area>/<slug>.md` | A durable technology fact |
| [`runbook.md`](runbook.md) | `runbooks/<slug>.md` or `projects/<p>/runbooks/<slug>.md` | A repeatable procedure |
| [`weekly-review.md`](weekly-review.md) | `reports/weekly/<YYYY-MM-DD>.md` | The weekly review |

Every template carries a `> quote block` of instructions at the top. **Delete it**, along with
all `<...>` placeholders — `mc validate` fails on any leftover placeholder.

## Rules that apply to all of them

1. **Fill in the front matter honestly.** `type`, `title`, `status`, `created` are required
   everywhere; `last_verified` is required for `knowledge/` and `runbooks/`. There is no
   `updated:` field — Git records that.
2. **Title as a claim, not a topic.** Titles are the primary retrieval surface for both `rg` and
   a scanning agent.
3. **Put the document at the narrowest scope where it is still true.** Project-specific findings
   go in the project, not in the general directory.
4. **Add an index row** to the directory's `README.md` in the same commit. An unindexed document
   is one nobody finds.
5. **Secret pointers, never secrets** — `secret: op://<vault>/<item>/<field>` (a 1Password secret reference).
6. **Never put task state in these documents.** Issues are the only source of truth.

Full guidance: [`../agent/MEMORY_POLICY.md`](../agent/MEMORY_POLICY.md).

## Issue templates

These are Markdown document templates. GitHub **issue** forms are separate and live in
[`../.github/ISSUE_TEMPLATE/`](../.github/ISSUE_TEMPLATE/).
