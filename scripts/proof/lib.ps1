# Shared by the proof scripts: the guards around the owner's database, and how to talk to SQL Server.
$ErrorActionPreference = "Stop"
$script:Server = "localhost"
$script:SqlUser = "sa"
$script:SqlPassword = "12345"
$script:RealDb = "PRJ301_LOCKER"
$script:RealDbCreated = "2026-10-28 07:20:35"
Add-Type -AssemblyName System.Data

function Assert-TestDb([string]$Name) {
    if ($Name -notmatch '^SL_[A-Za-z0-9_]+$') { throw "Refusing database '$Name': only SL_* names are allowed." }
}

function Open-Db([string]$Database) {
    $c = New-Object System.Data.SqlClient.SqlConnection("Server=$script:Server;Database=$Database;User Id=$script:SqlUser;Password=$script:SqlPassword;Encrypt=False;Connect Timeout=30")
    $c.Open()
    return $c
}

# Rows of a query as objects with the column names as properties.
function Get-Rows($Conn, [string]$Sql) {
    $cmd = $Conn.CreateCommand(); $cmd.CommandText = $Sql; $cmd.CommandTimeout = 600
    $table = New-Object System.Data.DataTable
    (New-Object System.Data.SqlClient.SqlDataAdapter($cmd)).Fill($table) | Out-Null
    return , $table
}

function Invoke-Master([string]$Sql) {
    & sqlcmd -S $script:Server -U $script:SqlUser -P $script:SqlPassword -d master -I -b -Q $Sql | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "sqlcmd failed: $Sql" }
}

function Remove-TestDb([string]$Name) {
    Assert-TestDb $Name
    Invoke-Master "IF DB_ID('$Name') IS NOT NULL BEGIN ALTER DATABASE [$Name] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$Name]; END"
}

# Run after every proof command: the owner's database must be the one created before the refactor.
function Assert-RealDbUntouched {
    $c = Open-Db "master"
    try {
        $t = Get-Rows $c "SELECT CONVERT(VARCHAR(19), create_date, 120) AS d FROM sys.databases WHERE name = '$script:RealDb'"
    } finally { $c.Close() }
    if ($t.Rows.Count -ne 1 -or $t.Rows[0].d -ne $script:RealDbCreated) {
        throw "ALARM: $script:RealDb create_date changed (expected $script:RealDbCreated)."
    }
    Write-Host "[ok] $script:RealDb create_date is still $script:RealDbCreated"
}

function Write-Utf8([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding $false))
}
