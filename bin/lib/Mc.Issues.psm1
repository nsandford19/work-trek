#!/usr/bin/env pwsh
<#
.SYNOPSIS
Shared live-issue fetch for every generated view (dashboard, issue cache).

.DESCRIPTION
One fetch, one field list, one pagination story. build-dashboard.ps1 and
build-issue-cache.ps1 both consume this so the two outputs can never diverge on what
"all issues" means. Keep any new consumer on this function instead of writing another
`gh issue list` variant.
#>

Set-StrictMode -Version Latest

function Get-McRepoSlug {
    param([Parameter(Mandatory)][string] $RepoRoot)
    $slug = 'nsandford19/work-trek'
    $url = (& git -C $RepoRoot remote get-url origin 2>$null)
    if ($url -and "$url" -match '[:/]([^/:]+/[^/]+?)(\.git)?/?$') { $slug = $Matches[1] }
    return $slug
}

function Get-McIssueSnapshot {
    <#
    Fetches ALL issues (open and closed, bodies included) in one gh call.
    Throws on failure; callers decide how to report it.
    #>
    param([Parameter(Mandatory)][string] $Slug)

    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw 'gh not found - live issue state is unavailable.'
    }

    # gh emits UTF-8, but PowerShell decodes native output with the CONSOLE's codepage;
    # a non-UTF-8 console turns emoji in titles/bodies into mojibake (same fix as
    # history sync). Force UTF-8 for this call only and restore afterwards.
    $prevEncoding = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $raw = & gh issue list -R $Slug --state all --limit 1000 `
            --json number,title,labels,state,stateReason,assignees,createdAt,closedAt,updatedAt,url,body 2>&1
        if ($LASTEXITCODE -ne 0) { throw "gh issue list failed: $raw" }
    }
    finally {
        [Console]::OutputEncoding = $prevEncoding
    }
    return @("$raw" | ConvertFrom-Json)
}

Export-ModuleMember -Function Get-McRepoSlug, Get-McIssueSnapshot
