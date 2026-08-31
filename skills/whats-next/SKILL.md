---
name: whats-next
description: Recommend what to work on next by ranking open GitHub Issues on readiness, priority, initiative membership and local repository availability. Use when asked "what should I work on?", "what am I working on?", "what's blocked?", "what am I waiting on?", "what can I do on this laptop?", or "what unfinished work do I have?"
---

# Skill: whats-next

Answer "what should I work on next?" from live issue state. **Never return the oldest open
issue** — rank properly and explain the reasoning.

Accelerator: `mc next`. The steps below are what it does, and what to do if it is unavailable.

## 1. Resolve the machine

```powershell
$env:MC_MACHINE ; hostname
```

Match against `id`/`aliases`/`hostnames` in `machines/*.yaml`. If it does not resolve, say so
and continue — only the local-availability filter (step 5) is affected.

## 2. Fetch open work — one call

```bash
gh issue list -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --state open --limit 200 \
  --json number,title,labels,body,createdAt,updatedAt
```

Bodies are needed for `Blocked by:` lines. One call is enough; do not query per label.
Fetch live — do not rank from the generated issue cache (`reports/generated/issues.md`),
which can be a day stale; readiness and status need current state. The cache is only for
the *pinpoint* case — "which issue was about X?" before or after ranking
([`../../agent/OPERATING_SYSTEM.md`](../../agent/OPERATING_SYSTEM.md) §3).

## 3. Exclude what is not actionable

Drop issues labelled `status:inbox` (untriaged), `status:blocked`, or `status:waiting`. Count
them — they are reported at the end.

Also set aside `type:initiative` issues. **An initiative is a container, not work** — you
advance one by doing its sub-issues, so recommending the initiative itself is not an
actionable answer. List them separately as active initiatives.

## 4. Recompute readiness — do not trust the labels

Labels drift. For every remaining issue, parse `Blocked by: #12, #15` from the body and check
each referenced issue:

```bash
gh issue view 12 -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --json number,state,title
```

- A `ready` issue whose blocker is still **open** → not ready. Fix the label:
  `gh issue edit <n> -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --remove-label status:ready --add-label status:blocked`
- A `blocked` issue whose blockers are **all closed** → it *is* ready. Fix the label and
  include it as a candidate. This is often the most valuable find of the whole workflow.

Mention any label you corrected.

## 5. Filter to this machine

- `needs:machine` labelled for a different machine → exclude.
- Issue names `Repository:` → match it exactly in `repositories/*.yaml`; if the current
  machine is absent from its `machines:` map, exclude it and **say which machine has it**.
- No explicit repository → use `project:<p>` only when it maps to exactly one repository.
  Multiple matches are ambiguous; report that the issue needs a `Repository:` line.

```bash
rg -l "project: <p>" repositories/
```

Never suggest work whose repository is not checked out here without saying so.

## 6. Rank

In order:

1. `status:in-progress` — **finishing beats starting**.
2. Priority: `p0` → `p1` → `p2` → `p3`.
3. Belongs to an open `type:initiative` — check the sub-issue relationship:
   ```bash
   gh api repos/{{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}}/issues/<initiative>/sub_issues \
     --jq '.[] | "#\(.number) \(.title) [\(.state)]"'
   ```
4. `type:decision` that blocks other issues — unblocking work is high leverage.
5. Age — **tie-break only**.

## 7. Read the recorded next action

Ranking finds the issue. It does not tell you where the last session stopped — that lives in the
newest comment, written by `session-checkpoint`, and it is the entire payload of a cross-machine
handoff. **Fetch it for the recommendation before answering:**

```bash
gh issue view <n> -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} \
  --json comments --jq '.comments[-1].body'
```

The body says what the work *is*; the latest comment says what to do *next*, and the two diverge
as soon as work starts — the body may describe a bug that is already fixed and awaiting review.
Quote the next action rather than paraphrasing it, so a resuming agent can act on it directly.

If an `in-progress` issue has no comment, say so plainly: it means nobody recorded where they
stopped, so you are restarting it blind rather than resuming it.

## 8. Answer

Give 2–4 candidates with a one-line reason each, name one recommendation, quote its recorded next
action, then report what is stuck so nothing rots invisibly.

> **Recommend #43** *Fix stale DNS records* — `p1`, already `in-progress`, and `dns-tools` is
> checked out here.
>
> **Next action**, recorded on `laptop` 2 days ago: *"Rebuild the zone file from
> `terraform/dns.tf`, then re-run `make verify-dns`."*
>
> Also ready:
> - #51 *Add retry to sync job* — `p1`, newly unblocked (#57 closed yesterday)
> - #38 *Update runbook* — `p2`, small, same project as #43
>
> Not available here: #62 (`needs:machine` → `linux-dev`)
> Blocked: 2 · Waiting: 1 — **#29, 12 days, worth chasing** · Inbox: 4 untriaged

Rules for the answer:

- **Always cite issue numbers.** They are how the operator acts on the recommendation.
- **Always quote the recommendation's recorded next action**, or state that none exists. A
  recommendation without it makes the reader re-derive what the last session already knew, which
  is the failure this system exists to prevent.
- **Flag stale `waiting`** — anything not updated in 7+ days.
- **Report the inbox count** every time. An unmentioned backlog becomes an invisible one.
- If nothing is actionable, say that plainly and suggest triaging the inbox or unblocking a
  blocker — do not invent work.
- If asked a narrower question ("what's blocked?"), answer just that with one `gh` call.

## 9. Optional

If the operator picks something up:

```bash
gh issue edit 43 -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --remove-label status:ready --add-label status:in-progress
```

Do not change labels unprompted, other than the readiness corrections in step 4.
