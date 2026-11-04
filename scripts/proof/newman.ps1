# Runs the Postman collection against the test stack: fresh SL_* database (core scripts + test_setup, no demo_box),
# then compares the failures with newman-baseline.txt. The test Tomcat must be running on that database.
#   powershell -ExecutionPolicy Bypass -File scripts\proof\newman.ps1 -Database SL_NEWMAN [-Out dir] [-UpdateBaseline]
param(
    [Parameter(Mandatory)][string]$Database,
    [string]$Out = (Join-Path ([IO.Path]::GetTempPath()) "sl-newman"),
    [string]$ApiKey = "device-1-api-key",    # the public seed key of 03_v2_v3.sql, not a secret
    [switch]$UpdateBaseline
)
. "$PSScriptRoot\lib.ps1"
Assert-TestDb $Database
$repo = (Resolve-Path "$PSScriptRoot\..\..").Path
New-Item -ItemType Directory -Force $Out | Out-Null

try { Invoke-WebRequest "http://localhost:8081/SmartLocker/api/locker-map" -UseBasicParsing -TimeoutSec 10 | Out-Null }
catch { throw "The test Tomcat does not answer on 8081; start it with test-stack.ps1." }

$setup = [IO.File]::ReadAllText("$repo\sql\test_setup.sql", [Text.Encoding]::UTF8).TrimStart([char]0xFEFF)
$setup = [regex]::Replace($setup, $script:RealDb, $Database, 'IgnoreCase')
$copy = Join-Path $Out "test_setup.sql"
[IO.File]::WriteAllText($copy, $setup, (New-Object System.Text.UTF8Encoding $true))
& sqlcmd -S $script:Server -U $script:SqlUser -P $script:SqlPassword -d $Database -I -f 65001 -b -i $copy | Out-Null
if ($LASTEXITCODE -ne 0) { throw "test_setup.sql failed on $Database." }

$json = Join-Path $Out "newman.json"
if (Test-Path $json) { Remove-Item -Force $json }   # a crashed run must not be judged by the results of the last one
& cmd /c "newman run `"$repo\docs\postman\SmartLocker-v2.postman_collection.json`" -e `"$repo\docs\postman\SmartLocker-local.postman_environment.json`" --env-var base_url=http://localhost:8081/SmartLocker --env-var api_key=$ApiKey --reporters json --reporter-json-export `"$json`" --reporter-json-omitHeaders --timeout-request 30000 >nul 2>&1"

if (-not (Test-Path $json)) { throw "newman wrote no report: it did not run." }
# One line per failed assertion, stable from run to run: folder/request :: assertion
$run = (Get-Content $json -Raw -Encoding UTF8 | ConvertFrom-Json).run
$failed = @($run.failures | ForEach-Object { "$($_.source.name) :: $(if ($_.error.test) { $_.error.test } else { $_.error.message })" } | Sort-Object)
$st = $run.stats
Write-Host "requests $($st.requests.total) (failed $($st.requests.failed)), assertions $($st.assertions.total) (failed $($st.assertions.failed))"
$now = Join-Path $Out "failures.txt"
Write-Utf8 $now (($failed -join "`n") + "`n")
$baseline = "$PSScriptRoot\newman-baseline.txt"
if ($UpdateBaseline) { Copy-Item $now $baseline -Force; Write-Host "newman-baseline.txt updated"; Assert-RealDbUntouched; exit 0 }
if (-not (Test-Path $baseline)) { throw "No newman-baseline.txt yet; run with -UpdateBaseline." }
$old = @([IO.File]::ReadAllLines($baseline, [Text.Encoding]::UTF8) | Where-Object { $_ })
$diff = @(Compare-Object $old $failed)
Assert-RealDbUntouched
if ($diff.Count) {
    $diff | ForEach-Object { Write-Host "$(if ($_.SideIndicator -eq '=>') { 'NEW FAILURE' } else { 'NOW PASSES ' }) $($_.InputObject)" }
    exit 1
}
Write-Host "[ok] the same $($old.Count) failures as newman-baseline.txt"
exit 0
