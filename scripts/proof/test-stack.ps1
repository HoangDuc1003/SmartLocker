# A Tomcat of our own for tests: its own CATALINA_BASE on port 8081 (shutdown 8015), DB_URL on an SL_* database, no mail.
# It shares only the program files of E:\apache-tomcat-9.0.113; the Tomcat on 8080 belongs to the owner and is never touched.
#   powershell -ExecutionPolicy Bypass -File scripts\proof\test-stack.ps1 start -Database SL_NEWMAN [-Build]
#   powershell -ExecutionPolicy Bypass -File scripts\proof\test-stack.ps1 stop
#   powershell -ExecutionPolicy Bypass -File scripts\proof\test-stack.ps1 clean     (stop, then delete the base folder)
param(
    [Parameter(Mandatory, Position = 0)][ValidateSet("start", "stop", "clean")][string]$Action,
    [string]$Database,
    [switch]$Build,      # clean build of build/web first; never touches the owner's SmartLocker.xml
    [string]$Base = "C:\sl-wt\tomcat-8081",
    [string]$TomcatHome = "E:\apache-tomcat-9.0.113"
)
. "$PSScriptRoot\lib.ps1"
$repo = (Resolve-Path "$PSScriptRoot\..\..").Path
$env:JAVA_HOME = "C:\Program Files\Java\jdk1.8.0_202"
$env:CATALINA_HOME = $TomcatHome
$env:CATALINA_BASE = $Base

function Test-Port([int]$Port) {
    $c = New-Object Net.Sockets.TcpClient
    try { $c.Connect("127.0.0.1", $Port); return $true } catch { return $false } finally { $c.Close() }
}

function Stop-Stack {
    if (-not (Test-Path "$Base\conf\server.xml")) { return }
    if (Test-Port 8015) {
        & cmd /c "`"$TomcatHome\bin\catalina.bat`" stop >nul 2>&1"
        for ($i = 0; $i -lt 30 -and (Test-Port 8081); $i++) { Start-Sleep -Seconds 1 }
    }
    if (Test-Port 8081) { throw "Port 8081 is still open after the stop." }
    Write-Host "[ok] test Tomcat is stopped"
}

if ($Action -eq "stop") { Stop-Stack; exit 0 }
if ($Action -eq "clean") { Stop-Stack; if (Test-Path $Base) { Remove-Item -Recurse -Force $Base }; exit 0 }

Assert-TestDb $Database
if (Test-Port 8081) { throw "Port 8081 is already in use." }
# MailService looks in these two places: neither may exist, or the clock jobs would send real reminders
foreach ($f in @("$repo\config\mail.local.properties", "$Base\conf\smartlocker-mail.properties")) {
    if (Test-Path $f) { throw "Mail settings found at ${f}: the test stack must not send mail." }
}
if ($Build) {
    if (Test-Path "$repo\build\web") { Remove-Item -Recurse -Force "$repo\build\web" }
    Push-Location $repo
    try {
        $env:TOMCAT = $TomcatHome
        # sh of Git for Windows: it is not on the PATH of PowerShell
        $gitRoot = (Get-Command git).Source -replace '\\(mingw64\\bin|cmd|bin)\\git\.exe$', ''
        & (Join-Path $gitRoot "bin\sh.exe") scripts/build-dev.sh --no-reload
        if ($LASTEXITCODE -ne 0) { throw "Build failed." }
    } finally { Pop-Location }
}

foreach ($d in "conf\Catalina\localhost", "logs", "temp", "work", "webapps") { New-Item -ItemType Directory -Force "$Base\$d" | Out-Null }
foreach ($f in "web.xml", "context.xml", "catalina.properties", "catalina.policy", "logging.properties", "tomcat-users.xml") {
    Copy-Item "$TomcatHome\conf\$f" "$Base\conf\$f" -Force
}
$xml = [IO.File]::ReadAllText("$TomcatHome\conf\server.xml")
$xml = $xml.Replace('<Server port="8005"', '<Server port="8015"').Replace('<Connector port="8080"', '<Connector port="8081"')
if ($xml -notmatch '<Server port="8015"' -or $xml -notmatch '<Connector port="8081"') { throw "server.xml did not take the new ports." }
Write-Utf8 "$Base\conf\server.xml" $xml
Write-Utf8 "$Base\conf\Catalina\localhost\SmartLocker.xml" "<Context docBase=`"$repo\build\web`" reloadable=`"false`"><CookieProcessor className=`"org.apache.tomcat.util.http.Rfc6265CookieProcessor`" sameSiteCookies=`"lax`" /></Context>`n"
Get-ChildItem "$Base\logs" -File | Remove-Item -Force

$env:DB_URL = "jdbc:sqlserver://localhost:1433;databaseName=$Database;encrypt=false"
Start-Process -FilePath "$TomcatHome\bin\catalina.bat" -ArgumentList "start" -WindowStyle Minimized

$up = $false
for ($i = 0; $i -lt 60 -and -not $up; $i++) {
    Start-Sleep -Seconds 2
    try {
        $r = Invoke-WebRequest "http://localhost:8081/SmartLocker/api/locker-map" -UseBasicParsing -TimeoutSec 5
        $up = $r.StatusCode -eq 200
    } catch { }
}
if (-not $up) { Stop-Stack; throw "The app did not answer on 8081; see $Base\logs." }

# The log must say that reminders are off, and the app must really be on the test database.
Start-Sleep -Seconds 2
$log = Get-ChildItem "$Base\logs" -Filter "*.log" | ForEach-Object { Get-Content $_.FullName -Encoding UTF8 }
if (-not ($log -match "Due reminder e-mails off")) { Stop-Stack; throw "The log does not say that the reminders are off." }
if ($log -match "Due reminder e-mails on") { Stop-Stack; throw "Reminders are ON: this stack could send real mail." }
Write-Host "[ok] log: Due reminder e-mails off"
$c = Open-Db "master"
try {
    $s = Get-Rows $c "SELECT DB_NAME(database_id) AS db, COUNT(*) AS n FROM sys.dm_exec_sessions WHERE program_name LIKE 'Microsoft JDBC%' AND DB_NAME(database_id) = '$Database' GROUP BY database_id"
} finally { $c.Close() }
if ($s.Rows.Count -eq 0) { Stop-Stack; throw "No JDBC session on $Database." }
Write-Host "[ok] test Tomcat on http://localhost:8081/SmartLocker, $($s.Rows[0].n) JDBC sessions on $Database"
Assert-RealDbUntouched
exit 0
