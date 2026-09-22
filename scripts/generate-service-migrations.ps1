[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\build\schema-preview')
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$databaseRoot = Join-Path $repositoryRoot '..\..\database'
$sourceRoot = Join-Path $databaseRoot '_parts'

if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
    throw "Database source directory was not found: $sourceRoot"
}

# 서비스 경계는 합의한 1차 구조를 따릅니다.
# Commerce, Payment, Settlement, Discovery/Data 경계를 넘는 외래 키는 의도적으로
# 제외합니다. 참조 값은 외부 ID로 두고 서비스 계약과 이벤트로 동기화합니다.
$serviceTables = [ordered]@{
    'commerce-service' = @(
        'member', 'member_auth_identity', 'member_profile', 'shipping_address',
        'seller', 'seller_member', 'seller_document', 'seller_verification',
        'seller_settlement_account', 'brand', 'seller_brand_relation',
        'brand_registration_request', 'category', 'product', 'product_revision',
        'product_image', 'product_feature', 'option_group', 'option_value', 'sku',
        'sku_option_value', 'inventory', 'inventory_ledger',
        'cart', 'cart_item', 'checkout', 'checkout_shipping_group', 'checkout_item',
        'inventory_reservation', 'inventory_reservation_item', 'orders',
        'order_shipping_group', 'order_item', 'order_charge', 'order_state_event',
        'shipment', 'shipment_item', 'shipment_event', 'purchase_confirmation_state',
        'purchase_confirmation_event', 'purchase_confirmation_hold', 'claim',
        'claim_item', 'claim_item_source_allocation', 'claim_evidence',
        'claim_reason_change', 'claim_review', 'claim_event', 'exchange_line',
        'review_eligibility', 'review', 'review_revision', 'review_image',
        'seller_review_reply', 'wishlist_item', 'notification',
        'notification_preference', 'notification_delivery', 'admin_user', 'admin_role',
        'admin_user_role', 'admin_permission', 'admin_role_permission',
        'admin_approval_request', 'admin_approval_step', 'admin_audit_log',
        'seller_incident', 'seller_penalty', 'seller_health_metric', 'seller_appeal',
        'compliance_rule', 'compliance_rule_version', 'product_compliance_finding',
        'seller_compliance_task', 'seller_compliance_task_item', 'outbox_event'
    )
    'payment-service' = @(
        'payment_attempt', 'payment', 'payment_item', 'payment_charge_allocation',
        'payment_transaction', 'payment_transaction_allocation', 'refund',
        'refund_item', 'refund_charge_adjustment', 'pg_webhook_inbox', 'outbox_event'
    )
    'settlement-service' = @(
        'seller_ledger_entry', 'settlement', 'settlement_allocation', 'settlement_hold',
        'settlement_payout_attempt', 'reconciliation_file', 'reconciliation_raw_row',
        'reconciliation_run', 'reconciliation_match', 'reconciliation_discrepancy',
        'bank_deposit_match', 'outbox_event'
    )
    'discovery-data-service' = @(
        'concept_taxonomy_version', 'concept', 'concept_alias', 'product_analysis_run',
        'product_concept', 'product_concept_evidence', 'search_request',
        'search_impression', 'user_behavior_event', 'outbox_event'
    )
}

$tableFiles = @(
    (Join-Path $sourceRoot '10_identity_catalog_tables.sql'),
    (Join-Path $sourceRoot '20_commerce_fulfillment_tables.sql'),
    (Join-Path $sourceRoot '30_finance_ops_tables.sql')
)
$foreignKeyFiles = @(
    (Join-Path $sourceRoot '40_identity_catalog_foreign_keys.sql'),
    (Join-Path $sourceRoot '50_commerce_fulfillment_foreign_keys.sql'),
    (Join-Path $sourceRoot '60_finance_ops_foreign_keys.sql')
)
$indexFiles = @(
    (Join-Path $sourceRoot '70_identity_catalog_indexes.sql'),
    (Join-Path $sourceRoot '80_commerce_fulfillment_indexes.sql'),
    (Join-Path $sourceRoot '90_finance_ops_indexes.sql')
)

$tableStatements = @{}
foreach ($file in $tableFiles) {
    foreach ($match in [regex]::Matches((Get-Content -LiteralPath $file -Raw -Encoding UTF8), '(?ms)^CREATE TABLE marketplace\.(?<name>[a-z0-9_]+) \(.*?^\);')) {
        $tableStatements[$match.Groups['name'].Value] = $match.Value.Trim()
    }
}

$foreignKeyStatements = @()
foreach ($file in $foreignKeyFiles) {
    foreach ($statement in [regex]::Matches((Get-Content -LiteralPath $file -Raw -Encoding UTF8), '(?ms)^ALTER TABLE marketplace\.(?<table>[a-z0-9_]+).*?;')) {
        $owner = $statement.Groups['table'].Value
        # A single ALTER can contain both internal and external references.
        # Filter each constraint, never discard the entire ALTER.
        foreach ($constraint in [regex]::Matches($statement.Value, '(?s)ADD CONSTRAINT\s+\w+.*?(?=,\s*ADD CONSTRAINT|;\s*$)')) {
            $foreignKeyStatements += [pscustomobject]@{
                Owner = $owner
                Value = "ALTER TABLE marketplace.$owner " + $constraint.Value.Trim() + ';'
            }
        }
    }
}

$indexStatements = @()
foreach ($file in $indexFiles) {
    $indexStatements += [regex]::Matches((Get-Content -LiteralPath $file -Raw -Encoding UTF8), '(?ms)^CREATE (?:UNIQUE )?INDEX .*?;')
}

foreach ($service in $serviceTables.Keys) {
    $ownedTables = $serviceTables[$service]
    $ownedTableSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$ownedTables)
    $missingTables = $ownedTables | Where-Object { -not $tableStatements.ContainsKey($_) }
    if ($missingTables) {
        throw "$service migration 생성에 실패했습니다. 누락된 테이블 정의: $($missingTables -join ', ')"
    }

    $migration = @(
        '-- scripts/generate-service-migrations.ps1가 workspace database 기준으로 생성한 파일입니다.',
        '-- 서비스 간 외래 키를 추가하지 마세요. 외부 ID를 유지하고 API/이벤트 계약으로 연동합니다.',
        'CREATE EXTENSION IF NOT EXISTS pgcrypto;',
        'CREATE SCHEMA IF NOT EXISTS marketplace;'
    )

    foreach ($table in $ownedTables) {
        $migration += $tableStatements[$table]
    }

    foreach ($statementMatch in $foreignKeyStatements) {
        $statement = $statementMatch.Value.Trim()
        $owner = $statementMatch.Owner
        $referencedTables = [regex]::Matches($statement, 'REFERENCES marketplace\.([a-z0-9_]+)') | ForEach-Object { $_.Groups[1].Value }
        if ($ownedTableSet.Contains($owner) -and @($referencedTables | Where-Object { -not $ownedTableSet.Contains($_) }).Count -eq 0) {
            $migration += $statement
        }
    }

    foreach ($statementMatch in $indexStatements) {
        $statement = $statementMatch.Value.Trim()
        $target = [regex]::Match($statement, 'ON marketplace\.([a-z0-9_]+)')
        if ($target.Success -and $ownedTableSet.Contains($target.Groups[1].Value)) {
            $migration += $statement
        }
    }

    $migrationDirectory = Join-Path $OutputDirectory $service
    $resolvedOutput = [System.IO.Path]::GetFullPath($migrationDirectory)
    if ($resolvedOutput -match '[\\/]src[\\/]main[\\/]resources[\\/]db[\\/]migration([\\/]|$)') {
        throw 'Do not overwrite applied Flyway migrations. Generate a preview and add a new version.'
    }
    New-Item -ItemType Directory -Path $migrationDirectory -Force | Out-Null
    $migrationPath = Join-Path $migrationDirectory 'V1__service_owned_schema.sql'
    Set-Content -LiteralPath $migrationPath -Value ($migration -join "`n`n") -Encoding utf8
    Write-Output "생성 완료: $migrationPath (소유 테이블 $($ownedTables.Count)개)"
}
