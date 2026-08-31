---
type: policy
title: Manual setup, step by step — the same work as bootstrap, as individual commands
status: active
created: 2026-08-18
---

# Manual setup, step by step

[`bin/bootstrap.sh`](../bin/bootstrap.sh) / [`bin/bootstrap.ps1`](../bin/bootstrap.ps1) do
all of this interactively and idempotently — this page is the same work as individual
commands, for when you want to run (or understand) each step yourself.

## 1. Replace the placeholders

Every value a cloner must supply uses one convention:

| Placeholder | Meaning | Example |
| --- | --- | --- |
| `nsandford19` | Your GitHub user or org | `jdoe` |
| `work-trek` | This repository's name | `work-trek` |

One command fills them in everywhere (it derives the values from your `origin` remote,
or takes them as arguments) and works standalone:

```bash
./bin/init-template.sh            # Linux / WSL / macOS
./bin/init-template.ps1           # anywhere with PowerShell 7
```

Equivalent one-liner if you prefer to do it by hand:

```bash
git ls-files -z | xargs -0 sed -i 's|nsandford19|<owner>|g; s|work-trek|<repo>|g'
```

Commit the result.

## 2. Sync the labels

The canonical taxonomy lives in [`.github/labels.yml`](../.github/labels.yml):

```bash
./bin/mc.ps1 labels sync
```

## 3. Everything else

Tool installs, machine registration ([`machines/README.md`](../machines/README.md)),
validation (`./bin/mc.ps1 validate`), qmd setup
([`decisions/0004`](../decisions/0004-qmd-as-memory-retrieval-driver.md)), agent pointers
(`./bin/mc.ps1 onboard`), status line (`./bin/mc.ps1 statusline`) — each with raw `gh`/`rg`
equivalents in [`agent/OPERATING_SYSTEM.md`](../agent/OPERATING_SYSTEM.md) §7.

## Verifying the result

`./bin/mc.ps1 validate` should print `Valid.`, `git grep -n 'nsandford19'` should
return nothing, and a bootstrap run on the finished clone should change nothing. The full
end-to-end test sequence is in [`WALKTHROUGH.md`](WALKTHROUGH.md) §7.
