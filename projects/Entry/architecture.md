---
type: project
title: Entry paperwork templates are per-project copies spread across two repos, and direct printing is enabled per project — neither is repo-wide
status: active
created: 2026-09-21
last_verified: 2026-09-21
project: Entry
repositories: [Millers-IT/Entry, Millers-IT/MpixEntry]
areas: [software-development]
tags: [paperwork, xslt, printing, roesprints]
issues: [13, 14, 20, 21]
---

# Entry paperwork: per-project templates, per-project delivery

**The two facts, first.** Paperwork XSLT templates are **copied per project, across two
repositories** — `Millers-IT/Entry` and `Millers-IT/MpixEntry` — with nothing shared between
them. And whether paperwork reaches a printer or a hot folder is decided **per project** (and in
multi-lab projects, per lab section) by `NoPrint` / `UsePrintApp` in that project's
`appSettings.json`. Neither is uniform, so a conclusion drawn in one entry project does not
transfer to its siblings. A third trap follows from the same shape: a project can carry a lab's
config section without running at that lab — see below.

## Why it matters

Two traps follow directly:

1. **Do not write a new paperwork template from scratch, and do not search only `Entry`.** The
   layout probably already exists — most likely in `MpixEntry`, which holds the richest set.
   #13 set out to build a ROESPrints packing slip from a sample HTML file; the sample turned out
   to be the output of `MpixEntry/Entry/PackingSlip.xslt`, a *different repository* from the one
   the work was happening in. Porting that template reproduced the sample byte-for-byte;
   reimplementing it would have been days of pixel-chasing.

2. **Do not generalise "direct printing is dead" from one project to the repo.** #13 removed
   every `RawPrinterHelper` call from `RoesPrintEntry` — correct there, because `NoPrint` was
   `"true"` in *both* its lab sections, making the branches unreachable. The same deletion in
   `ROESPress` (Pittsburg section) or `ROES_PPB` would break live printing.

## Where the templates live

Verified 2026-09-21. `Millers-IT/Entry` at merge commit `3eee73c`; `Millers-IT/MpixEntry` at the
`PNOELLES` working tree.

| Repository / project | Templates |
| --- | --- |
| `MpixEntry` — `Entry/` | `PackingSlip.xslt`, `PackingSlip2.xslt`, `KodakMoments_PackingSlip.xslt`, `RoutePreview.xslt`, `framepreview.xslt` |
| `Entry` — `RoesPrintEntry/` | `RoutePreview.xslt`, `OrderSummary.xslt`, `PackingSlip.xslt` *(added by #13, ported from MpixEntry)* |
| `Entry` — `ROESPress/` | `RoutePreview.xslt` |

Every other project in `Entry` has none. Note `RoutePreview.xslt` already exists in three places
under that same name — copies, not a shared file.

## Where direct printing is still live

`NoPrint` in checked-in `appSettings.json`; **`false` means direct printing is live**. Verified
2026-09-21.

| Project | Sections | `NoPrint` |
| --- | --- | --- |
| `ROESPress` | two | **`false`** (Pittsburg, line 60) / `true` (Columbia, line 113) |
| `ROES_PPB` | one | **`false`** (line 66) |
| `RoesPrintEntry` | two | *key removed by #13 — was `true` in both* |
| `RoesSportsEntry` | two | `true` / `true` |
| `SamplePrintEntry` | two | `true` / `true` |
| `Schools` | two | `true` / `true` |
| `SportsEventsEntry` | two | `true` / `true` |
| `ROES_SA` | one | `true` |
| `ROES_SB` | one | `true` |

**Five projects carry `RawPrinterHelper.cs` but define no `NoPrint` key at all** — `FilmEntry`,
`partnerschools/SEntry`, `SAEntry`, `SSEBulkEntry`, `taopix/TaoPixEntry`. How their printing is
gated has not been established; do not assume it matches either group.

Ignore `bin/Debug` and `bin/Release` copies when grepping — they are build output and drown the
real hits. **`OrdItems.NoPrint` and `XRef.NoPrint` are unrelated** despite the name: they are
per-item product attributes, not the config toggle.

## A lab section in `appSettings.json` does not mean the project runs at that lab

**RoesPrintEntry is not deployed at Columbia.** Its `AppsettingsColumbia` section exists for
visual parity with the other entry projects; nothing reads it. Confirmed by the operator
2026-09-21.

So the section's gaps are not defects: it has no `RunSheets`, `ItemPreviewXsl` or
`OrderSummaryXsl`, and its `BarcodeRenderUrl` points at the Pittsburg `pwebrender` host. None of
that resolves at runtime. #21 was opened as a config gap on exactly this evidence and closed
not-planned.

**Read the absence, not the presence.** A lab section that is missing the keys its siblings have
is the signal that the lab does not run the project — which means adding keys to such a section
erases the signal. #398 did that in a small way by writing `PackingSlipXsl` and `BarcodeRenderUrl`
into Columbia's for symmetry. Before treating any lab section as live, confirm deployment rather
than inferring it from the config shape.

## How the paperwork flow is shaped

Established in `RoesPrintEntry` specifically; the sibling projects follow a visibly similar
shape but were not verified line by line.

`ProcessPaperWork(OrderInfo inf)` in `Program.cs` orchestrates the packet. Each generator has
the same shape: build an `XDocument` from `OrderInfo`, run it through the shared
`Transform(XDocument, string xslFile)` helper (`XslCompiledTransform`), then deliver. Templates
are named by app-setting keys (`ItemPreviewXsl`, `OrderSummaryXsl`, `PackingSlipXsl`) and
registered as `Content` / `CopyToOutputDirectory=Always` in the `.csproj` — a new template needs
**both** or it silently will not be found at runtime.

Delivery is a file copy to the print folder, written directly under `UsePrintApp` or queued
through `Utils.DoAutoCorrect` on color-assist orders. `Utils.GetPrintFolder` reads
`PSet.PrinterName` to pick the hot folder, so the printer name still matters in a project that
no longer prints.

Output is **not** uniformly PDF: the summary and preview sheets render to PDF via
`Bee.HtmlToPdf.PdfGenerator`, while the packing slip ships as HTML, because the print app
renders HTML drops and rasterising first bought nothing.

## What surprised us

- The "new" packing slip design was not new. It was an existing template's output, in another
  repository, and nobody involved knew that until the sample's markup was traced back.
- `NoPrint` being `true` everywhere in *one* project reads like a repo-wide decommissioning of
  direct printing. It is not — two sibling projects still print directly, and five more do not
  use the toggle at all.
- Filenames collide by design gap: the summary and preview generators both write
  `{OrderID}.PDF` (#14). Any new sheet needs a distinct suffix.

## Related

- #13 — the packing slip work that established this; PR Millers-IT/Entry#398
- #14 — the `{OrderID}.PDF` collision between the summary and preview sheets
- #20 — `OrderInfo.PDoc` dead in `RoesPrintEntry`
- #21 — closed not-planned: RoesPrintEntry's Columbia section is parity, not a config gap
- Repositories: [`Entry.yaml`](../../repositories/Entry.yaml) ·
  [`MpixEntry.yaml`](../../repositories/MpixEntry.yaml)

## Re-verify by

```bash
git grep -n '"NoPrint"' -- '*/appSettings.json' ':!*/bin/*'
```

```bash
find . -name RawPrinterHelper.cs -not -path '*/bin/*'
```

Run the template inventory in **both** repositories:

```bash
find . -name '*.xslt' -not -path '*/bin/*'
```
