---
name: capture-work
description: Create a correctly typed, labelled and linked GitHub Issue in the Work Trek control plane. Use whenever a task, bug, idea, investigation, decision, research question or follow-up is mentioned that should not be lost — including "create a task for this", "we should look into X later", or work discovered while doing something else.
---

# Skill: capture-work

Turn something worth doing into a properly labelled issue, in one step.

**Capture must be cheap or it will not happen.** Do not interrogate the operator for metadata — pick
sensible labels, use `status:inbox` when unsure, and move on. A captured issue with imperfect
labels beats lost work.

## 1. Check it does not already exist

Cache first — a duplicate check is a *find*, not a decision
([`../../agent/OPERATING_SYSTEM.md`](../../agent/OPERATING_SYSTEM.md) §3):

```bash
rg -in "<key words>" reports/generated/issues.md
```

No cache, or nothing found and the cache is old? Fall back to the API:

```bash
gh issue list -R nsandford19/work-trek --state all --search "<key words>" --json number,title,state
```

If it exists, verify it live (`gh issue view <n> -R nsandford19/work-trek`)
and comment on it instead of creating a duplicate.

## 2. Choose the type — exactly one

| Type | The question |
| --- | --- |
| `type:task` | Do a specific bounded thing |
| `type:bug` | Something of mine is wrong |
| `type:investigation` | *Why is my system doing this?* (inward, already happening) |
| `type:research` | *Which option should I pick?* (outward, not yet chosen) |
| `type:decision` | A choice is needed before work continues |
| `type:initiative` | A multi-task outcome, will contain sub-issues |
| `type:maintenance` | Recurring upkeep, no new knowledge expected |

No `follow-up` type — a follow-up is a `type:task` with `Source: #N` in the body.

## 3. Choose status

- **`status:inbox`** — the default. Captured, not triaged. Correct whenever the operator is mid-something
  else; do not interrupt the current work to triage.
- **`status:ready`** — only when it is genuinely actionable now and nothing blocks it.
- **`status:blocked`** — something else must finish first. Add a `Blocked by:` line.

## 4. Priority and area

One priority, always: `p0` outage/blocking · `p1` this week · `p2` normal · `p3` someday.
Default `p2` if unclear.

Areas (0..n): `software-development` `infrastructure` `devops` `kubernetes` `databases`
`security` `ai` `networking` `personal-tools`.

Project (0..1): `project:<name>` must match a directory in `projects/`. Check first:

```bash
ls projects/
```

Do not invent a `project:` label — an unregistered project is not a project.

## 5. Write the body

```markdown
Blocked by: #12
Source: #40

## What
One or two sentences. What outcome is wanted.

## Why
The trigger — why this matters, or what broke.

## Context
Repository: example-org/dns-tools
Relevant memory: knowledge/networking/<slug>.md
Verbatim error, command, or log excerpt if there is one.
```

- `Blocked by:` and `Source:` go on the **first lines** so they are trivially parseable.
- Include **verbatim error text**. It is what future searches will match on.
- Link relevant durable memory if you know of it.
- **Never put credentials in an issue body** — a pointer instead
  (`secret: op://<vault>/<item>/<field>`).

## 6. Create it

```bash
gh issue create -R nsandford19/work-trek \
  --title "Fix stale DNS records surviving zone reload" \
  --body-file <path> \
  --label type:bug,status:inbox,p2,area:networking
```

Prefer `--body-file` for multi-line bodies. On Windows, **do not** use PowerShell here-strings
or heredocs through a Bash tool — write a temp file with a file-write tool instead.

## 7. Link it

If it belongs to an initiative, attach it as a native sub-issue (verified working on this repo):

```bash
gh api graphql -f query='mutation($p:ID!,$c:ID!){addSubIssue(input:{issueId:$p,subIssueId:$c}){issue{number}}}' \
  -F p="$(gh issue view 10 -R nsandford19/work-trek --json id --jq .id)" \
  -F c="$(gh issue view 43 -R nsandford19/work-trek --json id --jq .id)"
```

If that fails, add `Parent: #10` to the body instead. **Never maintain both** for the same pair.

## 8. Report back

Give the issue number and URL, and state the labels applied so the operator can correct them cheaply:

> Created #44 — `type:bug` `status:inbox` `p2` `area:networking`. Linked as a sub-issue of #10.

## Capturing several at once

Discovered a batch of follow-ups? Create them all with `status:inbox`, each with
`Source: #<n>`, then report the numbers as a list. Do not stop to triage.
