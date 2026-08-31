#!/usr/bin/env pwsh
# One-off template initialiser: replaces the Work Trek placeholders with your values
# across every tracked file, then leaves the repo ready for bin/bootstrap.ps1.
#
#   ./bin/init-template.ps1 -Owner <github-owner> -Name <repo-name>
#   ./bin/init-template.ps1 -Owner jdoe -Name work-trek
#
# Placeholders replaced (documented in README.md):
#   {{GITHUB_OWNER}}        your GitHub user or org  (e.g. jdoe)
#   {{CONTROL_PLANE_REPO}}  this repository's name   (e.g. work-trek)
#
# With no arguments, both values are derived from `git remote get-url origin`.
# Idempotent: running it again after substitution changes nothing.
#Requires -Version 7
[CmdletBinding()]
param(
    [string] $Owner,
    [string] $Name
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host 'git is required to identify the tracked files to update.' -ForegroundColor Red
    exit 1
}

if (-not $Owner -or -not $Name) {
    $url = git -C $root remote get-url origin 2>$null
    if ($url) {
        $slug = $url -replace '^(git@[^:]+:|https?://[^/]+/)', '' -replace '\.git$', ''
        if (-not $Owner) { $Owner = ($slug -split '/')[0] }
        if (-not $Name)  { $Name  = ($slug -split '/')[-1] }
    }
}
if (-not $Owner -or -not $Name) {
    Write-Host 'usage: ./bin/init-template.ps1 -Owner <github-owner> -Name <repo-name>' -ForegroundColor Red
    Write-Host '(or add an origin remote first and run it with no arguments)'
    exit 2
}
if ("$Owner$Name" -notmatch '^[A-Za-z0-9._-]+$') {
    Write-Host 'owner/name may only contain [A-Za-z0-9._-]' -ForegroundColor Red
    exit 2
}

# Patterns are assembled at runtime so this script survives its own substitution pass.
$phOwner = '{{' + 'GITHUB_OWNER' + '}}'
$phRepo  = '{{' + 'CONTROL_PLANE_REPO' + '}}'

Write-Host "Replacing $phOwner -> $Owner and $phRepo -> $Name across tracked files..."

$trackedFiles = @(& git -C $root ls-files)
if ($LASTEXITCODE -ne 0) {
    Write-Host "could not list tracked files under $root; run this script from a Git clone." -ForegroundColor Red
    exit 1
}

$changed = 0
foreach ($f in $trackedFiles) {
    if ($f -in @('bin/init-template.sh', 'bin/init-template.ps1')) { continue }
    $path = Join-Path $root $f
    if (-not (Test-Path $path)) { continue }
    $text = [System.IO.File]::ReadAllText($path)
    if ($text.Contains($phOwner) -or $text.Contains($phRepo)) {
        $text = $text.Replace($phOwner, $Owner).Replace($phRepo, $Name)
        [System.IO.File]::WriteAllText($path, $text)   # no BOM, preserves LF
        $changed++
        Write-Host "  $f"
    }
}

Write-Host "Done: $changed file(s) updated."
Write-Host "Review with 'git diff', commit, then run ./bin/bootstrap.ps1."
