---
type: policy
title: Work Trek template walkthrough — what was kept, cut, and how to verify a setup
status: active
created: 2026-08-18
---

# Work Trek — Template Walkthrough

This document explains how the template was put together: what it contains, what was
deliberately left out of the parent system it was derived from, the placeholder
convention, how the core mechanisms work, and how to verify a fresh setup end to end.

The *architecture* of the system itself (why Issues, why labels, why a hostname map, why
qmd) is documented where it belongs: [`../ARCHITECTURE.md`](../ARCHITECTURE.md) and the
four ADRs in [`../decisions/`](../decisions/README.md). This file is only about the
template.

---

## 1. What Work Trek is

A personal "engineering operating system" you own and evolve:

- **GitHub Issues on this repository are the single source of truth for all work state**,
  across every project and source repository you touch — not just work on this repo.
- **This repository is the durable memory** shared by every AI agent you use: policies in
  `agent/`, registries in `machines/` and `repositories/`, knowledge/decisions/
  investigations/runbooks as one-fact-per-file Markdown, reusable workflows in `skills/`.
- **Everything in `bin/` is an accelerator, never a dependency** — each command has a raw
  `gh`/`rg` equivalent, so a machine with nothing but git and gh still works.

## 2. What was kept from the parent system, and why

| Kept | Why |
| --- | --- |
| `agent/` policy set (operating manual, task/memory/security policy, context map, preferences template) | The behavioural kernel — the part that makes agents consistent. Genericized, not weakened. |
| `AGENTS.md`, `CLAUDE.md`, `ARCHITECTURE.md` | Entry points and design rationale. `CLAUDE.md` stays a thin pointer to `AGENTS.md`. |
| `skills/` — capture-work, start-work, whats-next, session-checkpoint, triage-notifications, document-investigation, record-decision, register-repository, mc, orchestrate-work, dispatch-remote-agent | Generic workflows that only touch this repo's own state. |
| `bin/` — `mc` + `mc.ps1` + `lib/`, `bootstrap.*`, `build-dashboard.ps1`, `build-issue-cache.ps1`, `setup-mission-control-project.ps1`, `install-gh-linux.sh`, `mc-briefing`, `mc-triage-notifications` | The CLI, onboarding, and dashboard machinery. Dashboard build logic is intact. |
| `bin/init-template.*` (**new**) | One-off placeholder substitution — see §4. |
| `tooling/` (Claude Code status line) | Installed by `mc statusline`; machine-agnostic by rule. |
| `docs/onboarding.html` | Self-contained onboarding page, sanitized. |
| `templates/` | Document templates for knowledge, decisions, investigations, runbooks, projects, weekly reviews. |
| `.github/` — labels.yml, issue forms, validate + dashboard + history-sync workflows | The canonical label taxonomy and the automation. Repo slugs genericized; the only secret any workflow needs is the optional `HISTORY_SYNC_TOKEN` (history-sync only). |
| `.claude/` — settings.json + generated skill stubs | Stubs regenerated to match exactly the skills kept (verified by `mc validate`). |
| `decisions/0001`–`0004` | **Judgment call.** These four ADRs document the design of this system itself (Issues as control plane; labels over Projects fields; hostname-map machine identity; qmd retrieval). They are referenced from policies, scripts, and workflows throughout, and they double as worked examples of the ADR format. They contain no personal data after genericization. |
| Registry/memory directory skeletons — `machines/`, `repositories/`, `projects/`, `knowledge/`, `decisions/`, `investigations/`, `runbooks/`, `organizations/`, `reports/` (incl. `reports/history/`) | Each keeps its README (the rules of the directory) plus at most one clearly-fictional example. |

Clearly-fictional examples shipped (delete them as you replace them with real entries):

- `machines/example-laptop.yaml.example` — machine schema (`.example` keeps it out of
  identity resolution and validation).
- `repositories/my-service.yaml.example` — repository schema.
- `projects/example-project/` — project layout, paired with the `project:example-project`
  label in `.github/labels.yml`.
- `knowledge/example-named-instance-breaks-connection-strings.md.example` — the shape of
  a good knowledge entry.
- `agent/PREFERENCES.md` — three clearly-marked fictional preferences showing the
  useful level of specificity.

## 3. What was excluded, and why

All of the parent operator's actual content — anything personal or company-specific:

| Excluded | Reason |
| --- | --- |
| Real `knowledge/`, `decisions/` (project-local), `investigations/`, `runbooks/` entries | Operator/company-specific findings and procedures. |
| Real `machines/*.yaml`, `repositories/*.yaml`, `projects/*`, `organizations/*` entries | Real hostnames, paths, org structure. |
| `reports/history/` ledgers, narratives, and `stats/` JSONs; `reports/weekly/` | Personal work history. |
| `IMPLEMENTATION_PLAN.md` | Parent-system planning state; references removed. |
| `skills/dns` | Bound to one company's internal DNS zones and a private helper script. |
| `skills/annual-report`, `bin/build-annual-report.ps1`, `bin/fetch-annual-stats.ps1` | The annual-report pipeline consumes the personal history ledgers/stats that are excluded. `mc history sync` (the generic ledger machinery) **is** kept. |
| `bin/wsl-ssh-portproxy.ps1`, `bin/register-wsl-ssh-task.ps1` | Machine-specific WSL networking scripts with personal paths. |
| Parent-specific runbooks (Herdr install, qmd repair, GitHub Project recreation, ssh-into-WSL, briefing timer) | Environment-specific; where a kept file referenced one, the reference was inlined or removed (`skills/orchestrate-work`, `bin/setup-mission-control-project.ps1`, ADR 0004). |

Dependency notes from the exclusions:

- `bin/setup-mission-control-project.ps1` previously linked a runbook for the one UI-only
  step (Project auto-add workflow); that step is now described inline in the script.
- `mc.ps1`'s PR pagination comments referenced the excluded annual-stats script; the
  comments were trimmed, the code is untouched.
- `bin/mc-briefing` / `bin/mc-triage-notifications` hardcoded a personal clone path; they
  now resolve the repo root from their own location, with an `MC_ROOT` env override.

## 4. Placeholder convention

Exactly two placeholders, used **only where a literal GitHub slug is required** (gh
commands, URLs, script fallbacks). Prose says "this repository" or "your control-plane
repository" instead.

| Placeholder | Meaning |
| --- | --- |
| `nsandford19` | Your GitHub user or org |
| `work-trek` | The name of your copy of this repository |

Where they appear: `agent/*.md`, `skills/*/SKILL.md` (+ `.claude/skills` stubs),
`templates/*.md`, `docs/onboarding.html`, registry READMEs, and as defaults/fallbacks in
`bin/mc`, `bin/mc.ps1`, `bin/lib/Mc.Issues.psm1`, `bin/bootstrap.*`,
`bin/setup-mission-control-project.ps1`, `bin/install-gh-linux.sh`, `bin/mc-briefing`,
`.github/ISSUE_TEMPLATE/config.yml`.

Substitution is wired into setup:

- `./bin/init-template.sh` / `./bin/init-template.ps1` replace both placeholders across
  every tracked file (deriving values from the `origin` remote, or from arguments). The
  scripts assemble the search patterns at runtime and skip themselves, so they are
  idempotent and survive their own pass. They remain usable standalone.
- Both bootstrap scripts **detect unsubstituted placeholders** in `AGENTS.md` as their
  step 0: they derive the values from the `origin` remote (or prompt for them), offer to
  run the initialiser, show what changed, and remind you to commit. In non-interactive
  mode they report and continue with what works before substitution. Already-substituted
  clones skip the step silently.
- Manual equivalent (documented in the README):
  `git ls-files -z | xargs -0 sed -i 's|nsandford19|<owner>|g; s|work-trek|<repo>|g'`

One deliberate softening: `Get-McRepoSlug` (used by the dashboard and issue-cache builds)
prefers the `origin` remote at runtime and uses the placeholder string only as a
last-resort fallback — so those builds work even before substitution.

## 5. How the issue-tracking logic works

- **Taxonomy** ([`../agent/TASK_POLICY.md`](../agent/TASK_POLICY.md)): every open issue
  carries exactly one `type:*`, one `status:*`, one `p0`–`p3`; optional `area:*`,
  `project:*`, `needs:*`. Done/Cancelled are native closed states (`state_reason`), not
  labels. `.github/labels.yml` is the canonical list; `mc labels sync` pushes it.
- **Relationships**: native sub-issues for hierarchy; a greppable `Blocked by: #N` body
  line (plus `status:blocked`) for dependencies; bidirectional links between issues and
  the Markdown they produce.
- **Ranking** (`mc next` / `skills/whats-next`): exclude inbox/blocked/waiting and
  initiatives, recompute readiness from `Blocked by:` lines (labels drift), filter by
  what this machine has checked out (via the registries), then rank in-progress → priority
  → initiative membership → decision leverage → age.
- **Hygiene**: `validate.yml` reports label violations weekly; `mc validate` checks
  front matter, registries, internal links, secret patterns, and that every documented
  `gh` recipe pins `-R <owner>/<repo>`.

## 6. How the dashboard works

`bin/build-dashboard.ps1` fetches all issues in one `gh` call
(`bin/lib/Mc.Issues.psm1 → Get-McIssueSnapshot`), enriches initiatives with sub-issue
progress via the REST sub-issues API, and renders a **single self-contained HTML file** —
no external assets — with sections for attention-required, current work, blocked/waiting
(with resolved-blocker detection), ranked next work, initiative health, and recently
completed, plus client-side filters and search over the embedded issue JSON.

- Locally: `./bin/mc.ps1 dashboard` → `reports/generated/dashboard.html` (gitignored —
  generated status is never committed to `main`).
- Automated: [`dashboard.yml`](../.github/workflows/dashboard.yml) rebuilds nightly and
  on demand, publishing `index.html` + `issues.md` (the greppable issue cache from
  `bin/build-issue-cache.ps1`) to a single-commit `dashboard` branch — deliberately not
  GitHub Pages, so a private repo's issue titles stay private.
- Every copy is a point-in-time snapshot; the issues remain canonical.

## 7. Testing the setup end to end

1. **Bootstrap**: `./bin/bootstrap.sh` — on a fresh clone it first offers the placeholder
   substitution (accept it, commit the result); then expect required-tool OKs, gh auth OK,
   an offer to register this machine (accept it), repository validation, and the
   label-sync offer (accept it). Afterwards `git grep -n 'nsandford19'` must return
   nothing, and a second bootstrap run must change nothing.
2. **Validation**: `./bin/mc.ps1 validate` → `Valid.` (front matter, registries, links,
   stubs, secret patterns, pinned recipes).
3. **Labels**: `gh label list -R <owner>/<repo>` shows the
   `type:/status:/p*/area:/project:/needs:` taxonomy (re-apply any time with
   `./bin/mc.ps1 labels sync`).
4. **First issue**: create one (`type:task,status:ready,p2`), then `./bin/mc.ps1 next`
   should recommend it; `./bin/mc.ps1 issue <n>` resolves it.
5. **Doctor**: `./bin/mc.ps1 doctor` — tools, auth, machine identity, repo paths.
6. **Dashboard**: `./bin/mc.ps1 dashboard` and open `reports/generated/dashboard.html`;
   optionally run the Dashboard workflow from the Actions tab and fetch the `dashboard`
   branch.
7. **Agent smoke test**: open the clone with an agent and ask *"What should I work on
   next?"* — it should follow `AGENTS.md` → `whats-next` and answer from live issues.
8. **Checkpoint**: finish the session with the `session-checkpoint` skill; confirm it
   updates labels and leaves a next-action comment rather than writing status Markdown.

## 8. Conventions preserved

- LF-only line endings (`.gitattributes`), enforced by `validate.yml`.
- Conventional commits scoped to the subsystem (`docs(memory):`, `chore(registry):`,
  `feat(skill):` …).
- Branch + PR for anything under `agent/**` or `skills/**`; direct commits to `main` are
  acceptable for knowledge notes and registry entries.
- Constrained YAML dialect for registries (parsed by `bin/lib/Mc.Yaml.psm1`, zero
  external dependencies) — documented in [`../machines/README.md`](../machines/README.md#yaml-dialect).
