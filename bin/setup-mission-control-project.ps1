#!/usr/bin/env pwsh
<#
.SYNOPSIS
Create or repair the personal Work Trek GitHub Project.

.DESCRIPTION
Idempotently creates the private user Project, links the Work Trek repository,
backfills every open issue, configures the planning-only Status options, and creates the
saved label-driven table and board views.

GitHub issue labels remain canonical. The Project Status field is deliberately used only
as a human planning horizon: This week, Next, or Later. GitHub does not expose creation of
the auto-add workflow through GraphQL, so that one step stays manual (Project settings ->
Workflows -> Auto-add to project).

.EXAMPLE
./bin/setup-mission-control-project.ps1
./bin/setup-mission-control-project.ps1 -VerifyOnly

#>
[CmdletBinding()]
param(
    [string] $Owner = '{{GITHUB_OWNER}}',
    [string] $Repository = '{{GITHUB_OWNER}}/{{CONTROL_PLANE_REPO}}',
    [string] $Title = 'Work Trek',
    [switch] $VerifyOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host 'setup-mission-control-project requires PowerShell 7+ (pwsh).' -ForegroundColor Red
    exit 1
}

function Write-Head { param([string] $Text) Write-Host ''; Write-Host "== $Text" -ForegroundColor Cyan }
function Write-Ok   { param([string] $Text) Write-Host "  ok    $Text" -ForegroundColor Green }
function Write-Warn { param([string] $Text) Write-Host "  warn  $Text" -ForegroundColor Yellow }
function Write-Bad  { param([string] $Text) $script:Problems++; Write-Host "  FAIL  $Text" -ForegroundColor Red }
function Write-Note { param([string] $Text) Write-Host "        $Text" -ForegroundColor DarkGray }

function Invoke-GhJson {
    param([Parameter(Mandatory)] [string[]] $Arguments)

    $raw = @(& gh @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    $text = ($raw | ForEach-Object { "$_" }) -join "`n"
    if ($exitCode -ne 0) {
        throw "gh $($Arguments -join ' ') failed: $text"
    }
    if (-not $text.Trim()) { return $null }
    return ($text | ConvertFrom-Json -Depth 100)
}

function Invoke-GhText {
    param([Parameter(Mandatory)] [string[]] $Arguments)

    $raw = @(& gh @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    $text = ($raw | ForEach-Object { "$_" }) -join "`n"
    if ($exitCode -ne 0) {
        throw "gh $($Arguments -join ' ') failed: $text"
    }
    return $text
}

function Invoke-GraphQl {
    param(
        [Parameter(Mandatory)] [string] $Query,
        [hashtable] $Variables = @{}
    )

    # JSON stdin handles nested GraphQL input safely and avoids interpolating API data into
    # query documents. Issue content is never read or executed by this script.
    $payload = [ordered]@{ query = $Query; variables = $Variables } |
        ConvertTo-Json -Depth 30 -Compress
    $raw = @($payload | & gh api graphql --input - 2>&1)
    $exitCode = $LASTEXITCODE
    $text = ($raw | ForEach-Object { "$_" }) -join "`n"
    if ($exitCode -ne 0) { throw "gh api graphql failed: $text" }

    $result = $text | ConvertFrom-Json -Depth 100
    if ($result.PSObject.Properties['errors'] -and $result.errors) {
        throw (($result.errors | ForEach-Object { $_.message }) -join '; ')
    }
    return $result.data
}

function Get-ProjectState {
    param([int] $Number)

    $query = @'
query($login:String!,$number:Int!){
  user(login:$login){
    projectV2(number:$number){
      id number title url closed public shortDescription readme
      repositories(first:100){nodes{nameWithOwner}}
      fields(first:100){nodes{
        __typename
        ... on ProjectV2Field{id name dataType}
        ... on ProjectV2IterationField{id name dataType}
        ... on ProjectV2MultiSelectField{id name dataType}
        ... on ProjectV2SingleSelectField{id name dataType options{id name color description}}
      }}
      views(first:100){nodes{
        id number name layout filter
        fields(first:100){nodes{
          ... on ProjectV2Field{id name}
          ... on ProjectV2IterationField{id name}
          ... on ProjectV2MultiSelectField{id name}
          ... on ProjectV2SingleSelectField{id name}
        }}
        verticalGroupByFields(first:10){nodes{
          ... on ProjectV2Field{id name}
          ... on ProjectV2IterationField{id name}
          ... on ProjectV2MultiSelectField{id name}
          ... on ProjectV2SingleSelectField{id name}
        }}
      }}
    }
  }
}
'@
    $data = Invoke-GraphQl -Query $query -Variables @{ login = $Owner; number = $Number }
    if (-not $data.user.projectV2) {
        throw "Project #$Number was not found under user '$Owner'."
    }
    return $data.user.projectV2
}

function Test-SequenceEqual {
    param([object[]] $Actual, [object[]] $Expected)
    return (($Actual -join "`u{001f}") -ceq ($Expected -join "`u{001f}"))
}

function Get-VisibleFieldNames {
    param($View)
    return @($View.fields.nodes | ForEach-Object { $_.name })
}

function Get-ProjectItems {
    param([int] $Number)
    $result = Invoke-GhJson -Arguments @(
        'project', 'item-list', "$Number", '--owner', $Owner,
        '--limit', '1000', '--format', 'json'
    )
    if ($result.totalCount -gt 1000) {
        throw "Project has $($result.totalCount) items; the 1000-item verification limit is incomplete."
    }
    return $result
}

$ProjectDescription = 'Human view of Work Trek issues; GitHub labels remain canonical.'
$ProjectReadme = @'
Human-facing views over {0} issues. GitHub issue labels remain canonical for workflow
status, type, priority, area, project, and gating; agents do not read Project fields. The Project
field named Status is used only as a human planning horizon: This week, Next, or Later. Moving a
card schedules attention and does not change issue workflow state.

Recreate or verify this Project with `./bin/setup-mission-control-project.ps1`. The
auto-add workflow is UI-only: Project settings -> Workflows -> Auto-add to project.
'@ -f $Repository

$DesiredOptions = @(
    [ordered]@{ name = 'This week'; color = 'GREEN'; description = 'Human planning only; work to look at this week' },
    [ordered]@{ name = 'Next';      color = 'BLUE';  description = 'Human planning only; likely next' },
    [ordered]@{ name = 'Later';     color = 'GRAY';  description = 'Human planning only; not scheduled now' }
)

$TableFields = @('Title', 'Labels', 'Linked pull requests', 'Parent issue', 'Sub-issues progress', 'Updated')
$BoardFields = @('Title', 'Labels', 'Parent issue', 'Updated')
$DesiredViews = @(
    [pscustomobject]@{ Name = 'Active';      Layout = 'TABLE_LAYOUT'; Filter = 'is:open label:"status:ready","status:in-progress","status:review"'; Fields = $TableFields },
    [pscustomobject]@{ Name = 'Stuck';       Layout = 'TABLE_LAYOUT'; Filter = 'is:open label:"status:blocked","status:waiting"'; Fields = $TableFields },
    [pscustomobject]@{ Name = 'Triage';      Layout = 'TABLE_LAYOUT'; Filter = 'is:open label:"status:inbox"'; Fields = $TableFields },
    [pscustomobject]@{ Name = 'Decisions';   Layout = 'TABLE_LAYOUT'; Filter = 'is:open label:"type:decision"'; Fields = $TableFields },
    [pscustomobject]@{ Name = 'Initiatives'; Layout = 'TABLE_LAYOUT'; Filter = 'is:open label:"type:initiative"'; Fields = $TableFields },
    [pscustomobject]@{ Name = 'Plan';        Layout = 'BOARD_LAYOUT'; Filter = 'is:open -label:"status:inbox" -label:"type:initiative"'; Fields = $BoardFields }
)

$script:Problems = 0
Write-Host ''
Write-Host 'Work Trek - GitHub Project setup' -ForegroundColor White
Write-Note "mode: $(if ($VerifyOnly) { 'verify only' } else { 'create or repair' })"

try {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw 'gh is required but was not found on PATH.'
    }

    Write-Head 'Project'
    try {
        $projectList = Invoke-GhJson -Arguments @(
            'project', 'list', '--owner', $Owner, '--limit', '100', '--closed', '--format', 'json'
        )
    }
    catch {
        throw "$($_.Exception.Message)`nRun: gh auth refresh -s project"
    }

    $matches = @($projectList.projects | Where-Object { $_.title -ceq $Title })
    if ($matches.Count -gt 1) {
        throw "More than one user Project is titled '$Title'; refusing to choose by intuition."
    }
    if ($matches.Count -eq 0) {
        if ($VerifyOnly) {
            Write-Bad "user Project '$Title' does not exist"
            exit 1
        }
        $null = Invoke-GhJson -Arguments @(
            'project', 'create', '--owner', $Owner, '--title', $Title, '--format', 'json'
        )
        $projectList = Invoke-GhJson -Arguments @(
            'project', 'list', '--owner', $Owner, '--limit', '100', '--closed', '--format', 'json'
        )
        $matches = @($projectList.projects | Where-Object { $_.title -ceq $Title })
        if ($matches.Count -ne 1) { throw "Created '$Title' but could not resolve it uniquely." }
        Write-Ok "created '$Title'"
    }

    $projectNumber = [int]$matches[0].number
    $project = Get-ProjectState -Number $projectNumber
    Write-Ok "resolved $($project.url)"

    if (-not $VerifyOnly) {
        $metadataDrift = $project.closed -or $project.public -or
            $project.shortDescription -cne $ProjectDescription -or
            ([string]$project.readme).Trim() -cne $ProjectReadme.Trim()
        if ($metadataDrift) {
            $metadataMutation = @'
mutation($project:ID!,$title:String!,$description:String!,$readme:String!){
  updateProjectV2(input:{
    projectId:$project,title:$title,shortDescription:$description,readme:$readme,
    closed:false,public:false
  }){projectV2{id}}
}
'@
            $null = Invoke-GraphQl -Query $metadataMutation -Variables @{
                project = $project.id
                title = $Title
                description = $ProjectDescription
                readme = $ProjectReadme
            }
            Write-Ok 'reconciled private/open metadata and README'
        }

        $linked = @($project.repositories.nodes | Where-Object { $_.nameWithOwner -ceq $Repository })
        if ($linked.Count -eq 0) {
            $null = Invoke-GhText -Arguments @(
                'project', 'link', "$projectNumber", '--owner', $Owner, '-R', $Repository
            )
            Write-Ok "linked $Repository"
        }
    }

    Write-Head 'Open issue backfill'
    $openIssues = @(Invoke-GhJson -Arguments @(
        'issue', 'list', '-R', $Repository, '--state', 'open', '--limit', '1000',
        '--json', 'number,url'
    ))
    if ($openIssues.Count -ge 1000) {
        throw 'Open-issue limit (1000) was reached; refusing an incomplete backfill.'
    }

    $items = Get-ProjectItems -Number $projectNumber
    $itemUrls = @($items.items | ForEach-Object { $_.content.url } | Where-Object { $_ })
    $missingIssues = @($openIssues | Where-Object { $itemUrls -cnotcontains $_.url })
    if (-not $VerifyOnly) {
        foreach ($issue in $missingIssues) {
            $null = Invoke-GhText -Arguments @(
                'project', 'item-add', "$projectNumber", '--owner', $Owner, '--url', $issue.url
            )
            Write-Ok "added #$($issue.number)"
        }
    }
    if ($missingIssues.Count -eq 0) { Write-Ok "all $($openIssues.Count) open issues are present" }

    Write-Head 'Planning field'
    $project = Get-ProjectState -Number $projectNumber
    $statusFields = @($project.fields.nodes | Where-Object {
        $_.__typename -eq 'ProjectV2SingleSelectField' -and $_.name -ceq 'Status'
    })
    if ($statusFields.Count -ne 1) {
        throw "Expected exactly one single-select field named Status; found $($statusFields.Count)."
    }
    $statusField = $statusFields[0]
    $currentOptions = @($statusField.options)
    $optionsMatch = $currentOptions.Count -eq $DesiredOptions.Count
    for ($i = 0; $optionsMatch -and $i -lt $DesiredOptions.Count; $i++) {
        $want = $DesiredOptions[$i]
        $have = $currentOptions[$i]
        $optionsMatch = $have.name -ceq $want.name -and
            $have.color -ceq $want.color -and $have.description -ceq $want.description
    }

    if (-not $VerifyOnly -and -not $optionsMatch) {
        # Preserve option IDs by matching desired names first, then by position. Preserving IDs
        # keeps existing planning assignments intact across repeat runs and schema repairs.
        $usedIds = [System.Collections.Generic.HashSet[string]]::new()
        $optionInputs = @()
        for ($i = 0; $i -lt $DesiredOptions.Count; $i++) {
            $want = $DesiredOptions[$i]
            $source = $currentOptions | Where-Object { $_.name -ceq $want.name } | Select-Object -First 1
            if (-not $source -and $i -lt $currentOptions.Count -and
                -not $usedIds.Contains([string]$currentOptions[$i].id)) {
                $source = $currentOptions[$i]
            }
            $entry = [ordered]@{
                name = $want.name
                color = $want.color
                description = $want.description
            }
            if ($source) {
                $entry.id = [string]$source.id
                [void]$usedIds.Add([string]$source.id)
            }
            $optionInputs += $entry
        }

        $fieldMutation = @'
mutation($field:ID!,$options:[ProjectV2SingleSelectFieldOptionInput!]!){
  updateProjectV2Field(input:{fieldId:$field,singleSelectOptions:$options}){
    projectV2Field{... on ProjectV2SingleSelectField{id}}
  }
}
'@
        $null = Invoke-GraphQl -Query $fieldMutation -Variables @{
            field = $statusField.id
            options = $optionInputs
        }
        Write-Ok 'set Status planning buckets: This week, Next, Later'
    }
    elseif ($optionsMatch) { Write-Ok 'planning buckets match' }

    Write-Head 'Saved views'
    $project = Get-ProjectState -Number $projectNumber
    $fieldIdByName = @{}
    foreach ($field in $project.fields.nodes) {
        if ($field.name -and -not $fieldIdByName.ContainsKey([string]$field.name)) {
            $fieldIdByName[[string]$field.name] = [string]$field.id
        }
    }
    foreach ($fieldName in @($TableFields + $BoardFields | Select-Object -Unique)) {
        if (-not $fieldIdByName.ContainsKey($fieldName)) {
            throw "Required Project field '$fieldName' was not found."
        }
    }

    if (-not $VerifyOnly) {
        $knownViews = @($project.views.nodes)
        foreach ($desired in $DesiredViews) {
            $matchesByName = @($knownViews | Where-Object { $_.name -ceq $desired.Name })
            if ($matchesByName.Count -gt 1) {
                throw "More than one saved view is named '$($desired.Name)'."
            }
            $view = if ($matchesByName.Count -eq 1) { $matchesByName[0] } else { $null }

            # A new blank Project starts with View 1. Reuse it for Active instead of leaving
            # a meaningless extra tab behind.
            if (-not $view -and $desired.Name -eq 'Active') {
                $defaultViews = @($knownViews | Where-Object { $_.name -ceq 'View 1' })
                if ($defaultViews.Count -eq 1) { $view = $defaultViews[0] }
            }

            $visibleIds = @($desired.Fields | ForEach-Object { $fieldIdByName[$_] })
            if (-not $view) {
                $createViewMutation = @'
mutation($project:ID!,$name:String!,$layout:ProjectV2ViewLayout!,$fields:[ID!]!){
  createProjectV2View(input:{
    projectId:$project,name:$name,layout:$layout,
    configuration:{visibleFieldIds:$fields}
  }){projectV2View{id name number layout filter}}
}
'@
                $created = Invoke-GraphQl -Query $createViewMutation -Variables @{
                    project = $project.id
                    name = $desired.Name
                    layout = $desired.Layout
                    fields = $visibleIds
                }
                $view = $created.createProjectV2View.projectV2View
                $knownViews += $view
            }

            $actualFields = if ($view.PSObject.Properties['fields']) {
                @(Get-VisibleFieldNames -View $view)
            } else { @() }
            $viewDrift = $view.name -cne $desired.Name -or $view.layout -cne $desired.Layout -or
                $view.filter -cne $desired.Filter -or
                -not (Test-SequenceEqual -Actual $actualFields -Expected $desired.Fields)
            if ($viewDrift) {
                $updateViewMutation = @'
mutation($view:ID!,$name:String!,$layout:ProjectV2ViewLayout!,$filter:String!,$fields:[ID!]!){
  updateProjectV2View(input:{
    viewId:$view,name:$name,layout:$layout,filter:$filter,
    configuration:{visibleFieldIds:$fields}
  }){projectV2View{id}}
}
'@
                $null = Invoke-GraphQl -Query $updateViewMutation -Variables @{
                    view = $view.id
                    name = $desired.Name
                    layout = $desired.Layout
                    filter = $desired.Filter
                    fields = $visibleIds
                }
                Write-Ok "reconciled $($desired.Name) ($($desired.Layout))"
            }
            else { Write-Ok "$($desired.Name) matches" }
        }
    }

    Write-Head 'Verification'
    $project = Get-ProjectState -Number $projectNumber
    # Project item writes are eventually consistent. Retry only the authoritative read used
    # for verification; five one-second attempts keep a successful add from looking broken.
    $missingIssues = @()
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        $items = Get-ProjectItems -Number $projectNumber
        $itemUrls = @($items.items | ForEach-Object { $_.content.url } | Where-Object { $_ })
        $missingIssues = @($openIssues | Where-Object { $itemUrls -cnotcontains $_.url })
        if ($missingIssues.Count -eq 0 -or $attempt -eq 5) { break }
        Start-Sleep -Seconds 1
    }

    if ($project.closed) { Write-Bad 'Project is closed' } else { Write-Ok 'Project is open' }
    if ($project.public) { Write-Bad 'Project is public' } else { Write-Ok 'Project is private' }
    if ($project.shortDescription -cne $ProjectDescription) { Write-Bad 'short description drifted' }
    if (([string]$project.readme).Trim() -cne $ProjectReadme.Trim()) { Write-Bad 'Project README drifted' }
    if (@($project.repositories.nodes | Where-Object { $_.nameWithOwner -ceq $Repository }).Count -ne 1) {
        Write-Bad "$Repository is not linked"
    }
    else { Write-Ok "$Repository is linked" }

    if ($missingIssues.Count -gt 0) {
        Write-Bad "missing open issues: $($missingIssues.number -join ', ')"
    }
    else { Write-Ok "all $($openIssues.Count) open issues are present" }

    $statusField = @($project.fields.nodes | Where-Object {
        $_.__typename -eq 'ProjectV2SingleSelectField' -and $_.name -ceq 'Status'
    }) | Select-Object -First 1
    if (-not $statusField) { Write-Bad 'Status field is missing' }
    else {
        $currentOptions = @($statusField.options)
        $optionsMatch = $currentOptions.Count -eq $DesiredOptions.Count
        for ($i = 0; $optionsMatch -and $i -lt $DesiredOptions.Count; $i++) {
            $want = $DesiredOptions[$i]
            $have = $currentOptions[$i]
            $optionsMatch = $have.name -ceq $want.name -and
                $have.color -ceq $want.color -and $have.description -ceq $want.description
        }
        if ($optionsMatch) { Write-Ok 'planning buckets match' }
        else { Write-Bad 'Status planning buckets drifted' }
    }

    foreach ($desired in $DesiredViews) {
        $views = @($project.views.nodes | Where-Object { $_.name -ceq $desired.Name })
        if ($views.Count -ne 1) {
            Write-Bad "expected one '$($desired.Name)' view; found $($views.Count)"
            continue
        }
        $view = $views[0]
        $actualFields = @(Get-VisibleFieldNames -View $view)
        if ($view.layout -cne $desired.Layout -or $view.filter -cne $desired.Filter -or
            -not (Test-SequenceEqual -Actual $actualFields -Expected $desired.Fields)) {
            Write-Bad "$($desired.Name) view configuration drifted"
        }
        else { Write-Ok "$($desired.Name) view matches" }

        if ($desired.Name -eq 'Plan') {
            $columns = @($view.verticalGroupByFields.nodes | ForEach-Object { $_.name })
            if (-not (Test-SequenceEqual -Actual $columns -Expected @('Status'))) {
                Write-Bad 'Plan board column field is not Status; select it in the Project UI'
            }
            else { Write-Ok 'Plan board columns use Status planning buckets' }
        }
    }

    Write-Host ''
    if ($script:Problems -gt 0) {
        Write-Host "Project verification failed: $script:Problems problem(s)." -ForegroundColor Red
        exit 1
    }

    Write-Host "Project verified: $($project.url)" -ForegroundColor Green
    Write-Warn 'GitHub exposes no create/update mutation for Project auto-add workflows.'
    Write-Note 'In the Project UI: Workflows -> Auto-add to project -> repository -> is:open.'
}
catch {
    Write-Host ''
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
