# The proof of a refactor: builds SL_PROOF_OLD from the rf-baseline worktree and SL_PROOF_NEW from this checkout, exports
# both as canonical text and compares them. Exit 0 means the two databases are the same (see README.md in this folder).
#   powershell -ExecutionPolicy Bypass -File scripts\proof\proof.ps1 [-TestSetup] [-Keep]
param(
    [string]$Old = "C:\sl-wt\baseline",
    [string]$New = (Resolve-Path "$PSScriptRoot\..\.."),
    [string]$Work = (Join-Path ([IO.Path]::GetTempPath()) "sl-proof"),
    [string]$Accepted = "$PSScriptRoot\accepted.txt",
    [switch]$TestSetup,     # also run sql/test_setup.sql on both sides
    [string[]]$Also = @(),  # more scripts of sql/ on both sides (demo_box.sql, test_overdue.sql, test_cleanup.sql)
    [switch]$Keep           # keep the two databases for inspection
)
. "$PSScriptRoot\lib.ps1"
if (-not (Test-Path (Join-Path $Old "sql"))) {
    throw "No baseline at $Old. Create it with: git worktree add --detach $Old rf-baseline"
}
$tag = & git -C $Old rev-parse HEAD
$want = & git -C $Old rev-parse "rf-baseline^{commit}"
if ($tag -ne $want -or (& git -C $Old status --porcelain -- sql)) { throw "$Old is not a clean checkout of rf-baseline." }

$oldDb = "SL_PROOF_OLD"; $newDb = "SL_PROOF_NEW"
& "$PSScriptRoot\build-db.ps1" -Repo $Old -Database $oldDb -TestSetup:$TestSetup -Also $Also
& "$PSScriptRoot\build-db.ps1" -Repo $New -Database $newDb -TestSetup:$TestSetup -Also $Also
if (Test-Path $Work) { Remove-Item -Recurse -Force $Work }
New-Item -ItemType Directory $Work | Out-Null
& "$PSScriptRoot\export-db.ps1" -Database $oldDb -OutDir "$Work\old"
& "$PSScriptRoot\export-db.ps1" -Database $newDb -OutDir "$Work\new"
if (-not $Keep) { Remove-TestDb $oldDb; Remove-TestDb $newDb }
& powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\compare.ps1" -Work $Work -Accepted $Accepted
$code = $LASTEXITCODE
Assert-RealDbUntouched
exit $code
