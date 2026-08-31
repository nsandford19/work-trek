---
type: report
title: Weekly review <YYYY-MM-DD>
status: active
created: <YYYY-MM-DD>
---

# Weekly review — week ending <YYYY-MM-DD>

> Delete this quote block and every `<...>` placeholder before committing.
> File as `reports/weekly/<YYYY-MM-DD>.md`. Commit as
> `docs(report): weekly review <YYYY-MM-DD>`.
>
> This is committed — unlike generated status output — because it contains **judgement**, and is
> valuable precisely because it is frozen. It answers "what was I thinking in August?", which
> live state never can. Write the interesting parts, not a query dump.

## Gathering (run these, then write below)

```bash
gh issue list -R nsandford19/work-trek --state closed --search "closed:>=<YYYY-MM-DD>" --json number,title,stateReason
gh issue list -R nsandford19/work-trek --state open --label status:blocked
gh issue list -R nsandford19/work-trek --state open --label status:waiting --json number,title,updatedAt
gh issue list -R nsandford19/work-trek --state open --label status:inbox
git log --since="1 week ago" --diff-filter=A --name-only -- knowledge/ '**/decisions/**'
```

## Finished

What actually shipped, and anything notable about what it cost.

- #<n> `<title>` — `<note>`

## Decisions made

- [`NNNN`](../../decisions/NNNN-<slug>.md) — `<decision>`, because `<reason>`

## Learned

New durable knowledge, and anything that changed how I will approach the next similar task.

- `<lesson>` → `knowledge/<area>/<slug>.md`

## Stalled

Blocked and waiting work, with **why** — and whether the reason is still real. Items that have
been waiting for weeks either need chasing or need closing.

| Issue | State | Since | Real blocker? |
| --- | --- | --- | --- |
| #<n> | waiting | `<date>` | `<yes/no + what to do>` |

## Untriaged

Inbox count, and whether it is trending up. A backlog that only grows is a signal to close
things, not to work harder.

## Changing next week

Concrete adjustments — including to this system itself. If a workflow caused friction, say so;
friction is what kills the habit.

## Next focus

The one or two things that matter most next week, and why.
