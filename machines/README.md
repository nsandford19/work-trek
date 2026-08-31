---
type: policy
title: Machine registry
status: active
created: 2026-08-10
---

# Machines

One YAML file per machine the operator works on. This registry does two jobs:

1. **Identity** — lets an agent answer "which computer am I on?" so it can resolve correct
   local paths from [`../repositories/`](../repositories/README.md).
2. **Machine scope** — carries constraints that override broader conventions (highest
   precedence; see [`../agent/OPERATING_SYSTEM.md`](../agent/OPERATING_SYSTEM.md) §2).

## Registered machines

| Machine | OS | Role | Notes |
| --- | --- | --- | --- |
| *(none yet — register your first machine below)* | | | |

A fictional worked example of the schema ships as
[`example-laptop.yaml.example`](example-laptop.yaml.example); the `.example` suffix keeps
it out of identity resolution and validation. Copy it, drop the suffix, and edit.

---

## How identity resolution works

In order — first match wins:

1. **`MC_MACHINE` environment variable.** Explicit override.
2. **Hostname**, matched against `id`, `aliases`, or `hostnames` in these files. Inside
   WSL, `<hostname>-wsl` is tried **before** the bare hostname (see below).
3. **No match** → the agent says the machine is unregistered and offers to add it. It must
   **not** guess: a wrong machine means handing back paths that do not exist.

```powershell
$env:MC_MACHINE          # 1
hostname                  # 2
```

```bash
echo "$MC_MACHINE"; hostname
```

```bash
rg -l "$(hostname)" machines/     # find the matching file
mc machine                       # accelerator for all of the above
```

### Why hostname-first

Hostname mapping needs **zero setup after the machine is registered once** — clone and go,
forever. The env var is the escape hatch for what hostnames cannot express: temporary
machines, containers, or two checkouts on one host. A gitignored local config file was
considered and rejected — a third mechanism to create, forget and debug, with no
capability the env var lacks.

### WSL is a separate machine

WSL reports the **same hostname as its Windows host** while being a different environment —
different OS, different tools, different paths (`/home/...`, `/mnt/d/...` instead of
`D:\...`). One registry entry cannot be true for both, so WSL registers separately under
the id **`<hostname>-wsl`**, and inside WSL the tooling (`mc machine`, both bootstraps)
probes that id before the bare hostname.

Two rules keep the pair unambiguous:

- The WSL entry sets `hostnames: [<hostname>-wsl]` — it must **not** list the bare
  hostname, which belongs to the Windows entry. The `-wsl` name is synthetic; resolution
  constructs it, so no OS-level configuration is needed.
- Agents matching by hand inside WSL (`grep -qi microsoft /proc/version` to detect it)
  should do the same: look for `<hostname>-wsl` first, and treat a fallback hit on a
  `os: windows` entry as a warning, not an answer.

Tradeoff accepted: hostnames are committed to a private repo. That is inventory data, not a
secret. Reasoning: [ADR 0003](../decisions/0003-machine-identity-via-hostname-map.md).

### Temporary machines

Set `MC_MACHINE` for the session and skip registration entirely:

```bash
export MC_MACHINE=example-laptop      # bash
$env:MC_MACHINE = 'example-laptop'    # PowerShell
```

---

## Schema

```yaml
id: example-laptop                  # REQUIRED — filename must match
aliases: [desktop-main]        # optional — friendly/former names
hostnames: [example-laptop]         # REQUIRED — actual hostnames that map here
os: windows                    # REQUIRED — windows | linux | macos
os_detail: Windows 11 Pro for Workstations 10.0.26200
role: primary workstation      # REQUIRED — one line
status: active                 # REQUIRED — active | retired
last_verified: 2026-08-10      # REQUIRED — YYYY-MM-DD, when this entry was last confirmed true
shells: [powershell, bash]
dev_roots:                     # where source repositories live; used by `mc repo scan`
  - 'C:\dev'
tools: [git, gh, vscode]       # notable tools present
constraints:                   # MACHINE SCOPE — overrides all broader conventions
  - 'Line endings must stay LF; core.autocrlf is not relied on.'
notes:
  - 'Free-form facts useful to an agent.'
```

### Field notes

- **`id`** must match the filename and be safe to use in paths and branch names: letters,
  digits, dots, underscores, and hyphens only, beginning and ending with a letter or digit.
  Windows device-name segments such as `CON`, `NUL`, `COM1`, and `LPT1` are not valid ids.
  Using the real hostname as the id avoids inventing a label that later turns out wrong;
  add a friendlier `aliases:` entry any time.
- **`hostnames`** is a list because the same machine can answer to several names (short vs
  FQDN). A WSL environment is **not** an extra hostname of its Windows host — it gets its
  own `<hostname>-wsl` entry (see above).
- Every id, alias, and hostname must identify exactly one machine, case-insensitively. The
  validator rejects duplicate identities rather than letting resolution pick a file based
  on directory enumeration order.
- **`status: retired`** keeps the file: repository entries and old issues may still reference
  it, and deleting it would orphan those references. Add a note saying what replaced it.
- **`dev_roots`** is the only field `mc repo scan` reads. Keep it short; scanning a whole
  drive is slow and noisy.
- **`constraints`** is the highest-precedence scope in the system. Put a rule here only if it
  is true *because of this machine*, not because of the project you happen to be using it for.

### Never record here

Serial numbers, licence keys, VPN or network configuration, credentials of any kind, or
inventory detail with no operational value. See
[`../agent/SECURITY_POLICY.md`](../agent/SECURITY_POLICY.md) §4.

---

## YAML dialect

These files are parsed by a small built-in reader (`bin/lib/Mc.Yaml.psm1`) so that no
external YAML module is needed on any machine. Stay inside this subset — `mc validate`
enforces it:

- 2-space indentation, **no tabs**
- no anchors (`&`), aliases (`*`), or merge keys (`<<`)
- no block scalars (`|`, `>`) and no multi-document files (`---` separators)
- lists as block sequences (`- item`) or simple flow sequences (`[a, b]`)
- quote any value containing `\`, `:`, `#`, or a leading `[`/`{` — **Windows paths must be
  single-quoted**
- maximum nesting depth 3

This constraint is deliberate: it keeps the registry parseable everywhere with zero
dependencies, and nothing here needs richer YAML.

---

## Adding a machine

```bash
cp machines/example-laptop.yaml.example machines/<new-id>.yaml   # then edit
mc validate
```

Then add a row to the table above and commit:

```
chore(registry): register <new-id>
```
