# Gives the real box LOCKER-01 a secret API key (spec v2: LOCKER-01 is reachable through the tunnel,
# so the public seed key device-1-api-key must not open it).
# The key lives only in config/device-keys.local.properties (ignored by git); the database keeps its SHA-256.
# Safe to run again: an existing key is reused, a missing one is created.
#   powershell -ExecutionPolicy Bypass -File scripts/set-device-key.ps1           # create or reuse the key
#   powershell -ExecutionPolicy Bypass -File scripts/set-device-key.ps1 -New      # rotate to a new key
param([switch]$New, [string]$Device = 'LOCKER-01')

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$file = Join-Path $root 'config\device-keys.local.properties'
New-Item -ItemType Directory -Force (Split-Path $file) | Out-Null

# read KEY=VALUE lines
$keys = [ordered]@{}
if (Test-Path $file) {
    foreach ($line in Get-Content $file) {
        if ($line -match '^\s*([^#=\s]+)\s*=\s*(\S+)\s*$') { $keys[$Matches[1]] = $Matches[2] }
    }
}

if ($New -or -not $keys.Contains($Device)) {
    $bytes = New-Object byte[] 24
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $keys[$Device] = ($bytes | ForEach-Object { $_.ToString('x2') }) -join ''
    $out = @('# Secret API keys of the real boxes. Never commit this file (see .gitignore).')
    foreach ($k in $keys.Keys) { $out += "$k=$($keys[$k])" }
    Set-Content -Path $file -Value $out -Encoding ASCII
    Write-Host "New key written to $file"
}

# SHA-256 of the UTF-8 key, lower-case hex: the same as util.SecurityUtils.sha256Hex
$sha = [System.Security.Cryptography.SHA256]::Create()
$hash = ($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($keys[$Device])) | ForEach-Object { $_.ToString('x2') }) -join ''

$sql = "SET NOCOUNT ON; UPDATE dbo.Device SET api_key_hash = '$hash' WHERE device_code = N'$Device'; SELECT @@ROWCOUNT;"
$rows = & sqlcmd -S localhost -U sa -P 12345 -d PRJ301_LOCKER -I -h -1 -W -Q $sql
if ($LASTEXITCODE -ne 0) { throw "sqlcmd failed" }
if ([int]($rows | Select-Object -Last 1) -ne 1) { throw "Device $Device not found" }
Write-Host "$Device now accepts only the key in $file (SHA-256 stored in Device.api_key_hash)."
