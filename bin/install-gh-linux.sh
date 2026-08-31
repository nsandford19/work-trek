#!/usr/bin/env bash
# Install or upgrade the GitHub CLI from GitHub's official APT repository.
#
# Ubuntu ships its own `gh` (noble carries 2.49.2), which is too old for Work Trek:
# `mc history sync` asks for `--json stateReason` on `gh issue list` and older builds reject
# the field outright.
#
# The usual failure is a repository line copied with an Ubuntu codename:
#
#     deb https://cli.github.com/packages noble main      # wrong - no such suite
#     deb https://cli.github.com/packages stable main     # right
#
# GitHub publishes one `stable` suite for every distribution. A codename suite resolves to
# nothing, apt silently keeps the distro package, and `gh --version` never moves.
#
# Safe to re-run. Every step is idempotent.
#
# Usage:
#   ./bin/install-gh-linux.sh            install or upgrade
#   ./bin/install-gh-linux.sh --check    report what it would do, change nothing

set -euo pipefail

KEYRING='/etc/apt/keyrings/githubcli-archive-keyring.gpg'
LIST='/etc/apt/sources.list.d/github-cli.list'
REPO_HOST='cli.github.com'
LEGACY_APT_KEY='C99B11DEB97541F0'

# The oldest gh verified to expose `stateReason` on `gh issue list --json`.
# 2.49.2 does not. Raise this only with evidence, never by guessing.
MIN_VERSION='2.62.0'

CHECK_ONLY=0
case "${1:-}" in
    --check) CHECK_ONLY=1 ;;
    -h | --help)
        sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    '') ;;
    *)
        printf 'unknown argument: %s (try --help)\n' "$1" >&2
        exit 2
        ;;
esac

say() { printf '\n\033[36m== %s\033[0m\n' "$1"; }
ok() { printf '  \033[32mok\033[0m    %s\n' "$1"; }
warn() { printf '  \033[33mwarn\033[0m  %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; }
run() { if [ "$CHECK_ONLY" -eq 1 ]; then printf '  would run: %s\n' "$*"; else "$@"; fi; }

# ---------------------------------------------------------------- preconditions

say 'Preconditions'
[ "$(uname -s)" = 'Linux' ] || {
    bad "this script is for Linux; found $(uname -s)"
    exit 1
}
command -v apt-get >/dev/null 2>&1 || {
    bad 'apt-get not found - this script targets Debian/Ubuntu only'
    printf '        On other distributions install gh from https://github.com/cli/cli#installation\n'
    exit 1
}
ok "Debian/Ubuntu detected: $(. /etc/os-release 2>/dev/null && printf '%s' "${PRETTY_NAME:-unknown}")"

if [ "$(id -u)" -ne 0 ]; then
    command -v sudo >/dev/null 2>&1 || {
        bad 'not root and sudo is not installed'
        exit 1
    }
    SUDO='sudo'
    # Prompt once, up front, rather than midway through a partially applied change.
    [ "$CHECK_ONLY" -eq 1 ] || sudo -v
else
    SUDO=''
fi
ok 'root access available'

# ---------------------------------------------------------------- current state

say 'Current state'
if command -v gh >/dev/null 2>&1; then
    CURRENT="$(gh --version 2>/dev/null | head -1 | awk '{print $3}')"
    ok "gh $CURRENT at $(command -v gh)"
else
    CURRENT=''
    warn 'gh is not installed'
fi

# A codename suite instead of `stable` is the failure this script exists to fix, so name the
# offending file rather than silently rewriting it.
BROKEN_LISTS=''
for f in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
    [ -e "$f" ] || continue
    [ "$f" = "$LIST" ] && continue
    if grep -q "$REPO_HOST" "$f" 2>/dev/null; then
        BROKEN_LISTS="$BROKEN_LISTS $f"
        warn "conflicting GitHub CLI repository: $f"
    fi
done
if grep -q "$REPO_HOST" /etc/apt/sources.list 2>/dev/null; then
    warn '/etc/apt/sources.list mentions cli.github.com - remove that line by hand'
fi
[ -n "$BROKEN_LISTS" ] || ok 'no conflicting repository files'

# ---------------------------------------------------------------- apply

say 'GitHub CLI APT repository'

for f in $BROKEN_LISTS; do
    run $SUDO rm -f "$f"
    [ "$CHECK_ONLY" -eq 1 ] || ok "removed $f"
done

run $SUDO mkdir -p -m 755 /etc/apt/keyrings

if [ "$CHECK_ONLY" -eq 1 ]; then
    printf '  would run: download %s to %s\n' "https://$REPO_HOST/packages/githubcli-archive-keyring.gpg" "$KEYRING"
else
    if command -v wget >/dev/null 2>&1; then
        wget -qO- "https://$REPO_HOST/packages/githubcli-archive-keyring.gpg" | $SUDO tee "$KEYRING" >/dev/null
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL "https://$REPO_HOST/packages/githubcli-archive-keyring.gpg" | $SUDO tee "$KEYRING" >/dev/null
    else
        bad 'neither wget nor curl is installed'
        exit 1
    fi
    # A truncated download still writes a file; an empty keyring fails apt with a confusing
    # signature error, so catch it here where the cause is obvious.
    [ -s "$KEYRING" ] || {
        bad "keyring download produced an empty file: $KEYRING"
        exit 1
    }
    $SUDO chmod go+r "$KEYRING"
    ok "keyring installed: $KEYRING"
fi

ARCH="$(dpkg --print-architecture)"
LINE="deb [arch=$ARCH signed-by=$KEYRING] https://$REPO_HOST/packages stable main"
if [ -f "$LIST" ] && [ "$(cat "$LIST")" = "$LINE" ]; then
    ok "repository already correct: $LIST"
elif [ "$CHECK_ONLY" -eq 1 ]; then
    printf '  would write %s:\n    %s\n' "$LIST" "$LINE"
else
    printf '%s\n' "$LINE" | $SUDO tee "$LIST" >/dev/null
    ok "repository written: $LIST"
fi

say 'Install'
run $SUDO apt-get update
run $SUDO apt-get install -y gh

# Legacy apt-key entries are unused once signed-by is in play, but they keep apt emitting
# deprecation warnings on every update. Never fatal.
if command -v apt-key >/dev/null 2>&1 && apt-key list 2>/dev/null | grep -q "$LEGACY_APT_KEY"; then
    run $SUDO apt-key del "$LEGACY_APT_KEY" || warn 'could not remove the legacy apt-key; harmless'
fi

# ---------------------------------------------------------------- verify

say 'Verification'
if [ "$CHECK_ONLY" -eq 1 ]; then
    printf '  (check mode - nothing was changed)\n\n'
    exit 0
fi

hash -r 2>/dev/null || true
command -v gh >/dev/null 2>&1 || {
    bad 'gh is still not on PATH after install'
    exit 1
}

RESOLVED="$(command -v gh)"
VERSION="$(gh --version | head -1 | awk '{print $3}')"

# PATH shadowing is the trap that makes a successful install look like a failed one: the apt
# package lands in /usr/bin/gh while an earlier PATH entry still answers `gh`.
SHADOW=0
for d in $(printf '%s' "$PATH" | tr ':' '\n'); do
    [ -n "$d" ] || continue
    cand="$d/gh"
    [ -e "$cand" ] || [ -L "$cand" ] || continue
    if [ -L "$cand" ] && [ ! -e "$cand" ]; then
        bad "dangling symlink shadowing gh: $cand"
        SHADOW=1
    elif [ "$cand" != '/usr/bin/gh' ] && [ "$cand" = "$RESOLVED" ]; then
        warn "gh resolves to $cand, not the apt package at /usr/bin/gh"
        SHADOW=1
    fi
    break
done

# Sort -V puts the lower version first; if that is not MIN_VERSION, we are below the floor.
lowest="$(printf '%s\n%s\n' "$MIN_VERSION" "$VERSION" | sort -V | head -1)"
if [ "$VERSION" != "$MIN_VERSION" ] && [ "$lowest" = "$VERSION" ]; then
    bad "gh $VERSION is below the $MIN_VERSION floor Work Trek needs (stateReason support)"
    exit 1
fi

ok "gh $VERSION at $RESOLVED"
if [ -n "$CURRENT" ] && [ "$CURRENT" != "$VERSION" ]; then
    ok "upgraded from $CURRENT"
fi

# The capability the floor exists for. Proves the install rather than trusting the number.
if gh auth status >/dev/null 2>&1; then
    if gh issue list -R {{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}} --state all --limit 1 --json number,stateReason >/dev/null 2>&1; then
        ok 'issue JSON exposes stateReason (the capability the floor exists for)'
    else
        bad 'gh accepted the version check but rejected --json stateReason'
        exit 1
    fi
else
    warn 'gh is not authenticated, so the stateReason capability was not exercised'
    printf '        authenticate with: gh auth login\n'
fi

[ "$SHADOW" -eq 0 ] || printf '\n  Resolve the PATH problem above, or gh will keep answering from the wrong binary.\n'
printf '\n'
apt policy gh 2>/dev/null | head -3 || true
printf '\n'
