param(
    [string]$Server = "localhost",
    [string]$User = "sa",
    [string]$Password = "12345"
)

$ErrorActionPreference = "Stop"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   SmartLocker - Database Setup & 100 Demo Accounts Seed   " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Target Server: $Server" -ForegroundColor Yellow
Write-Host "User:          $User" -ForegroundColor Yellow

$sqlDir = Join-Path $PSScriptRoot "sql"
if (-not (Test-Path $sqlDir)) {
    Write-Error "Cannot find 'sql' directory at: $sqlDir"
    exit 1
}

$scripts = @(
    "01_schema.sql",
    "02_sample_data.sql",
    "03_scenarios.sql",
    "04_wallet_booking.sql",
    "05_fix_reviewer_feedback.sql"
)

foreach ($s in $scripts) {
    $filePath = Join-Path $sqlDir $s
    if (-not (Test-Path $filePath)) {
        Write-Error "Script file not found: $filePath"
        exit 1
    }
    Write-Host "`n--> Executing $s ..." -ForegroundColor Green
    & sqlcmd -S $Server -U $User -P $Password -b -i "$filePath"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error executing $s! Aborting." -ForegroundColor Red
        exit $LASTEXITCODE
    }
    Write-Host "    [OK] $s executed successfully." -ForegroundColor Gray
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "                 VERIFYING DATABASE INTEGRITY               " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Verify balance column exists
$verifyBalanceQuery = "SET NOCOUNT ON; SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Users' AND COLUMN_NAME = 'balance';"
$hasBalanceStr = & sqlcmd -S $Server -U $User -P $Password -d PRJ301_LOCKER -h -1 -Q $verifyBalanceQuery
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
& sqlcmd -S $Server -U $User -P $Password -d PRJ301_LOCKER -h -1 -Q $verifyUsersQuery

# 3. Overall stats
Write-Host ""
Write-Host "--- Demo Activity Stats ---" -ForegroundColor Yellow
$verifyStatsQuery = "SET NOCOUNT ON; SELECT 'Total Users:      ' + CAST(COUNT(*) AS VARCHAR(10)) FROM Users WHERE username != 'system' UNION ALL SELECT 'Total Slots:      ' + CAST(COUNT(*) AS VARCHAR(10)) FROM LockerSlot UNION ALL SELECT 'Total Sessions:   ' + CAST(COUNT(*) AS VARCHAR(10)) FROM LockerSession UNION ALL SELECT 'Topup Requests:   ' + CAST(COUNT(*) AS VARCHAR(10)) FROM TopupRequest UNION ALL SELECT 'Active/Overdue:   ' + CAST(COUNT(*) AS VARCHAR(10)) FROM Deposit WHERE status IN ('ACTIVE', 'RESERVED', 'OVERDUE') UNION ALL SELECT 'Security Alerts:  ' + CAST(COUNT(*) AS VARCHAR(10)) FROM Alert;"
& sqlcmd -S $Server -U $User -P $Password -d PRJ301_LOCKER -h -1 -Q $verifyStatsQuery

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  SUCCESS! Database is fully seeded and ready for demo!   " -ForegroundColor Green
Write-Host "  Password for all demo accounts: 123456                   " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
