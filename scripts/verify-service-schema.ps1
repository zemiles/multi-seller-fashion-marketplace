[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'generate-service-migrations.ps1')
$services = @('commerce-service', 'payment-service', 'settlement-service', 'discovery-data-service')
foreach ($service in $services) {
    $preview = Get-Content (Join-Path $repositoryRoot "build/schema-preview/$service/V1__service_owned_schema.sql") -Raw -Encoding UTF8
    $migrationRoot = Join-Path $repositoryRoot "$service/src/main/resources/db/migration"
    $effective = (Get-ChildItem $migrationRoot -Filter 'V*.sql' | Sort-Object Name | ForEach-Object {
        Get-Content $_.FullName -Raw -Encoding UTF8
    }) -join "`n"
    $tables = @([regex]::Matches($effective, 'CREATE TABLE marketplace\.(\w+)') | ForEach-Object { $_.Groups[1].Value })
    if (($tables | Sort-Object -Unique).Count -ne $tables.Count) { throw "$service has duplicate tables" }
    $expected = @([regex]::Matches($preview, 'ADD CONSTRAINT\s+(\w+)') | ForEach-Object { $_.Groups[1].Value })
    $actual = @([regex]::Matches($effective, 'ADD CONSTRAINT\s+(\w+)') | ForEach-Object { $_.Groups[1].Value })
    if (Compare-Object $expected $actual) { throw "$service is missing or has unexpected internal constraints" }
    foreach ($reference in [regex]::Matches($effective, 'REFERENCES marketplace\.(\w+)')) {
        if ($reference.Groups[1].Value -notin $tables) { throw "$service contains a cross-service FK" }
    }
    Write-Output "$service : $($tables.Count) tables, $($actual.Count) internal foreign keys verified"
}
