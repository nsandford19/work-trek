---
type: project
title: Entry — container for Entry-related projects
status: active
created: 2026-08-31
last_verified: 2026-09-11
repositories: [Millers-IT/Entry]
areas: [software-development]
tags: [millers]
---

# Project: Entry

## Purpose

Durable context for the `Entry` codebase — a repository housing the Entry-related projects.
The live work lives in issues; this directory holds what outlives any single issue.

## Current shape

| Piece | Where |
| --- | --- |
| Entry projects | `Millers-IT/Entry` |

## Live work

**Never list tasks or status here** — issues are the only source of truth:

```bash
gh issue list -R nsandford19/work-trek --state open --label project:Entry
```

## Key decisions

| ADR | Decision |
| --- | --- |
| _(none yet)_ | |

## Key facts

- **The paperwork print folder accepts HTML drops.** Files copied to
  `{PrintPath}{PrinterName}` (the `UsePrintApp` path) are rendered by the print app, so
  paperwork does not have to be rasterised to PDF first — other programs already deliver
  HTML this way. Stated by the operator 2026-09-11 while adding the ROESPrints packing slip
  (#13). This is why `RoesPrintEntry` writes `<OrderID>_PackingSlip.html` rather than a PDF,
  matching how `MpixEntry`'s `Route.PrintAndSave` has always shipped its packing slip.
- **`NoPrint` is `"true"` in both lab sections of `RoesPrintEntry/appSettings.json`**, so the
  `RawPrinterHelper.SendBytesToPrinter` branches in the paperwork generators do not run in
  production. Delivery is the print-folder copy, either direct or queued through
  `Utils.DoAutoCorrect` on color-assist orders.
- **XSLT templates are per-project — there is no shared or global template library.** Each
  project keeps its own alongside its code (`MpixEntry\Entry\PackingSlip.xslt`;
  `RoesPrintEntry`'s `RoutePreview.xslt`, `OrderSummary.xslt`, `PackingSlip.xslt`), each
  registered as `Content` in that project and named by its own app setting. A layout wanted in
  a second project is **copied into that project**, not referenced across repos — so the two
  copies then diverge independently, and a fix to one is not a fix to the other.
- **Where to look for prior art on a paperwork layout:** whichever project already prints it.
  `RoesPrintEntry`'s packing slip was seeded from `MpixEntry`'s, which is why the layouts match.
  On that layout the `<h1>` cell is the customer ship-address sort code from MAPI, and the
  `QC:` number is unique image count — not a quantity.

## Conventions

**Scope: `project`** — overrides organization and personal defaults; overridden by repository
and machine scope. Only rules that are true *because of this project*.

- _(none recorded yet)_

## Related

- Repository: [`../../repositories/Entry.yaml`](../../repositories/Entry.yaml)
- Decisions: `decisions/`
- Investigations: `investigations/`
- Runbooks: `runbooks/`
