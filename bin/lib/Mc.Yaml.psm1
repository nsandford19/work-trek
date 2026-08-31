# Mc.Yaml — a deliberately tiny YAML reader for the constrained subset used by
# Work Trek registries and Markdown front matter.
#
# WHY THIS EXISTS instead of powershell-yaml:
#   Zero external dependencies. A registry that cannot be read on a fresh machine
#   without `Install-Module` is a registry that fails exactly when it is needed most
#   (new laptop, offline, restricted network). The schema is constrained to match
#   (documented in machines/README.md#yaml-dialect) so a small parser is sufficient.
#
# SUPPORTED
#   key: scalar
#   key: 'single quoted'  |  key: "double quoted"
#   key: [a, b, c]                          flow sequence of simple scalars
#   key:                                    block mapping (nesting up to depth 3)
#     child: value
#   key:                                    block sequence of scalars
#     - item
#   key:                                    block sequence of mappings
#     - a: 1
#       b: 2
#   # comments, and blank lines
#
# NOT SUPPORTED (and rejected loudly, not silently mis-parsed)
#   tabs for indentation, anchors (&), aliases (*), merge keys (<<),
#   block scalars (| >), multi-document files, flow mappings ({ }),
#   complex keys, multi-line plain scalars.
#
# Values are returned as strings, except: true/false -> [bool], null/~/'' -> $null.
# Numbers stay strings on purpose — versions and zero-padded ids must not be mangled.

Set-StrictMode -Version Latest

function Convert-McScalar {
    param([string] $Raw)

    $v = $Raw.Trim()
    if ($v.Length -eq 0) { return $null }

    # Quoted: parse to the closing quote, take the inside literally. Only whitespace or a
    # trailing comment may follow the closing quote - anything else is an error, never a
    # silent fall-through to the unquoted path (which would keep the literal quotes).
    if ($v[0] -eq "'") {
        $i = 1
        while ($i -lt $v.Length) {
            if ($v[$i] -eq "'") {
                if ($i + 1 -lt $v.Length -and $v[$i + 1] -eq "'") { $i += 2; continue }  # '' escape
                break
            }
            $i++
        }
        if ($i -ge $v.Length) { throw "unterminated single-quoted scalar: $Raw" }
        $rest = $v.Substring($i + 1).Trim()
        if ($rest.Length -gt 0 -and -not $rest.StartsWith('#')) {
            throw "unexpected content after closing quote: '$Raw'"
        }
        return $v.Substring(1, $i - 1).Replace("''", "'")
    }
    if ($v[0] -eq '"') {
        $i = 1
        while ($i -lt $v.Length) {
            if ($v[$i] -eq '\' -and $i + 1 -lt $v.Length) { $i += 2; continue }  # skip escapes
            if ($v[$i] -eq '"') { break }
            $i++
        }
        if ($i -ge $v.Length) { throw "unterminated double-quoted scalar: $Raw" }
        $rest = $v.Substring($i + 1).Trim()
        if ($rest.Length -gt 0 -and -not $rest.StartsWith('#')) {
            throw "unexpected content after closing quote: '$Raw'"
        }
        return $v.Substring(1, $i - 1).Replace('\"', '"')
    }

    # Unquoted: a ' #' sequence starts a trailing comment.
    $hash = $v.IndexOf(' #')
    if ($hash -ge 0) { $v = $v.Substring(0, $hash).TrimEnd() }

    switch -Regex ($v) {
        '^(true|True|TRUE|yes|Yes)$'  { return $true }
        '^(false|False|FALSE|no|No)$' { return $false }
        '^(null|Null|NULL|~)$'        { return $null }
    }
    return $v
}

function Convert-McFlowSequence {
    param([string] $Raw)

    $inner = $Raw.Trim()
    $inner = $inner.Substring(1, $inner.Length - 2).Trim()
    if ($inner.Length -eq 0) { return @() }

    # Split on commas that are not inside quotes.
    $items = @()
    $buf = ''
    $quote = $null
    foreach ($ch in $inner.ToCharArray()) {
        if ($quote) {
            if ($ch -eq $quote) { $quote = $null }
            $buf += $ch
        }
        elseif ($ch -eq "'" -or $ch -eq '"') { $quote = $ch; $buf += $ch }
        elseif ($ch -eq ',') { $items += $buf; $buf = '' }
        else { $buf += $ch }
    }
    $items += $buf

    return @($items | ForEach-Object { Convert-McScalar $_ })
}

# Structural line model: indent, kind (key / key-empty / item / item-key), key, value.
function Get-McLines {
    param([string[]] $Lines, [string] $Path)

    $out = @()
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i]
        $no = $i + 1

        if ($line -match '^\s*$' -or $line -match '^\s*#') { continue }
        if ($line -match "^\s*\t" -or $line -match "^\t") {
            throw "${Path}:${no}: tab used for indentation; this dialect requires 2-space indents."
        }
        if ($line -match '^\s*---\s*$' -or $line -match '^\s*\.\.\.\s*$') {
            throw "${Path}:${no}: document separators are not supported."
        }
        if ($line -match '(^|\s)[&*]\w' -or $line -match '^\s*<<\s*:') {
            throw "${Path}:${no}: anchors, aliases and merge keys are not supported."
        }
        if ($line -match ':\s*[|>][-+0-9]*\s*$') {
            throw "${Path}:${no}: block scalars (| and >) are not supported; use a quoted single-line string."
        }

        $indent = ($line -replace '^( *).*$', '$1').Length
        if ($indent % 2 -ne 0) {
            throw "${Path}:${no}: indent of $indent spaces; this dialect requires multiples of 2."
        }
        $body = $line.Trim()

        if ($body -match '^-\s*(.*)$') {
            $rest = $Matches[1].Trim()
            if ($rest -match '^([A-Za-z0-9_.-]+):\s*(.*)$') {
                $out += [pscustomobject]@{
                    Indent = $indent; Kind = 'item-key'; Key = $Matches[1]
                    Value = $Matches[2]; Line = $no
                }
            }
            else {
                $out += [pscustomobject]@{
                    Indent = $indent; Kind = 'item'; Key = $null; Value = $rest; Line = $no
                }
            }
            continue
        }

        if ($body -match '^([^:#]+):\s*(.*)$') {
            $key = $Matches[1].Trim()
            $val = $Matches[2]
            $kind = if ($val.Trim().Length -eq 0) { 'key-empty' } else { 'key' }
            $out += [pscustomobject]@{
                Indent = $indent; Kind = $kind; Key = $key; Value = $val; Line = $no
            }
            continue
        }

        throw "${Path}:${no}: cannot parse '$body'. See machines/README.md#yaml-dialect."
    }
    return $out
}

function Read-McBlock {
    param(
        [object[]] $Nodes,
        [ref] $Index,
        [int] $Indent,
        [string] $Path,
        [int] $Depth = 1
    )

    if ($Depth -gt 4) {
        throw "${Path}: nesting deeper than the supported limit; flatten the structure."
    }

    # Decide once whether this block is a sequence or a mapping.
    $first = $Nodes[$Index.Value]
    $isSequence = $first.Kind -in @('item', 'item-key')

    if ($isSequence) {
        $list = [System.Collections.Generic.List[object]]::new()
        while ($Index.Value -lt $Nodes.Count) {
            $n = $Nodes[$Index.Value]
            if ($n.Indent -lt $Indent) { break }
            if ($n.Indent -gt $Indent) {
                throw "$Path`:$($n.Line): unexpected indentation inside a sequence."
            }
            if ($n.Kind -eq 'item') {
                $list.Add((Convert-McScalar $n.Value)) | Out-Null
                $Index.Value++
            }
            elseif ($n.Kind -eq 'item-key') {
                # A mapping whose first pair sits on the dash line. Its sibling keys are
                # indented two further (aligned under the key, not the dash).
                $map = [ordered]@{}
                $map[$n.Key] = if ($n.Value.Trim().Length -eq 0) { $null } else { Convert-McValue $n.Value }
                $childIndent = $n.Indent + 2
                $Index.Value++
                while ($Index.Value -lt $Nodes.Count -and
                       $Nodes[$Index.Value].Indent -eq $childIndent -and
                       $Nodes[$Index.Value].Kind -in @('key', 'key-empty')) {
                    $c = $Nodes[$Index.Value]
                    if ($map.Contains($c.Key)) {
                        throw "$Path`:$($c.Line): duplicate key '$($c.Key)'."
                    }
                    if ($c.Kind -eq 'key') {
                        $map[$c.Key] = Convert-McValue $c.Value
                        $Index.Value++
                    }
                    else {
                        $Index.Value++
                        $map[$c.Key] = Read-McNested -Nodes $Nodes -Index $Index -ParentIndent $c.Indent -Path $Path -Depth ($Depth + 1)
                    }
                }
                $list.Add($map) | Out-Null
            }
            else {
                throw "$Path`:$($n.Line): mapping key found where a sequence item was expected."
            }
        }
        return $list.ToArray()
    }

    $map = [ordered]@{}
    while ($Index.Value -lt $Nodes.Count) {
        $n = $Nodes[$Index.Value]
        if ($n.Indent -lt $Indent) { break }
        if ($n.Indent -gt $Indent) {
            throw "$Path`:$($n.Line): unexpected indentation; expected $Indent spaces."
        }
        if ($n.Kind -notin @('key', 'key-empty')) {
            throw "$Path`:$($n.Line): sequence item found where a mapping key was expected."
        }
        if ($map.Contains($n.Key)) {
            throw "$Path`:$($n.Line): duplicate key '$($n.Key)'."
        }
        if ($n.Kind -eq 'key') {
            $map[$n.Key] = Convert-McValue $n.Value
            $Index.Value++
        }
        else {
            $Index.Value++
            $map[$n.Key] = Read-McNested -Nodes $Nodes -Index $Index -ParentIndent $n.Indent -Path $Path -Depth ($Depth + 1)
        }
    }
    return $map
}

# A key with no inline value: either a nested block, or an explicit empty value.
function Read-McNested {
    param([object[]] $Nodes, [ref] $Index, [int] $ParentIndent, [string] $Path, [int] $Depth)

    if ($Index.Value -ge $Nodes.Count) { return $null }
    $next = $Nodes[$Index.Value]
    if ($next.Indent -le $ParentIndent) { return $null }
    return Read-McBlock -Nodes $Nodes -Index $Index -Indent $next.Indent -Path $Path -Depth $Depth
}

function Convert-McValue {
    param([string] $Raw)

    $v = $Raw.Trim()
    if ($v.StartsWith('[')) {
        if (-not $v.EndsWith(']')) {
            throw "unterminated flow sequence: '$Raw' (multi-line flow sequences are not supported)"
        }
        return Convert-McFlowSequence $v
    }
    if ($v.StartsWith('{')) {
        throw "flow mappings ({ }) are not supported: '$Raw'"
    }
    return Convert-McScalar $v
}

<#
.SYNOPSIS
Parse a constrained-subset YAML string into an ordered hashtable.
#>
function ConvertFrom-McYaml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Text,
        [string] $Path = '<string>'
    )

    $lines = $Text -split "`r?`n"
    $nodes = @(Get-McLines -Lines $lines -Path $Path)
    if ($nodes.Count -eq 0) { return [ordered]@{} }

    $i = 0
    $result = Read-McBlock -Nodes $nodes -Index ([ref] $i) -Indent $nodes[0].Indent -Path $Path
    if ($i -lt $nodes.Count) {
        throw "$Path`:$($nodes[$i].Line): unexpected content after the top-level block."
    }
    return $result
}

<#
.SYNOPSIS
Parse a constrained-subset YAML file.
#>
function Import-McYaml {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) { throw "file not found: $Path" }
    $text = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path))
    return ConvertFrom-McYaml -Text $text -Path $Path
}

<#
.SYNOPSIS
Split a Markdown file into its front matter (parsed) and body.

.DESCRIPTION
Returns an object with FrontMatter (ordered hashtable, or $null when absent) and Body.
Front matter must open on line 1 with '---' and close with a '---' line.
#>
function Get-McFrontMatter {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Path)

    $text = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path))
    $lines = $text -split "`r?`n"

    if ($lines.Count -eq 0 -or $lines[0].Trim() -ne '---') {
        return [pscustomobject]@{ FrontMatter = $null; Body = $text; Path = $Path }
    }

    $end = -1
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '---') { $end = $i; break }
    }
    if ($end -lt 0) { throw "${Path}: front matter opened with '---' but never closed." }

    $fmText = if ($end -gt 1) { ($lines[1..($end - 1)]) -join "`n" } else { '' }
    $body = if ($end + 1 -lt $lines.Count) { ($lines[($end + 1)..($lines.Count - 1)]) -join "`n" } else { '' }

    return [pscustomobject]@{
        FrontMatter = (ConvertFrom-McYaml -Text $fmText -Path $Path)
        Body        = $body
        Path        = $Path
    }
}

Export-ModuleMember -Function ConvertFrom-McYaml, Import-McYaml, Get-McFrontMatter
