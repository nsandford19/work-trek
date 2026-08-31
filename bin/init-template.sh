#!/usr/bin/env bash
# One-off template initialiser: replaces the Work Trek placeholders with your values
# across every tracked file, then leaves the repo ready for bin/bootstrap.sh.
#
#   ./bin/init-template.sh <github-owner> <repo-name>
#   ./bin/init-template.sh jdoe work-trek
#
# Placeholders replaced (documented in README.md):
#   {{GITHUB_OWNER}}        your GitHub user or org  (e.g. jdoe)
#   {{CONTROL_PLANE_REPO}}  this repository's name   (e.g. work-trek)
#
# With no arguments, both values are derived from `git remote get-url origin`.
# Idempotent: running it again after substitution changes nothing.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/.." && pwd)"

if ! command -v git >/dev/null 2>&1; then
  echo 'git is required to identify the tracked files to update.' >&2
  exit 1
fi
if ! git -C "$root" ls-files >/dev/null 2>&1; then
  echo "could not list tracked files under $root; run this script from a Git clone." >&2
  exit 1
fi

owner="${1:-}"
name="${2:-}"

if [ -z "$owner" ] || [ -z "$name" ]; then
  url="$(git -C "$root" remote get-url origin 2>/dev/null || true)"
  if [ -n "$url" ]; then
    slug="$(printf '%s' "$url" | sed -E 's#^(git@[^:]+:|https?://[^/]+/)##; s#\.git$##')"
    owner="${owner:-${slug%%/*}}"
    name="${name:-${slug##*/}}"
  fi
fi

if [ -z "$owner" ] || [ -z "$name" ]; then
  echo 'usage: ./bin/init-template.sh <github-owner> <repo-name>' >&2
  echo '(or add an origin remote first and run it with no arguments)' >&2
  exit 2
fi

case "$owner$name" in *[!A-Za-z0-9._-]*) echo "owner/name may only contain [A-Za-z0-9._-]" >&2; exit 2 ;; esac

# Patterns are assembled at runtime so this script survives its own substitution pass.
ph_owner='{{''GITHUB_OWNER''}}'
ph_repo='{{''CONTROL_PLANE_REPO''}}'

echo "Replacing $ph_owner -> $owner and $ph_repo -> $name across tracked files..."

changed=0
while IFS= read -r f; do
  case "$f" in bin/init-template.sh|bin/init-template.ps1) continue ;; esac
  if grep -qF -e "$ph_owner" -e "$ph_repo" "$root/$f" 2>/dev/null; then
    sed -i.bak "s|$ph_owner|$owner|g; s|$ph_repo|$name|g" "$root/$f"
    rm -f "$root/$f.bak"
    changed=$((changed + 1))
    echo "  $f"
  fi
done < <(git -C "$root" ls-files)

echo "Done: $changed file(s) updated."
echo "Review with 'git diff', commit, then run ./bin/bootstrap.sh (or bootstrap.ps1)."
