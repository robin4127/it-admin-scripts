#Requires -Version 7.0
<#
.SYNOPSIS
    Checks PowerShell syntax, comment-based help and PSScriptAnalyzer errors.
.DESCRIPTION
    Validates repository scripts without executing administrative scripts.
    Analyzer warnings are reported but not blocking.
.PARAMETER Root
    Repository root directory to validate.
.EXAMPLE
    ./.github/scripts/Test-PowerShellQuality.ps1
.NOTES
    Requires PowerShell 7+ and PSScriptAnalyzer.
    Read-only; no tenant connections are made.
#>
[CmdletBinding()]
param([string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path)
$ErrorActionPreference = 'Stop'
Import-Module PSScriptAnalyzer -ErrorAction Stop

$failures = [System.Collections.Generic.List[string]]::new()
$files = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Filter '*.ps1')
if ($files.Count -eq 0) { throw 'No scripts found' }

foreach ($file in $files) {
    Write-Host "Checking $($file.FullName)"
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName, [ref]$tokens, [ref]$errors
    )
    foreach ($err in $errors) {
        $failures.Add("$($file.Name): syntax: $($err.Message)")
    }

    $content = Get-Content -LiteralPath $file.FullName -Raw
    foreach ($section in @('SYNOPSIS','DESCRIPTION','EXAMPLE','NOTES')) {
        if ($content -notmatch "(?im)^\s*\.$section\b") {
            $failures.Add("$($file.Name): missing .$section")
        }
    }
    if ($ast.ParamBlock) {
        foreach ($parameter in $ast.ParamBlock.Parameters) {
            $name = $parameter.Name.VariablePath.UserPath
            if ($content -notmatch "(?im)^\s*\.PARAMETER\s+$([regex]::Escape($name))\s*$") {
                $failures.Add("$($file.Name): missing .PARAMETER $name")
            }
        }
    }
    foreach ($item in @(Invoke-ScriptAnalyzer -Path $file.FullName -Severity Error)) {
        $failures.Add("$($file.Name): $($item.RuleName): $($item.Message)")
    }
    foreach ($item in @(Invoke-ScriptAnalyzer -Path $file.FullName -Severity Warning)) {
        Write-Warning "$($file.Name): $($item.RuleName): $($item.Message)"
    }
}
if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ -ErrorAction Continue }
    throw "$($failures.Count) blocking PowerShell quality issues."
}
Write-Host "PowerShell quality passed for $($files.Count) scripts." -ForegroundColor Green
