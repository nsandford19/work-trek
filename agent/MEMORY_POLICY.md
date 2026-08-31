---
type: policy
title: Memory Policy — what to write down, where, and when to stop trusting it
status: active
created: 2026-08-10
---

# Memory Policy

The value of this repository is inversely proportional to how much junk is in it. A small
set of well-titled, verified documents beats a large set of half-remembered notes, because
the small set can be searched and trusted.

Default to **not** writing. Write when the promotion bar in §3 is met.

---

## 1. Three tiers

| Tier | What | Where | Changes |
| --- | --- | --- | --- |
| **Operational** | What work exists and its state | GitHub Issues | Daily |
| **Durable** | What is true and why | Markdown in this repo | When something is learned |
| **Behavioural** | How I want agents to act | `agent/**`, `skills/**` | When the operator changes their mind |

Working notes belong in **issue comments** — timestamped, free, no commit noise. Promote only
conclusions.

---

## 2. Where a document goes

Put it at the **narrowest scope where it is still true.** Over-broad placement is the most
common mistake: a fact about *my* cluster filed as a general truth will mislead later.

| Content | Location |
| --- | --- |
| How a general technology behaves | `knowledge/<area>/<slug>.md` |
| How *my* specific system is built | `projects/<project>/architecture.md` |
| Why a cross-cutting choice was made | `decisions/NNNN-<slug>.md` |
| Why a project-local choice was made | `projects/<p>/decisions/NNNN-<slug>.md` |
| What diagnosing a general problem revealed | `investigations/<slug>.md` |
| What diagnosing *this project's* problem revealed | `projects/<p>/investigations/<slug>.md` |
| A repeatable procedure | `runbooks/<slug>.md` or `projects/<p>/runbooks/<slug>.md` |
| Where a source repository lives | `repositories/<name>.yaml` |
| A machine's capabilities and constraints | `machines/<id>.yaml` |
| A stable personal preference | `agent/PREFERENCES.md` |
| A preference about how one skill behaves | `skills/<skill>/PREFERENCES.md` (Rules/Candidates — §8) |
| A rule true only for one org/project/repo/machine | The relevant scope file (see precedence in [`OPERATING_SYSTEM.md`](OPERATING_SYSTEM.md) §2) |

`area` values match the `area:*` issue labels: `software-development`, `infrastructure`,
`devops`, `kubernetes`, `databases`, `security`, `ai`, `networking`, `personal-tools`.

Add a one-line entry to the directory's `README.md` index whenever you add a file. An
unindexed document is a document nobody finds.

---

## 3. The promotion bar

Promote to durable Markdown when **at least one** is true:

- It will plausibly be needed again in ≥ 3 months.
- It explains *why* something is the way it is — a decision, a constraint, a workaround.
- It resolves a problem that has now happened **more than once**.
- It is a procedure just performed for the **second time** — twice is a routine, and a
  routine becomes a runbook (offer it when the repeat is noticed, not only at checkpoint).
- It contains a command, query, or procedure that was **non-trivial to derive**.
- It documents infrastructure that is not self-describing.
- It explains **surprising** behaviour — the gap between what a system should do and what it does.
- It establishes a convention.
- It is a lesson learned that would change how the next similar task is approached.

Do **not** promote:

- narration of what was done — Git history and issue timelines already have it;
- anything rediscoverable in under two minutes;
- unvalidated speculation (leave it as an issue comment until confirmed);
- a copy of upstream documentation — link it, and record only the part that surprised you;
- status, progress, or plans — those are issues.

> **The test:** *would a future agent, with no memory of today, do measurably better work
> because this document exists?* If not, do not write it.

---

## 4. Front matter

Small on purpose. Every field must be worth maintaining by hand.

```yaml
---
type: investigation          # REQUIRED
title: Stale DNS records survive a zone reload   # REQUIRED
status: active               # REQUIRED — draft | active | superseded | obsolete
created: 2026-08-10          # REQUIRED — YYYY-MM-DD
last_verified: 2026-08-10    # REQUIRED for knowledge/ and runbooks/
project: dns-automation      # optional
repositories: [example-org/dns-tools]   # optional
machines: [example-laptop]        # optional
areas: [networking, infrastructure]    # optional
tags: [bind, zone-transfer]  # optional
issues: [42, 57]             # optional — the issues this came from
superseded_by: knowledge/networking/dns-zone-reload.md   # REQUIRED if status: superseded
---
```

`type` values: `policy` `project` `knowledge` `decision` `investigation` `runbook` `report`
`machine` `repository` `skill`.

### There is no `updated:` field

Git already records precisely when a file changed, without human effort. A hand-maintained
`updated:` rots and then lies. Use `git log -1 --format=%as <file>` if you need it.

`last_verified:` is different and **is** maintained: it records the last time someone
confirmed the claim still matches reality — something Git cannot know. Update it when you
re-verify, even if the content does not change.

---

## 5. Writing well for a future agent

- **Title as a claim, not a topic.** "SQL Express installs as a named instance, breaking
  default-instance connection strings" beats "SQL Express notes". Titles are what `qmd`,
  `rg`, and a scanning agent match on; a good title is half the retrieval system. (Retrieval
  itself: `qmd query`, falling back to `rg` —
  [ADR 0004](../decisions/0004-qmd-as-memory-retrieval-driver.md).)
- **Lead with the answer.** First paragraph states the conclusion. Evidence after.
- **Include the exact commands and error text.** Verbatim error strings are the highest-value
  searchable content in the whole repository.
- **Record what you ruled out**, not just what you found. It prevents re-treading.
- **State scope explicitly** — versions, environment, which machine, which cluster. A fact
  without its scope becomes a trap.
- **Link, do not restate.** If a fact lives elsewhere, link it. Duplicated prose diverges.
- **One fact per file.** Small files make conflicts nearly impossible across machines and
  make supersession surgical.

---

## 6. Correction and forgetting

**Never silently delete a document that explains a past decision.** The reasoning is the
value, even when the conclusion turned out wrong.

| Situation | Action |
| --- | --- |
| Better answer found | Old: `status: superseded` + `superseded_by:`. New links back. |
| Infrastructure retired | `status: obsolete` + `## Historical note` saying what replaced it and when. |
| Discovery was wrong | `status: obsolete` + a `## Correction` section stating what is actually true. **Keep it** — it stops the same wrong conclusion being reached twice. |
| Project/machine renamed | Rename the file; keep the old id in `aliases:`; update the index. |
| Two documents conflict | Later `last_verified` wins; supersede the other. If neither is verified, **say so** instead of picking. |
| Genuinely worthless | Delete it. Git retains the history. |

### Reading rules

1. Check `status:` **before** trusting content.
2. When quoting a `superseded`/`obsolete` document, say so and link the successor.
3. Weigh `last_verified` against how fast the subject moves. A two-year-old Kubernetes note
   deserves suspicion; a two-year-old note about why a schema was denormalised does not.
4. If content contradicts what you observe right now, **reality wins** — then correct the
   document.

---

## 7. Verification

When you rely on a `knowledge/` or `runbooks/` document and confirm it still holds, bump
`last_verified`. It is a one-line commit and it is what keeps the corpus trustworthy:

```
docs(memory): re-verify SQL Express instance behaviour
```

If it no longer holds, apply §6 in the same session. A document known to be wrong and left
alone poisons every future answer.

---

## 8. Promoting a pattern into policy

When the same lesson recurs across **three or more** projects, it has stopped being knowledge
and become a preference. Move it to `agent/PREFERENCES.md` (or the appropriate scope file),
and leave the original in place with a link.

Ask before writing to `agent/**`. Behavioural changes affect every future session on every
machine, so they are the operator's call, not yours.

The feedback loop runs the other way too: when the operator corrects you or repeats a
request, **offer** to record it rather than waiting for it to recur three times
([`OPERATING_SYSTEM.md`](OPERATING_SYSTEM.md) §3). For preferences scoped to a single
skill, [`skills/triage-notifications/PREFERENCES.md`](../skills/triage-notifications/PREFERENCES.md)
is the canonical pattern any skill may adopt: **Rules** are applied every run and exist
only from explicit operator feedback, each with its date and provenance; **Candidates**
are agent-observed patterns whose only permitted effect is a "suggested rule?" question —
one becomes a rule only when the operator explicitly says yes.
