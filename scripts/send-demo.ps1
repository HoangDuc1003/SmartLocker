# Sends demo open/close sessions to POST /api/locker/batch, as a locker box would (rubric part B: live demo).
# Then reload "Dữ liệu cảm biến" (LockerSessionController): the new rows are on top of the list.
#
#   powershell -ExecutionPolicy Bypass -File scripts\send-demo.ps1                      3 good sessions
#   powershell -ExecutionPolicy Bypass -File scripts\send-demo.ps1 -Count 5 -Fault -Bad   plus one sensor fault, one malformed
#
# -ApiKey: the key of the box that "sends". The seed keys are public (device-N-api-key, see README); LOCKER-01 of a real
#          box has its own key (scripts/set-device-key.ps1), never put that one in a script.
# -Fault:  adds a session with an impossible weight: saved, then flagged SENSOR_FAULT by the rules (Cảnh báo page).
# -Bad:    adds a session without measured_at: the server refuses it (rejected, BAD_SESSION) and stores nothing.
# -Slot:   pick a slot with no open booking: a stay longer than its booking allows is flagged OVERDUE.
# The times are this PC's clock in UTC: run it on the server, or on a PC whose clock is right (more than 5 minutes ahead
# of the server and every row becomes SENSOR_FAULT, see RuleEngine.CLOCK_AHEAD_SEC).
param(
    [string]$BaseUrl = "http://localhost:8080/SmartLocker",
    [string]$ApiKey = "device-3-api-key",
    [string]$Slot = "A01",
    [ValidateRange(1, 50)][int]$Count = 3,
    [switch]$Fault,
    [switch]$Bad
)
$ErrorActionPreference = "Stop"
$inv = [Globalization.CultureInfo]::InvariantCulture   # Gregorian year and ":" whatever the culture of the PC

# a sequence number the box never used before: seconds since 1970 (mod 20,000,000, about 231 days) x100 + index;
# the server ignores a repeated one and counts it as a duplicate
$epoch = [int64]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
$base = [int]($epoch % 20000000) * 100
$rand = New-Object System.Random
$methods = @("PIN", "FINGERPRINT")
# door s, weight g, stay min of NORMAL seed rows that the model scores as normal (checked: no ML_ANOMALY)
$normal = @(@(4.5, -24, 24), @(6.5, -58, 58), @(5.5, -17, 17), @(8.5, -52, 52), @(5.5, -41, 41), @(4.5, -72, 72))
$sessions = @()
for ($i = 0; $i -lt $Count; $i++) {
    $v = $normal[$rand.Next($normal.Count)]
    $sessions += [ordered]@{
        seq            = $base + $i
        measured_at    = [DateTime]::UtcNow.AddMilliseconds(-100 * ($Count - $i)).ToString("yyyy-MM-dd HH:mm:ss.fff", $inv)   # UTC, as the box sends
        door_open_sec  = $v[0]
        weight_delta_g = $v[1]
        unlock_count   = 1
        rfid_ok        = $true
        stay_min       = $v[2]
        slot_code      = $Slot
        open_source    = $methods[$rand.Next($methods.Count)]
    }
}
if ($Fault) {
    $sessions += [ordered]@{ seq = $base + $Count; measured_at = [DateTime]::UtcNow.ToString("yyyy-MM-dd HH:mm:ss.fff", $inv);
        door_open_sec = 6; weight_delta_g = -5000; unlock_count = 1; rfid_ok = $true; stay_min = 30;
        slot_code = $Slot; open_source = "PIN" }
}
if ($Bad) {
    $sessions += [ordered]@{ seq = $base + $Count + 1; door_open_sec = 6; weight_delta_g = 10; unlock_count = 1;
        rfid_ok = $true; stay_min = 30; slot_code = $Slot; open_source = "PIN" }   # no measured_at
}

$body = @{ sessions = $sessions } | ConvertTo-Json -Depth 4
$bytes = [Text.Encoding]::UTF8.GetBytes($body)
Write-Host "POST $BaseUrl/api/locker/batch ($($sessions.Count) phiên, seq từ $base)"
try {
    $reply = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/locker/batch" -Headers @{ "X-API-Key" = $ApiKey } `
        -ContentType "application/json; charset=utf-8" -Body $bytes
} catch {
    Write-Host "Máy chủ từ chối: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) { Write-Host $_.ErrorDetails.Message }
    exit 1
}
Write-Host ("Đã lưu {0}, trùng {1}, bị từ chối {2}" -f $reply.saved, $reply.duplicates, $reply.rejected) -ForegroundColor Green
foreach ($e in $reply.errors) { Write-Host ("  seq {0}: {1}" -f $e.seq, $e.code) -ForegroundColor Yellow }
Write-Host "Tải lại trang: $BaseUrl/LockerSessionController"
