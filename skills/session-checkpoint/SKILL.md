---
name: session-checkpoint
description: End-of-session reconciliation — update issue state, capture discovered work, promote durable knowledge, mark obsolete memory, record the next action, and commit. Use when meaningful work is finishing, when asked to "wrap up", "checkpoint", or "update memory with what we learned", and before ending any session where issues or files changed.
---

# Skill: session-checkpoint

The step that makes continuity real. Without it, a session's knowledge dies with the context
window and the next agent starts blind.

**If nothing meaningful happened, do nothing and say so.** An empty checkpoint is a correct
outcome — manufacturing a commit to look productive damages the record.

Work through the questions in order.

## 1. Did issue state change?

Reconcile every issue touched. No issue should be left saying something untrue.

```bash
gh issue list -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --state open --label status:in-progress
```

```bash
gh issue edit 43 -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --remove-label status:in-progress --add-label status:review     # work done, unverified
gh issue edit 43 -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --remove-label status:in-progress --add-label status:blocked    # hit a blocker
gh issue edit 43 -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --remove-label status:in-progress --add-label status:waiting    # waiting on someone
gh issue edit 43 -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --remove-label status:in-progress --add-label status:ready      # parked, still actionable
```

Leaving something `in-progress` is fine **if it genuinely is** and the next action is recorded
(step 8).

## 2. Was reusable knowledge discovered?

Test against the promotion bar
([`../../agent/MEMORY_POLICY.md`](../../agent/MEMORY_POLICY.md) §3): will it be needed again in
3+ months, does it explain *why*, has this problem now happened twice, was the command non-trivial
to derive, does it explain surprising behaviour?

- **Passes** → [`document-investigation`](../document-investigation/SKILL.md), or write a
  `knowledge/<area>/` note directly.
- **Fails** → leave it as an issue comment. Say that you chose not to promote it.

Then ask the shape question explicitly: **was any of this session a repeatable procedure?**
Offer a runbook ([`templates/runbook.md`](../../templates/runbook.md) → `runbooks/<slug>.md`
— free on a branch). **Was it an agent workflow with decision points?** Offer a skill in
`skills/` (ask first — hard rule 4). Twice is a routine; ideally this offer already happened
mid-session ([`../../agent/OPERATING_SYSTEM.md`](../../agent/OPERATING_SYSTEM.md) §3), and the
checkpoint is the backstop.

Do not promote narration of what was done. Git and the issue timeline already have that.

## 3. Was a constraining decision made?

If a choice was made that will look wrong without its context →
[`record-decision`](../record-decision/SKILL.md). Apply the six-months test; do not write trivial
ADRs.

## 4. Is something now blocked?

```bash
gh issue edit 43 -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --add-label status:blocked --remove-label status:in-progress
```

Add `Blocked by: #57` to the **first line** of the body and comment what the blocker actually is.
A `blocked` label with no named blocker is a dead end for the next agent.

Also check the reverse: did anything you finished unblock something?

```bash
gh issue list -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --state open --label status:blocked --json number,title,body
gh issue edit 51 -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --remove-label status:blocked --add-label status:ready
```

## 5. Was follow-up work discovered?

Create the issues **now**, with `Source: #<n>` in each body —
[`capture-work`](../capture-work/SKILL.md). Use `status:inbox`; do not stop to triage.

**Discovered work that is not captured is lost work.** This is the most common failure of the
whole system.

## 6. Is existing memory now obsolete?

If something in the repo is now wrong or superseded, fix it — **do not delete it**:

- Better answer found → `status: superseded` + `superseded_by:` on the old document.
- Discovery was wrong → `status: obsolete` + a `## Correction` section stating what is actually
  true. Keeping it stops the same wrong conclusion being reached twice.
- Re-verified something and it still holds → bump `last_verified:`.
- A registry path changed → update `repositories/<name>.yaml`.

## 7. Did the operator correct or redirect you this session?

A correction, a stated preference, or the same adjustment asked for twice is memory —
**offer to record it**, at the narrowest true scope
([`../../agent/OPERATING_SYSTEM.md`](../../agent/OPERATING_SYSTEM.md) §3):

- Stable and cross-project → [`../../agent/PREFERENCES.md`](../../agent/PREFERENCES.md)
  (ask first — it is `agent/**`).
- True only for one project → that project's `README.md` `## Conventions`.
- About how one skill behaves → that skill's `PREFERENCES.md`, Rules/Candidates pattern
  ([`../../agent/MEMORY_POLICY.md`](../../agent/MEMORY_POLICY.md) §8) — a rule only from
  explicit operator feedback, with provenance; anything you merely observed stays a candidate.

Never record silently, never invent. If the operator declines, drop it — a declined offer
is an answer, not a candidate.

## 8. What is the likely next action?

Record it as an issue comment. **This is the highest-value 30 seconds of the session** — it is
what lets a different agent, on a different machine, weeks later, resume without the
conversation.

```bash
gh issue comment 43 -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --body "Stopped here: <state>. Next: <specific action>. Watch out for: <trap>."
```

Be specific. "Continue working on this" is useless; "the retry logic in SyncJob.cs:88 double-counts
— add the guard before touching the tests" is not.

## 9. Commit and push

```bash
git status --short
git diff --check              # confirm no CRLF or whitespace damage
```

One logical change per commit — a registry update and a new ADR are two commits:

```bash
git add <specific files>
git commit -m "docs(memory): document <the fact>"
```

**Never** `chore: agent run`. If there is nothing durable to commit, commit nothing.

```bash
git pull --rebase && git push
```

Pushing to `main` needs asking. If the work touched `agent/**` or `skills/**`, it must go through
a branch and a PR.

## 10. Report

Summarise plainly:

> Checkpoint: #43 → `review`. Created #47, #48 (follow-ups). Documented the zone-reload cause in
> `knowledge/networking/<slug>.md`. Marked `investigations/old-dns.md` superseded. Next action
> recorded on #43. Two commits pushed to `feat/dns-retry`.

If you skipped a step because it did not apply, say so — silence looks like an omission.
