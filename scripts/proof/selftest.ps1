# Proves the proof tool itself: two builds of rf-baseline must match, natural.txt must be exactly what differs between
# them, each planted fault must be caught in the right file, and accepted.txt must refuse what it may never cover.
#   powershell -ExecutionPolicy Bypass -File scripts\proof\selftest.ps1 [-Old C:\sl-wt\baseline]
param([string]$Old = "C:\sl-wt\baseline")
. "$PSScriptRoot\lib.ps1"
$root = Join-Path ([IO.Path]::GetTempPath()) "sl-proof-selftest"
if (Test-Path $root) { Remove-Item -Recurse -Force $root }
New-Item -ItemType Directory $root | Out-Null
$failed = 0
function Check([string]$Name, [bool]$Ok) {
    if ($Ok) { Write-Host "[pass] $Name" -ForegroundColor Green } else { Write-Host "[FAIL] $Name" -ForegroundColor Red; $script:failed++ }
}
function Run-Proof([string]$New, [string]$Work, [string]$Accepted = "$PSScriptRoot\accepted.txt") {
    & powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\proof.ps1" -Old $Old -New $New -Work $Work -Accepted $Accepted | Out-Null
    return $LASTEXITCODE
}
# A copy of the baseline scripts with one text change; the change must have hit exactly one place.
function New-Fault([string]$Name, [string]$File, [string]$From, [string]$To) {
    $dir = Join-Path $root $Name
    New-Item -ItemType Directory "$dir\sql" | Out-Null
    Copy-Item "$Old\sql\*" "$dir\sql\"
    $path = "$dir\sql\$File"
    $text = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
    if ($From) {
        $at = $text.IndexOf($From)
        if ($at -lt 0) { throw "Fault '$Name': text not found in ${File}: $From" }
        $text = $text.Remove($at, $From.Length).Insert($at, $To)
    } else {
        $text += "`r`nGO`r`n$To`r`nGO`r`n"   # a statement at the end of the script
    }
    [IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding $true))
    return $dir
}

# 1. Two builds of the same scripts, a little apart, compared raw: what differs must be exactly natural.txt.
$a = "SL_PROOF_A"; $b = "SL_PROOF_B"
& "$PSScriptRoot\build-db.ps1" -Repo $Old -Database $a | Out-Null
Start-Sleep -Seconds 70
& "$PSScriptRoot\build-db.ps1" -Repo $Old -Database $b | Out-Null
& "$PSScriptRoot\export-db.ps1" -Database $a -OutDir "$root\raw\a" -RawNatural | Out-Null
& "$PSScriptRoot\export-db.ps1" -Database $b -OutDir "$root\raw\b" -RawNatural | Out-Null
$differs = New-Object System.Collections.Generic.HashSet[string]
foreach ($f in Get-ChildItem "$root\raw\a\data" -File) {
    $la = [IO.File]::ReadAllLines($f.FullName); $lb = [IO.File]::ReadAllLines("$root\raw\b\data\$($f.Name)")
    if ($la.Count -ne $lb.Count) { [void]$differs.Add("$($f.BaseName).<row count>"); continue }
    for ($i = 0; $i -lt $la.Count; $i++) {
        if ($la[$i] -ceq $lb[$i]) { continue }
        $ca = $la[$i] -split ' \| '; $cb = $lb[$i] -split ' \| '
        for ($j = 0; $j -lt $ca.Count; $j++) {
            if ($ca[$j] -cne $cb[$j]) { [void]$differs.Add("$($f.BaseName).$(($ca[$j] -split '=')[0])") }
        }
    }
}
$listed = @(Get-Content "$PSScriptRoot\natural.txt" -Encoding UTF8 | Where-Object { $_ -and -not $_.StartsWith('#') } | ForEach-Object { $_.Trim() } | Sort-Object)
$found = @($differs | Sort-Object)
Write-Host "natural.txt lists: $($listed -join ', ')"
Write-Host "really differ:     $($found -join ', ')"
Check "natural.txt is exactly what differs between two builds" (($listed -join ',') -ceq ($found -join ','))
& "$PSScriptRoot\export-db.ps1" -Database $a -OutDir "$root\same\old" | Out-Null
& "$PSScriptRoot\export-db.ps1" -Database $b -OutDir "$root\same\new" | Out-Null
& powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\compare.ps1" -Work "$root\same" | Out-Null
Check "two builds of rf-baseline are identical after masking" ($LASTEXITCODE -eq 0)
Remove-TestDb $a; Remove-TestDb $b

# 2. Planted faults: each must fail the proof and show in the expected file.
$faults = @(
    @{ n = "literal in a procedure"; f = "03_v2_v3.sql"; from = "extended 3 times at most"; to = "extended 4 times at most"; expect = "new/07_modules.txt" },
    @{ n = "one check";              f = "01_schema.sql"; from = "CHECK (amount >= 1000)"; to = "CHECK (amount >= 1001)"; expect = "new/03_constraints.txt" },
    @{ n = "one seed cell";          f = "02_data_v1.sql"; from = "N'0905000001'"; to = "N'0905999001'"; expect = "new/data/Users.txt" },
    # what the export missed before the cross-review
    @{ n = "a disabled index";       f = "03_v2_v3.sql"; from = ""; to = "ALTER INDEX UX_Users_email ON dbo.Users DISABLE;"; expect = "new/04_indexes.txt" },
    @{ n = "a database trigger";     f = "03_v2_v3.sql"; from = ""; to = "CREATE TRIGGER tr_proof_ddl ON DATABASE FOR CREATE_TABLE AS PRINT 'x';"; expect = "new/06_objects.txt" },
    @{ n = "a database user";        f = "03_v2_v3.sql"; from = ""; to = "CREATE USER proof_user WITHOUT LOGIN; GRANT SELECT ON dbo.Users TO proof_user;"; expect = "new/08_security.txt" },
    @{ n = "a database option";      f = "03_v2_v3.sql"; from = ""; to = "ALTER DATABASE PRJ301_LOCKER SET RECURSIVE_TRIGGERS ON;"; expect = "new/09_database.txt" },
    @{ n = "a broken audit chain";   f = "03_v2_v3.sql"; from = ""; to = "UPDATE dbo.HashChain SET chain_hash = REPLICATE('0', 64) WHERE anchor_id = 3;"; expect = "new/10_audit_chain.txt" },
    @{ n = "a logged row edited";    f = "03_v2_v3.sql"; from = ""; to = "UPDATE dbo.AuditLog SET action = N'EDITED' WHERE audit_id = 3;"; expect = "new/10_audit_chain.txt" }
)
$i = 0
foreach ($x in $faults) {
    $i++
    $dir = New-Fault "fault$i" $x.f $x.from $x.to
    $work = "$root\work$i"
    $code = Run-Proof $dir $work
    $hit = (Test-Path "$work\diff.txt") -and ((Get-Content "$work\diff.txt" -Raw -Encoding UTF8).Contains("b/" + $x.expect))
    Check "caught: $($x.n)" (($code -eq 1) -and $hit)
}

# 3. A clean copy passes through the whole of proof.ps1; accepted.txt refuses what it must never cover, and a stale line.
$clean = "$root\clean"
New-Item -ItemType Directory "$clean\sql" | Out-Null
Copy-Item "$Old\sql\*" "$clean\sql\"
Check "proof.ps1 passes on an unchanged copy" ((Run-Proof $clean "$root\work0") -eq 0)
foreach ($t in @(
    @{ n = "accepted.txt refuses a data cell"; l = "data/Users.txt|+|anything" },
    @{ n = "accepted.txt refuses an index";    l = "04_indexes.txt|+|anything" },
    @{ n = "accepted.txt refuses THROW text";  l = "07_modules.txt|+|THROW 50001, N'x', 1;" },
    @{ n = "accepted.txt fails on a stale line"; l = "07_modules.txt|+|a line that is not in the diff" }
)) {
    Write-Utf8 "$root\accepted.txt" ($t.l + "`n")
    & powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\compare.ps1" -Work "$root\same" -Accepted "$root\accepted.txt" | Out-Null
    Check $t.n ($LASTEXITCODE -eq 1)
}
# Fixtures: what git or the parser could lose.
function Compare-Fixture([string]$Name, [string]$File, [string]$OldText, [string]$NewText, [string]$AcceptedLine = "") {
    $w = "$root\fx"
    if (Test-Path $w) { Remove-Item -Recurse -Force $w }
    New-Item -ItemType Directory "$w\old", "$w\new" | Out-Null
    Write-Utf8 "$w\old\$File" $OldText
    Write-Utf8 "$w\new\$File" $NewText
    Write-Utf8 "$root\accepted.txt" $AcceptedLine
    & powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\compare.ps1" -Work $w -Accepted "$root\accepted.txt" | Out-Null
    Check $Name ($LASTEXITCODE -eq 1)
}
Compare-Fixture "a NUL in a line does not make the diff binary" "a.txt" "a=1$([char]0)x`n" "a=2$([char]0)x`n"
Compare-Fixture "a changed line that starts with -- is seen" "a.txt" "-- one`n" "-- two`n"
Compare-Fixture "accepted.txt is case sensitive" "07_modules.txt" "A: x`n" "A: x`nA: 'active'`n" "07_modules.txt|+|A: 'ACTIVE'`n"
Compare-Fixture "one accepted line covers one occurrence" "07_modules.txt" "A: x`n" "A: x`nA: y`nA: y`n" "07_modules.txt|+|A: y`n"
Compare-Fixture "accepted.txt refuses RAISERROR" "07_modules.txt" "A: x`n" "A: x`nA: RAISERROR(1)`n" "07_modules.txt|+|A: RAISERROR(1)`n"

# 4. The guard: no other database, whatever the command line says.
$refused = $false
try { Assert-TestDb "PRJ301_LOCKER" } catch { $refused = $true }
Check "a database without the SL_ prefix is refused" $refused

Remove-Item -Recurse -Force $root
Assert-RealDbUntouched
if ($failed) { Write-Host "$failed checks failed" -ForegroundColor Red; exit 1 }
Write-Host "All checks passed" -ForegroundColor Green
exit 0
