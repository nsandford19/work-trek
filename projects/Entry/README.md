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
- **The lab's packing-slip templates live in `MpixEntry\Entry`** (`PackingSlip.xslt`,
  `PackingSlip2.xslt`, `KodakMoments_PackingSlip.xslt`), not in the `Entry` repo. On that
  slip the `<h1>` cell is the customer ship-address sort code from MAPI, and the `QC:` number
  is unique image count — not a quantity.

## Conventions

**Scope: `project`** — overrides organization and personal defaults; overridden by repository
and machine scope. Only rules that are true *because of this project*.

- _(none recorded yet)_

## Related

- Repository: [`../../repositories/Entry.yaml`](../../repositories/Entry.yaml)
- Decisions: `decisions/`
- Investigations: `investigations/`
- Runbooks: `runbooks/`
