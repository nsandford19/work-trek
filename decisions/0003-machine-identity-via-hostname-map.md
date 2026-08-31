---
type: decision
title: Machine identity resolves via a committed hostname map with an environment override
status: active
created: 2026-08-10
areas: [personal-tools, infrastructure]
tags: [machine-identity, multi-machine, bootstrap]
issues: []
---

# 0003 — Machine identity via a hostname map, with an environment-variable override

## Context

Work Trek is cloned onto several machines. To answer *"which tasks can I do here?"* and
*"where is repository X on this machine?"*, an agent must first know **which machine it is on**,
then resolve paths from [`../repositories/`](../repositories/README.md).

Getting this wrong is worse than not knowing: a confidently wrong machine yields paths that do
not exist and work suggestions that cannot be started.

Requirements: works on Windows, Linux, and WSL; survives cloning to a new machine; no secrets
committed; and as little per-machine setup as possible, because setup that is skipped is setup
that does not exist.

## Decision

Resolution order, first match wins:

1. **`MC_MACHINE` environment variable** — explicit override.
2. **Hostname**, matched against `id`, `aliases`, or `hostnames` in `machines/*.yaml`.
3. **No match** → the agent states the machine is unregistered and offers to add it. It must
   **not guess**.

Machine files use the real hostname as `id` by default, with `aliases:` available for a
friendlier name. `machines/README.md` documents the schema; `mc machine` implements the
lookup, and `rg -l "$(hostname)" machines/` does the same thing without any tooling.

## Alternatives considered

| Alternative | Why not |
| --- | --- |
| **Hostname only** | Cannot express temporary machines, containers, two clones on one host, or WSL and Windows sharing a name. |
| **Env var only** | Requires setup on every machine before anything works, and a forgotten variable produces an unhelpful failure on a machine that is otherwise fine. Fails the "clone and go" goal. |
| **Gitignored local config file** (`.mc/machine`) | A third mechanism with no capability the env var lacks — one more thing to create, forget, and debug. Rejected as redundant, not as wrong. |
| **Machine GUID / hardware id** | Opaque, unreadable in diffs, changes on reinstall, and leaks hardware detail for no benefit. |
| **Git remote or checkout path heuristics** | Coincidental. Two clones on one machine break it immediately. |

## Reasoning

1. **Hostname-first means zero setup after registering once.** Clone the repo on that machine
   any number of times, in any location, forever — identity still resolves. This is the single
   biggest usability win and it is why hostname is step 2 rather than step 1 of a manual flow.
2. **The env var covers exactly the cases hostnames cannot** — temporary and ambiguous
   machines — without imposing setup on the normal case.
3. **Human-readable and reviewable.** `machines/*.yaml` diffs legibly and doubles as
   documentation of the operator's environment.
4. **Explicit failure.** Not resolving is a *reported* state, not a silent fallback. This is
   the property that prevents wrong-path answers.

## Consequences

**Good**

- Clone and go on any registered machine, on any OS.
- One override handles every exception.
- No local state files, no generated identity, nothing to keep in sync.

**Bad, and accepted**

- **Hostnames are committed** to a private repository. That is inventory data, not a secret,
  and the registry is only useful if it names real machines. `SECURITY_POLICY.md` §4 forbids
  going further (serials, licence keys, network configuration).
- **Renaming a machine breaks resolution** until `hostnames:` is updated. Mitigated by keeping
  old names in `hostnames:`/`aliases:` rather than replacing them.
- **Hostname collisions across networks** are possible in principle. If it ever happens, use
  `MC_MACHINE` — the escape hatch already exists.
- **One more registration step** for a new permanent machine. Bootstrap prompts for it, and it
  is a single small file.

## Related

- [`../machines/README.md`](../machines/README.md) — schema and resolution details
- [`../repositories/README.md`](../repositories/README.md) — per-machine path resolution
- [`../agent/OPERATING_SYSTEM.md`](../agent/OPERATING_SYSTEM.md) §1 — startup step 2
