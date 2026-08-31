---
type: policy
title: Work history — committed ledgers and narratives so agents can answer "what did I do"
status: active
created: 2026-01-01
---

# Work history

This directory answers **"what have I done this year?"** and supports analysis of past
work. It exists because closed PRs and issues otherwise live only in each source
repository's GitHub history — invisible to memory search.

Two layers:

| Layer | Files | Written by | For |
| --- | --- | --- | --- |
| **Ledger** | `<repo-name>/<year>.md` | `mc history sync <owner/repo>` | Counting, grouping, filtering — the analysis layer |
| **Narrative** | `<year>.md` (past years), `<year>-<month>.md` (current year) | An agent, by hand | Retrieval and reading — the memory-search layer |

## Ledgers are generated — never edit them

One file per source repository per year. **Scope: the operator's work only** — pull
requests the operator authored, and issues the operator created *or* is assigned to (bot
and teammate activity is excluded; "the operator" is whoever the authenticated `gh` token
belongs to). Three sections:

- **Merged pull requests** — by merge date (date, link, title, size, labels).
- **Closed issues** — by close date, with the done/cancelled outcome and author.
- **Open issues (snapshot)** — by creation date. A local *pointer index*: use it to
  pinpoint an issue number with `rg`/`qmd`, then read its live state from GitHub. GitHub
  is always the source of truth.

Refresh with:

```bash
mc history sync example-org/my-service   # one repository (also how a NEW repo is backfilled)
mc history sync --all                    # every repository already covered here
```

Regeneration is safe by construction: merged PRs and closed issues do not change, so the
command converges on the same content instead of conflicting (open-issue snapshots simply
update). These files are committed — unlike `reports/generated/` — because the closed
record is frozen history, the same rationale as weekly reviews.

[`history-sync.yml`](../../.github/workflows/history-sync.yml) runs `--all` weekly (and on
demand via *Run workflow*, where a slug input can also backfill a new repo) and lands any
change as a PR. It needs the `HISTORY_SYNC_TOKEN` repository secret: a fine-grained PAT
with read-only Contents/Issues/Pull requests on every covered repository.

## Narratives are judgement — one per period, spanning repos

A narrative file covers **all** repositories for its period, one `## owner/repo` section
per repository, so "what did I do in March?" is one file. Monthly granularity for the
current year, yearly for past years. They summarize themes and link the notable PRs; they
never list routine version bumps individually.

When a new repository is backfilled, merge its story into the **existing** period files —
do not create parallel files.

## Rules

1. **GitHub wins.** A ledger is a snapshot; if it disagrees with GitHub, re-run the sync.
2. **Not the promotion path.** A durable lesson found in an old PR still goes to
   `knowledge/`, `decisions/` or `investigations/` per
   [`../../agent/MEMORY_POLICY.md`](../../agent/MEMORY_POLICY.md) — narratives link, they
   do not substitute.
3. **No per-PR summary files.** Hundreds of near-identical stubs would dominate memory
   search. The ledger row plus the period narrative is the record.
4. **After a sync that changed a period, update that period's narrative** in the same PR.

## Covered repositories

| Repository | Ledgers | First year |
| --- | --- | --- |
| *(none yet — the first `mc history sync <owner/repo>` adds one)* | | |
