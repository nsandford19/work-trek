---
type: decision
title: <The decision, as a statement — "Use X for Y", not "Choosing a Y">
status: active
created: <YYYY-MM-DD>
areas: [<area>]
tags: [<tag>]
issues: [<decision issue number>]
repositories: [<owner/name> or remove]
---

# NNNN — <The decision as a statement>

> Delete this quote block and every `<...>` placeholder before committing.
> File as `decisions/NNNN-<slug>.md` (cross-cutting) or
> `projects/<p>/decisions/NNNN-<slug>.md` (project-local). Use the next free number in that
> directory; never reuse a number, even for a superseded decision.
>
> **Only write an ADR if a competent engineer six months from now might undo this choice
> without knowing why it was made.** Trivial ADRs make the important ones unreadable.

## Context

What forced a decision. Constraints, requirements, and what was already true. Enough that the
reasoning below makes sense to someone with no memory of today — including the facts that
turned out to be decisive.

## Decision

What was chosen, stated unambiguously and in the present tense. Concrete enough to be
followed: name the mechanism, not the intent.

## Alternatives considered

| Alternative | Why not |
| --- | --- |
| `<option>` | `<the specific reason, not "worse">` |

An ADR with no credible alternatives is usually not a decision worth recording.

## Reasoning

Why the chosen option won, in priority order. Reference the decisive facts — measurements,
verified constraints, or platform limits — rather than preferences alone.

## Consequences

**Good**

- `<what this makes easy>`

**Bad, and accepted**

- `<what this makes harder, and the mitigation>`

Be honest here. An ADR listing only benefits reads as advocacy and gets ignored. The accepted
costs are what future readers need most, because those are the symptoms that will tempt them to
reverse the decision.

## Revisit if

The specific conditions that would justify changing this. This is what turns an ADR from a
tombstone into something actionable.

- `<condition>` → `<what to reconsider>`

## Related

- Decision issue: #<n>
- Supersedes: `<path or none>`
- Related ADRs, knowledge notes, or registry entries
