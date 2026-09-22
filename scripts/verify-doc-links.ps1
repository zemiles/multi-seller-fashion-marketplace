[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$failures = @()
$files = @(Get-ChildItem $repositoryRoot -Recurse -Filter '*.md' -File | Where-Object {
    $_.FullName -notmatch '[\\/](build|\.gradle|\.git|node_modules)[\\/]'
})
foreach ($file in $files) {
    $insideFence = $false
    foreach ($line in Get-Content $file.FullName -Encoding UTF8) {
        if ($line -match '^\s*```') { $insideFence = -not $insideFence; continue }
        if ($insideFence) { continue }
        foreach ($match in [regex]::Matches($line, '\[[^\]]+\]\(([^)]+)\)')) {
            $target = $match.Groups[1].Value.Trim('<', '>')
            if ($target -match '^(https?://|mailto:|#)') { continue }
            $path = ($target -split '#')[0]
            if (-not (Test-Path -LiteralPath (Join-Path $file.DirectoryName $path))) {
                $failures += "$($file.Name): broken link $target"
            }
        }
    }
    if ($insideFence) { $failures += "$($file.Name): unclosed code fence" }
}
if ($failures.Count) { throw ($failures -join "`n") }
Write-Output "$($files.Count) Markdown files: local links and code fences verified."
