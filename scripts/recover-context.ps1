[CmdletBinding()]
param(
    [Parameter()]
    [string]$Root = ".",

    [Parameter()]
    [string]$Task = "",

    [Parameter()]
    [string]$Topic = "",

    [Parameter()]
    [ValidateRange(2000, 50000)]
    [int]$MaxChars = 12000,

    [Parameter()]
    [ValidateRange(1, 5)]
    [int]$ProgressEntries = 1
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-MarkdownSections {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return @()
    }

    $lines = @(Get-Content -LiteralPath $Path)
    $sections = [System.Collections.Generic.List[object]]::new()
    $currentTitle = ""
    $currentLines = [System.Collections.Generic.List[string]]::new()

    foreach ($line in $lines) {
        if ($line -match '^##\s+(.+?)\s*$') {
            if ($currentTitle) {
                $sections.Add([PSCustomObject]@{
                    Title = $currentTitle
                    Text = ($currentLines -join [Environment]::NewLine).Trim()
                })
            }
            $currentTitle = $Matches[1]
            $currentLines = [System.Collections.Generic.List[string]]::new()
            $currentLines.Add($line)
            continue
        }

        if ($currentTitle) {
            $currentLines.Add($line)
        }
    }

    if ($currentTitle) {
        $sections.Add([PSCustomObject]@{
            Title = $currentTitle
            Text = ($currentLines -join [Environment]::NewLine).Trim()
        })
    }

    return @($sections)
}

function Select-MatchingSections {
    param(
        [Parameter(Mandatory)][object[]]$Sections,
        [Parameter(Mandatory)][string[]]$Terms,
        [int]$Limit = 1,
        [switch]$Newest
    )

    $usableTerms = @($Terms | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($usableTerms.Count -eq 0) {
        $matches = @($Sections)
    }
    else {
        $matches = @($Sections | Where-Object {
            $candidate = $_.Title + [Environment]::NewLine + $_.Text
            foreach ($term in $usableTerms) {
                if ($candidate.IndexOf($term, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    return $true
                }
            }
            return $false
        })
    }

    if ($Newest) {
        return @($matches | Select-Object -Last $Limit)
    }
    return @($matches | Select-Object -First $Limit)
}

function Format-Block {
    param(
        [Parameter(Mandatory)][string]$Title,
        [AllowEmptyCollection()]
        [string[]]$Lines = @()
    )

    $block = [System.Collections.Generic.List[string]]::new()
    $block.Add("## $Title")
    if ($Lines.Count -eq 0) {
        $block.Add("(none)")
    }
    else {
        foreach ($line in $Lines) {
            $block.Add($line)
        }
    }
    $block.Add("")
    return $block.ToArray()
}

$resolvedRoot = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Root).Path)
$planPath = Join-Path $resolvedRoot "task_plan.md"
$progressPath = Join-Path $resolvedRoot "progress.md"
$findingsPath = Join-Path $resolvedRoot "findings.md"
$output = [System.Collections.Generic.List[string]]::new()

$output.Add("# Planning Context Snapshot")
$output.Add("")
$output.Add("root: $resolvedRoot")
$output.Add("task: $(if ($Task) { $Task } else { '(unspecified)' })")
$output.Add("topic: $(if ($Topic) { $Topic } else { '(unspecified)' })")
$output.Add("")

$planSections = @(Get-MarkdownSections -Path $planPath)
$planPattern = '^(Goal|Current Phase|Active Task|Constraints|Blockers|Next Step|Next Action|Relevant Files)$'
$selectedPlan = @($planSections | Where-Object { $_.Title -match $planPattern })
if ($selectedPlan.Count -eq 0 -and (Test-Path -LiteralPath $planPath -PathType Leaf)) {
    $selectedPlan = @($planSections | Select-Object -First 4)
}
foreach ($line in (Format-Block -Title "Current plan" -Lines @($selectedPlan | ForEach-Object { $_.Text }))) {
    $output.Add($line)
}

$terms = @($Task, $Topic)
$progressSections = @(Get-MarkdownSections -Path $progressPath)
$selectedProgress = @(Select-MatchingSections -Sections $progressSections -Terms $terms -Limit $ProgressEntries -Newest)
if ($selectedProgress.Count -eq 0 -and $progressSections.Count -gt 0) {
    $selectedProgress = @($progressSections | Select-Object -Last $ProgressEntries)
}
foreach ($line in (Format-Block -Title "Recent matching progress" -Lines @($selectedProgress | ForEach-Object { $_.Text }))) {
    $output.Add($line)
}

$findingSections = @(Get-MarkdownSections -Path $findingsPath)
$selectedFindings = @(Select-MatchingSections -Sections $findingSections -Terms $terms -Limit 3)
if ($selectedFindings.Count -eq 0 -and $findingSections.Count -gt 0) {
    $selectedFindings = @($findingSections | Select-Object -First 2)
}
foreach ($line in (Format-Block -Title "Relevant findings" -Lines @($selectedFindings | ForEach-Object { $_.Text }))) {
    $output.Add($line)
}

$gitLines = [System.Collections.Generic.List[string]]::new()
if (Get-Command git -ErrorAction SilentlyContinue) {
    $inside = & git -C $resolvedRoot rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -eq 0 -and $inside -eq "true") {
        $status = @(& git -C $resolvedRoot status --short 2>$null | Select-Object -First 30)
        $stat = @(& git -C $resolvedRoot diff --stat 2>$null | Select-Object -First 30)
        if ($status.Count -eq 0) {
            $gitLines.Add("working tree: clean")
        }
        else {
            $gitLines.Add("working tree:")
            foreach ($line in $status) { $gitLines.Add($line) }
        }
        if ($stat.Count -gt 0) {
            $gitLines.Add("diff stat:")
            foreach ($line in $stat) { $gitLines.Add($line) }
        }
    }
}
foreach ($line in (Format-Block -Title "Git summary" -Lines @($gitLines))) {
    $output.Add($line)
}

$rendered = ($output -join [Environment]::NewLine).TrimEnd()
if ($rendered.Length -gt $MaxChars) {
    $notice = [Environment]::NewLine + [Environment]::NewLine + "[truncated: context exceeded MaxChars=$MaxChars; inspect one referenced section at a time]"
    $keep = [Math]::Max(0, $MaxChars - $notice.Length)
    $rendered = $rendered.Substring(0, $keep) + $notice
}

Write-Output $rendered
