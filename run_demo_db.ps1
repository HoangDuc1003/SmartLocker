param(
    [string]$Server = "localhost",
    [string]$User = "sa",
    [string]$Password = "12345",
    [string]$Database = "PRJ301_LOCKER",
    # Azure SQL Database (docs/deploy-render.md): it has no USE / CREATE DATABASE, so those lines are removed,
    # the old tables are dropped instead, and the scripts run inside -Database over an encrypted connection.
    [switch]$Azure
)
# Local:  powershell -ExecutionPolicy Bypass -File .\run_demo_db.ps1
# Azure:  powershell -ExecutionPolicy Bypass -File .\run_demo_db.ps1 -Azure -Server <name>.database.windows.net -User <admin> -Password <password>

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   SmartLocker - Database Setup & 100 Demo Accounts Seed   " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Target Server: $Server / $Database" -ForegroundColor Yellow
Write-Host "User:          $User" -ForegroundColor Yellow

$sqlDir = Join-Path $PSScriptRoot "sql"
$scripts = @("01_schema.sql", "02_data_v1.sql", "03_v2_v3.sql")
$conn = @("-S", $Server, "-U", $User, "-P", $Password)
if ($Azure) { $conn += @("-d", $Database, "-N", "-l", "60") }

$dropAll = @"
DECLARE @sql NVARCHAR(MAX) = N'';
SELECT @sql += N'DROP VIEW ' + QUOTENAME(SCHEMA_NAME(schema_id)) + '.' + QUOTENAME(name) + ';' FROM sys.views WHERE is_ms_shipped = 0;
SELECT @sql += N'DROP PROCEDURE ' + QUOTENAME(SCHEMA_NAME(schema_id)) + '.' + QUOTENAME(name) + ';' FROM sys.procedures WHERE is_ms_shipped = 0;
SELECT @sql += N'DROP FUNCTION ' + QUOTENAME(SCHEMA_NAME(schema_id)) + '.' + QUOTENAME(name) + ';' FROM sys.objects WHERE type IN ('FN','IF','TF') AND is_ms_shipped = 0;
SELECT @sql += N'ALTER TABLE ' + QUOTENAME(OBJECT_SCHEMA_NAME(parent_object_id)) + '.' + QUOTENAME(OBJECT_NAME(parent_object_id)) + ' DROP CONSTRAINT ' + QUOTENAME(name) + ';' FROM sys.foreign_keys;
SELECT @sql += N'DROP TABLE ' + QUOTENAME(SCHEMA_NAME(schema_id)) + '.' + QUOTENAME(name) + ';' FROM sys.tables WHERE is_ms_shipped = 0;
SELECT @sql += N'DROP TYPE ' + QUOTENAME(SCHEMA_NAME(schema_id)) + '.' + QUOTENAME(name) + ';' FROM sys.types WHERE is_user_defined = 1;
EXEC sp_executesql @sql;
GO
"@

$tmpDir = Join-Path ([IO.Path]::GetTempPath()) "smartlocker-db"
New-Item -ItemType Directory -Force $tmpDir | Out-Null
$utf8Bom = New-Object System.Text.UTF8Encoding $true

foreach ($s in $scripts) {
    $filePath = Join-Path $sqlDir $s
    if (-not (Test-Path $filePath)) {
        Write-Error "Script file not found: $filePath"
        exit 1
    }
    if ($Azure) {
        $text = [IO.File]::ReadAllText($filePath, [Text.Encoding]::UTF8)
        $text = [regex]::Replace($text, '(?s)USE master;.*?CREATE DATABASE PRJ301_LOCKER;', '')
        $text = [regex]::Replace($text, '(?im)^\s*USE\s+PRJ301_LOCKER\s*;?\s*$', '')
        if ($s -eq "01_schema.sql") { $text = $dropAll + "`r`n" + $text }
        $filePath = Join-Path $tmpDir $s
        [IO.File]::WriteAllText($filePath, $text, $utf8Bom)
    }
    Write-Host "`n--> Executing $s ..." -ForegroundColor Green
    & sqlcmd @conn -I -f 65001 -b -i "$filePath"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error executing $s! Aborting." -ForegroundColor Red
        exit $LASTEXITCODE
    }
    Write-Host "    [OK] $s executed successfully." -ForegroundColor Gray
}
Remove-Item -Recurse -Force $tmpDir

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "                 VERIFYING DATABASE INTEGRITY               " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
$query = @("-d", $Database, "-f", "65001", "-h", "-1")
if ($Azure) { $query = @("-f", "65001", "-h", "-1") }

# 1. Verify balance column exists
$verifyBalanceQuery = "SET NOCOUNT ON; SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Users' AND COLUMN_NAME = 'balance';"
$hasBalanceStr = & sqlcmd @conn @query -Q $verifyBalanceQuery
$hasBalance = [int]($hasBalanceStr.Trim())

if ($hasBalance -ge 1) {
    Write-Host "[PASS] Column 'Users.balance' verified: OK" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Column 'Users.balance' MISSING!" -ForegroundColor Red
    exit 1
}

# 2. Display users count by role
Write-Host ""
Write-Host "--- Users Summary by Role ---" -ForegroundColor Yellow
$verifyUsersQuery = "SET NOCOUNT ON; SELECT r.role_name + ': ' + CAST(COUNT(*) AS VARCHAR(10)) + ' accounts' FROM Users u JOIN UserRole ur ON ur.user_id = u.user_id JOIN Roles r ON r.role_id = ur.role_id WHERE u.username != 'system' GROUP BY r.role_name, r.rank_no ORDER BY r.rank_no;"
& sqlcmd @conn @query -Q $verifyUsersQuery

# 3. Overall stats
Write-Host ""
Write-Host "--- Demo Activity Stats ---" -ForegroundColor Yellow
$verifyStatsQuery = "SET NOCOUNT ON; SELECT 'Total Users:      ' + CAST(COUNT(*) AS VARCHAR(10)) FROM Users WHERE username != 'system' UNION ALL SELECT 'Total Slots:      ' + CAST(COUNT(*) AS VARCHAR(10)) FROM LockerSlot UNION ALL SELECT 'Total Sessions:   ' + CAST(COUNT(*) AS VARCHAR(10)) FROM LockerSession UNION ALL SELECT 'Topup Requests:   ' + CAST(COUNT(*) AS VARCHAR(10)) FROM TopupRequest UNION ALL SELECT 'Active/Overdue:   ' + CAST(COUNT(*) AS VARCHAR(10)) FROM Deposit WHERE status IN ('ACTIVE', 'RESERVED', 'OVERDUE') UNION ALL SELECT 'Security Alerts:  ' + CAST(COUNT(*) AS VARCHAR(10)) FROM Alert;"
& sqlcmd @conn @query -Q $verifyStatsQuery

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  SUCCESS! Database is fully seeded and ready for demo!   " -ForegroundColor Green
Write-Host "  Password for all demo accounts: 123456                   " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next step: 03_v2_v3.sql resets the LOCKER-01 key to the public seed key." -ForegroundColor Yellow
Write-Host "Run: powershell -ExecutionPolicy Bypass -File scripts\set-device-key.ps1" -ForegroundColor Yellow
