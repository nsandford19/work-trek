---
type: policy
title: Skills index
status: active
created: 2026-08-10
---

# Skills

Reusable workflows. Each is a short procedure with literal commands — not a prompt.

**Check here before improvising a multi-step workflow.** These encode decisions already made,
so following one is faster and produces consistent results across agents.

| Skill | Use when |
| --- | --- |
| [`whats-next`](whats-next/SKILL.md) | "What should I work on?" · "What's blocked?" · "What can I do on this machine?" |
| [`triage-notifications`](triage-notifications/SKILL.md) | "What needs my attention on GitHub?" · triage unread notifications into a prioritized briefing |
| [`start-work`](start-work/SKILL.md) | "Fix issue #N" · "Continue #N" · resolve selected work to its local source checkout |
| [`capture-work`](capture-work/SKILL.md) | Anything worth doing later is mentioned — task, bug, idea, investigation |
| [`document-investigation`](document-investigation/SKILL.md) | A diagnosis reached a conclusion and should become durable memory |
| [`record-decision`](record-decision/SKILL.md) | A choice was made that will constrain future work |
| [`register-repository`](register-repository/SKILL.md) | A source repository or machine should be known to the system |
| [`session-checkpoint`](session-checkpoint/SKILL.md) | Meaningful work is finishing — **run this before ending a session** |
| [`orchestrate-work`](orchestrate-work/SKILL.md) | Coordinate a selected issue through helper agents in Herdr |
| [`dispatch-remote-agent`](dispatch-remote-agent/SKILL.md) | Send an issue to an agent on **another** registered machine over SSH |
| [`mc`](mc/SKILL.md) | A tooling request — doctor, validate, dashboard, label/skill sync, onboard — without remembering `mc` commands |

---

## How agents find these

| Agent | Mechanism |
| --- | --- |
| **Claude Code** | Auto-discovers `.claude/skills/<name>/SKILL.md`, which are generated stubs that delegate here |
| **Codex** | `AGENTS.md` points at this index |
| **Antigravity CLI (`agy`)** | `AGENTS.md` points at this index |

Canonical bodies live **here**, in `skills/<name>/SKILL.md`. Edit these, then run
`mc skills sync` to regenerate the Claude stubs. The validator checks they match.

The stubs duplicate only a name and a description — never procedure text — so there is one
copy of every workflow.

## What belongs here

**Inclusion test: does it read or write Work Trek state** — issues, registries, or
durable memory? If not, it does not belong here.

Generic coding workflows (`review-dotnet-code`, `debug-kubernetes`, `plan-refactor`) fail that
test. They gain nothing from living in this repository and they dilute this index, which every
agent scans. Put those in the target code repository or in the agent's global configuration.

## Authoring rules

1. **Vendor-neutral.** Plain Markdown, real shell commands. No vendor tool names, no
   model-specific syntax. It must be executable by Claude, Codex, and Antigravity alike.
2. **Short.** Past ~150 lines it is really two skills, or it is documentation that belongs in
   `runbooks/`.
3. **Literal commands, not descriptions of commands.** `gh issue edit 42 -R
   {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --add-label status:ready` — not "update the label".
4. **Numbered steps** in the order they are performed.
5. **Name what requires asking first.** Closing issues, pushing to `main`, editing `agent/**`.
6. **Front matter** with `name` and `description`; the description is what makes it
   discoverable, so write it as trigger conditions.
7. **Degrade gracefully.** If a skill mentions `mc`, give the raw `gh`/`rg` equivalent too.

### Adding one

```bash
mkdir -p skills/<name>
# write skills/<name>/SKILL.md
mc skills sync         # regenerate .claude/skills stubs
mc validate
```

Add a row to the table above, then commit `feat(skill): add <name>`. Skills are `agent/**`-class
policy — **branch and open a PR** rather than committing to `main`.
