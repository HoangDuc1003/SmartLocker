# Compares two exports ($Work\old, $Work\new) with git diff --no-index and applies accepted.txt.
# Exit 0: identical, or every changed line is accepted and every accepted line was needed. The diff is left in $Work\diff.txt.
param(
    [Parameter(Mandatory)][string]$Work,
    [string]$Accepted = "$PSScriptRoot\accepted.txt"
)
. "$PSScriptRoot\lib.ps1"

# An accepted line is "<file>|<+ or ->|<the exact line>". Only metadata may be accepted: a difference in a data cell,
# identity, column order, index name or THROW text is never fine, however it is written down.
$acceptable = '^(03_constraints|05_parameters|06_objects|07_modules)\.txt$'
$wanted = New-Object System.Collections.Hashtable ([StringComparer]::Ordinal)   # case matters: 'ACTIVE' is not 'active'
$problems = New-Object System.Collections.Generic.List[string]
if (Test-Path $Accepted) {
    foreach ($line in [IO.File]::ReadAllLines($Accepted, [Text.Encoding]::UTF8)) {
        if (-not $line.Trim() -or $line.StartsWith('#')) { continue }
        $parts = $line.Split('|', 3)
        if ($parts.Count -ne 3 -or $parts[1] -notmatch '^[+-]$') { $problems.Add("accepted.txt, bad line: $line"); continue }
        if ($parts[0] -notmatch $acceptable) { $problems.Add("accepted.txt may not cover $($parts[0]): $line"); continue }
        if ($parts[2] -match '\b(THROW|RAISERROR)\b') { $problems.Add("accepted.txt may not cover THROW text: $line"); continue }
        $wanted[$line] = 1 + [int]$wanted[$line]   # one line covers one occurrence
    }
}

$diffFile = Join-Path $Work "diff.txt"
Push-Location $Work
try {
    # through cmd: PowerShell 5.1 would decode the bytes with the console code page and rewrite the line ends
    & cmd /c "git -c core.autocrlf=false -c core.safecrlf=false -c core.quotepath=false diff --no-index --no-color --text --unified=2 old new > diff.txt 2>nul"
    $code = $LASTEXITCODE
} finally { Pop-Location }
if ($code -gt 1) { throw "git diff failed with exit code $code" }

$file = ""
$inHunk = $false
$changed = 0
$unaccepted = New-Object System.Collections.Generic.List[string]
$perFile = @{}
foreach ($line in [IO.File]::ReadAllLines($diffFile, [Text.Encoding]::UTF8)) {
    if ($line -match '^diff --git a/(?:old|new)/(\S+) b/(?:old|new)/(\S+)') { $file = $Matches[2]; $inHunk = $false; continue }
    if ($line.StartsWith('@@ ')) { $inHunk = $true; continue }
    if (-not $inHunk -or $line -notmatch '^[+-]') { continue }   # outside a hunk, --- and +++ are file names; inside, they are content
    $changed++
    $key = $file + '|' + $line.Substring(0, 1) + '|' + $line.Substring(1)
    if ([int]$wanted[$key] -gt 0) { $wanted[$key] = [int]$wanted[$key] - 1; continue }
    $unaccepted.Add($key)
    $perFile[$file] = 1 + [int]$perFile[$file]
}
foreach ($k in $wanted.Keys) { if ($wanted[$k] -gt 0) { $problems.Add("accepted.txt, no longer needed: $k") } }
# git says the folders differ but nothing above saw a changed line (a new or removed empty file, a mode change...)
if ($code -eq 1 -and $changed -eq 0) { $problems.Add("git diff reports a difference that was not parsed, see $diffFile") }

foreach ($p in $problems) { Write-Host "[fail] $p" -ForegroundColor Red }
if ($unaccepted.Count) {
    Write-Host "[fail] $($unaccepted.Count) changed lines are not accepted, see $diffFile" -ForegroundColor Red
    $perFile.Keys | Sort-Object | ForEach-Object { Write-Host ("  {0,5}  {1}" -f $perFile[$_], $_) }
    $unaccepted | Select-Object -First 12 | ForEach-Object { Write-Host "  $($_.Substring(0, [math]::Min(170, $_.Length)))" }
}
if ($problems.Count -or $unaccepted.Count) { exit 1 }
Write-Host "[ok] no difference between old and new ($($wanted.Count) accepted lines)" -ForegroundColor Green
exit 0
