#!/usr/bin/env bash
# Bootstrap Work Trek on this machine (Linux / WSL / macOS) — the single setup
# entry point.
#
# Delegates to bin/bootstrap.ps1 — the full guided onboarding walkthrough — when
# PowerShell 7 is available. Without pwsh it still does the useful part — the one-off
# template-placeholder substitution (offered, never forced), tool checks (offering to
# install missing tools via apt/dnf/brew, one [y/N] prompt per tool), auth check,
# machine identity resolution, and a label-taxonomy check — using only POSIX tools,
# then tells you what to do next. Idempotent: every step probes current state first,
# and a fully set-up clone re-runs to all-ok with no prompts.
#
# Work Trek never *requires* these scripts: every operation has a raw gh/rg
# equivalent (agent/OPERATING_SYSTEM.md §7).
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/.." && pwd)"

cyan() { printf '\n\033[36m== %s\033[0m\n' "$1"; }
ok()   { printf '  \033[32mok    %s\033[0m\n' "$1"; }
warn() { printf '  \033[33mwarn  %s\033[0m\n' "$1"; }
bad()  { printf '  \033[31mFAIL  %s\033[0m\n' "$1"; }
note() { printf '        \033[90m%s\033[0m\n' "$1"; }

if command -v pwsh >/dev/null 2>&1; then
  exec pwsh -NoProfile -File "$here/bootstrap.ps1" "$@"
fi

printf '\nWork Trek — bootstrap (POSIX fallback, no pwsh)\n'
note "$root"

# Installs are per-tool opt-in prompts, and only when stdin is a terminal.
interactive=''
[ -t 0 ] && interactive=1

# ------------------------------------------------------------ 0. Template placeholders
# A fresh "Use this template" clone still carries the GITHUB_OWNER / CONTROL_PLANE_REPO
# placeholders. Offer the one-off substitution (bin/init-template.sh), deriving the values
# from the origin remote, instead of refusing. Already-substituted clones skip this
# silently. (Pattern assembled at runtime so this check does not match itself after
# substitution; sed -i replaces files by rename, so rewriting this running script is safe.)
ph='{{''GITHUB_OWNER''}}'
ph2='{{''CONTROL_PLANE_REPO''}}'
if grep -q "$ph" "$root/AGENTS.md" 2>/dev/null; then
  cyan '0. Template placeholders'
  warn "this clone still contains template placeholders ($ph, $ph2)"
  owner=''; name=''
  url="$(git -C "$root" remote get-url origin 2>/dev/null || true)"
  if [ -n "$url" ]; then
    slug="$(printf '%s' "$url" | sed -E 's#^(git@[^:]+:|https?://[^/]+/)##; s#\.git$##')"
    owner="${slug%%/*}"; name="${slug##*/}"
  fi
  if [ -n "$interactive" ]; then
    if [ -n "$owner" ]; then
      note "derived from origin: $owner/$name"
    else
      note 'no origin remote to derive the values from - enter them (blank to skip):'
      printf '  GitHub owner (user or org): '; read -r owner
      [ -n "$owner" ] && { printf '  repository name: '; read -r name; }
    fi
    if [ -n "$owner" ] && [ -n "$name" ]; then
      printf "  Replace the placeholders with '%s/%s' now (runs bin/init-template.sh)? [y/N] " "$owner" "$name"
      read -r answer
      case "$answer" in
        y|Y|yes|YES)
          if "$here/init-template.sh" "$owner" "$name"; then
            ok "placeholders replaced with $owner/$name"
            note "Review with 'git diff', then commit the substitution."
          else
            warn 'init-template did not complete - see output above'
          fi ;;
        *) note 'Skipped. Later:  ./bin/init-template.sh' ;;
      esac
    else
      note 'Skipped. Later:  ./bin/init-template.sh <github-owner> <repo-name>'
    fi
  else
    [ -n "$owner" ] && note "origin suggests: $owner/$name"
    note 'Non-interactive: fill them in later with ./bin/init-template.sh (derives from origin).'
    note 'Continuing with the steps that work before substitution.'
  fi
fi

pm=''
if command -v apt-get >/dev/null 2>&1; then pm='apt'
elif command -v dnf >/dev/null 2>&1; then pm='dnf'
elif command -v brew >/dev/null 2>&1; then pm='brew'
fi

pkg_for() {
  # tool name -> package name under $pm; empty means no plain package there
  case "$1" in
    rg) echo ripgrep ;;
    pwsh) [ "$pm" = brew ] && echo powershell ;;   # apt/dnf need Microsoft's repo
    code) [ "$pm" = brew ] && echo visual-studio-code ;;
    *) echo "$1" ;;
  esac
}

install_tool() {
  pkg="$(pkg_for "$1")"
  [ -n "$pkg" ] || return 1
  case "$pm" in
    apt)
      if [ -z "${apt_updated:-}" ]; then sudo apt-get update; apt_updated=1; fi
      sudo apt-get install -y "$pkg" ;;
    dnf) sudo dnf install -y "$pkg" ;;
    brew)
      case "$1" in
        pwsh|code) brew install --cask "$pkg" ;;
        *) brew install "$pkg" ;;
      esac ;;
    *) return 1 ;;
  esac
}

offer_install() { # $1 tool, $2 'required'|'optional'
  [ -n "$interactive" ] && [ -n "$pm" ] || return 1
  [ -n "$(pkg_for "$1")" ] || return 1   # no plain package under $pm — leave the manual hint
  printf '  Install %s tool %s via %s? [y/N] ' "$2" "$1" "$pm"
  read -r answer
  case "$answer" in
    y|Y|yes|YES)
      if install_tool "$1" && command -v "$1" >/dev/null 2>&1; then
        ok "$1 installed"
        return 0
      fi
      warn "$1: install did not complete"
      [ "$1" = gh ] && note 'gh may need the official repo: https://github.com/cli/cli/blob/trunk/docs/install_linux.md'
      ;;
  esac
  return 1
}

cyan '1. Required tools'
fatal=0
for t in git gh; do
  if command -v "$t" >/dev/null 2>&1; then
    ok "$t — $("$t" --version 2>&1 | head -1)"
  else
    bad "$t not found"
    offer_install "$t" required || true
    command -v "$t" >/dev/null 2>&1 || fatal=$((fatal + 1))
  fi
done
for t in rg jq code; do
  if command -v "$t" >/dev/null 2>&1; then
    ok "$t (optional)"
  else
    warn "$t not found (optional but useful)"
    offer_install "$t" optional || true
  fi
done
# On PATH is not proof it runs: on node, qmd loads a native better-sqlite3 prebuild that
# breaks after a Node major switch (fnm/nvm) or when a stale global copy shadows PATH. On
# bun it uses bun:sqlite and has no Node ABI, which is why ADR 0004 prefers bun.
qmd_bun_dir="${BUN_INSTALL:-$HOME/.bun}/install/global/node_modules/@tobilu/qmd"
if ! command -v qmd >/dev/null 2>&1; then
  warn 'qmd not found (optional — semantic memory search, ADR 0004)'
  note 'Install:  bun install -g @tobilu/qmd'
elif ! qmd --version >/dev/null 2>&1; then
  warn "qmd is on PATH ($(command -v qmd)) but does not run — rg fallback still works"
  note 'Usually a native better-sqlite3 built for another Node major. Move it to bun:'
  note '  npm uninstall -g @tobilu/qmd && bun install -g @tobilu/qmd'
elif [ ! -d "$qmd_bun_dir" ]; then
  ok 'qmd (optional — memory search)'
  note 'Installed on node — breaks on the next Node major upgrade. Prefer:  bun install -g @tobilu/qmd'
elif [ ! -f "$qmd_bun_dir/bun.lock" ]; then
  ok 'qmd (optional — memory search)'
  note 'bun install, but still routes to node — run bin/bootstrap.ps1 to pin it to bun'
else
  ok 'qmd (optional — memory search, on bun)'
fi
warn 'pwsh not found — the mc accelerator is unavailable on this machine'
if offer_install pwsh optional; then
  note 'pwsh is now available — handing over to the full walkthrough (bin/bootstrap.ps1)'
  exec pwsh -NoProfile -File "$here/bootstrap.ps1" "$@"
fi
note 'Install:  sudo apt-get install -y powershell   |   brew install --cask powershell'
note 'Not a blocker: use the raw gh/rg equivalents below.'

if [ "$fatal" -gt 0 ]; then
  printf '\n'; bad 'Install the missing required tools, then re-run.'
  exit 1
fi

cyan '2. GitHub authentication'
if gh auth status >/dev/null 2>&1; then
  ok 'gh is authenticated'
  note 'Projects scope is not needed — labels are canonical (ADR 0002).'
else
  warn 'gh is not authenticated — run: gh auth login'
  note 'Durable memory works offline; only live issue state needs auth.'
fi

cyan '3. Machine identity'
hostname_short="$(hostname | cut -d. -f1)"
note "hostname: $hostname_short"

# WSL shares the Windows host's name but is a different environment with different
# paths; its identity is '<hostname>-wsl' by convention (machines/README.md).
is_wsl=''
if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null; then
  is_wsl=1
  note "WSL detected — this environment registers separately as '${hostname_short}-wsl'"
fi
[ -n "${MC_MACHINE:-}" ] && note "MC_MACHINE: $MC_MACHINE"

known="$(cd "$root/machines" && ls -1 *.yaml 2>/dev/null | sed 's/\.yaml$//' | tr '\n' ' ')"
note "known machines: ${known:-none}"

# Match a name against id / aliases / hostnames in one machine file, covering both the
# flow form (hostnames: [a, b]) and the block form (hostnames:\n  - a).
name_in_file() {
  grep -qiE "^(id|hostnames|aliases):([^#]*[[:space:],[])?${1}([],[:space:]]|$)" "$2" ||
  grep -qiE "^[[:space:]]+-[[:space:]]*'?${1}'?[[:space:]]*$" "$2"
}

candidates="$hostname_short"
[ -n "$is_wsl" ] && candidates="${hostname_short}-wsl $hostname_short"

match=''
if [ -n "${MC_MACHINE:-}" ]; then
  if [ -f "$root/machines/$MC_MACHINE.yaml" ]; then
    match="$MC_MACHINE"
    ok "resolved via MC_MACHINE=$match"
  else
    warn "MC_MACHINE=$MC_MACHINE is not registered; hostname fallback is disabled because an explicit identity was supplied"
  fi
else
  for cand in $candidates; do
    for f in "$root"/machines/*.yaml; do
      [ -f "$f" ] || continue
      if name_in_file "$cand" "$f"; then
        # A bare-hostname hit on the Windows entry is not an answer inside WSL
        # (machines/README.md): stay unmatched so the registration hint below fires.
        if [ -n "$is_wsl" ] && [ "$cand" = "$hostname_short" ] && grep -qE '^os:[[:space:]]*windows' "$f"; then
          warn "bare hostname matches '$(basename "$f" .yaml)', the WINDOWS registration — its paths do not exist inside WSL"
          continue
        fi
        match="$(basename "$f" .yaml)"
        ok "this machine is registered as '$match' (matched '$cand')"
        break
      fi
    done
    [ -n "$match" ] && break
  done
fi

if [ -z "$match" ]; then
  warn 'this machine is not registered'
  want_id="${hostname_short}$( [ -n "$is_wsl" ] && printf '%s' '-wsl' )"
  note 'Permanent machine: copy the schema example and edit it —'
  note "  cp machines/example-laptop.yaml.example machines/${want_id}.yaml"
  note '  (schema: machines/README.md; then add a row to its table and commit)'
  [ -n "$is_wsl" ] && note "  (WSL: set hostnames: [${want_id}] — the Windows entry owns '${hostname_short}')"
  note 'Temporary machine: export MC_MACHINE=<an existing id>'
fi

cyan '4. Repository validation'
warn 'skipped — validation needs pwsh'
note 'Schemas to check by hand: machines/README.md, agent/MEMORY_POLICY.md §4'
note 'CI validates every PR anyway (.github/workflows/validate.yml)'

# .github/labels.yml is the canonical label list (ADR 0002). Checking is cheap with gh's
# built-in --jq (names only); the sync itself is mc.ps1 code, so without pwsh this step
# reports what to run later instead of failing.
cyan '5. Label taxonomy'
if ! gh auth status >/dev/null 2>&1; then
  warn 'gh is not authenticated — skipped'
  note 'Later (needs pwsh):  ./bin/mc.ps1 labels sync'
elif have="$(cd "$root" && gh label list --limit 200 --json name --jq '.[].name' 2>/dev/null)"; then # mc-validate:allow - pinned by cd "$root"
  total=0; missing=0
  while IFS= read -r lname; do
    [ -n "$lname" ] || continue
    total=$((total + 1))
    printf '%s\n' "$have" | grep -qxF "$lname" || missing=$((missing + 1))
  done <<EOF
$(sed -n "s/^- name: *'\(.*\)'.*/\1/p" "$root/.github/labels.yml")
EOF
  if [ "$total" -eq 0 ]; then
    warn 'could not read label names from .github/labels.yml'
  elif [ "$missing" -eq 0 ]; then
    ok "all $total canonical labels exist on the repository"
    note 'Names only are compared; re-apply colors/descriptions any time:  ./bin/mc.ps1 labels sync'
  else
    warn "$missing of $total canonical label(s) missing"
    note 'Applying them needs pwsh — run later:  ./bin/mc.ps1 labels sync'
  fi
else
  warn 'could not list the repository labels (no origin remote, or no access)'
  note 'Later (needs pwsh):  ./bin/mc.ps1 labels sync'
fi

# qmd (github.com/tobi/qmd) is the primary retrieval driver over durable memory
# (ADR 0004): local BM25 + vector search, index in ~/.cache/qmd, nothing committed.
# Optional, like everything in bin/ — rg remains the universal fallback.
cyan '6. Memory search (qmd)'
if command -v qmd >/dev/null 2>&1; then
  ok 'qmd is installed'
  note 'If this clone is not indexed on this machine yet, register it once:'
  note "  qmd collection add '$root' --name work-trek"
  note '  qmd context add qmd://work-trek "personal engineering memory: decisions, knowledge, runbooks, investigations"'
  note '  qmd embed        # first run downloads ~2 GB of local models (optional; enables `qmd query`)'
  note 'After a git pull:  qmd update'
else
  warn 'qmd not installed — agents fall back to rg keyword search (works, lower recall)'
  note 'Install (bun preferred; npm + Node >= 22 works but breaks on Node upgrades):'
  note '  bun install -g @tobilu/qmd'
  note 'Then re-run bootstrap for the collection setup and the bun pin. Details: decisions/0004.'
fi

cyan '7. What now'
cat <<'EOF'

  Open this directory with Claude Code, Codex, or Antigravity CLI and ask:

    What should I work on next?
    What is blocked?
    Which machine has repository X?
    What did I learn about <technology>?

  Raw equivalents while pwsh is unavailable:

    what to work on   gh issue list -R nsandford19/work-trek --state open --json number,title,labels,body
                      then follow skills/whats-next/SKILL.md
    resolve issue     gh issue view 42 -R nsandford19/work-trek --json labels,body
                      then map Repository/project through repositories/*.yaml
    what is blocked   gh issue list -R nsandford19/work-trek --state open --label status:blocked
    find a repo       rg -i '<term>' repositories/
    find a repo scan  rg --files --hidden --glob '**/.git/HEAD' <dev-root>
    search memory     qmd query "<topic>"   (or rg -i '<topic>' over this clone)

  So agents opened in OTHER repositories can find Work Trek, add the pointer
  block to your global agent files (~/.claude/CLAUDE.md, ~/.codex/AGENTS.md) —
  with pwsh this is `mc onboard`; without it, copy the block
  from skills/register-repository/SKILL.md section D.

  Claude Code status line (same line on every machine) — with pwsh this is
  `mc statusline`; without it, two commands:

    cp tooling/claude/statusline-command.sh ~/.claude/statusline-command.sh
    # then set in ~/.claude/settings.json:
    #   "statusLine": { "type": "command", "command": "bash \"$HOME/.claude/statusline-command.sh\"" }

  It needs bash and jq. Details: tooling/claude/README.md

  Read next: AGENTS.md, then agent/OPERATING_SYSTEM.md

EOF
