---
type: knowledge
title: <The fact, as a full claim — someone should learn something from the title alone>
status: active
created: <YYYY-MM-DD>
last_verified: <YYYY-MM-DD>
areas: [<area>]
tags: [<tag>]
issues: [<issue numbers this came from, or remove>]
---

# <The claim>

> Delete this quote block and every `<...>` placeholder before committing.
> File as `knowledge/<area>/<slug>.md`. Areas match the `area:*` issue labels.
>
> **Title it as a claim, not a topic.** "SQL Express installs as a named instance, breaking
> default-instance connection strings" beats "SQL Express notes". Titles are what `rg` and a
> scanning agent match on — a good title is half the retrieval system.

## The fact

State it plainly in the first paragraph, with its scope: which versions, which platform, which
conditions. A fact without its scope becomes a trap.

## Why it matters

The practical consequence — what goes wrong, or what becomes possible, because of this. If
there is no consequence, this note probably fails the promotion bar.

## Evidence

How it was established. Verbatim commands and output; error strings exactly as they appear.

```console
$ <command>
<verbatim output>
```

## What surprised us

The gap between what the system *should* do and what it does. This is usually the whole reason
the note exists — do not leave it implicit.

## Related

- Upstream documentation: `<url>` — **link it, do not copy it.** Record only the part that
  surprised you; copied docs go stale and add nothing.
- Investigation this came from: `investigations/<slug>.md` or #<n>
- Decision it informed: `decisions/NNNN-<slug>.md`

## Re-verify by

The exact command or check that confirms this still holds — so a future agent can bump
`last_verified` in under a minute, or discover the fact has changed.
