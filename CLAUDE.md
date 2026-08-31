# CLAUDE.md

This file exists only because Claude Code does not yet auto-load `AGENTS.md`.

**Read [`AGENTS.md`](AGENTS.md) now and follow it.** It is the canonical entry point for
every agent working in this repository, and it points to the operating manual in `agent/`.

Do not duplicate operating instructions here. If something needs to change in how agents
behave, change [`agent/OPERATING_SYSTEM.md`](agent/OPERATING_SYSTEM.md) so all agents get it.

Claude-specific note: skills are auto-discovered from `.claude/skills/`, but those files are
generated stubs. The canonical skill bodies live in [`skills/`](skills/README.md) — edit
those, then run `mc skills sync`.
