<#
.SYNOPSIS
  Cập nhật trang chuyển tiếp cố định (GitHub Pages, nhánh gh-pages) sang địa chỉ
  Cloudflare quick tunnel mới.

.DESCRIPTION
  Tạo nội dung nhánh gh-pages trong một git worktree tạm:
    index.html             -> chuyển tới <tunnel>/SmartLocker/
    k/<DEVICE>/index.html  -> chuyển tới <tunnel>/SmartLocker/k/<DEVICE>
    config.json            -> {"base_url":"<tunnel>/SmartLocker","updated_at":"<UTC>"}
    .nojekyll
  Chỉ commit trên nhánh gh-pages (tạo nhánh orphan nếu chưa có), rồi hỏi xác nhận
  trước khi chạy `git push origin gh-pages`. Không đụng tới nhánh main và git config.

.PARAMETER TunnelUrl
  Địa chỉ quick tunnel, ví dụ https://abc-def.trycloudflare.com

.PARAMETER LogFile
  File log của cloudflared (ví dụ tạo bằng --logfile). Script lấy địa chỉ
  *.trycloudflare.com xuất hiện cuối cùng trong file.

.PARAMETER DryRun
  Chỉ in nội dung các file sẽ tạo, không động tới git.

.PARAMETER NoPush
  Tạo commit trên gh-pages nhưng không hỏi và không push.

.PARAMETER SkipCheck
  Bỏ qua bước thử gọi <tunnel>/SmartLocker/ trước khi cập nhật.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\update-tunnel-link.ps1 -TunnelUrl https://abc-def.trycloudflare.com

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\update-tunnel-link.ps1 -LogFile C:\temp\cloudflared.log
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$TunnelUrl,
    [string]$LogFile,
    [string[]]$DeviceCode = @('LOCKER-01'),
    [string]$AppPath = '/SmartLocker',
    [string]$Remote = 'origin',
    [string]$Branch = 'gh-pages',
    [switch]$DryRun,
    [switch]$NoPush,
    [switch]$SkipCheck
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$UrlPattern = '^https://[a-z0-9]+(-[a-z0-9]+)*\.trycloudflare\.com$'

function Write-Step([string]$msg) { Write-Host ("==> " + $msg) -ForegroundColor Cyan }
function Fail([string]$msg) { Write-Host ("LỖI: " + $msg) -ForegroundColor Red; exit 1 }

# Chạy git; trả về stdout (mảng dòng). Ném lỗi nếu mã thoát khác 0 (trừ khi -AllowFail).
function Invoke-Git {
    param([string[]]$GitArgs, [string]$Dir = $RepoRoot, [switch]$AllowFail)
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & git -C $Dir @GitArgs
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $old
    }
    if ($code -ne 0 -and -not $AllowFail) {
        throw ("git " + ($GitArgs -join ' ') + " thất bại (mã " + $code + ")")
    }
    $script:LastGitCode = $code
    return $out
}

# ---------------------------------------------------------------- 1. Địa chỉ tunnel
if (-not $TunnelUrl -and $LogFile) {
    if (-not (Test-Path -LiteralPath $LogFile)) { Fail ("Không thấy file log: " + $LogFile) }
    # Mở chia sẻ để đọc được cả khi cloudflared đang ghi file.
    $fs = [System.IO.File]::Open((Resolve-Path -LiteralPath $LogFile).Path, 'Open', 'Read', 'ReadWrite')
    try {
        $sr = New-Object System.IO.StreamReader($fs, $Utf8NoBom)
        $text = $sr.ReadToEnd()
        $sr.Close()
    } finally { $fs.Close() }
    $found = [regex]::Matches($text, 'https://[a-z0-9-]+\.trycloudflare\.com') |
        ForEach-Object { $_.Value } |
        Where-Object { $_ -ne 'https://api.trycloudflare.com' }
    if (-not $found) { Fail ("Không tìm thấy địa chỉ *.trycloudflare.com trong " + $LogFile) }
    $TunnelUrl = @($found)[-1]
    Write-Step ("Đọc từ log: " + $TunnelUrl)
}
if (-not $TunnelUrl) {
    $TunnelUrl = Read-Host 'Dán địa chỉ tunnel (https://....trycloudflare.com)'
}

$TunnelUrl = $TunnelUrl.Trim().ToLowerInvariant()
# Cho phép dán cả đường dẫn (ví dụ .../SmartLocker/): chỉ giữ lại https://<host>.
if ($TunnelUrl -match '^(https://[^/?#]+)[/?#]') { $TunnelUrl = $Matches[1] }
if ($TunnelUrl -notmatch $UrlPattern -or $TunnelUrl -eq 'https://api.trycloudflare.com') {
    Fail ("Địa chỉ không hợp lệ: '" + $TunnelUrl + "'. Cần dạng https://<tên>.trycloudflare.com")
}
if ($AppPath -notmatch '^/[A-Za-z0-9_-]+$') { Fail ("AppPath không hợp lệ: " + $AppPath) }
foreach ($d in $DeviceCode) {
    if ($d -notmatch '^[A-Za-z0-9_-]+$') { Fail ("Mã thiết bị không hợp lệ: " + $d) }
}

$BaseUrl = $TunnelUrl + $AppPath
$UpdatedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")

# ---------------------------------------------------------------- 2. Nội dung file
$PageTemplate = @'
<!doctype html>
<html lang="vi">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
<meta http-equiv="refresh" content="3; url=__TARGET__">
<title>__TITLE__</title>
<style>
body{margin:0;padding:32px 16px;font-family:system-ui,-apple-system,"Segoe UI",Roboto,Arial,sans-serif;line-height:1.5;background:#f5f6f8;color:#1d2430}
main{max-width:480px;margin:0 auto;padding:24px;background:#fff;border:1px solid #d8dde4;border-radius:10px}
h1{margin:0 0 12px;font-size:20px}
a{color:#0b5cad;word-break:break-all}
small{color:#5d6876}
@media (prefers-color-scheme:dark){body{background:#13161b;color:#e5e8ed}main{background:#1c2027;border-color:#2d333c}a{color:#80b7ff}small{color:#9aa4b1}}
</style>
</head>
<body>
<main>
<h1>__HEADING__</h1>
<p>Nếu trang không tự chuyển sau vài giây, bấm vào liên kết sau:</p>
<p><a id="go" href="__TARGET__">__TARGET__</a></p>
<p><small>Địa chỉ cập nhật lúc __UPDATED__ (UTC). Nếu liên kết không mở được, máy chủ demo có thể đang tắt.</small></p>
</main>
<script>
(function () {
  var fallback = "__TARGET__";
  var suffix = "__SUFFIX__";
  var done = false;
  function go(u) { if (done) { return; } done = true; window.location.replace(u); }
  var timer = setTimeout(function () { go(fallback); }, 2500);
  // Đọc config.json mới nhất (bỏ qua cache) để vẫn đúng khi trình duyệt còn giữ trang cũ.
  try {
    var x = new XMLHttpRequest();
    x.open("GET", "__CONFIG__?t=" + new Date().getTime(), true);
    x.timeout = 2000;
    x.onload = function () {
      try {
        var c = JSON.parse(x.responseText);
        if (/^https:\/\/[a-z0-9-]+\.trycloudflare\.com\/[A-Za-z0-9_-]+$/.test(c.base_url)) {
          clearTimeout(timer);
          var u = c.base_url + suffix;
          document.getElementById("go").href = u;
          go(u);
        }
      } catch (e) { }
    };
    x.send();
  } catch (e) { }
})();
</script>
</body>
</html>
'@

function New-RedirectPage([string]$suffix, [string]$configRel, [string]$title, [string]$heading) {
    return $PageTemplate.Replace('__TARGET__', $BaseUrl + $suffix).
        Replace('__SUFFIX__', $suffix).
        Replace('__CONFIG__', $configRel).
        Replace('__TITLE__', $title).
        Replace('__HEADING__', $heading).
        Replace('__UPDATED__', $UpdatedAt)
}

# Thứ tự giữ ổn định để in ra dễ đọc.
$Files = New-Object System.Collections.Specialized.OrderedDictionary
$Files['index.html'] = New-RedirectPage '/' 'config.json' 'Smart Locker' 'Đang chuyển tới hệ thống Smart Locker...'
foreach ($d in $DeviceCode) {
    $Files[('k/' + $d + '/index.html')] = New-RedirectPage ('/k/' + $d) '../../config.json' `
        ('Mở tủ ' + $d) ('Đang mở trang nhập mật mã của tủ ' + $d + '...')
}
$Files['config.json'] = '{"base_url":"' + $BaseUrl + '","updated_at":"' + $UpdatedAt + '"}' + "`n"
$Files['.nojekyll'] = ''

function Write-Files([string]$root) {
    foreach ($rel in $Files.Keys) {
        $path = Join-Path $root ($rel -replace '/', '\')
        $dir = Split-Path -Parent $path
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $content = ([string]$Files[$rel]) -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText($path, $content, $Utf8NoBom)
    }
}

Write-Step ("Tunnel:   " + $TunnelUrl)
Write-Step ("base_url: " + $BaseUrl)

if ($DryRun) {
    foreach ($rel in $Files.Keys) {
        Write-Host ""
        Write-Host ("----- " + $rel + " -----") -ForegroundColor Yellow
        if ($Files[$rel] -eq '') { Write-Host '(file rỗng)' } else { Write-Host $Files[$rel] }
    }
    Write-Host ""
    Write-Step 'DryRun: không tạo worktree, không commit, không push.'
    exit 0
}

# ---------------------------------------------------------------- 3. Thử tunnel (chỉ cảnh báo)
if (-not $SkipCheck) {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $resp = Invoke-WebRequest -Uri ($BaseUrl + '/') -UseBasicParsing -TimeoutSec 15 -MaximumRedirection 5
        Write-Step ("Tunnel trả lời HTTP " + [int]$resp.StatusCode)
    } catch {
        Write-Host ("CẢNH BÁO: chưa gọi được " + $BaseUrl + "/ (" + $_.Exception.Message + ")") -ForegroundColor Yellow
        Write-Host '          Kiểm tra Tomcat và cloudflared. Script vẫn tiếp tục.' -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------- 4. Worktree gh-pages
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Fail 'Không tìm thấy git trên PATH.' }
Invoke-Git @('rev-parse', '--git-dir') | Out-Null
Invoke-Git @('worktree', 'prune') | Out-Null

$branchRef = 'refs/heads/' + $Branch
$remoteRef = 'refs/remotes/' + $Remote + '/' + $Branch

# Lấy nhánh gh-pages trên GitHub (nếu có) để commit mới nối tiếp, tránh bị từ chối khi push.
$remoteHas = $false
$ls = Invoke-Git @('ls-remote', '--heads', $Remote, $Branch) -AllowFail
if ($script:LastGitCode -ne 0) {
    Write-Host ("CẢNH BÁO: không kiểm tra được " + $Remote + "/" + $Branch + " (mất mạng?). Dùng bản cục bộ.") -ForegroundColor Yellow
} elseif ($ls) {
    $remoteHas = $true
    Invoke-Git @('fetch', '--quiet', $Remote, ('+' + $branchRef + ':' + $remoteRef)) | Out-Null
}

Invoke-Git @('rev-parse', '--verify', '--quiet', $branchRef) -AllowFail | Out-Null
$localHas = ($script:LastGitCode -eq 0)

if ($remoteHas -and -not $localHas) {
    Invoke-Git @('branch', $Branch, $remoteRef) | Out-Null
    $localHas = $true
} elseif ($remoteHas -and $localHas) {
    Invoke-Git @('merge-base', '--is-ancestor', $branchRef, $remoteRef) -AllowFail | Out-Null
    if ($script:LastGitCode -eq 0) {
        Invoke-Git @('branch', '-f', $Branch, $remoteRef) | Out-Null   # tua nhanh tới bản trên GitHub
    }
}

$Worktree = Join-Path ([System.IO.Path]::GetTempPath()) ('smartlocker-ghpages-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$committed = $false
try {
    if ($localHas) {
        Write-Step ("Mở worktree tạm cho nhánh " + $Branch + ": " + $Worktree)
        Invoke-Git @('worktree', 'add', '--quiet', $Worktree, $Branch) | Out-Null
    } else {
        Write-Step ("Chưa có nhánh " + $Branch + ", tạo nhánh orphan trong worktree tạm: " + $Worktree)
        Invoke-Git @('worktree', 'add', '--quiet', '--orphan', '-b', $Branch, $Worktree) | Out-Null
    }

    Write-Files $Worktree
    # core.safecrlf=false chỉ áp dụng cho lệnh này (tắt cảnh báo LF/CRLF), không sửa git config.
    Invoke-Git @('-c', 'core.safecrlf=false', 'add', '-A', '--', '.') -Dir $Worktree | Out-Null
    Invoke-Git @('diff', '--cached', '--quiet') -Dir $Worktree -AllowFail | Out-Null
    if ($script:LastGitCode -eq 0) {
        Write-Step 'Không có thay đổi để commit.'
    } else {
        $msg = 'Update tunnel link: ' + $BaseUrl + ' (' + $UpdatedAt + ')'
        Invoke-Git @('commit', '--quiet', '-m', $msg) -Dir $Worktree | Out-Null
        $committed = $true
        $head = Invoke-Git @('log', '-1', '--format=%h %s') -Dir $Worktree
        Write-Step ("Đã commit trên " + $Branch + ": " + $head)
    }
} finally {
    if (Test-Path -LiteralPath $Worktree) {
        Invoke-Git @('worktree', 'remove', '--force', $Worktree) -AllowFail | Out-Null
        if (Test-Path -LiteralPath $Worktree) { Remove-Item -LiteralPath $Worktree -Recurse -Force -ErrorAction SilentlyContinue }
    }
    Invoke-Git @('worktree', 'prune') -AllowFail | Out-Null
}

# ---------------------------------------------------------------- 5. Push (cần xác nhận)
$pagesBase = 'https://hoangduc1003.github.io/SmartLocker/'
if ($NoPush) {
    Write-Step ("NoPush: chưa push. Khi sẵn sàng: git push " + $Remote + " " + $Branch)
    exit 0
}
Write-Host ""
$answer = Read-Host ("Đẩy nhánh " + $Branch + " lên GitHub (git push " + $Remote + " " + $Branch + ")? Gõ 'co' để đồng ý")
if ($answer -notmatch '^\s*(co|có|c|y|yes)\s*$') {
    Write-Step ("Chưa push. Commit vẫn nằm ở nhánh " + $Branch + " cục bộ. Lệnh push: git push " + $Remote + " " + $Branch)
    exit 0
}
Invoke-Git @('push', $Remote, $Branch) -AllowFail | Out-Null
if ($script:LastGitCode -ne 0) {
    Fail ("Push thất bại. Xem lỗi git ở trên (đăng nhập GitHub, mạng, hoặc nhánh trên GitHub đã khác). Xem docs/deploy.md mục Xử lý sự cố.")
}
Write-Step 'Đã push. GitHub Pages có thể mất tới khoảng 10 phút để cập nhật.'
Write-Host ("    Trang web:   " + $pagesBase)
foreach ($d in $DeviceCode) { Write-Host ("    Trang QR:    " + $pagesBase + 'k/' + $d + '/') }
Write-Host ("    config.json: " + $pagesBase + 'config.json')
