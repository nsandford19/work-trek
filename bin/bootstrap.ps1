#!/usr/bin/env pwsh
<#
.SYNOPSIS
Bootstrap Work Trek on this machine — the guided onboarding walkthrough.

.DESCRIPTION
The single setup entry point. Walks the whole onboarding process on Windows, Linux, and
macOS: detects unsubstituted template placeholders and offers the one-off init-template
substitution (deriving the values from the origin remote), verifies required and
optional tools and offers to install anything missing (winget on Windows, apt/dnf/brew
elsewhere), offers gh auth login, resolves machine identity and offers to register the
machine if it is unknown, validates the repository, checks the canonical labels and offers
`mc labels sync`, offers the qmd memory-search setup, offers `mc onboard` to plant the
global agent pointers, and offers `mc statusline` to install the shared Claude Code
status line.

Idempotent and ask-first: every step probes current state before acting, and every install
or write is a per-item [y/N] prompt. The repo files it can write are machines/<id>.yaml
and — only when you accept the placeholder prompt on a fresh template clone — the one-off
init-template substitution across tracked files. Outside the repo, step 6 can write the qmd
bun-runtime marker and — when you accept the prompt — a QMD_FORCE_CPU export into your shell
rc file (a User-scope variable on Windows), both as replaceable marker blocks. With
-NonInteractive nothing is installed or written — it only reports. Safe to re-run any time.

.EXAMPLE
./bin/bootstrap.ps1
./bin/bootstrap.ps1 -MachineId laptop-01
#>
[CmdletBinding()]
param(
    # Register (or resolve) under this id instead of the hostname.
    [string] $MachineId,
    # Do not prompt; report and exit. Useful in CI or a quick check.
    [switch] $NonInteractive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# $IsWindows/$IsLinux do not exist in Windows PowerShell 5.1, where strict mode turns
# them into hard errors. Fail early with a useful message instead.
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host 'bootstrap requires PowerShell 7+ (pwsh). Install: winget install Microsoft.PowerShell' -ForegroundColor Red
    exit 1
}

$RepoRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $PSScriptRoot 'lib/Mc.Yaml.psm1') -Force

# WSL shares the Windows host's name but is a different environment with different paths;
# machine identity there is '<hostname>-wsl' by convention (machines/README.md).
$IsWsl = $IsLinux -and ($env:WSL_DISTRO_NAME -or
    ((Test-Path '/proc/version') -and ((Get-Content '/proc/version' -Raw) -match '(?i)microsoft')))

function Say  { param($T) Write-Host $T }
function Head { param($T) Write-Host ''; Write-Host "== $T" -ForegroundColor Cyan }
function Ok   { param($T) Write-Host "  ok    $T" -ForegroundColor Green }
function Warn { param($T) Write-Host "  warn  $T" -ForegroundColor Yellow }
function Bad  { param($T) Write-Host "  FAIL  $T" -ForegroundColor Red }
function Note { param($T) Write-Host "        $T" -ForegroundColor DarkGray }

Write-Host ''
Write-Host 'Work Trek - bootstrap' -ForegroundColor White
Note $RepoRoot

# --------------------------------------------------------------- 0. Template placeholders
# A fresh "Use this template" clone still carries the GITHUB_OWNER / CONTROL_PLANE_REPO
# placeholders. Offer the one-off substitution here (bin/init-template.ps1), deriving the
# values from the origin remote, instead of refusing and sending the operator away.
# Already-substituted clones skip this silently. (Patterns assembled at runtime so this
# check does not match itself after substitution; rewriting the running script is safe
# because pwsh parses the whole file before execution.)
$phOwner = '{{' + 'GITHUB_OWNER' + '}}'
$phRepo  = '{{' + 'CONTROL_PLANE_REPO' + '}}'
$agentsFile = Join-Path $RepoRoot 'AGENTS.md'
if ((Test-Path $agentsFile) -and ([System.IO.File]::ReadAllText($agentsFile).Contains($phOwner))) {
    Head '0. Template placeholders'
    Warn "this clone still contains template placeholders ($phOwner, $phRepo)"

    $tplOwner = $null; $tplName = $null
    $originUrl = if (Get-Command git -ErrorAction SilentlyContinue) {
        (& git -C $RepoRoot remote get-url origin 2>$null)
    }
    else { $null }
    if ($originUrl -and "$originUrl" -match '[:/]([^/:]+)/([^/]+?)(\.git)?/?$') {
        $tplOwner = $Matches[1]; $tplName = $Matches[2]
    }

    if ($NonInteractive) {
        if ($tplOwner) { Note "origin suggests: $tplOwner/$tplName" }
        Note 'Fill them in with:  ./bin/init-template.ps1   (derives the values from origin)'
        Note 'Continuing with the steps that work before substitution.'
    }
    else {
        if ($tplOwner) { Note "derived from origin: $tplOwner/$tplName" }
        else {
            Note 'no origin remote to derive the values from - enter them (blank to skip):'
            $tplOwner = Read-Host '  GitHub owner (user or org)'
            if ($tplOwner) { $tplName = Read-Host '  repository name' }
        }
        if ($tplOwner -and $tplName) {
            $answer = Read-Host "  Replace the placeholders with '$tplOwner/$tplName' now (runs bin/init-template.ps1)? [y/N]"
            if ($answer -match '^(y|yes)$') {
                & (Join-Path $PSScriptRoot 'init-template.ps1') -Owner $tplOwner -Name $tplName
                if ($LASTEXITCODE -eq 0) {
                    Ok "placeholders replaced with $tplOwner/$tplName"
                    Note 'Review with `git diff`, then commit the substitution.'
                }
                else { Warn 'init-template did not complete - see output above' }
            }
            else { Note 'Skipped. Later:  ./bin/init-template.ps1' }
        }
        else { Note 'Skipped. Later:  ./bin/init-template.ps1 -Owner <github-owner> -Name <repo-name>' }
    }
}

# ---------------------------------------------------------------------------- 1. Tools
Head '1. Required tools'

# One OS package manager, detected once. Every install below is a per-tool [y/N] prompt;
# -NonInteractive keeps the old report-only behaviour.
$pkgMgr =
    if ($IsWindows -and (Get-Command winget -ErrorAction SilentlyContinue)) { 'winget' }
    elseif (Get-Command apt-get -ErrorAction SilentlyContinue) { 'apt' }
    elseif (Get-Command dnf -ErrorAction SilentlyContinue) { 'dnf' }
    elseif (Get-Command brew -ErrorAction SilentlyContinue) { 'brew' }
    else { $null }

# Tool -> package per manager. $null means no plain package there (e.g. code on apt needs
# Microsoft's repo) - bootstrap then leaves the manual hint, as before. Check is the
# command probed with Get-Command; it differs from Name when the package puts something
# other than a same-named binary on PATH.
$toolCatalog = @(
    [pscustomobject]@{ Name = 'git';  Check = 'git';  Required = $true;  winget = 'Git.Git';                    apt = 'git';     dnf = 'git';     brew = 'git' }
    [pscustomobject]@{ Name = 'gh';   Check = 'gh';   Required = $true;  winget = 'GitHub.cli';                 apt = 'gh';      dnf = 'gh';      brew = 'gh' }
    [pscustomobject]@{ Name = 'rg';   Check = 'rg';   Required = $false; winget = 'BurntSushi.ripgrep.MSVC';    apt = 'ripgrep'; dnf = 'ripgrep'; brew = 'ripgrep' }
    [pscustomobject]@{ Name = 'jq';   Check = 'jq';   Required = $false; winget = 'jqlang.jq';                  apt = 'jq';      dnf = 'jq';      brew = 'jq' }
    [pscustomobject]@{ Name = 'code'; Check = 'code'; Required = $false; winget = 'Microsoft.VisualStudioCode'; apt = $null;     dnf = $null;     brew = 'visual-studio-code' }
)
if ($IsWindows) {
    # Microsoft's GNU-style coreutils for pwsh text/stream work (agent/PREFERENCES.md,
    # Environment). The package's own coreutils.exe is NOT on PATH - the individual exes
    # in bin\ are - and generic names like sha256sum also exist in Git's usr\bin, so
    # probe coreutils-manager, which only this package ships. Linux/macOS ship coreutils
    # natively.
    # Required on Windows: Git Bash, Cygwin and MSYS2 are off-limits for scripting here, so
    # coreutils is the only sanctioned way to get head/tail/wc/cut/sort/uniq/tr/sha256sum
    # behaviour in pwsh. A Windows box without it silently pushes work back to Git Bash.
    # Missing coreutils does NOT hard-stop bootstrap (the rest of setup still works) - it
    # ends the run with a loud warning instead; see the final block of this script.
    $toolCatalog += [pscustomobject]@{ Name = 'coreutils'; Check = 'coreutils-manager'; Required = $true; winget = 'Microsoft.Coreutils'; apt = $null; dnf = $null; brew = $null }
}

$script:aptUpdated = $false
function Install-McTool {
    # Runs the package-manager install for one catalog entry; $true when the tool
    # answers Get-Command afterwards.
    param($Tool)
    $pkg = $Tool.$pkgMgr
    switch ($pkgMgr) {
        'winget' { & winget install --id $pkg --exact --accept-source-agreements --accept-package-agreements }
        'apt'    {
            if (-not $script:aptUpdated) { & sudo apt-get update; $script:aptUpdated = $true }
            & sudo apt-get install -y $pkg
        }
        'dnf'    { & sudo dnf install -y $pkg }
        'brew'   {
            if ($Tool.Name -eq 'code') { & brew install --cask $pkg } else { & brew install $pkg }
        }
    }
    if ($LASTEXITCODE -ne 0) { return $false }
    # winget updates the registry PATH, not this process's - re-read it so the freshly
    # installed tool is visible without opening a new shell.
    if ($pkgMgr -eq 'winget') {
        $env:Path = @(
            [Environment]::GetEnvironmentVariable('Path', 'Machine'),
            [Environment]::GetEnvironmentVariable('Path', 'User')
        ) -join [IO.Path]::PathSeparator
    }
    [bool](Get-Command $Tool.Check -ErrorAction SilentlyContinue)
}

$missingTools = @()
foreach ($t in $toolCatalog) {
    if (Get-Command $t.Check -ErrorAction SilentlyContinue) {
        if ($t.Required) { Ok "$($t.Name) - $((& $t.Check --version 2>&1 | Select-Object -First 1))" }
        else { Ok "$($t.Name) (optional)" }
    }
    elseif ($t.Required) { Bad "$($t.Name) not found"; $missingTools += $t }
    else { Warn "$($t.Name) not found (optional but useful)"; $missingTools += $t }
}
Ok "PowerShell $($PSVersionTable.PSVersion)"
if (Get-Command qmd -ErrorAction SilentlyContinue) { Ok 'qmd (optional - memory search)' }
else { Warn 'qmd not found (optional - semantic memory search, ADR 0004)' }

if ($missingTools.Count -gt 0 -and $pkgMgr -and -not $NonInteractive) {
    Say ''
    Note "$pkgMgr is available - bootstrap can install the missing tools (one prompt per tool)."
    foreach ($t in $missingTools) {
        $pkg = $t.$pkgMgr
        if (-not $pkg) { Note "$($t.Name): no plain $pkgMgr package - install by hand (hints below or docs/onboarding.html)"; continue }
        $kind = if ($t.Required) { 'required' } else { 'optional' }
        $answer = Read-Host "  Install $kind tool '$($t.Name)' via $pkgMgr ($pkg)? [y/N]"
        if ($answer -match '^(y|yes)$') {
            if (Install-McTool $t) { Ok "$($t.Name) installed" }
            else {
                Warn "$($t.Name): install did not complete (or a new shell is needed for PATH)"
                if ($t.Name -eq 'gh' -and $pkgMgr -in @('apt', 'dnf')) {
                    Note 'gh may need the official repo: https://github.com/cli/cli/blob/trunk/docs/install_linux.md'
                }
            }
        }
    }
}

$stillMissing = @($toolCatalog | Where-Object { $_.Required -and -not (Get-Command $_.Check -ErrorAction SilentlyContinue) })
# coreutils is required in policy but must not block the rest of setup - it leaves the
# hard gate here and triggers the loud closing warning at the end of the script instead.
$CoreutilsMissing = [bool]($stillMissing | Where-Object { $_.Name -eq 'coreutils' })
$stillMissing = @($stillMissing | Where-Object { $_.Name -ne 'coreutils' })
if ($stillMissing.Count -gt 0) {
    Write-Host ''
    Bad 'Install the missing required tools, then re-run.'
    if (-not $pkgMgr) { Note 'No supported package manager found (winget / apt-get / dnf / brew).' }
    Note 'Windows:  winget install Git.Git; winget install GitHub.cli; winget install Microsoft.Coreutils'
    Note 'Debian:   sudo apt-get install -y git gh'
    Note 'macOS:    brew install git gh'
    exit 1
}

# ----------------------------------------------------------------------------- 2. Auth
Head '2. GitHub authentication'
$null = & gh auth status 2>&1
if ($LASTEXITCODE -eq 0) {
    Ok 'gh is authenticated'
    Note 'Projects scope is not needed - labels are canonical (ADR 0002).'
}
else {
    Warn 'gh is not authenticated'
    Note 'Durable memory works offline; only live issue state needs auth.'
    $didLogin = $false
    if (-not $NonInteractive) {
        $answer = Read-Host '  Run gh auth login now? [y/N]'
        if ($answer -match '^(y|yes)$') {
            & gh auth login
            if ($LASTEXITCODE -eq 0) { Ok 'gh is authenticated'; $didLogin = $true }
            else { Warn 'gh auth login did not complete' }
        }
    }
    if (-not $didLogin) { Note 'Run:  gh auth login' }
}

# -------------------------------------------------------------------- 3. Machine identity
Head '3. Machine identity'
$hostName = [System.Net.Dns]::GetHostName()
$identityOverride = if ($MachineId) { $MachineId } elseif ($env:MC_MACHINE) { $env:MC_MACHINE } else { $null }
$wantId = if ($identityOverride) { $identityOverride } elseif ($IsWsl) { "$hostName-wsl" } else { $hostName }
Note "hostname: $hostName"
if ($IsWsl) { Note "WSL detected ($($env:WSL_DISTRO_NAME)) - this environment registers separately as '$wantId'" }
if ($env:MC_MACHINE) { Note "MC_MACHINE: $($env:MC_MACHINE)" }

# Machine ids become filenames and branch-name components during registration. Refuse
# separators, traversal names, shell metacharacters, and Windows device names before the
# value reaches any filesystem or git command.
$machineIdValid = $wantId -match '^[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?$' -and
    $wantId -notmatch '^(?i:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)'
if (-not $machineIdValid) {
    Bad "machine id '$wantId' is not safe"
    Note 'Use letters, digits, dot, underscore, or hyphen; begin and end with a letter or digit.'
    exit 2
}

$machineDir = Join-Path $RepoRoot 'machines'
$registered = @()
foreach ($f in Get-ChildItem -Path $machineDir -Filter '*.yaml' -File) {
    try {
        $y = Import-McYaml -Path $f.FullName
        $names = @($y['id'])
        foreach ($k in @('aliases', 'hostnames')) {
            if ($y.Contains($k) -and $y[$k]) { $names += @($y[$k]) }
        }
        $registered += [pscustomobject]@{ Id = $y['id']; Names = $names; Data = $y }
    }
    catch { Bad "machines/$($f.Name): $($_.Exception.Message)" }
}

$resolved = $null
if ($identityOverride) {
    $source = if ($MachineId) { '-MachineId' } else { 'MC_MACHINE' }
    $resolved = $registered | Where-Object { $_.Id -eq $identityOverride } | Select-Object -First 1
    if (-not $resolved) {
        Warn "$source=$identityOverride is not registered; hostname fallback is disabled because an explicit identity was supplied"
    }
}
else {
    # In WSL prefer the dedicated '-wsl' registration; the bare hostname would resolve to
    # the Windows entry, whose paths do not exist inside WSL.
    $candidates = if ($IsWsl) { @("$hostName-wsl", $hostName) } else { @($hostName) }
    foreach ($cand in $candidates) {
        $resolved = $registered |
            Where-Object { $_.Names | Where-Object { $_ -and ([string]$_).ToLower() -eq $cand.ToLower() } } |
            Select-Object -First 1
        if ($resolved) {
            # A bare-hostname hit on the Windows entry is not an answer inside WSL
            # (machines/README.md): stay unresolved so the registration offer below
            # fires for '<hostname>-wsl'.
            if ($IsWsl -and $cand -eq $hostName -and $resolved.Data['os'] -eq 'windows') {
                Warn "bare hostname matches '$($resolved.Id)', the WINDOWS registration - its paths do not exist in WSL"
                $resolved = $null
                continue
            }
            break
        }
    }
}

if ($resolved) {
    Ok "this machine is registered as '$($resolved.Id)'"
}
else {
    Warn "this machine is not registered"
    # $registered.Id would be a strict-mode error when no machine is registered yet -
    # exactly the state of a fresh template clone.
    $knownIds = @($registered | ForEach-Object { $_.Id })
    Note ('known machines: {0}' -f $(if ($knownIds) { $knownIds -join ', ' } else { 'none' }))

    $doIt = $false
    if (-not $NonInteractive) {
        $answer = Read-Host "  Register this machine as '$wantId'? [y/N]"
        $doIt = $answer -match '^(y|yes)$'
    }

    if ($doIt) {
        $os = if ($IsWindows) { 'windows' } elseif ($IsLinux) { 'linux' } elseif ($IsMacOS) { 'macos' } else { 'linux' }
        $osDetail = try {
            if ($IsWindows) { (Get-CimInstance Win32_OperatingSystem).Caption } else { (& uname -sr) }
        } catch { [System.Environment]::OSVersion.VersionString }

        $role = Read-Host '  One-line role (e.g. laptop, primary workstation)'
        if (-not $role) { $role = 'unspecified' }
        $rootsRaw = Read-Host '  Dev root(s) where source repos live, comma-separated (blank to skip)'
        $roots = @()
        if ($rootsRaw) {
            $roots = @($rootsRaw -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        }

        $today = (Get-Date -Format 'yyyy-MM-dd')
        $tools = @('git', 'gh', 'rg', 'code', 'docker', 'kubectl', 'node', 'python', 'dotnet') |
            Where-Object { Get-Command $_ -ErrorAction SilentlyContinue }

        $yamlQuote = {
            param($Value)
            "'$(([string]$Value).Replace("'", "''"))'"
        }

        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendLine('# Machine registry entry. Schema: machines/README.md')
        [void]$sb.AppendLine("# Registered by bin/bootstrap.ps1 on $today.")
        [void]$sb.AppendLine("id: $(& $yamlQuote $wantId)")
        [void]$sb.AppendLine('aliases: []')
        # A WSL entry must NOT list the bare hostname: the Windows registration owns it,
        # and resolution inside WSL probes '<hostname>-wsl' by itself (machines/README.md).
        $registryHostName = if ($IsWsl) { $wantId } else { $hostName }
        [void]$sb.AppendLine("hostnames: [$(& $yamlQuote $registryHostName)]")
        [void]$sb.AppendLine("os: $os")
        [void]$sb.AppendLine("os_detail: $(& $yamlQuote $osDetail)")
        [void]$sb.AppendLine("role: $(& $yamlQuote $role)")
        [void]$sb.AppendLine('status: active')
        [void]$sb.AppendLine("last_verified: $today")
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine("shells: [$(if ($IsWindows) { 'powershell, bash' } else { 'bash, powershell' })]")
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('# Only these roots are scanned by `mc repo scan`. Keep the list short.')
        if ($roots.Count -gt 0) {
            [void]$sb.AppendLine('dev_roots:')
            foreach ($r in $roots) { [void]$sb.AppendLine("  - '$($r.Replace("'", "''"))'") }
        }
        else { [void]$sb.AppendLine('dev_roots: []') }
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine("tools: [$($tools -join ', ')]")
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('# MACHINE SCOPE - highest precedence. Only rules true *because of this machine*.')
        [void]$sb.AppendLine('constraints: []')
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('notes: []')

        $outPath = Join-Path $machineDir "$wantId.yaml"
        [System.IO.File]::WriteAllText($outPath, ($sb.ToString() -replace "`r`n", "`n"))
        Ok "wrote machines/$wantId.yaml"

        # Best-effort: append the row to the 'Registered machines' table so the change is
        # complete. If the table is not where this expects, the manual note still covers it.
        $readmePath = Join-Path $machineDir 'README.md'
        $rowAdded = $false
        try {
            $readme = [System.IO.File]::ReadAllText($readmePath)
            $rows = [regex]::Matches($readme, '(?m)^\|\s*\[`[^`]+`\]\([^)]+\.yaml\)[^\r\n]*$')
            if ($rows.Count -gt 0) {
                $lastRow = $rows[$rows.Count - 1]
                $rowNotes = if ($roots.Count -gt 0) { 'Repos under `{0}`' -f $roots[0] } else { '' }
                $row = '| [`{0}`]({0}.yaml) | {1} | {2} | {3} |' -f $wantId, $osDetail, $role, $rowNotes
                $readme = $readme.Insert($lastRow.Index + $lastRow.Length, "`n$row")
                [System.IO.File]::WriteAllText($readmePath, $readme)
                Ok 'added the row to machines/README.md'
                $rowAdded = $true
            }
        }
        catch { }
        if (-not $rowAdded) { Warn 'could not update machines/README.md - add the table row by hand' }

        # Land it the standard way: a new branch, one commit, push, PR - never straight to
        # main. Declining (or -NonInteractive) leaves the files in place with instructions.
        $doPr = $false
        if (-not $NonInteractive) {
            $answer = Read-Host "  Commit on a new branch and open a PR now? [y/N]"
            $doPr = $answer -match '^(y|yes)$'
        }

        $branch = "chore/register-$wantId"
        $landed = $false
        if ($doPr) {
            Push-Location $RepoRoot
            try {
                $prevBranch = (& git rev-parse --abbrev-ref HEAD)
                $null = & git rev-parse --verify --quiet $branch
                if ($LASTEXITCODE -eq 0) {
                    Warn "branch '$branch' already exists - not touching it; commit by hand instead"
                }
                else {
                    & git switch -c $branch
                    if ($LASTEXITCODE -ne 0) {
                        # Never fall through to committing on the current branch.
                        Warn "could not create branch '$branch' - nothing committed"
                    }
                    else {
                        & git add -- "machines/$wantId.yaml" 'machines/README.md'
                        & git commit -m "chore(registry): register $wantId"
                        if ($LASTEXITCODE -ne 0) { Warn 'commit failed - see output above; the files are still in the worktree' }
                        else {
                            $landed = $true
                            & git push -u origin $branch
                            if ($LASTEXITCODE -ne 0) {
                                Warn 'push failed - the commit remains on the local branch'
                                Note "retry with:  git push -u origin $branch && gh pr create -R nsandford19/work-trek --fill"
                            }
                            else {
                                $prOut = & gh pr create --head $branch --title "chore(registry): register $wantId" --body 'Generated by bin/bootstrap.ps1. Review dev_roots, constraints and the README row before merging.' 2>&1
                                if ($LASTEXITCODE -eq 0) { Ok "PR opened: $(@($prOut) | Select-Object -Last 1)" }
                                else { Warn "PR creation failed: $prOut"; Note 'open it by hand:  gh pr create -R nsandford19/work-trek --fill' }
                            }
                            Note "you are on '$branch' now (was '$prevBranch'), so the new entry stays usable locally."
                            Note "after the PR merges:  git switch $prevBranch && git pull"
                        }
                    }
                }
            }
            finally { Pop-Location }
        }
        if (-not $landed) {
            Note 'Review the files, then commit on a branch:'
            Note "  git switch -c $branch"
            Note "  git add machines/$wantId.yaml machines/README.md"
            Note "  git commit -m 'chore(registry): register $wantId'"
            Note "  git push -u origin $branch && gh pr create -R nsandford19/work-trek --fill"
        }
    }
    else {
        Note 'Not registered. Two options:'
        Note "  permanent machine  ->  re-run and answer y, or copy machines/example-laptop.yaml.example"
        Note "  temporary machine  ->  `$env:MC_MACHINE = '<an existing id>'"
    }
}

# -------------------------------------------------------------------------- 4. Validate
Head '4. Repository validation'
& (Join-Path $PSScriptRoot 'mc.ps1') validate
$validateFailed = $LASTEXITCODE -ne 0

# ------------------------------------------------------ helpers shared by steps 5-8

# Run a native command and capture its output and exit code without letting stderr
# turn into a terminating error under $ErrorActionPreference = 'Stop'.
function Invoke-Native {
    param([string] $Exe, [string[]] $Arguments)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & $Exe @Arguments 2>&1 | ForEach-Object { "$_" }
        [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = @($out) }
    }
    finally { $ErrorActionPreference = $prev }
}

# Persist an environment variable for future shells and set it for this process, so anything
# later in this run already sees it. Windows gets a real User-scope variable; elsewhere a
# marker-delimited block in the login shell's rc file, replaced in place on re-run (the same
# idempotent shape as `mc onboard`). Returns where it wrote, for the caller to report.
function Set-PersistentEnv {
    param([Parameter(Mandatory)][string] $Name, [Parameter(Mandatory)][string] $Value)

    [Environment]::SetEnvironmentVariable($Name, $Value)
    if ($IsWindows) {
        [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
        return 'the Windows User environment'
    }

    $rc = switch -Regex ($env:SHELL) {
        'zsh'   { Join-Path $HOME '.zshrc';  break }
        'bash'  { Join-Path $HOME '.bashrc'; break }
        default { Join-Path $HOME '.profile' }
    }
    $begin = "# work-trek:env:${Name}:begin"
    $end   = "# work-trek:env:${Name}:end"
    $block = @($begin, "export $Name=$Value", $end) -join "`n"

    $existing = if (Test-Path $rc) { [IO.File]::ReadAllText($rc) } else { '' }
    $bi = $existing.IndexOf($begin)
    $ei = $existing.IndexOf($end)
    $new = if ($bi -ge 0 -and $ei -gt $bi) {
        $existing.Substring(0, $bi) + $block + $existing.Substring($ei + $end.Length)
    }
    else {
        ($existing.TrimEnd() + "`n`n" + $block + "`n").TrimStart("`n")
    }
    [IO.File]::WriteAllText($rc, $new)
    $rc
}

# Compare two filesystem paths as the OS would: resolved, separator-normalised, and
# case-insensitive only on Windows.
function Test-SamePath {
    param([string] $A, [string] $B)
    if (-not $A -or -not $B) { return $false }
    $norm = {
        param($p)
        try { $p = (Resolve-Path -LiteralPath $p -ErrorAction Stop).ProviderPath } catch { }
        ([IO.Path]::GetFullPath($p)).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    }
    $cmp = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    [string]::Equals((& $norm $A), (& $norm $B), $cmp)
}

# Two paths belong to the same repository when they share a git common directory - which is
# exactly what distinguishes a linked worktree from an unrelated second clone.
function Test-SameGitRepo {
    param([string] $A, [string] $B)
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $false }
    $common = {
        param($p)
        if (-not (Test-Path $p)) { return $null }
        $r = Invoke-Native 'git' @('-C', $p, 'rev-parse', '--path-format=absolute', '--git-common-dir')
        if ($r.ExitCode -ne 0) { return $null }
        @($r.Output | Where-Object { $_ -match '\S' })[0]
    }
    $ca = & $common $A
    $cb = & $common $B
    if (-not $ca -or -not $cb) { return $false }
    Test-SamePath $ca $cb
}

# Ask an mc subcommand what it *would* do, so bootstrap can report state instead of
# prompting for work that is already done. Both onboard and statusline support --dry-run.
$McScript = Join-Path $PSScriptRoot 'mc.ps1'
function Invoke-McDryRun {
    param([string] $Command)
    Invoke-Native 'pwsh' @('-NoProfile', '-File', $McScript, $Command, '--dry-run')
}

# ------------------------------------------------------------------ 5. Label taxonomy
# .github/labels.yml is the canonical label list (ADR 0002). Check what the repository
# already has before offering to push: a clone whose labels all exist re-runs to a quiet
# ok. The check compares names only - cheap and enough to tell "set up" from "not yet";
# `mc labels sync` is idempotent (--force), so re-applying is always safe.
Head '5. Label taxonomy'
$wantLabels = @()
try { $wantLabels = @(Import-McYaml -Path (Join-Path $RepoRoot '.github/labels.yml')) } catch { }
$null = & gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Warn 'gh is not authenticated - skipped'
    Note 'Later:  ./bin/mc.ps1 labels sync'
}
elseif ($wantLabels.Count -eq 0) {
    Warn 'could not read .github/labels.yml - skipped'
}
else {
    # gh resolves its repository from the caller's cwd - pin to the repo root.
    $haveLabels = $null
    Push-Location $RepoRoot
    try {
        $ghLabels = Invoke-Native 'gh' @('label', 'list', '--limit', '200', '--json', 'name')
        if ($ghLabels.ExitCode -eq 0) {
            try { $haveLabels = @((($ghLabels.Output -join "`n") | ConvertFrom-Json).name) } catch { }
        }
    }
    finally { Pop-Location }

    if ($null -eq $haveLabels) {
        Warn 'could not list the repository labels (no origin remote, or no access)'
        Note 'Later:  ./bin/mc.ps1 labels sync'
    }
    else {
        $missingLabels = @($wantLabels | Where-Object { $_['name'] -notin $haveLabels })
        if ($missingLabels.Count -eq 0) {
            Ok ('all {0} canonical labels exist on the repository' -f $wantLabels.Count)
            Note 'Names only are compared; re-apply colors/descriptions any time:  ./bin/mc.ps1 labels sync'
        }
        elseif ($NonInteractive) {
            Note ('{0} of {1} canonical label(s) missing - run:  ./bin/mc.ps1 labels sync' -f
                $missingLabels.Count, $wantLabels.Count)
        }
        else {
            Warn ('{0} of {1} canonical label(s) missing (e.g. {2})' -f
                $missingLabels.Count, $wantLabels.Count, $missingLabels[0]['name'])
            $answer = Read-Host '  Apply .github/labels.yml to the repository now (mc labels sync)? [y/N]'
            if ($answer -match '^(y|yes)$') { & $McScript labels sync }
            else { Note 'Later:  ./bin/mc.ps1 labels sync' }
        }
    }
}

# --------------------------------------------------------------- 6. Memory search (qmd)
# qmd (github.com/tobi/qmd) is the primary retrieval driver over durable memory
# (ADR 0004): local BM25 + vector search, index in ~/.cache/qmd, nothing committed.
# Optional, like everything in bin/ - rg remains the universal fallback.

# Bun is the preferred runtime (ADR 0004). Under bun, qmd uses the built-in bun:sqlite and
# never loads better-sqlite3 - the NAN addon whose NODE_MODULE_VERSION pins it to one Node
# major. The bun global install directory is the same shape on every platform.
$BunHome = if ($env:BUN_INSTALL) { $env:BUN_INSTALL } else { Join-Path $HOME '.bun' }
$BunQmdDir = Join-Path $BunHome 'install/global/node_modules/@tobilu/qmd'

# qmd's bin/qmd launcher picks its runtime from the lockfile in the package directory:
# bun.lock -> bun, package-lock.json -> node, neither -> node. `bun install -g` writes its
# lockfile at the global root, not in the package, so a bun install still runs under node
# until this marker exists. Rewritten after every upgrade, which is why we check for it.
$BunLockMarker = @'
// Marker only - not a real dependency lockfile.
//
// qmd's bin/qmd launcher picks its runtime from the lockfile in THIS directory:
// bun.lock -> bun, package-lock.json -> node, neither -> node. `bun install -g` writes its
// lockfile at the global root instead, so without this file qmd runs under node and loads
// better-sqlite3, a NAN addon pinned to one NODE_MODULE_VERSION that breaks on the next
// Node major upgrade. With this file qmd runs under bun and uses bun:sqlite - no Node ABI.
//
// `bun install -g @tobilu/qmd` replaces the package directory and deletes this file.
// bin/bootstrap.ps1 and `mc doctor` check for it and offer to put it back.
{
  "lockfileVersion": 1,
  "workspaces": {},
  "packages": {}
}
'@

Head '6. Memory search (qmd)'
$qmdCmd = Get-Command qmd -ErrorAction SilentlyContinue
if (-not $qmdCmd) {
    Warn 'qmd not installed - agents fall back to rg keyword search (works, lower recall)'
    $hasBun = [bool](Get-Command bun -ErrorAction SilentlyContinue)
    $nodeMajor = 0
    if (Get-Command node -ErrorAction SilentlyContinue) {
        try { $nodeMajor = [int]((((& node --version) -replace '^v') -split '\.')[0]) } catch { }
    }
    if (-not $NonInteractive -and $hasBun) {
        $answer = Read-Host '  bun found - install qmd now (bun install -g @tobilu/qmd)? [y/N]'
        if ($answer -match '^(y|yes)$') {
            & bun install -g '@tobilu/qmd'
            if ($LASTEXITCODE -ne 0) { Warn 'qmd install did not complete - see output above' }
            $qmdCmd = Get-Command qmd -ErrorAction SilentlyContinue
        }
    }
    elseif (-not $NonInteractive -and $nodeMajor -ge 22 -and (Get-Command npm -ErrorAction SilentlyContinue)) {
        Note 'bun is not installed. npm works, but pins qmd to this Node major - see ADR 0004.'
        Note 'Prefer:  curl -fsSL https://bun.sh/install | bash   then re-run bootstrap'
        $answer = Read-Host "  Install qmd with npm instead (Node $nodeMajor)? [y/N]"
        if ($answer -match '^(y|yes)$') {
            & npm install -g '@tobilu/qmd'
            if ($LASTEXITCODE -ne 0) { Warn 'qmd install did not complete - see output above' }
            $qmdCmd = Get-Command qmd -ErrorAction SilentlyContinue
        }
    }
}

# A shim on PATH is not proof qmd runs: it loads a native better-sqlite3 prebuild, so an
# install made under one Node major stops working the moment fnm/nvm switches to another
# (or an old `bun install -g` copy keeps shadowing PATH). Probe it before trusting it.
$qmdHealthy = $false
if ($qmdCmd) {
    $probe = Invoke-Native 'qmd' @('--version')
    if ($probe.ExitCode -eq 0) {
        $qmdHealthy = $true
        Ok ('qmd is installed ({0})' -f (($probe.Output -join ' ').Trim()))
        Note $qmdCmd.Source
    }
    else {
        Bad 'qmd is on PATH but does not run - agents fall back to rg keyword search'
        Note $qmdCmd.Source
        # A native crash buries the useful line under a loader preamble - lift it out.
        $lines = @($probe.Output | Where-Object { $_ -match '\S' })
        $signal = @($lines | Where-Object { $_ -match 'Error|NODE_MODULE_VERSION|not found|cannot' })
        foreach ($line in @($(if ($signal) { $signal } else { $lines }) | Select-Object -First 3)) {
            Note $line.Trim()
        }
        if (@($probe.Output) -match 'NODE_MODULE_VERSION') {
            Note 'Its native better-sqlite3 was built for a different Node major. Reinstall on bun,'
            Note 'which sidesteps the Node ABI entirely, removing the node-pinned copy first:'
            Note '  npm uninstall -g @tobilu/qmd'
            Note '  bun install -g @tobilu/qmd'
            Note 'Then re-run bootstrap - it pins the launcher to bun.'
        }
    }
}

# Installed and running is not the whole story: qmd on node re-acquires the ABI coupling that
# broke it before, so report which runtime it actually uses and offer the one-file fix.
if ($qmdHealthy) {
    $doctor = Invoke-Native 'qmd' @('doctor')
    $runtime = $null
    foreach ($line in @($doctor.Output)) {
        if ($line -match '^\s*Runtime:\s*(\S+)') { $runtime = $Matches[1]; break }
    }

    if ($runtime -eq 'bun:sqlite') {
        Ok 'qmd runs on bun (bun:sqlite) - no Node ABI to break on the next Node upgrade'
    }
    elseif ($qmdCmd.Source -and $qmdCmd.Source.StartsWith($BunHome, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path $BunQmdDir)) {
        # Installed with bun, still routed to node: the launcher marker is missing.
        Warn ("qmd is a bun install but runs on {0} - a Node upgrade will break it" -f ($runtime ?? 'node'))
        if ($NonInteractive) {
            Note "Pin it to bun by creating:  $(Join-Path $BunQmdDir 'bun.lock')"
        }
        else {
            $answer = Read-Host '  Pin qmd to the bun runtime now (writes a bun.lock marker in the package)? [y/N]'
            if ($answer -match '^(y|yes)$') {
                Set-Content -LiteralPath (Join-Path $BunQmdDir 'bun.lock') -Value $BunLockMarker -Encoding utf8
                $doctor = Invoke-Native 'qmd' @('doctor')
                if (@($doctor.Output) -match 'Runtime:\s*bun:sqlite') { Ok 'qmd now runs on bun (bun:sqlite)' }
                else { Warn 'marker written but qmd still reports another runtime - see `qmd doctor`' }
            }
        }
    }
    elseif ($runtime) {
        Warn "qmd runs on $runtime - it breaks the next time this machine's Node major changes"
        Note 'Move it to bun, which uses bun:sqlite and has no Node ABI coupling:'
        Note '  npm uninstall -g @tobilu/qmd'
        Note '  bun install -g @tobilu/qmd'
        Note 'Then re-run bootstrap to pin the launcher.'
    }


    # Registration is a one-off per machine, so check rather than asking the operator to remember -
    # and check *what* it points at, not just that the name is taken. A collection left
    # pointing at an old clone path indexes files that are no longer the ones being edited.
    $registered = $false
    $collections = Invoke-Native 'qmd' @('collection', 'list')
    if ($collections.ExitCode -eq 0) {
        $registered = [bool](@($collections.Output) -match '(?m)^\s*work-trek\b')
    }
    $indexedPath = $null
    if ($registered) {
        $show = Invoke-Native 'qmd' @('collection', 'show', 'work-trek')
        foreach ($line in @($show.Output)) {
            if ($line -match '^\s*Path:\s*(.+?)\s*$') { $indexedPath = $Matches[1]; break }
        }
    }
    $sameClone = $indexedPath -and (Test-SamePath $indexedPath $RepoRoot)
    # A git worktree is a second checkout of the same repository, so a collection pointing at
    # the main clone is correct even when bootstrap runs from the worktree. Repointing it at a
    # throwaway worktree would be the actual mistake.
    $sameRepo = (-not $sameClone) -and $indexedPath -and (Test-SameGitRepo $indexedPath $RepoRoot)

    if ($registered -and $sameClone) {
        Ok 'collection work-trek is registered and indexes this clone'
    }
    elseif ($registered -and $sameRepo) {
        Ok "collection work-trek indexes $indexedPath"
        Note 'Another checkout of this same repository - left alone (this run is not in the main clone).'
    }
    elseif ($registered -and -not $indexedPath) {
        Ok 'collection work-trek is registered'
        Warn 'could not read its path from `qmd collection show` - check by hand that it indexes this clone'
    }
    elseif ($registered) {
        Warn 'collection work-trek indexes a different clone'
        Note "indexed:    $indexedPath"
        Note "this clone: $RepoRoot"
        if ($NonInteractive) {
            Note 'Repoint it with:  qmd collection remove work-trek, then add it again.'
        }
        else {
            Note 'Repointing removes the collection and re-adds it, which discards its index and'
            Note 'any embeddings for it. The Markdown is untouched; `qmd embed` rebuilds the rest.'
            $answer = Read-Host '  Repoint work-trek at this clone? [y/N]'
            if ($answer -match '^(y|yes)$') {
                & qmd collection remove work-trek
                if ($LASTEXITCODE -ne 0) { Warn 'qmd collection remove failed - see output above' }
                else {
                    & qmd collection add $RepoRoot --name work-trek
                    if ($LASTEXITCODE -ne 0) { Warn 'qmd collection add failed - see output above' }
                    else {
                        & qmd context add qmd://work-trek "personal engineering memory: decisions, knowledge, runbooks, investigations"
                        if ($LASTEXITCODE -ne 0) { Warn 'qmd context add failed - see output above' }
                        else {
                            Ok "collection work-trek now indexes $RepoRoot"
                            $doctor = Invoke-Native 'qmd' @('doctor')
                        }
                    }
                }
            }
            else { Note 'Left as it is. `qmd query` will keep returning the other clone''s copies.' }
        }
    }
    elseif ($NonInteractive) {
        Note 'collection work-trek is not registered - register this clone once:'
        Note "  qmd collection add '$RepoRoot' --name work-trek"
        Note '  qmd context add qmd://work-trek "personal engineering memory: decisions, knowledge, runbooks, investigations"'
    }
    else {
        $answer = Read-Host '  Register this clone as the work-trek collection now? [y/N]'
        if ($answer -match '^(y|yes)$') {
            & qmd collection add $RepoRoot --name work-trek
            if ($LASTEXITCODE -ne 0) {
                Warn 'qmd collection add failed - see output above'
            }
            else {
                & qmd context add qmd://work-trek "personal engineering memory: decisions, knowledge, runbooks, investigations"
                if ($LASTEXITCODE -ne 0) { Warn 'qmd context add failed - see output above' }
                else {
                    Ok 'collection work-trek registered'
                    $registered = $true
                    # The document counts below come from doctor; registering invalidated them.
                    $doctor = Invoke-Native 'qmd' @('doctor')
                }
            }
        }
        else {
            Note 'Later:'
            Note "  qmd collection add '$RepoRoot' --name work-trek"
            Note '  qmd context add qmd://work-trek "personal engineering memory: decisions, knowledge, runbooks, investigations"'
        }
    }

    # Device mode. Whether embedding takes minutes or an hour turns on this, and qmd keeps
    # warning about CPU until the choice is explicit rather than merely a fallback.
    $deviceMode = $null
    $deviceProbe = $null
    foreach ($line in @($doctor.Output)) {
        if (-not $deviceMode -and $line -match 'device mode:\s*(.+?)\s*$') { $deviceMode = $Matches[1] }
        if (-not $deviceProbe -and $line -match 'device probe:\s*(.+?)\s*$') { $deviceProbe = $Matches[1] }
    }
    # qmd appends its own "Next: ..." advice to the probe; we give our own below.
    if ($deviceProbe) { $deviceProbe = ($deviceProbe -replace '\.?\s*Next:.*$', '').TrimEnd('.', ' ') }
    $onCpu = $true

    if ($deviceMode -match 'CPU forced') {
        Ok 'device: CPU mode is already explicit (QMD_FORCE_CPU=1)'
    }
    elseif ($deviceProbe -match '^GPU\b' -and $deviceProbe -match 'offloading enabled') {
        Ok "device: $deviceProbe"
        $onCpu = $false
    }
    else {
        # No GPU, a GPU that will not offload, or a probe that could not tell. Only the first
        # is a case for forcing CPU - the others want the backend fixed - so ask when unsure.
        $noGpu = $false
        if ($deviceProbe -match 'running on CPU') {
            Warn "device: no GPU acceleration - $deviceProbe"
            $noGpu = $true
        }
        elseif ($deviceProbe -match 'offloading disabled') {
            Warn "device: a GPU is present but llama.cpp is not offloading to it - $deviceProbe"
            Note 'For the speed, fix the backend (QMD_LLAMA_GPU=metal|cuda|vulkan) rather than forcing CPU.'
        }
        else {
            Warn ('device: could not determine GPU support{0}' -f $(if ($deviceProbe) { " - $deviceProbe" } else { '' }))
        }

        if ($NonInteractive) {
            Note 'Set QMD_FORCE_CPU=1 to make CPU-only explicit, or configure a GPU backend.'
        }
        else {
            $prompt = if ($noGpu) {
                '  No GPU found - set QMD_FORCE_CPU=1 permanently? CPU is already what runs; this only makes it explicit [y/N]'
            }
            else {
                '  Treat this machine as CPU-only for qmd (set QMD_FORCE_CPU=1 permanently)? [y/N]'
            }
            $answer = Read-Host $prompt
            if ($answer -match '^(y|yes)$') {
                $where = Set-PersistentEnv 'QMD_FORCE_CPU' '1'
                Ok "device: QMD_FORCE_CPU=1 written to $where - already active here, new shells pick it up"
            }
            else { Note 'Left on auto. Later:  QMD_FORCE_CPU=1 to silence it, or QMD_LLAMA_GPU=metal|cuda|vulkan to use a GPU.' }
        }
    }

    # Embeddings are what make `qmd query` hybrid rather than BM25-only. Expensive once and
    # slow on CPU, so ask - and only when the collection exists and there is work to do.
    $pending = 0
    foreach ($line in @($doctor.Output)) {
        if ($line -match 'embedding freshness:\s*(\d+)\s+active document') { $pending = [int]$Matches[1]; break }
    }
    $modelsMissing = [bool](@($doctor.Output) -match 'model cache:\s*missing')

    if (-not $registered) {
        Note 'qmd embed        # once the collection is registered; enables `qmd query`'
    }
    elseif ($pending -le 0 -and -not $modelsMissing) {
        Ok 'embeddings are current - `qmd query` runs hybrid search'
    }
    elseif ($NonInteractive) {
        Note ('qmd embed        # {0} document(s) unembedded{1}; until then `qmd query` degrades to BM25' -f
            $pending, $(if ($modelsMissing) { ', models not downloaded (~2 GB)' } else { '' }))
    }
    else {
        Warn ('{0} document(s) have no embeddings - `qmd query` degrades to BM25 until they do' -f $pending)
        if ($modelsMissing) { Note 'First run downloads ~2 GB of local models into ~/.cache/qmd/models.' }
        if ($onCpu) { Note 'On CPU this takes a while. Skipping is safe - `qmd search` and `rg` work meanwhile.' }
        $answer = Read-Host '  Run qmd embed now? [y/N]'
        if ($answer -match '^(y|yes)$') {
            & qmd embed
            if ($LASTEXITCODE -ne 0) { Warn 'qmd embed did not finish - re-run `qmd embed` when convenient' }
            else { Ok 'embeddings built - `qmd query` now runs hybrid search' }
        }
        else { Note 'Later:  qmd embed' }
    }

    Note 'After a git pull:  qmd update'
}
elseif (-not $qmdCmd) {
    Note 'Install (bun preferred; npm + Node >= 22 works but breaks on Node upgrades):'
    Note '  bun install -g @tobilu/qmd'
    Note 'Then re-run bootstrap for the collection setup and the bun pin. Details: decisions/0004.'
}

# ----------------------------------------------------------- 7. Global agent pointers
Head '7. Global agent pointers'
# Ask onboard what it would change before asking the operator anything. A pointer block that already
# names this clone needs no prompt; one that names a different clone needs a *repoint*, and
# saying so is more useful than offering to "add" a block that is already there.
$onboardDry = Invoke-McDryRun 'onboard'
$onboardPending = @($onboardDry.Output | Where-Object { $_ -match 'would (update|append to|create) ' })
$onboardCurrent = @($onboardDry.Output | Where-Object { $_ -match 'already current' })
$onboardSkipped = @($onboardDry.Output | Where-Object { $_ -match 'not present - skipped' })

if (-not $onboardPending -and ($onboardCurrent -or $onboardSkipped)) {
    Ok ('global agent pointers are current ({0} file(s); {1} agent(s) not set up here)' -f
        $onboardCurrent.Count, $onboardSkipped.Count)
}
elseif ($NonInteractive) {
    Note ('{0} file(s) would change - run:  ./bin/mc.ps1 onboard' -f $onboardPending.Count)
    foreach ($line in $onboardPending) { Note $line.Trim() }
}
else {
    Note 'mc onboard keeps a marker-delimited Work Trek block in ~/.claude/CLAUDE.md and'
    Note '~/.codex/AGENTS.md so agents opened in OTHER repositories still find this clone.'
    Note 'Surrounding content is untouched; it asks again per file.'
    if ($onboardPending -match 'would update') {
        Note 'An existing block points somewhere else - updating it repoints those agents here.'
    }
    foreach ($line in $onboardPending) { Note $line.Trim() }
    $answer = Read-Host '  Write the Work Trek pointer block to your global agent files? [y/N]'
    if ($answer -match '^(y|yes)$') { & $McScript onboard }
    else { Note 'Later:  ./bin/mc.ps1 onboard' }
}

# --------------------------------------------------------- 8. Claude Code status line
Head '8. Claude Code status line'
$claudeDir = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.claude'
if (-not (Test-Path $claudeDir)) {
    Note "$claudeDir not present - skipped (Claude Code is not set up on this machine)"
}
else {
    # Same rule as step 7: find out what is already installed before offering to install it.
    $slDry = Invoke-McDryRun 'statusline'
    $slScriptCurrent = [bool](@($slDry.Output) -match 'script already current')
    $slSettingsCurrent = [bool](@($slDry.Output) -match 'settings\.json already points at it')
    $slPending = @($slDry.Output | Where-Object { $_ -match '^\s*would ' })

    if ($slScriptCurrent -and $slSettingsCurrent) {
        Ok 'status line is installed and settings.json points at it'
    }
    elseif ($NonInteractive) {
        Note 'not current - run:  ./bin/mc.ps1 statusline'
        foreach ($line in $slPending) { Note $line.Trim() }
    }
    else {
        Note 'mc statusline copies tooling/claude/statusline-command.sh to ~/.claude and points'
        Note 'settings.json .statusLine at it, so every machine shows the same line: model,'
        Note 'context %, directory and branch, session length, effort, and usage meters. It'
        Note 'backs up whatever it replaces and needs bash + jq.'
        if ($slScriptCurrent) { Note 'The script itself is current; settings.json is what needs pointing at it.' }
        elseif ($slPending -match 'would replace') { Note 'An older copy is installed - this replaces it (the old one is backed up).' }
        $verb = if ($slScriptCurrent -or $slPending -match 'would replace') { 'Update' } else { 'Install' }
        $answer = Read-Host "  $verb the shared Claude Code status line? [y/N]"
        if ($answer -match '^(y|yes)$') { & $McScript statusline --yes }
        else { Note 'Later:  ./bin/mc.ps1 statusline' }
    }
}

# ------------------------------------------------------------------------ 9. Next steps
Head '9. What now'
Say ''
Say '  Open this directory with Claude Code, Codex, or Antigravity CLI and ask:'
Say ''
Write-Host '    What should I work on next?' -ForegroundColor White
Write-Host '    What is blocked?' -ForegroundColor White
Write-Host '    Which machine has repository X?' -ForegroundColor White
Write-Host '    What did I learn about <technology>?' -ForegroundColor White
Say ''
Say '  Useful commands:'
Note '    ./bin/mc.ps1 next          rank open work and recommend the next task'
Note '    ./bin/mc.ps1 repo scan     propose repository registry entries for this machine'
Note '    ./bin/mc.ps1 onboard       add a pointer block to the global agent files, so'
Note '                               agents opened in OTHER repos find Work Trek'
Note '    ./bin/mc.ps1 statusline    install the shared Claude Code status line'
Note '    qmd query "<topic>"        semantic search over durable memory (see step 6)'
Say ''
Say '  Read next: AGENTS.md, then agent/OPERATING_SYSTEM.md'
Say ''

# Deferred from step 1: loud, last, and impossible to miss - but not a hard stop, because
# everything else bootstrap set up works without it.
if ($CoreutilsMissing) {
    Write-Host ''
    Write-Host '  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!' -ForegroundColor Red
    Write-Host '  !!                                                                    !!' -ForegroundColor Red
    Write-Host '  !!   coreutils is NOT installed on this Windows machine.              !!' -ForegroundColor Red
    Write-Host '  !!                                                                    !!' -ForegroundColor Red
    Write-Host '  !!   Git Bash / Cygwin / MSYS2 are NOT acceptable substitutes here.   !!' -ForegroundColor Red
    Write-Host '  !!   Without coreutils, head/tail/wc/cut/sort/uniq/tr/sha256sum       !!' -ForegroundColor Red
    Write-Host '  !!   are missing from pwsh and work silently drifts back to a bash    !!' -ForegroundColor Red
    Write-Host '  !!   emulation layer.                                                 !!' -ForegroundColor Red
    Write-Host '  !!                                                                    !!' -ForegroundColor Red
    Write-Host '  !!   Fix it now:   winget install Microsoft.Coreutils                 !!' -ForegroundColor Red
    Write-Host '  !!   Then re-run:  ./bin/bootstrap.ps1                                !!' -ForegroundColor Red
    Write-Host '  !!                                                                    !!' -ForegroundColor Red
    Write-Host '  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!' -ForegroundColor Red
    Write-Host ''
}

if ($validateFailed) { exit 1 }
