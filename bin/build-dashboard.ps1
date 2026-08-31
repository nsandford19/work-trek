#!/usr/bin/env pwsh
<#
.SYNOPSIS
Build the Work Trek progress dashboard as one self-contained HTML file.

.DESCRIPTION
Reads live issue state with gh, aggregates it, and renders a static page with no
external requests. Local output goes to reports/generated/ (gitignored - generated
status output is never canonical, see ARCHITECTURE.md). CI publishes the same file
to the dedicated `dashboard` branch nightly (.github/workflows/dashboard.yml).

The page is a management view: attention-required triage, current work by project,
blocked/waiting with resolved blockers, ranked next work (whats-next skill rules),
initiative health, and recently completed - plus client-side filtering/search over
issue data embedded once as JSON. Everything degrades gracefully without JS.

-Fragment emits the same page without the <!doctype>/<html>/<head>/<body> wrappers
(first line is the <title>, then the <style>, then body content) for publishing as
a Claude artifact, which supplies its own document skeleton.

.EXAMPLE
./bin/build-dashboard.ps1
./bin/build-dashboard.ps1 -Out /tmp/index.html
./bin/build-dashboard.ps1 -Fragment -Out /tmp/dashboard-fragment.html
#>
[CmdletBinding()]
param(
    [string] $Out,
    [switch] $Fragment
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host 'build-dashboard requires PowerShell 7+ (pwsh).' -ForegroundColor Red
    exit 1
}

$RepoRoot = Split-Path -Parent $PSScriptRoot
if (-not $Out) { $Out = Join-Path $RepoRoot 'reports/generated/dashboard.html' }
Import-Module (Join-Path $PSScriptRoot 'lib/Mc.Issues.psm1') -Force

# ---------------------------------------------------------------------------- data
$slug = Get-McRepoSlug -RepoRoot $RepoRoot

Write-Host "fetching issues from $slug ..."
try { $issues = Get-McIssueSnapshot -Slug $slug }
catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }

$now = [datetime]::UtcNow

function Get-Label { param($Issue, [string] $Prefix)
    @($Issue.labels | ForEach-Object { $_.name } |
        Where-Object { $_.StartsWith($Prefix) } |
        ForEach-Object { $_.Substring($Prefix.Length) }) | Select-Object -First 1
}
function Get-Prio { param($Issue)
    @($Issue.labels | ForEach-Object { $_.name } | Where-Object { $_ -match '^p[0-3]$' }) |
        Select-Object -First 1
}
function Get-Blockers { param($Issue)
    $out = @()
    if ($Issue.body) {
        foreach ($m in [regex]::Matches($Issue.body, '(?im)^\s*Blocked by:\s*((?:#\d+[,;\s]*)+)')) {
            foreach ($n in [regex]::Matches($m.Groups[1].Value, '#(\d+)')) { $out += [int]$n.Groups[1].Value }
        }
    }
    return @($out | Select-Object -Unique)
}
function ConvertTo-UtcDate { param($D)
    $dt = [datetime]$D
    if ($dt.Kind -eq 'Local') { $dt = $dt.ToUniversalTime() }
    return $dt
}
function Get-DaysAgo { param($D) [int][Math]::Floor(($now - (ConvertTo-UtcDate $D)).TotalDays) }
function Get-IsoZ { param($D)
    if ($null -eq $D -or "$D" -eq '') { return $null }
    (ConvertTo-UtcDate $D).ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
}

# Index and per-issue extracts, computed once.
$byNumber = @{}
foreach ($i in $issues) { $byNumber[[int]$i.number] = $i }

$ext = @{}
foreach ($i in $issues) {
    $flat = ("$($i.body)" -replace '\s+', ' ').Trim()
    if ($flat.Length -gt 300) { $flat = $flat.Substring(0, 300).TrimEnd() + '...' }
    $ext[[int]$i.number] = [pscustomobject]@{
        Project  = Get-Label $i 'project:'
        Type     = Get-Label $i 'type:'
        Status   = Get-Label $i 'status:'
        Prio     = Get-Prio $i
        Blockers = @(Get-Blockers $i)
        Excerpt  = $flat
    }
}
function Get-OpenBlockers { param([int]$N)
    @($ext[$N].Blockers | Where-Object { $byNumber.ContainsKey($_) -and $byNumber[$_].state -eq 'OPEN' })
}

$open   = @($issues | Where-Object { $_.state -eq 'OPEN' })
$closed = @($issues | Where-Object { $_.state -eq 'CLOSED' })

$byStatus = @{}
foreach ($s in @('inbox', 'ready', 'in-progress', 'blocked', 'waiting', 'review')) { $byStatus[$s] = @() }
$noStatus = @()
foreach ($i in $open) {
    $s = $ext[[int]$i.number].Status
    if ($s -and $byStatus.ContainsKey($s)) { $byStatus[$s] += $i } else { $noStatus += $i }
}

$closed30 = @($closed | Where-Object { $_.closedAt -and (Get-DaysAgo $_.closedAt) -le 30 })
$staleWaiting = @($byStatus['waiting'] | Where-Object { (Get-DaysAgo $_.updatedAt) -gt 7 })

function Group-Count { param($Set, [scriptblock] $KeyOf)
    $g = [ordered]@{}
    foreach ($i in $Set) {
        $k = & $KeyOf $i
        if (-not $k) { $k = '(none)' }
        if (-not $g.Contains($k)) { $g[$k] = 0 }
        $g[$k] = $g[$k] + 1
    }
    return $g
}

$prioCounts = [ordered]@{}
foreach ($p in @('p0', 'p1', 'p2', 'p3')) {
    $c = @($open | Where-Object { (Get-Prio $_) -eq $p }).Count
    if ($c -gt 0) { $prioCounts[$p] = $c }
}
$typeCounts    = Group-Count $open { param($i) Get-Label $i 'type:' }
$projectCounts = Group-Count $open { param($i) Get-Label $i 'project:' }

# Opened / closed per week, last 8 weeks, weeks starting Monday (UTC).
$monday = $now.Date.AddDays( - ((([int]$now.DayOfWeek) + 6) % 7) )
$weeks = @()
for ($w = 7; $w -ge 0; $w--) {
    $start = $monday.AddDays(-7 * $w)
    $end = $start.AddDays(7)
    $weeks += [pscustomobject]@{
        Label  = $start.ToString('MM-dd')
        Opened = @($issues | Where-Object { $d = [datetime]$_.createdAt; $d -ge $start -and $d -lt $end }).Count
        Closed = @($issues | Where-Object { $_.closedAt -and ($d = [datetime]$_.closedAt) -and $d -ge $start -and $d -lt $end }).Count
    }
}

# Which open issues does each issue block? (reverse of the Blocked by: lines)
$blockedByMap = @{}
foreach ($i in $open) {
    foreach ($b in $ext[[int]$i.number].Blockers) {
        if (-not $blockedByMap.ContainsKey($b)) { $blockedByMap[$b] = @() }
        $blockedByMap[$b] += [int]$i.number
    }
}

# Initiative health via native sub-issues (TASK_POLICY.md section 2). One extra call
# per open initiative; sub-issue details resolve against the already-fetched set.
$initiatives = @()
$initSubNums = [System.Collections.Generic.HashSet[int]]::new()
foreach ($i in ($open | Where-Object { (Get-Label $_ 'type:') -eq 'initiative' })) {
    $subs = @()
    try {
        $subRaw = & gh api "repos/$slug/issues/$($i.number)/sub_issues" 2>$null
        if ($LASTEXITCODE -eq 0 -and $subRaw) { $subs = @("$subRaw" | ConvertFrom-Json) }
    } catch { $subs = @() }
    $done = 0; $blocked = 0; $done30 = 0
    foreach ($s in $subs) {
        $sn = [int]$s.number
        [void]$initSubNums.Add($sn)
        $local = if ($byNumber.ContainsKey($sn)) { $byNumber[$sn] } else { $null }
        $state = if ($local) { $local.state } else { "$($s.state)".ToUpperInvariant() }
        if ($state -eq 'CLOSED') {
            $done++
            $closedAt = if ($local) { $local.closedAt }
                        elseif ($s.PSObject.Properties['closed_at']) { $s.closed_at } else { $null }
            if ($closedAt -and (Get-DaysAgo $closedAt) -le 30) { $done30++ }
        }
        elseif ($local) {
            $lx = $ext[$sn]
            if ($lx.Status -eq 'blocked' -or @(Get-OpenBlockers $sn).Count -gt 0) { $blocked++ }
        }
    }
    $initiatives += [pscustomobject]@{
        Number = [int]$i.number; Title = $i.title; Url = $i.url
        Total  = $subs.Count
        Done   = $done
        Open   = $subs.Count - $done
        Blocked = $blocked
        Done30 = $done30
        Prio   = Get-Prio $i
        StaleDays = Get-DaysAgo $i.updatedAt
    }
}

# ---- Attention required: ranked, deduped, each with a one-line WHY -----------
$attention = [System.Collections.Generic.List[object]]::new()
$attnIndex = @{}
function Add-Attention { param($Issue, [string]$Why, [int]$Rank, [string]$Sev)
    $n = [int]$Issue.number
    if ($attnIndex.ContainsKey($n)) {
        $e = $attnIndex[$n]
        $e.Why = $e.Why + ' - also: ' + $Why
        if ($Rank -lt $e.Rank) { $e.Rank = $Rank; $e.Sev = $Sev }
    }
    else {
        $e = [pscustomobject]@{ Issue = $Issue; Why = $Why; Rank = $Rank; Sev = $Sev }
        $attention.Add($e); $attnIndex[$n] = $e
    }
}
foreach ($i in $open) {
    $p = $ext[[int]$i.number].Prio
    if ($p -eq 'p0') { Add-Attention $i 'p0 - highest priority, act now' 0 'critical' }
    elseif ($p -eq 'p1') { Add-Attention $i 'p1 - high priority' 1 'serious' }
}
foreach ($i in $byStatus['blocked']) {
    $n = [int]$i.number; $bs = $ext[$n].Blockers
    if ($bs.Count -eq 0) { continue }
    $known = @($bs | Where-Object { $byNumber.ContainsKey($_) })
    if ($known.Count -eq $bs.Count -and @(Get-OpenBlockers $n).Count -eq 0) {
        Add-Attention $i "labelled blocked but every blocker is closed - label drift, likely ready" 2 'warning'
    }
}
foreach ($i in $byStatus['ready']) {
    $ob = @(Get-OpenBlockers ([int]$i.number))
    if ($ob.Count -gt 0) {
        Add-Attention $i "labelled ready but #$($ob -join ', #') still open - label drift, actually blocked" 2 'warning'
    }
}
foreach ($i in $staleWaiting) {
    Add-Attention $i "waiting $(Get-DaysAgo $i.updatedAt)d without update - chase it" 3 'warning'
}
foreach ($i in $byStatus['inbox']) {
    $age = Get-DaysAgo $i.createdAt
    if ($age -gt 7) { Add-Attention $i "sitting in the inbox untriaged for ${age}d" 4 'warning' }
}
$prioIdx = @{ p0 = 0; p1 = 1; p2 = 2; p3 = 3 }
function Get-PrioIdx { param($P) if ($P -and $prioIdx.ContainsKey($P)) { $prioIdx[$P] } else { 4 } }
$attention = @($attention | Sort-Object Rank, { Get-PrioIdx $ext[[int]$_.Issue.number].Prio }, { ConvertTo-UtcDate $_.Issue.updatedAt })

# ---- Next work: status:ready ranked per the whats-next skill ------------------
# priority -> open-initiative membership -> decision that unblocks work -> age.
$nextWork = @()
$nextExcluded = 0
foreach ($i in $byStatus['ready']) {
    $n = [int]$i.number; $x = $ext[$n]
    if ($x.Type -eq 'initiative') { continue }                     # containers are not work
    if (@(Get-OpenBlockers $n).Count -gt 0) { $nextExcluded++; continue }  # drift; surfaced above
    $inInit = $initSubNums.Contains($n)
    $unblocks = @(if ($x.Type -eq 'decision' -and $blockedByMap.ContainsKey($n)) { $blockedByMap[$n] })
    $why = @()
    $why += if ($x.Prio) { $x.Prio } else { 'no priority' }
    if ($inInit) { $why += 'part of an open initiative' }
    if ($unblocks.Count -gt 0) { $why += "decision unblocking #$($unblocks -join ', #')" }
    $why += "$(Get-DaysAgo $i.createdAt)d old"
    $nextWork += [pscustomobject]@{
        Issue = $i; PrioIdx = Get-PrioIdx $x.Prio
        InInit = [int]$inInit; Unblocks = $unblocks.Count
        Created = ConvertTo-UtcDate $i.createdAt
        Why = ($why -join ' - ')
    }
}
$nextWork = @($nextWork | Sort-Object PrioIdx,
    @{ Expression = 'InInit'; Descending = $true },
    @{ Expression = 'Unblocks'; Descending = $true },
    Created)

# ---- Recently completed: 90-day pool, 30-day default window -------------------
$completed90 = @($closed |
    Where-Object { $_.closedAt -and (Get-DaysAgo $_.closedAt) -le 90 } |
    Sort-Object { ConvertTo-UtcDate $_.closedAt } -Descending)
$done30Count = @($completed90 | Where-Object { $_.stateReason -ne 'NOT_PLANNED' -and (Get-DaysAgo $_.closedAt) -le 30 }).Count
$np30Count   = @($completed90 | Where-Object { $_.stateReason -eq 'NOT_PLANNED' -and (Get-DaysAgo $_.closedAt) -le 30 }).Count

# ---------------------------------------------------------------------------- html
function E { param([string] $S) [System.Net.WebUtility]::HtmlEncode("$S") }

$sb = [System.Text.StringBuilder]::new()
function Add { param([string] $S) [void]$script:sb.AppendLine($S) }

# Horizontal bar chart. Single series (identity is on the axis), so no legend box;
# bars 18px in a 28px band, 4px rounded data-end, square at the baseline, value at tip.
function New-HBars { param([System.Collections.Specialized.OrderedDictionary] $Counts)
    if ($Counts.Count -eq 0) { return '<p class="empty">nothing here yet</p>' }
    $max = ($Counts.Values | Measure-Object -Maximum).Maximum
    if ($max -lt 1) { $max = 1 }
    $labelW = 130; $valueW = 34; $plotW = 300; $band = 28; $barH = 18
    $h = $Counts.Count * $band + 4
    $svg = [System.Text.StringBuilder]::new()
    [void]$svg.AppendLine("<svg viewBox=""0 0 $($labelW + $plotW + $valueW) $h"" role=""img"" style=""width:100%;height:auto"">")
    $y = 2
    foreach ($k in $Counts.Keys) {
        $v = $Counts[$k]
        $w = [Math]::Round($plotW * $v / $max)
        if ($v -gt 0 -and $w -lt 5) { $w = 5 }
        $yBar = $y + [int](($band - $barH) / 2)
        $ty = $y + [int]($band / 2) + 4
        [void]$svg.AppendLine("<text x=""$($labelW - 8)"" y=""$ty"" text-anchor=""end"" class=""axis"">$(E $k)</text>")
        if ($v -gt 0) {
            $x2 = $labelW + $w
            $r = [Math]::Min(4, $w)
            $path = "M$labelW,$yBar H$($x2 - $r) A$r,$r 0 0 1 $x2,$($yBar + $r) V$($yBar + $barH - $r) A$r,$r 0 0 1 $($x2 - $r),$($yBar + $barH) H$labelW Z"
            [void]$svg.AppendLine("<path d=""$path"" fill=""var(--series-1)"" class=""mark"" data-tip=""$(E $k): $v""></path>")
        }
        [void]$svg.AppendLine("<text x=""$($labelW + $w + 6)"" y=""$ty"" class=""val"">$v</text>")
        $y += $band
    }
    [void]$svg.AppendLine('</svg>')
    return $svg.ToString()
}

# Opened vs closed per week: two 2px lines, >=8px end markers with a 2px surface ring,
# legend (two series always get one), hairline gridlines on clean ticks.
function New-Trend {
    $w = 460; $h = 170; $padL = 30; $padR = 60; $padT = 12; $padB = 24
    $plotW = $w - $padL - $padR; $plotH = $h - $padT - $padB
    $max = (@($weeks | ForEach-Object { $_.Opened, $_.Closed }) | Measure-Object -Maximum).Maximum
    if ($max -lt 3) { $max = 3 }
    $step = [Math]::Ceiling($max / 3)
    $max = $step * 3
    $svg = [System.Text.StringBuilder]::new()
    [void]$svg.AppendLine("<svg viewBox=""0 0 $w $h"" role=""img"" style=""width:100%;height:auto"">")
    for ($g = 0; $g -le 3; $g++) {
        $gy = [Math]::Round($padT + $plotH - ($plotH * $g / 3), 1)
        $cls = if ($g -eq 0) { 'baseline' } else { 'grid' }
        [void]$svg.AppendLine("<line x1=""$padL"" y1=""$gy"" x2=""$($padL + $plotW)"" y2=""$gy"" class=""$cls""/>")
        [void]$svg.AppendLine("<text x=""$($padL - 6)"" y=""$($gy + 4)"" text-anchor=""end"" class=""axis"">$($step * $g)</text>")
    }
    $n = $weeks.Count
    $xOf = { param($idx) [Math]::Round($padL + ($plotW * $idx / ($n - 1)), 1) }
    $yOf = { param($v) [Math]::Round($padT + $plotH - ($plotH * $v / $max), 1) }
    foreach ($idx in 0..($n - 1)) {
        $lx = & $xOf $idx
        [void]$svg.AppendLine("<text x=""$lx"" y=""$($h - 6)"" text-anchor=""middle"" class=""axis"">$($weeks[$idx].Label)</text>")
    }
    $seriesDefs = @(
        @{ Name = 'opened'; Var = '--series-1'; Prop = 'Opened' }
        @{ Name = 'closed'; Var = '--series-2'; Prop = 'Closed' }
    )
    foreach ($s in $seriesDefs) {
        $pts = @()
        foreach ($idx in 0..($n - 1)) {
            $pts += "$(& $xOf $idx),$(& $yOf ($weeks[$idx].($s.Prop)))"
        }
        [void]$svg.AppendLine("<polyline points=""$($pts -join ' ')"" fill=""none"" stroke=""var($($s.Var))"" stroke-width=""2"" stroke-linejoin=""round"" stroke-linecap=""round""/>")
        foreach ($idx in 0..($n - 1)) {
            $cx = & $xOf $idx; $cy = & $yOf ($weeks[$idx].($s.Prop))
            [void]$svg.AppendLine("<circle cx=""$cx"" cy=""$cy"" r=""4"" fill=""var($($s.Var))"" stroke=""var(--surface-1)"" stroke-width=""2"" class=""mark"" data-tip=""week of $($weeks[$idx].Label): $($weeks[$idx].($s.Prop)) $($s.Name)""/>")
        }
        $endY = & $yOf ($weeks[$n - 1].($s.Prop))
        [void]$svg.AppendLine("<text x=""$($padL + $plotW + 8)"" y=""$($endY + 4)"" class=""val"">$($s.Name)</text>")
    }
    [void]$svg.AppendLine('</svg>')
    $legend = '<div class="legend"><span><i style="background:var(--series-1)"></i>opened</span>' +
              '<span><i style="background:var(--series-2)"></i>closed</span></div>'
    return $legend + $svg.ToString()
}

# Expandable issue row: native <details> so it works with JS disabled; the JS layer
# only filters. $NoteHtml must already be encoded by the caller.
function New-IssueDetail { param($Issue)
    $n = [int]$Issue.number; $x = $ext[$n]
    $d = [System.Text.StringBuilder]::new()
    [void]$d.Append('<div class="idetail">')
    $labels = @($Issue.labels | ForEach-Object { $_.name })
    if ($labels.Count -gt 0) { [void]$d.Append("<div>labels: $(E ($labels -join ' | '))</div>") }
    $dates = "created $((ConvertTo-UtcDate $Issue.createdAt).ToString('yyyy-MM-dd')) - updated $((ConvertTo-UtcDate $Issue.updatedAt).ToString('yyyy-MM-dd'))"
    if ($Issue.closedAt) {
        $dates += " - closed $((ConvertTo-UtcDate $Issue.closedAt).ToString('yyyy-MM-dd'))"
        if ($Issue.stateReason -eq 'NOT_PLANNED') { $dates += ' (not planned)' }
    }
    [void]$d.Append("<div>$dates</div>")
    foreach ($b in $x.Blockers) {
        if ($byNumber.ContainsKey($b)) {
            $bi = $byNumber[$b]
            $bState = if ($bi.state -eq 'OPEN') { 'open' } else { 'closed' }
            [void]$d.Append("<div>blocked by <a href=""$(E $bi.url)"">#$b</a> $(E $bi.title) <span class=""bstate $bState"">$bState</span></div>")
        }
        else {
            [void]$d.Append("<div>blocked by #$b (not in the fetched issue set)</div>")
        }
    }
    if ($x.Excerpt) { [void]$d.Append("<p class=""excerpt"">$(E $x.Excerpt)</p>") }
    [void]$d.Append("<div><a href=""$(E $Issue.url)"">open on GitHub</a></div>")
    [void]$d.Append('</div>')
    return $d.ToString()
}

function New-Row { param($Issue, [string]$NoteHtml = '', [string]$LiClass = '', [string]$ExtraAttrs = '')
    $n = [int]$Issue.number
    $cls = ('irow ' + $LiClass).Trim()
    $attrs = "class=""$cls"" data-n=""$n"""
    if ($ExtraAttrs) { $attrs += ' ' + $ExtraAttrs }
    return "<li $attrs><details><summary><a href=""$(E $Issue.url)"">#$n</a> $(E $Issue.title) $NoteHtml</summary>$(New-IssueDetail $Issue)</details></li>"
}

$jsEmpty = '<p class="jsempty empty" hidden>no issues match the current filters</p>'
function New-RowList { param([object[]]$Rows, [string]$Empty, [string]$UlAttrs = '')
    if (@($Rows).Count -eq 0) { return "<p class=""empty"">$(E $Empty)</p>" }
    $a = if ($UlAttrs) { ' ' + $UlAttrs } else { '' }
    return "<ul class=""issues filterable""$a>`n$($Rows -join "`n")`n</ul>"
}

$generated = $now.ToString('yyyy-MM-dd HH:mm') + ' UTC'

$style = @'
<style>
  :root {
    color-scheme: light;
    --page: #f9f9f7; --surface-1: #fcfcfb;
    --ink-1: #0b0b0b; --ink-2: #52514e; --muted: #898781;
    --grid: #e1e0d9; --baseline: #c3c2b7; --border: rgba(11,11,11,0.10);
    --series-1: #2a78d6; --series-2: #eb6834;
    --track: #cde2fb;
    --status-good: #0ca30c; --status-warning: #fab219;
    --status-serious: #ec835a; --status-critical: #d03b3b;
  }
  @media (prefers-color-scheme: dark) {
    :root:where(:not([data-theme="light"])) {
      color-scheme: dark;
      --page: #0d0d0d; --surface-1: #1a1a19;
      --ink-1: #ffffff; --ink-2: #c3c2b7; --muted: #898781;
      --grid: #2c2c2a; --baseline: #383835; --border: rgba(255,255,255,0.10);
      --series-1: #3987e5; --series-2: #d95926;
      --track: #0d366b;
    }
  }
  :root[data-theme="dark"] {
    color-scheme: dark;
    --page: #0d0d0d; --surface-1: #1a1a19;
    --ink-1: #ffffff; --ink-2: #c3c2b7; --muted: #898781;
    --grid: #2c2c2a; --baseline: #383835; --border: rgba(255,255,255,0.10);
    --series-1: #3987e5; --series-2: #d95926;
    --track: #0d366b;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; background: var(--page); color: var(--ink-1);
    font: 15px/1.45 system-ui, -apple-system, "Segoe UI", sans-serif;
    padding: 24px; max-width: 1060px; margin-inline: auto;
  }
  h1 { font-size: 20px; margin: 0 0 2px; }
  h2 { font-size: 14px; margin: 0 0 10px; color: var(--ink-2); font-weight: 600; }
  h3 { font-size: 13px; margin: 12px 0 2px; color: var(--ink-2); font-weight: 600; }
  .sub { color: var(--muted); font-size: 13px; margin-bottom: 20px; }
  .sub a { color: inherit; }
  .sub strong { color: var(--ink-2); font-weight: 600; }
  .tiles { display: grid; grid-template-columns: repeat(auto-fit, minmax(120px, 1fr)); gap: 10px; margin-bottom: 18px; }
  .tile { background: var(--surface-1); border: 1px solid var(--border); border-radius: 10px; padding: 12px 14px; }
  .tile .label { font-size: 12px; color: var(--ink-2); }
  .tile .value { font-size: 30px; font-weight: 600; margin-top: 2px; }
  .tile .note { font-size: 12px; margin-top: 2px; display: flex; align-items: center; gap: 5px; color: var(--ink-2); }
  .dot { width: 8px; height: 8px; border-radius: 50%; display: inline-block; flex: none; }
  .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 12px; margin-bottom: 18px; }
  .card { background: var(--surface-1); border: 1px solid var(--border); border-radius: 10px; padding: 14px 16px; overflow-x: auto; }
  .card.wide { grid-column: 1 / -1; }
  .card.solo { margin-bottom: 18px; }
  .cardhead { display: flex; align-items: baseline; justify-content: space-between; gap: 10px; flex-wrap: wrap; }
  svg text.axis { font: 11px system-ui, sans-serif; fill: var(--muted); }
  svg text.val  { font: 12px system-ui, sans-serif; fill: var(--ink-2); }
  svg line.grid { stroke: var(--grid); stroke-width: 1; }
  svg line.baseline { stroke: var(--baseline); stroke-width: 1; }
  .legend { display: flex; gap: 14px; font-size: 12px; color: var(--ink-2); margin-bottom: 6px; }
  .legend i { width: 10px; height: 10px; border-radius: 2px; display: inline-block; margin-right: 5px; }
  .legend span { display: inline-flex; align-items: center; }
  ul.issues { list-style: none; padding: 0; margin: 0; }
  ul.issues li { border-bottom: 1px solid var(--grid); font-size: 14px; }
  ul.issues li:last-child { border-bottom: 0; }
  ul.issues a { color: var(--series-1); text-decoration: none; font-variant-numeric: tabular-nums; }
  .meta { color: var(--muted); font-size: 12px; }
  .why { color: var(--ink-2); font-size: 12px; }
  .empty { color: var(--muted); font-size: 13px; }
  .irow details { margin: 0; }
  .irow summary { list-style: none; cursor: pointer; padding: 7px 0 7px 16px; position: relative; color: inherit; font-size: 14px; }
  .irow summary::-webkit-details-marker { display: none; }
  .irow summary::before { content: '\25B8'; position: absolute; left: 2px; top: 8px; color: var(--muted); font-size: 10px; }
  .irow details[open] summary::before { content: '\25BE'; }
  .irow summary:focus-visible { outline: 2px solid var(--series-1); outline-offset: 2px; border-radius: 4px; }
  .idetail { padding: 0 0 10px 16px; display: grid; gap: 4px; font-size: 13px; color: var(--ink-2); }
  .idetail .excerpt { margin: 0; color: var(--muted); }
  .bstate { font-size: 11px; padding: 1px 7px; border-radius: 999px; border: 1px solid var(--border); }
  .bstate.open { color: var(--status-critical); }
  .bstate.closed { color: var(--status-good); }
  .badge { font-size: 11px; padding: 1px 7px; border-radius: 999px; border: 1px solid var(--border); color: var(--ink-2); white-space: nowrap; }
  .badge.stale { color: var(--status-serious); border-color: var(--status-serious); }
  li.dim, .dim { opacity: 0.55; }
  .rule-note { font-size: 12px; color: var(--muted); margin: -4px 0 8px; }
  .fbrow { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; }
  .fbrow input[type="search"] { flex: 1 1 220px; min-width: 160px; padding: 6px 10px; border: 1px solid var(--border); border-radius: 8px; background: var(--page); color: var(--ink-1); font: inherit; font-size: 13px; }
  .fbrow input[type="search"]:focus-visible, button:focus-visible { outline: 2px solid var(--series-1); outline-offset: 1px; }
  .btn { font: 12px system-ui, sans-serif; padding: 6px 12px; border-radius: 8px; border: 1px solid var(--border); background: var(--surface-1); color: var(--ink-2); cursor: pointer; }
  .chips { display: flex; flex-direction: column; gap: 6px; margin-top: 10px; }
  .chipgroup { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; }
  .glabel { font-size: 11px; color: var(--muted); text-transform: uppercase; letter-spacing: 0.05em; flex: 0 0 60px; }
  .chip { font: 12px/1 system-ui, sans-serif; padding: 5px 10px; border-radius: 999px; border: 1px solid var(--border); background: var(--surface-1); color: var(--ink-2); cursor: pointer; }
  .chip[aria-pressed="true"] { background: var(--series-1); border-color: var(--series-1); color: #ffffff; }
  .wbtns { display: inline-flex; gap: 4px; }
  .wbtn { font: 12px/1 system-ui, sans-serif; padding: 4px 9px; border-radius: 999px; border: 1px solid var(--border); background: var(--surface-1); color: var(--ink-2); cursor: pointer; }
  .wbtn[aria-pressed="true"] { background: var(--series-1); border-color: var(--series-1); color: #ffffff; }
  .meter { margin: 10px 0; }
  .meter .head { display: flex; justify-content: space-between; font-size: 13px; margin-bottom: 4px; gap: 10px; align-items: baseline; }
  .meter .head a { color: inherit; text-decoration: none; }
  .meter .head .n { color: var(--ink-2); font-variant-numeric: tabular-nums; white-space: nowrap; }
  .meter .bar { height: 10px; border-radius: 5px; background: var(--track); overflow: hidden; }
  .meter .fill { height: 100%; background: var(--series-1); border-radius: 5px; }
  .meter .sig { font-size: 12px; color: var(--muted); margin-top: 3px; }
  details.tablefold { margin-bottom: 18px; }
  details.tablefold > summary { cursor: pointer; color: var(--ink-2); font-size: 14px; }
  table { border-collapse: collapse; width: 100%; margin-top: 10px; font-size: 13px; background: var(--surface-1); }
  th, td { text-align: left; padding: 6px 10px; border-bottom: 1px solid var(--grid); white-space: nowrap; }
  td.title { white-space: normal; }
  th { color: var(--muted); font-weight: 600; }
  td.num { font-variant-numeric: tabular-nums; }
  .tablewrap { overflow-x: auto; }
  footer { color: var(--muted); font-size: 12px; margin-top: 24px; }
  #tip { position: fixed; pointer-events: none; background: var(--ink-1); color: var(--page);
         font-size: 12px; padding: 4px 8px; border-radius: 5px; display: none; z-index: 10; }
  svg .mark:hover { opacity: 0.85; }
</style>
'@

if ($Fragment) {
    Add '<title>Work Trek Dashboard</title>'
    Add $style
}
else {
    Add '<!doctype html>'
    Add '<html lang="en"><head><meta charset="utf-8">'
    Add '<meta name="viewport" content="width=device-width, initial-scale=1">'
    Add '<title>Work Trek — Dashboard</title>'
    Add $style
    Add '</head><body>'
}

Add '<h1>Work Trek</h1>'
Add "<div class=""sub"">work state on <a href=""https://github.com/$(E $slug)/issues"">$(E $slug)</a> · generated <strong>$generated</strong> — point-in-time snapshot, <strong>GitHub Issues are canonical</strong> · <a href=""https://github.com/$(E $slug)/actions/workflows/dashboard.yml"">rebuild on demand</a></div>"

# Stat tiles. Status colors are semantic and never carry meaning alone (dot + label).
$attnSevColor = 'var(--status-warning)'
if (@($attention | Where-Object { $_.Sev -eq 'critical' }).Count -gt 0) { $attnSevColor = 'var(--status-critical)' }
elseif (@($attention | Where-Object { $_.Sev -eq 'serious' }).Count -gt 0) { $attnSevColor = 'var(--status-serious)' }
Add '<div class="tiles">'
$attnNote = if (@($attention).Count -gt 0) { "<div class=""note""><span class=""dot"" style=""background:$attnSevColor""></span>see below</div>" } else { '' }
Add "<div class=""tile""><div class=""label"">needs attention</div><div class=""value"">$(@($attention).Count)</div>$attnNote</div>"
Add "<div class=""tile""><div class=""label"">open issues</div><div class=""value"">$($open.Count)</div></div>"
Add "<div class=""tile""><div class=""label"">in progress</div><div class=""value"">$($byStatus['in-progress'].Count)</div></div>"
Add "<div class=""tile""><div class=""label"">ready</div><div class=""value"">$($byStatus['ready'].Count)</div></div>"
$blockedNote = if ($byStatus['blocked'].Count -gt 0) { "<div class=""note""><span class=""dot"" style=""background:var(--status-critical)""></span>needs unblocking</div>" } else { '' }
Add "<div class=""tile""><div class=""label"">blocked</div><div class=""value"">$($byStatus['blocked'].Count)</div>$blockedNote</div>"
$waitNote = if ($staleWaiting.Count -gt 0) { "<div class=""note""><span class=""dot"" style=""background:var(--status-warning)""></span>$($staleWaiting.Count) stale &gt;7d</div>" } else { '' }
Add "<div class=""tile""><div class=""label"">waiting</div><div class=""value"">$($byStatus['waiting'].Count)</div>$waitNote</div>"
Add "<div class=""tile""><div class=""label"">inbox (untriaged)</div><div class=""value"">$($byStatus['inbox'].Count)</div></div>"
Add "<div class=""tile""><div class=""label"">closed, 30 days</div><div class=""value"">$($closed30.Count)</div></div>"
Add '</div>'

# ---- 1. Attention required ----------------------------------------------------
$sevColor = @{ critical = 'var(--status-critical)'; serious = 'var(--status-serious)'; warning = 'var(--status-warning)' }
Add '<div class="card solo" data-filtersect>'
Add '<h2>Attention required</h2>'
Add '<p class="rule-note">ranked: p0/p1 first, then label drift, stale waiting (&gt;7d), old inbox (&gt;7d)</p>'
$attnRows = foreach ($e in $attention) {
    $note = "<span class=""dot"" style=""background:$($sevColor[$e.Sev])""></span> <span class=""why"">$(E $e.Why)</span>"
    New-Row $e.Issue $note
}
Add (New-RowList @($attnRows) 'nothing needs attention')
Add $jsEmpty
Add '</div>'

# ---- Filter toolbar (hidden until the JS layer boots; useless without it) ------
Add '<div class="card solo" id="filterbar" hidden>'
Add '<div class="fbrow">'
Add '<input id="q" type="search" placeholder="search #number or title" aria-label="search issues">'
Add '<span id="showing" class="meta"></span>'
Add '<button id="clear" type="button" class="btn">clear filters</button>'
Add '</div>'
Add '<div class="chips" id="chips"></div>'
Add '</div>'

# ---- 2. Current work, grouped by project --------------------------------------
Add '<div class="grid">'
Add '<div class="card" data-filtersect>'
Add '<h2>Current work — in progress</h2>'
if ($byStatus['in-progress'].Count -eq 0) {
    Add '<p class="empty">nothing in progress</p>'
}
else {
    $byProject = [ordered]@{}
    foreach ($i in ($byStatus['in-progress'] | Sort-Object { Get-PrioIdx $ext[[int]$_.number].Prio })) {
        $k = $ext[[int]$i.number].Project; if (-not $k) { $k = '(no project)' }
        if (-not $byProject.Contains($k)) { $byProject[$k] = @() }
        $byProject[$k] += $i
    }
    foreach ($proj in $byProject.Keys) {
        Add '<div class="pgroup">'
        Add "<h3>$(E $proj)</h3>"
        $rows = foreach ($i in $byProject[$proj]) {
            $x = $ext[[int]$i.number]
            $meta = @(); if ($x.Prio) { $meta += $x.Prio }; if ($x.Type) { $meta += "type:$($x.Type)" }
            $meta += "updated $(Get-DaysAgo $i.updatedAt)d ago"
            New-Row $i "<span class=""meta"">$(E ($meta -join ' · '))</span>"
        }
        Add (New-RowList @($rows) '')
        Add '</div>'
    }
}
Add $jsEmpty
Add '</div>'

# ---- 3. Blocked / waiting -------------------------------------------------------
Add '<div class="card" data-filtersect>'
Add '<h2>Blocked / waiting</h2>'
Add '<p class="rule-note">time in state approximated from last update</p>'
$stuck = @($byStatus['blocked']) + @($byStatus['waiting'])
$stuckRows = foreach ($i in ($stuck | Sort-Object { Get-DaysAgo $_.updatedAt } -Descending)) {
    $n = [int]$i.number; $x = $ext[$n]
    $days = Get-DaysAgo $i.updatedAt
    $meta = @("status:$($x.Status)")
    foreach ($b in $x.Blockers) {
        $bState = if ($byNumber.ContainsKey($b)) { if ($byNumber[$b].state -eq 'OPEN') { 'open' } else { 'closed' } } else { '?' }
        $meta += "blocked by #$b ($bState)"
    }
    $meta += "~${days}d in state"
    $stale = ($days -gt 7)
    $note = "<span class=""meta"">$(E ($meta -join ' · '))</span>"
    if ($stale) { $note += ' <span class="badge stale">stale</span>' }
    New-Row $i $note
}
Add (New-RowList @($stuckRows) 'nothing stuck')
Add $jsEmpty
Add '</div>'
Add '</div>'

# ---- 4. Next work ---------------------------------------------------------------
Add '<div class="card solo" data-filtersect>'
Add '<h2>Next work — ready, ranked</h2>'
Add '<p class="rule-note">ranked per the whats-next skill: priority (p0&#8594;p3), then membership in an open initiative, then decisions that unblock other work; age is a tie-break only — never simply oldest-first</p>'
$nextRows = foreach ($e in $nextWork) {
    New-Row $e.Issue "<span class=""why"">$(E $e.Why)</span>"
}
Add (New-RowList @($nextRows) 'nothing ready — triage the inbox or unblock something')
if ($nextExcluded -gt 0) {
    Add "<p class=""meta"">$nextExcluded ready-labelled issue(s) excluded: their blockers are still open (see Attention required)</p>"
}
Add $jsEmpty
Add '</div>'

# ---- 5. Initiative health -------------------------------------------------------
if (@($initiatives).Count -gt 0) {
    Add '<div class="card solo">'
    Add '<h2>Initiative health</h2>'
    foreach ($ini in $initiatives) {
        $pct = if ($ini.Total -gt 0) { [Math]::Round(100 * $ini.Done / $ini.Total) } else { 0 }
        $count = if ($ini.Total -gt 0) { "$($ini.Done)/$($ini.Total) sub-issues" } else { 'no sub-issues yet' }
        $badges = ''
        if ($ini.Prio) { $badges += " <span class=""badge"">$(E $ini.Prio)</span>" }
        if ($ini.StaleDays -gt 21) { $badges += " <span class=""badge stale"">stale — no update in $($ini.StaleDays)d</span>" }
        Add "<div class=""meter""><div class=""head""><span><a href=""$(E $ini.Url)"">#$($ini.Number) $(E $ini.Title)</a>$badges</span><span class=""n"">$count</span></div>"
        Add "<div class=""bar""><div class=""fill"" style=""width:$pct%""></div></div>"
        $sig = @("$($ini.Open) open", "$($ini.Done) done")
        if ($ini.Blocked -gt 0) { $sig += "$($ini.Blocked) blocked" }
        $sig += "$($ini.Done30) completed in 30d"
        Add "<div class=""sig"">$(E ($sig -join ' · '))</div></div>"
    }
    Add '</div>'
}

# ---- 6. Recently completed + inbox ---------------------------------------------
Add '<div class="grid">'
Add '<div class="card" data-filtersect>'
Add '<div class="cardhead"><h2>Recently completed</h2><span class="wbtns" hidden>'
foreach ($wd in @(7, 30, 90)) {
    $pressed = if ($wd -eq 30) { 'true' } else { 'false' }
    Add "<button type=""button"" class=""wbtn"" data-w=""$wd"" aria-pressed=""$pressed"">${wd}d</button>"
}
Add '</span></div>'
$npNote = if ($np30Count -gt 0) { " · $np30Count not planned (dimmed, excluded from count)" } else { '' }
Add "<p class=""rule-note"" id=""donesum"">$done30Count completed in last 30 days$npNote</p>"
$compRows = foreach ($i in $completed90) {
    $n = [int]$i.number
    $days = Get-DaysAgo $i.closedAt
    $np = ($i.stateReason -eq 'NOT_PLANNED')
    $meta = @("closed $((ConvertTo-UtcDate $i.closedAt).ToString('MM-dd'))")
    if ($np) { $meta += 'not planned' }
    $liClass = if ($np) { 'dim' } else { '' }
    $attrs = "data-days=""$days"""
    if ($np) { $attrs += ' data-np' }
    if ($days -gt 30) { $attrs += ' hidden' }   # default window; JS switches it
    New-Row $i "<span class=""meta"">$(E ($meta -join ' · '))</span>" $liClass $attrs
}
Add (New-RowList @($compRows) 'nothing completed in the last 90 days' 'data-completed')
Add $jsEmpty
Add '</div>'

Add '<div class="card" data-filtersect>'
Add '<h2>Inbox — needs triage</h2>'
$inboxRows = foreach ($i in ($byStatus['inbox'] | Sort-Object { ConvertTo-UtcDate $_.createdAt })) {
    New-Row $i "<span class=""meta"">captured $(Get-DaysAgo $i.createdAt)d ago</span>"
}
Add (New-RowList @($inboxRows) 'inbox zero')
Add $jsEmpty
Add '</div>'
Add '</div>'

# ---- Trends & distribution (server-rendered SVG, unchanged) ---------------------
Add '<div class="grid">'
Add "<div class=""card""><h2>Open by status</h2>$(New-HBars (Group-Count $open { param($i) Get-Label $i 'status:' }))</div>"
Add "<div class=""card""><h2>Open by type</h2>$(New-HBars $typeCounts)</div>"
Add "<div class=""card""><h2>Open by priority</h2>$(New-HBars $prioCounts)</div>"
Add "<div class=""card""><h2>Open by project</h2>$(New-HBars $projectCounts)</div>"
Add "<div class=""card wide""><h2>Opened vs closed per week</h2>$(New-Trend)</div>"
Add '</div>'

if (@($noStatus).Count -gt 0) {
    Add '<div class="card solo" data-filtersect>'
    Add '<h2>Label drift — open issues without a status label</h2>'
    $driftRows = foreach ($i in $noStatus) { New-Row $i }
    Add (New-RowList @($driftRows) '')
    Add $jsEmpty
    Add '</div>'
}

# Table view: the accessibility fallback that carries every value the charts show.
Add '<details class="tablefold"><summary>All open issues as a table</summary><div class="tablewrap">'
Add '<table><thead><tr><th>#</th><th>Title</th><th>Type</th><th>Status</th><th>Priority</th><th>Project</th><th>Age (days)</th></tr></thead><tbody>'
foreach ($i in ($open | Sort-Object { [int]$_.number })) {
    $age = Get-DaysAgo $i.createdAt
    Add ("<tr><td class=""num""><a href=""{0}"">#{1}</a></td><td class=""title"">{2}</td><td>{3}</td><td>{4}</td><td>{5}</td><td>{6}</td><td class=""num"">{7}</td></tr>" -f `
        (E $i.url), $i.number, (E $i.title), (E (Get-Label $i 'type:')), (E (Get-Label $i 'status:')), (E (Get-Prio $i)), (E (Get-Label $i 'project:')), $age)
}
Add '</tbody></table></div></details>'

Add "<footer>Generated by <code>bin/build-dashboard.ps1</code> from live GitHub Issues — the single source of truth (agent/TASK_POLICY.md). This page is a snapshot, never canonical. Local rebuild: <code>mc dashboard</code>. Nightly rebuild publishes to the <code>dashboard</code> branch. Artifact copy: rebuild with <code>-Fragment</code> and republish.</footer>"

# ---- Embedded issue data (one JSON block; </ is escaped for script safety) ------
$jsonArr = @(foreach ($i in $issues) {
    $n = [int]$i.number; $x = $ext[$n]
    [ordered]@{
        number      = $n
        title       = $i.title
        url         = $i.url
        state       = $i.state
        stateReason = $i.stateReason
        labels      = @($i.labels | ForEach-Object { $_.name })
        createdAt   = Get-IsoZ $i.createdAt
        closedAt    = Get-IsoZ $i.closedAt
        updatedAt   = Get-IsoZ $i.updatedAt
        blockers    = @($x.Blockers)
        project     = $x.Project
        type        = $x.Type
        status      = $x.Status
        priority    = $x.Prio
        excerpt     = $x.Excerpt
    }
})
$json = ConvertTo-Json -InputObject $jsonArr -Depth 5 -Compress
$json = $json -replace '</', '<\/'
Add "<script type=""application/json"" id=""issue-data"">$json</script>"

Add '<div id="tip"></div>'
Add @'
<script>
  // Chart tooltips (hover layer for the server-rendered SVGs).
  var tip = document.getElementById('tip');
  document.querySelectorAll('[data-tip]').forEach(function (el) {
    el.addEventListener('mousemove', function (e) {
      tip.textContent = el.dataset.tip;
      tip.style.display = 'block';
      tip.style.left = Math.min(e.clientX + 12, window.innerWidth - tip.offsetWidth - 8) + 'px';
      tip.style.top = (e.clientY + 14) + 'px';
    });
    el.addEventListener('mouseleave', function () { tip.style.display = 'none'; });
  });

  // Interactive filter layer over the embedded issue data. Everything below only
  // hides/shows server-rendered rows - with JS disabled the full page still reads.
  (function () {
    var dataEl = document.getElementById('issue-data');
    if (!dataEl) return;
    var DATA;
    try { DATA = JSON.parse(dataEl.textContent); } catch (err) { return; }
    var M = {};
    DATA.forEach(function (i) { M[i.number] = i; });

    var groups = ['project', 'status', 'priority', 'type'];
    var active = { project: {}, status: {}, priority: {}, type: {} };
    var q = '';
    var win = 30;

    function valueOf(i, g) {
      if (g === 'status') return i.state === 'CLOSED' ? 'closed' : (i.status || 'none');
      return i[g] || 'none';
    }
    function anyActive(g) {
      for (var k in active[g]) { if (active[g][k]) return true; }
      return false;
    }
    function matches(i) {
      for (var gi = 0; gi < groups.length; gi++) {
        var g = groups[gi];
        if (anyActive(g) && !active[g][valueOf(i, g)]) return false;
      }
      if (q) {
        var hay = ('#' + i.number + ' ' + i.title).toLowerCase();
        if (hay.indexOf(q) === -1) return false;
      }
      return true;
    }

    function updateDone(ul) {
      var done = 0, np = 0;
      ul.querySelectorAll('li.irow').forEach(function (r) {
        if (!r.hidden) { if (r.hasAttribute('data-np')) np++; else done++; }
      });
      var sum = document.getElementById('donesum');
      if (sum) {
        sum.textContent = done + ' completed in last ' + win + ' days' +
          (np ? ' · ' + np + ' not planned (dimmed, excluded from count)' : '');
      }
    }

    function apply() {
      var tot = {}, vis = {};
      document.querySelectorAll('[data-filtersect]').forEach(function (card) {
        var cardRows = 0, cardVis = 0;
        card.querySelectorAll('ul.filterable').forEach(function (ul) {
          var completed = ul.hasAttribute('data-completed');
          var ulVis = 0;
          ul.querySelectorAll('li.irow').forEach(function (r) {
            var n = +r.getAttribute('data-n');
            var i = M[n];
            if (completed && +r.getAttribute('data-days') > win) { r.hidden = true; return; }
            cardRows++; tot[n] = 1;
            var ok = i ? matches(i) : true;
            r.hidden = !ok;
            if (ok) { ulVis++; cardVis++; vis[n] = 1; }
          });
          var pg = ul.closest('.pgroup');
          if (pg) pg.hidden = (ulVis === 0);
          if (completed) updateDone(ul);
        });
        var je = card.querySelector('.jsempty');
        if (je) je.hidden = !(cardRows > 0 && cardVis === 0);
      });
      var showing = document.getElementById('showing');
      if (showing) {
        showing.textContent = 'showing ' + Object.keys(vis).length + ' of ' +
          Object.keys(tot).length + ' issues';
      }
    }

    // Build chips from the values actually present in the rendered rows.
    var values = { project: {}, status: {}, priority: {}, type: {} };
    document.querySelectorAll('ul.filterable li.irow').forEach(function (r) {
      var i = M[+r.getAttribute('data-n')];
      if (!i) return;
      groups.forEach(function (g) { values[g][valueOf(i, g)] = true; });
    });
    var order = {
      status: ['inbox', 'ready', 'in-progress', 'blocked', 'waiting', 'review', 'closed', 'none'],
      priority: ['p0', 'p1', 'p2', 'p3', 'none']
    };
    var chipbox = document.getElementById('chips');
    groups.forEach(function (g) {
      var vals = Object.keys(values[g]);
      if (!vals.length) return;
      if (order[g]) { vals.sort(function (a, b) { return order[g].indexOf(a) - order[g].indexOf(b); }); }
      else { vals.sort(); }
      var div = document.createElement('div');
      div.className = 'chipgroup';
      var lab = document.createElement('span');
      lab.className = 'glabel';
      lab.textContent = g;
      div.appendChild(lab);
      vals.forEach(function (v) {
        var b = document.createElement('button');
        b.type = 'button';
        b.className = 'chip';
        b.textContent = (v === 'none') ? '(no ' + g + ')' : v;
        b.setAttribute('aria-pressed', 'false');
        b.addEventListener('click', function () {
          active[g][v] = !active[g][v];
          b.setAttribute('aria-pressed', active[g][v] ? 'true' : 'false');
          apply();
        });
        div.appendChild(b);
      });
      chipbox.appendChild(div);
    });

    document.getElementById('q').addEventListener('input', function () {
      q = this.value.trim().toLowerCase();
      apply();
    });
    document.getElementById('clear').addEventListener('click', function () {
      groups.forEach(function (g) { active[g] = {}; });
      q = '';
      document.getElementById('q').value = '';
      document.querySelectorAll('.chip[aria-pressed="true"]').forEach(function (c) {
        c.setAttribute('aria-pressed', 'false');
      });
      apply();
    });
    document.querySelectorAll('.wbtn').forEach(function (b) {
      b.addEventListener('click', function () {
        win = +b.getAttribute('data-w');
        document.querySelectorAll('.wbtn').forEach(function (o) {
          o.setAttribute('aria-pressed', o === b ? 'true' : 'false');
        });
        apply();
      });
    });

    document.getElementById('filterbar').hidden = false;
    document.querySelectorAll('.wbtns').forEach(function (w) { w.hidden = false; });
    apply();
  })();
</script>
'@
if (-not $Fragment) { Add '</body></html>' }

$dir = Split-Path -Parent $Out
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
[System.IO.File]::WriteAllText($Out, ($sb.ToString() -replace "`r`n", "`n"))
$mode = if ($Fragment) { 'fragment' } else { 'page' }
Write-Host "wrote $Out ($mode, $([Math]::Round((Get-Item $Out).Length / 1kb)) KB, $($issues.Count) issue(s))" -ForegroundColor Green
exit 0
