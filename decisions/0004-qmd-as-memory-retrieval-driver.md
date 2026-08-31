---
type: decision
title: qmd is the primary retrieval driver for durable memory, with rg as the fallback
status: active
created: 2026-08-11
areas: [personal-tools, ai]
tags: [memory, retrieval, search, qmd, onboarding]
issues: []
---

# 0004 — qmd as the primary memory-retrieval driver

## Context

Durable memory is one-fact-per-file Markdown ([`../agent/MEMORY_POLICY.md`](../agent/MEMORY_POLICY.md)).
Retrieval so far is `rg` keyword search plus good titles. That works while the corpus is
small, but keyword search misses paraphrases: an agent looking for "connection string
breaks against SQL Express" will not match a note titled around "named instances" unless
the words overlap. As the corpus grows, the miss rate is what quietly erodes the whole
premise — memory that is not found might as well not exist.

Requirements: local-only (this is a private corpus — no external APIs), zero committed
state (nothing generated goes in the repo), and degradation to raw tools, because every
capability here must survive a machine that has none of the accelerators installed.

## Decision

[`tobi/qmd`](https://github.com/tobi/qmd) (npm package `@tobilu/qmd`) is the **primary
retrieval driver** over this repository's Markdown. It combines BM25 full-text search,
local vector search, and on-device re-ranking (GGUF models via node-llama-cpp) — no
external APIs, index in `~/.cache/qmd/`, models in `~/.cache/qmd/models/`.

Per machine, onboarding registers the clone as a global collection:

```bash
bun install -g @tobilu/qmd     # bun, not npm — see "Runtime: bun over node" below
qmd collection add <clone-path> --name work-trek
qmd context add qmd://work-trek "personal engineering memory: decisions, knowledge, runbooks, investigations"
qmd embed                      # first run downloads ~2 GB of models
```

### Runtime: bun over node

**Amended 2026-08-16.** Install qmd with **bun**, not npm, and pin its launcher to
the bun runtime. This is a runtime choice, not a package-manager preference:

- On **node**, qmd's SQLite layer is `better-sqlite3` — a NAN addon whose prebuilt binary is
  selected by `NODE_MODULE_VERSION` at install time. It is pinned to the Node major that was
  active when it was installed. The next `fnm`/`nvm` major upgrade makes every qmd command
  abort with an ABI mismatch, and the error names better-sqlite3 rather than qmd.
- On **bun**, qmd uses the built-in `bun:sqlite` instead and never loads the addon. No Node
  ABI is involved, so Node upgrades cannot break it. `qmd doctor` reports which is in use:
  `Runtime: bun:sqlite` or `Runtime: better-sqlite3`.

One wrinkle: qmd's `bin/qmd` launcher chooses its runtime from the lockfile **in its own
package directory** — `bun.lock` selects bun, `package-lock.json` or neither selects node.
`bun install -g` writes its lockfile at the global root, not in the package, so a bun install
still runs under node until a `bun.lock` marker exists there. `bin/bootstrap.ps1` checks for
that marker and offers to write it; `bun install -g @tobilu/qmd` deletes it again on every
upgrade - re-run bootstrap after upgrading qmd to restore it.

npm remains supported for machines without bun — it works, it is simply not durable across
Node upgrades, and `mc doctor` says so.

Retrieval, in preference order:

| Command | What it is | Cost |
| --- | --- | --- |
| `qmd query "<topic>"` | Hybrid BM25 + vector + re-rank — best quality | Needs models (~2 GB, one-off) |
| `qmd search "<topic>"` | BM25 keyword — fast, no models needed | Index only |
| `rg -i '<topic>'` over the clone | Raw fallback | Nothing |

`qmd update` refreshes the index after pulls; `qmd mcp` exposes the same search as MCP
tools for agents that prefer a tool call over a shell command (Claude Code:
`claude plugin marketplace add tobi/qmd && claude plugin install qmd@qmd`).

**qmd is an accelerator, not a dependency** — the same contract as `mc`
([`../agent/OPERATING_SYSTEM.md`](../agent/OPERATING_SYSTEM.md) §7). A machine without
Node or without the models still has `rg` and loses recall quality, never function. No
task is ever blocked on qmd being present.

## Alternatives considered

| Alternative | Why not |
| --- | --- |
| **`rg` only (status quo)** | Keyword-only recall degrades as the corpus grows; paraphrase misses are silent. Kept as the universal fallback. |
| **Custom `mc index` (SQLite FTS5)** | Was the earlier plan. Building and maintaining a bespoke indexer duplicates what qmd already does better (it adds vectors and re-ranking on top of FTS), for a corpus that is plain Markdown — qmd's exact target. |
| **Vector database / embedding service** | External service or committed index violates local-only and zero-committed-state. Heavyweight for a corpus of this size. |
| **MCP-only integration** | The MCP server is a bonus, not the base: shell commands work for every agent (Codex, Antigravity CLI) without per-agent MCP config. |

## Reasoning

1. **Purpose-built for exactly this corpus.** qmd indexes Markdown knowledge bases; the
   whole repository is one.
2. **Local by construction.** Models run on-device; nothing leaves the machine. The
   private-corpus constraint is satisfied without policy effort.
3. **Zero committed state.** Index and models live under `~/.cache/qmd/`; the repo stays
   clean and the no-generated-files rule holds.
4. **Maintained upstream.** The FTS + embeddings + re-ranking pipeline is somebody else's
   well-tested code, not a bespoke `mc` subsystem to debug on three machines.
5. **Graceful degradation preserved.** `qmd search` works without the model download;
   `rg` works without qmd; the accelerator contract is unchanged.

## Consequences

**Good**

- Semantic recall over the corpus; paraphrase queries start working.
- One `qmd update` after `git pull` keeps the index fresh; stale index only costs recall
  of the newest documents, never correctness of what it does return.
- MCP path available for agents that support it, with zero obligation.

**Bad, and accepted**

- **~2 GB model download per machine** for hybrid search, plus an embedding pass that is slow
  on a CPU-only machine. Opt-in at onboarding — bootstrap offers `qmd embed` and declining is
  safe, since BM25 (`qmd search`) and `rg` work without it and `qmd query` degrades to BM25.
- **Device mode has to be stated on CPU-only machines.** Without a GPU, qmd warns on every
  command until `QMD_FORCE_CPU=1` makes the fallback explicit. Bootstrap reads the device probe
  from `qmd doctor` and offers to persist it; where a GPU exists but does not offload, the
  answer is `QMD_LLAMA_GPU=metal|cuda|vulkan`, not forcing CPU.
- **Bun (or Node >= 22) becomes an optional prerequisite.** It joins `pwsh`/`rg`/`jq` in
  the optional tier, not the required one.
- **The bun runtime marker is re-applied after every qmd upgrade.** `bun install -g` wipes
  it, silently returning the machine to the node runtime. Bootstrap and `mc doctor` detect
  it rather than relying on anyone remembering.
- **Per-machine index state** can lag the repo. Acceptable: the index is derived data,
  never canonical — the Markdown is.
- **WSL indexes separately** from its Windows host (separate install, separate
  `~/.cache`), consistent with WSL being a separate machine
  ([`../machines/README.md`](../machines/README.md)).

## Related

- [`../agent/MEMORY_POLICY.md`](../agent/MEMORY_POLICY.md) — what gets written and how it is titled
- [`../agent/OPERATING_SYSTEM.md`](../agent/OPERATING_SYSTEM.md) §3, §7 — prior-art search and the accelerator contract
- [`../docs/onboarding.html`](../docs/onboarding.html) — the per-machine setup step
