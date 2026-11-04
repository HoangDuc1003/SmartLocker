# Builds an SL_* database from the SQL scripts of a checkout (this one or the rf-baseline worktree).
# The scripts are copied to a temp folder with the database name replaced; the checkout is never changed.
#   powershell -ExecutionPolicy Bypass -File scripts\proof\build-db.ps1 -Repo C:\sl-wt\baseline -Database SL_OLD [-TestSetup]
param(
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][string]$Database,
    [switch]$TestSetup,     # also run sql/test_setup.sql (the Postman accounts) after the core scripts
    [string[]]$Also = @()   # more scripts of sql/ to run last, in this order (demo_box.sql, test_overdue.sql...)
)
. "$PSScriptRoot\lib.ps1"
Assert-TestDb $Database

# sql/build-order.txt lets a later phase rename or merge the scripts without touching this tool.
$orderFile = Join-Path $Repo "sql\build-order.txt"
$scripts = if (Test-Path $orderFile) { Get-Content $orderFile | Where-Object { $_.Trim() } }
           else { @("01_schema.sql", "02_data_v1.sql", "03_v2_v3.sql") }
if ($TestSetup) { $scripts = @($scripts) + "test_setup.sql" }
$scripts = @($scripts) + $Also

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("sl-proof-" + $Database)
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
New-Item -ItemType Directory $tmp | Out-Null
$bom = New-Object System.Text.UTF8Encoding $true
$createsDb = $false
$copies = foreach ($s in $scripts) {
    $text = [IO.File]::ReadAllText((Join-Path $Repo "sql\$s"), [Text.Encoding]::UTF8)
    $text = $text.TrimStart([char]0xFEFF)   # 03_v2_v3.sql of rf-baseline starts with two BOMs and sqlcmd stops at the second
    $text = [regex]::Replace($text, $script:RealDb, $Database, 'IgnoreCase')
    # a statement that still names another database would write outside the test database
    foreach ($m in [regex]::Matches($text, '(?im)^\s*(USE|CREATE\s+DATABASE|DROP\s+DATABASE|ALTER\s+DATABASE)\s+\[?(\w+)')) {
        $name = $m.Groups[2].Value
        if ($name -ne $Database -and $name -ne 'master') { throw "$s still names database '$name' ($($m.Value.Trim()))." }
    }
    if ($text -match '(?im)^\s*CREATE\s+DATABASE\b') { $createsDb = $true }
    $copy = Join-Path $tmp $s
    [IO.File]::WriteAllText($copy, $text, $bom)   # sqlcmd reads Vietnamese text right only with the BOM
    $copy
}

Remove-TestDb $Database
if (-not $createsDb) { Invoke-Master "CREATE DATABASE [$Database]" }
foreach ($copy in $copies) {
    $name = Split-Path $copy -Leaf
    $target = if ($createsDb -and $name -eq (Split-Path $copies[0] -Leaf)) { "master" } else { $Database }
    Write-Host "--> $Database : $name"
    $log = & sqlcmd -S $script:Server -U $script:SqlUser -P $script:SqlPassword -d $target -I -f 65001 -b -i $copy 2>&1
    if ($LASTEXITCODE -ne 0) {
        $log | Select-Object -Last 15 | ForEach-Object { Write-Host $_ }
        throw "$name failed on $Database."
    }
}
Remove-Item -Recurse -Force $tmp
Assert-RealDbUntouched
