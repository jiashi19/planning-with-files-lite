[CmdletBinding()]
param(
    [Parameter()]
    [string]$Root = "."
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$resolvedRoot = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Root).Path)
$templateRoot = Join-Path (Split-Path -Parent $PSScriptRoot) "templates"
$created = [System.Collections.Generic.List[string]]::new()
$preserved = [System.Collections.Generic.List[string]]::new()

foreach ($name in @("task_plan.md", "findings.md", "progress.md")) {
    $source = Join-Path $templateRoot $name
    $destination = Join-Path $resolvedRoot $name

    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Template missing: $source"
    }

    if (Test-Path -LiteralPath $destination) {
        $preserved.Add($destination)
        continue
    }

    Copy-Item -LiteralPath $source -Destination $destination
    $created.Add($destination)
}

Write-Output "PLANNING_INIT_OK root=$resolvedRoot created=$($created.Count) preserved=$($preserved.Count)"
foreach ($path in $created) {
    Write-Output "created: $path"
}
foreach ($path in $preserved) {
    Write-Output "preserved: $path"
}
