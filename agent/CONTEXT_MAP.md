---
type: policy
title: Context Map — question shape to smallest file set
status: active
created: 2026-08-10
---

# Context Map

This is the routing table that keeps startup cheap. Find the row matching what was asked,
open **only** those sources, and stop.

Reading more is not thoroughness — it is context spent on irrelevant text, which makes
answers worse, not better.

---

## Operational questions — answered from GitHub, not files

| Asked | Read |
| --- | --- |
| What should I work on next? | [`skills/whats-next`](../skills/whats-next/SKILL.md) → `gh issue list -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --state open`, plus `repositories/*.yaml` for local availability |
| What am I working on right now? | `gh issue list -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --state open --label status:in-progress` |
| What is blocked? | `gh issue list -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --state open --label status:blocked` then check each `Blocked by:` line |
| What am I waiting on? | `gh issue list -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --state open --label status:waiting` — flag anything not updated in 7+ days |
| What unfinished work do I have? | `status:in-progress` + `status:review` + `status:blocked` |
| What needs triage? | `gh issue list -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --state open --label status:inbox` |
| What did I finish recently? | `gh issue list -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --state closed --limit 20 --json number,title,closedAt,stateReason` |
| How is initiative X going? | `gh issue view <n> -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}}` for the initiative, then its sub-issues |
| Which tasks can I do on this laptop? | `whats-next`, machine filter step — `needs:machine` labels + `repositories/*.yaml` |

---

## Historical questions — issues first, then durable memory

| Asked | Read |
| --- | --- |
| What happened with project X? | `projects/X/README.md` → then `gh issue list -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --state all --label project:X` |
| What happened with <topic>? | `gh issue list -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --state all --search "<topic>"`, then `gh issue view N -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --comments`, then the linked findings doc |
| What did we conclude last time? | The investigation's findings doc (linked from the issue), not the comment thread |
| Why did we choose Y? | `rg -il "<topic>" decisions/ projects/*/decisions/` → read the ADR |
| What was the result of investigation Y? | `rg -il "<topic>" investigations/ projects/*/investigations/` |
| What did I learn about technology Z? | `rg -il "<Z>" knowledge/` → then the specific file |
| Have I solved something like this before? | `rg -i "<error text or symptom>" knowledge/ investigations/ projects/` then `gh issue list -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --state all --search` |
| What recurring problems do I hit with <area>? | `knowledge/<area>/`, plus `gh issue list -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --state all --label area:<area>` |
| What have I learned recently? | `git log --since="3 weeks ago" --name-only -- knowledge/ decisions/ investigations/` |
| What decisions were made this month? | `git log --since="1 month ago" --diff-filter=A --name-only -- '**/decisions/**'` |

**Start with the ADR or findings doc, not the issue thread.** The document is the distilled
answer; the thread is the raw material. Read the thread only when the document is missing or
does not cover the question.

**Pinpointing an issue number is a grep, not an API call.** Before any `--search` above, grep
the issue cache — `rg -in '<topic>' reports/generated/issues.md`, ladder and staleness rule in
[`OPERATING_SYSTEM.md`](OPERATING_SYSTEM.md) §3. Anything authoritative still reads GitHub live.

---

## Registry questions — read the YAML, nothing else

| Asked | Read |
| --- | --- |
| Which repository contains X? | `rg -i "<X>" repositories/` (descriptions and purposes are indexed there) |
| Which machine has repository X checked out? | `repositories/X.yaml` → `machines:` |
| Where is repository X on this machine? | `repositories/X.yaml` → `machines.<current>.path` |
| What repositories exist here? | `repositories/README.md` index, filtered by current machine |
| What does an org-wide naming convention (host prefixes, cluster names, namespaces) mean? | `organizations/<name>.md` — org-scoped conventions live there |
| Which repository owns this production problem? | `organizations/<name>.md` ownership notes, then `repositories/*.yaml` descriptions |
| What machine am I on? | `$env:MC_MACHINE` else `hostname` → match `machines/*.yaml` |
| What tools/constraints does this machine have? | `machines/<id>.yaml` |
| What tasks relate to repository X? | Search issues for its exact `Repository:` identity; use `repositories/X.yaml` → `project:` → `gh issue list -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --label project:<p>` only as fallback |

---

## Doing work

| Situation | Read |
| --- | --- |
| Starting or continuing Work Trek issue #N | [`skills/start-work`](../skills/start-work/SKILL.md) → resolve its `Repository:` through the current machine registry |
| Starting work in a source repo | `repositories/<name>.yaml`, then the linked `projects/<p>/README.md` — and that project's `## Conventions` |
| Need conventions/preferences | Narrowest first: `machines/` → `repositories/` → `projects/*/README.md` → `organizations/` → [`PREFERENCES.md`](PREFERENCES.md) |
| Performing a known procedure | `runbooks/` or `projects/<p>/runbooks/` |
| Need to understand a system's design | `projects/<p>/architecture.md` |
| About to record something | [`MEMORY_POLICY.md`](MEMORY_POLICY.md) §2–3 |
| About to create or edit an issue | [`TASK_POLICY.md`](TASK_POLICY.md) §1, §3 |
| Finishing meaningful work | [`session-checkpoint`](../skills/session-checkpoint/SKILL.md) |

---

## Meta questions

| Asked | Read |
| --- | --- |
| Why is this system built this way? | [`../ARCHITECTURE.md`](../ARCHITECTURE.md) |
| What skills exist? | [`../skills/README.md`](../skills/README.md) |
| How do I set up a new machine? | [`../README.md`](../README.md) bootstrap section |

---

## Search technique

1. **Titles and front matter first** — titles are written as claims, so they match well:
   ```bash
   rg -i --glob '**/*.md' '^title:.*<term>'
   ```
2. **Then full text**, listing files before reading any:
   ```bash
   rg -il '<term>' knowledge/ investigations/ decisions/ projects/
   ```
3. **Verbatim error strings are the best queries.** They were deliberately recorded for this.
4. **Then operational history:**
   ```bash
   gh issue list -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --state all --search '<term>' --json number,title,state
   ```
5. **Check `status:` before trusting** anything you open (see [`MEMORY_POLICY.md`](MEMORY_POLICY.md) §6).

---

## Never read at startup

- `projects/**` in bulk — only the one project in question
- Any closed investigation no search pointed at
- `ARCHITECTURE.md` unless asked about the system itself
- `reports/**` unless asked for a report
- Another project's context to answer a question about this one
- More than one ADR when the question names one decision
