---
type: runbook
title: Add a new Mpix product — CMS content, pricing, sitemap, navigation
status: active
created: 2026-09-10
last_verified: 2026-09-10
repositories: [Millers-IT/mpix-3, Millers-IT/Mpix.Com.Core, MillersProfessionalImaging/Mpix.Com]
areas: [software-development]
tags: [mpix, squidex, cms, products, navigation]
---

# Runbook: Add a new Mpix product

The operator's checklist, in order. A product is not "added" until every step is done —
the failure mode is a half-linked product that renders nowhere, or renders with no price.

## The checklist

1. **Make sure the link product is made.** The `DefProduct` must exist in Squidex and
   reference the right `SyncMlProduct` rows.
2. **Link the product to the content page.** The `PageProduct` references the `DefProduct`.
3. **Define pricing specs in the CMS appsettings files.**
4. **Add product links to `sitemap.xml`.**
5. **Add to the header files across mpix3, mpix2, and local.**

---

## 1. The link product (`DefProduct`)

Squidex app `mpix`, content type `DefProduct`. Confirm the `SyncMlProduct` rows exist first
— they arrive from ML by sync and cannot be hand-authored; if the SKU is not there, stop.

Fields that matter:

| Field | Notes |
| --- | --- |
| `name` | snake_case, e.g. `framed_magnets` |
| `syncMLProducts` | the orderable ML products |
| `syncMLProductsDefault` | the pre-selected one |
| `sku` | populated on 42 of 76 products — fill it |
| `syncYotpoMLProducts` | **no reviews on the PDP without this** |
| `pricingSubheadline` / `pricingDetails` | rare (12 and 9 of 76) — usually skip |

## 2. Link to the content page (`PageProduct`)

`PageProduct` carries `categoryUrl` + `url` (+ optional `url2`), which together form the
route **and** the CMSKey. Also set `seo`, `overview` (`H003Component`), `sections`
(`S001Component` / `S003Component`), `details`, `faqs`.

Reuse the shared `ProductDetail` blocks rather than duplicating them — every sibling PDP
carries `processing_1-2`, `retouching_all`, `boutique_packaging_all`, `free_shipping_all`.

The app resolves the PDP with an OData filter on exactly those URL fields
(`libs/web/mpix/features/product/.../product.effects.ts`):

```
data/categoryUrl/en eq '<category>' and data/url/en eq '<product>' and data/url2/en eq <url2>
```

A mismatch between these and the Angular route is the usual "PDP 404s" cause.

**Publishing matters.** The content API serves published content only, and the app reads
**prod** Squidex in every environment — all `appsettings*.json` set
`Squidex.MainUrl` to `https://cms.mpix.com`. Content authored in `cms-dev.mpix.com` is
invisible to a local dev run, and cannot be pointed at without a code change:
dev returns 401 anonymously and `SquidexSettings` has no token field.

## 3. Pricing specs — `apps/api/appsettings-CMSKeySettings.json`

Add a `CMSKeys` entry keyed by `<categoryUrl>/<url>`, matching the `PageProduct` exactly.
Copy the nearest sibling. Typical shape:

```json
{
  "CMSKey": "photo-gifts/framed-magnets",
  "Values": [
    { "Key": "create", "Value": "{ \"type\": \"designer\" }" },
    { "Key": "pricingFormatType", "Value": "ListGeneral" },
    { "Key": "pricingLineItemGroups", "Value": "[]" }
  ]
}
```

An empty `pricingLineItemGroups` is normal — 30 of 64 `ListGeneral` entries have none.
Non-empty groups are for products with real line-item axes (e.g. `film/film`).

**Restart the API after editing.** These are read via `IOptions<List<CMSKeySettings>>`
(`PricingService`, `ProductService`), which resolves **once at startup** — the
`reloadOnChange: true` on the JSON file has no effect.

## 4. `sitemap.xml`

`libs/web/mpix/core/src/sitemap.xml` in `mpix-3`. Add the product URL.

## 5. Header files — three repos

Same nav change in each. `Mpix.Com` and `Mpix.Com.Core` also duplicate every link in a
**mobile drill-down** section, so those are 2 insertions each, not 1.

| Operator's name | Repo | File | Copies |
| --- | --- | --- | --- |
| mpix3 | `Millers-IT/mpix-3` | `libs/web/mpix/core-ui/src/lib/header/components/header-menu/header-menu.component.html` | desktop only |
| mpix2 | `MillersProfessionalImaging/Mpix.Com` | `Mpix.Com/Shared/Header3.ascx` | desktop + mobile |
| local | `Millers-IT/Mpix.Com.Core` | `Mpix.Com.Local/Pages/Shared/Components/Header3/Default.cshtml` | desktop + mobile |

Conventions:

- New products carry a badge: `<span class="new">New</span>`. Both desktop and mobile
  sections use it in the legacy repos.
- `title` attribute casing follows the **local block**, not a global rule — the desktop
  blocks use sentence case (`title="Framed magnets"`), the mobile ornaments block uses
  title case. Copy the neighbouring line.
- mpix-3 uses `[routerLink]="['/path']"`; the legacy repos use plain `href="/path"`.
- The legacy files are **UTF-8 with BOM**. Stripping it shows up as a spurious change to
  the `<%@ Control %>` / `@using` directive on line 1 — preserve it.

## Gotchas

- **Verify `categoryUrl` before writing the route anywhere.** It appears in the nav links
  (three repos), the CMSKey, and the sitemap. Guessing it wrong means fixing all of them.
- **The nav links 404 until the `PageProduct` is published.** Land the nav PRs alongside
  the CMS work, not ahead of it.
- Squidex OData paths use the field's own locale partition: invariant fields are `/iv`
  (e.g. `data/name/iv`, `data/id/iv`), English-localised fields are `/en` (e.g.
  `data/url/en`, `data/sku/en`). Wrong segment → *"Could not find a property named 'iv'"*.

## Worked example

Framed Magnets and Framed Ornaments, September 2026 —
[nsandford19/work-trek#11](https://github.com/nsandford19/work-trek/issues/11),
with PRs Millers-IT/mpix-3#3407, MillersProfessionalImaging/Mpix.Com#557,
Millers-IT/Mpix.Com.Core#54.
