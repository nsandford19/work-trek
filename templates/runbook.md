---
type: runbook
title: <Imperative — "Reindex the X cluster", "Rotate the Y certificate">
status: active
created: <YYYY-MM-DD>
last_verified: <YYYY-MM-DD>
project: <project-name or remove>
repositories: [<owner/name> or remove]
machines: [<machine-id, if it only works somewhere specific, or remove>]
areas: [<area>]
tags: [<tag>]
---

# <Imperative title>

> Delete this quote block and every `<...>` placeholder before committing.
> File as `runbooks/<slug>.md` or `projects/<p>/runbooks/<slug>.md`.
>
> A runbook will be followed **literally, on a real system, probably under pressure.** Write it
> for that reader. `last_verified` is required.

## When to use this

The situation that calls for this procedure — and when *not* to use it.

## Preconditions

What must be true before starting, each with a check.

- [ ] `<condition>` — verify with `<command>`
- [ ] Access needed: `secret: op://<vault>/<item>/<field>` (**pointer only, never the value**)

## Where to run it

| | |
| --- | --- |
| Machine | `<machine-id, or "any registered machine">` |
| Shell | `<powershell | bash>` — these are not interchangeable |
| Working directory | `<path, or "the repository root">` |

## Steps

1. `<what this step achieves>`

   ```bash
   <exact command>
   ```

   Expected: `<output that means it worked>`

2. `<next step>`

   ```bash
   <exact command>
   ```

Number every step. Put the command in a code block, not in prose. If a step is conditional, say
so in its first words.

## Verification

How to prove the procedure achieved its goal — not merely that the commands exited zero.

```bash
<verification command>
```

## Rollback

What to do when a step fails partway. This is the section people skip writing and later
desperately need.

| Failed at | Do this |
| --- | --- |
| Step `<n>` | `<recovery>` |

## Notes

Gotchas, timing, expected duration, anything that surprised you the first time.

## Related

- Investigation that produced this: `investigations/<slug>.md` or #<n>
- Knowledge note explaining *why* it works this way: `knowledge/<area>/<slug>.md`
