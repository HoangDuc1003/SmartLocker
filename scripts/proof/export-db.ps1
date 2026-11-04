# Writes an SL_* database as canonical text, so two databases can be compared with a plain diff.
# Names SQL Server generates (PK__Users__3B75D760) print as <auto>; times (also ISO text in a string column) print as an
# offset in minutes from the moment the database was created; a value of a natural.txt column prints as <natural:length>
# (NULL stays NULL): those columns differ between two builds of one script.
#   powershell -ExecutionPolicy Bypass -File scripts\proof\export-db.ps1 -Database SL_OLD -OutDir C:\temp\old
param(
    [Parameter(Mandatory)][string]$Database,
    [Parameter(Mandatory)][string]$OutDir,
    [switch]$RawNatural      # do not mask natural.txt: used to learn which columns really differ
)
. "$PSScriptRoot\lib.ps1"
Assert-TestDb $Database
if (Test-Path $OutDir) { Remove-Item -Recurse -Force $OutDir }
New-Item -ItemType Directory (Join-Path $OutDir "data") | Out-Null
$natural = @{}
Get-Content "$PSScriptRoot\natural.txt" -Encoding UTF8 | Where-Object { $_ -and -not $_.StartsWith('#') } | ForEach-Object { $natural[$_.Trim()] = $true }

$conn = Open-Db $Database
function Save-Query([string]$File, [string]$Sql) {
    $t = Get-Rows $conn $Sql
    Write-Utf8 (Join-Path $OutDir $File) ((@($t.Rows | ForEach-Object { $_.line }) -join "`n") + "`n")
}

# ---- metadata ----
$typeOf = "t.name + CASE WHEN t.name IN ('nvarchar','nchar') THEN '(' + IIF(c.max_length = -1, 'max', CAST(c.max_length / 2 AS VARCHAR)) + ')' WHEN t.name IN ('varchar','char','varbinary','binary') THEN '(' + IIF(c.max_length = -1, 'max', CAST(c.max_length AS VARCHAR)) + ')' WHEN t.name IN ('decimal','numeric') THEN '(' + CAST(c.precision AS VARCHAR) + ',' + CAST(c.scale AS VARCHAR) + ')' WHEN t.name IN ('datetime2','time','datetimeoffset') THEN '(' + CAST(c.scale AS VARCHAR) + ')' ELSE '' END"
Save-Query "01_columns.txt" @"
SELECT o.type_desc COLLATE DATABASE_DEFAULT + ' ' + o.name + ' #' + RIGHT('00' + CAST(c.column_id AS VARCHAR), 3) + ' ' + c.name + ' ' + $typeOf
  + IIF(c.is_nullable = 1, ' NULL', ' NOT NULL') + ISNULL(' COLLATE ' + c.collation_name COLLATE DATABASE_DEFAULT, '')
  + ISNULL(' COMPUTED ' + cc.definition + IIF(cc.is_persisted = 1, ' PERSISTED', ''), '') AS line
FROM sys.columns c JOIN sys.objects o ON o.object_id = c.object_id AND o.type IN ('U','V','TF','IF')
JOIN sys.types t ON t.user_type_id = c.user_type_id
LEFT JOIN sys.computed_columns cc ON cc.object_id = c.object_id AND cc.column_id = c.column_id
ORDER BY o.type_desc, o.name, c.column_id
"@
Save-Query "02_identity.txt" @"
SELECT o.name + '.' + c.name + ' seed=' + CAST(c.seed_value AS VARCHAR) + ' inc=' + CAST(c.increment_value AS VARCHAR)
  + ' last=' + ISNULL(CAST(c.last_value AS VARCHAR), 'NULL') AS line
FROM sys.identity_columns c JOIN sys.objects o ON o.object_id = c.object_id AND o.type = 'U' ORDER BY o.name
"@
Save-Query "03_constraints.txt" @"
SELECT line FROM (
  SELECT 'CHECK ' + OBJECT_NAME(k.parent_object_id) + ' ' + IIF(k.is_system_named = 1, '<auto>', k.name)
    + ISNULL(' on ' + COL_NAME(k.parent_object_id, NULLIF(k.parent_column_id, 0)), '') + ' ' + k.definition
    + IIF(k.is_disabled = 1, ' DISABLED', '') + IIF(k.is_not_trusted = 1, ' NOT TRUSTED', '') AS line
  FROM sys.check_constraints k
  UNION ALL
  SELECT 'DEFAULT ' + OBJECT_NAME(k.parent_object_id) + ' ' + IIF(k.is_system_named = 1, '<auto>', k.name)
    + ' on ' + COL_NAME(k.parent_object_id, k.parent_column_id) + ' ' + k.definition
  FROM sys.default_constraints k
  UNION ALL
  SELECT 'FK ' + OBJECT_NAME(f.parent_object_id) + ' ' + IIF(f.is_system_named = 1, '<auto>', f.name) + ' ('
    + (SELECT STRING_AGG(COL_NAME(x.parent_object_id, x.parent_column_id), ',') WITHIN GROUP (ORDER BY x.constraint_column_id) FROM sys.foreign_key_columns x WHERE x.constraint_object_id = f.object_id)
    + ') -> ' + OBJECT_NAME(f.referenced_object_id) + ' ('
    + (SELECT STRING_AGG(COL_NAME(x.referenced_object_id, x.referenced_column_id), ',') WITHIN GROUP (ORDER BY x.constraint_column_id) FROM sys.foreign_key_columns x WHERE x.constraint_object_id = f.object_id)
    + ') delete=' + f.delete_referential_action_desc COLLATE DATABASE_DEFAULT + ' update=' + f.update_referential_action_desc COLLATE DATABASE_DEFAULT
    + IIF(f.is_disabled = 1, ' DISABLED', '') + IIF(f.is_not_trusted = 1, ' NOT TRUSTED', '')
  FROM sys.foreign_keys f
) x ORDER BY line
"@
Save-Query "04_indexes.txt" @"
SELECT o.name + ' ' + IIF(kc.is_system_named = 1, '<auto>', ISNULL(i.name, '<heap>')) + ' ' + i.type_desc COLLATE DATABASE_DEFAULT
  + IIF(i.is_primary_key = 1, ' PK', '') + IIF(i.is_unique_constraint = 1, ' UQ', '') + IIF(i.is_unique = 1, ' UNIQUE', '')
  + ' (' + ISNULL((SELECT STRING_AGG(COL_NAME(x.object_id, x.column_id) + IIF(x.is_descending_key = 1, ' DESC', ''), ',') WITHIN GROUP (ORDER BY x.key_ordinal) FROM sys.index_columns x WHERE x.object_id = i.object_id AND x.index_id = i.index_id AND x.is_included_column = 0), '') + ')'
  + ISNULL(' INCLUDE (' + (SELECT STRING_AGG(COL_NAME(x.object_id, x.column_id), ',') WITHIN GROUP (ORDER BY x.column_id) FROM sys.index_columns x WHERE x.object_id = i.object_id AND x.index_id = i.index_id AND x.is_included_column = 1) + ')', '')
  + ISNULL(' WHERE ' + i.filter_definition, '') + IIF(i.is_disabled = 1, ' DISABLED', '') + IIF(i.ignore_dup_key = 1, ' IGNORE_DUP_KEY', '')
  + IIF(i.fill_factor <> 0, ' FILLFACTOR=' + CAST(i.fill_factor AS VARCHAR), '') AS line
FROM sys.indexes i JOIN sys.objects o ON o.object_id = i.object_id AND o.type IN ('U','V')
LEFT JOIN sys.key_constraints kc ON kc.parent_object_id = i.object_id AND kc.unique_index_id = i.index_id
ORDER BY line
"@
Save-Query "05_parameters.txt" @"
SELECT o.name + ' #' + RIGHT('00' + CAST(c.parameter_id AS VARCHAR), 3) + ' ' + IIF(c.name = '', '<return>', c.name) + ' ' + $typeOf
  + IIF(c.is_output = 1 AND c.parameter_id > 0, ' OUTPUT', '') AS line
FROM sys.parameters c JOIN sys.objects o ON o.object_id = c.object_id JOIN sys.types t ON t.user_type_id = c.user_type_id
WHERE o.is_ms_shipped = 0 ORDER BY o.name, c.parameter_id
"@
Save-Query "06_objects.txt" @"
SELECT line FROM (
  SELECT o.type_desc COLLATE DATABASE_DEFAULT + ' ' + o.name AS line FROM sys.objects o
    WHERE o.is_ms_shipped = 0 AND o.parent_object_id = 0 AND o.type NOT IN ('S','IT','SQ') OR o.type = 'SO'
  UNION ALL SELECT 'USER TYPE ' + t.name + ' base=' + TYPE_NAME(t.system_type_id) + ' len=' + CAST(t.max_length AS VARCHAR) + ' prec=' + CAST(t.precision AS VARCHAR) + ' scale=' + CAST(t.scale AS VARCHAR) + IIF(t.is_nullable = 1, ' NULL', ' NOT NULL')
    FROM sys.types t WHERE t.is_user_defined = 1
  UNION ALL SELECT 'TABLE TYPE ' + tt.name + ' #' + RIGHT('00' + CAST(c.column_id AS VARCHAR), 3) + ' ' + c.name + ' ' + TYPE_NAME(c.user_type_id) + ' len=' + CAST(c.max_length AS VARCHAR) + IIF(c.is_nullable = 1, ' NULL', ' NOT NULL')
    FROM sys.table_types tt JOIN sys.columns c ON c.object_id = tt.type_table_object_id
  UNION ALL SELECT 'SEQUENCE ' + s.name + ' start=' + CAST(s.start_value AS VARCHAR) + ' inc=' + CAST(s.increment AS VARCHAR) + ' current=' + CAST(s.current_value AS VARCHAR)
    FROM sys.sequences s
  UNION ALL SELECT 'TRIGGER ' + tr.name + ' on ' + ISNULL(OBJECT_NAME(tr.parent_id), 'DATABASE') + IIF(tr.is_disabled = 1, ' DISABLED', '') + IIF(tr.is_instead_of_trigger = 1, ' INSTEAD OF', '')
    FROM sys.triggers tr
) x ORDER BY line
"@

Save-Query "08_security.txt" @"
SELECT line FROM (
  SELECT 'PRINCIPAL ' + p.name + ' ' + p.type_desc COLLATE DATABASE_DEFAULT AS line FROM sys.database_principals p WHERE p.is_fixed_role = 0 AND p.principal_id > 4 AND p.principal_id < 16384
  UNION ALL SELECT 'PERMISSION ' + d.state_desc COLLATE DATABASE_DEFAULT + ' ' + d.permission_name COLLATE DATABASE_DEFAULT + ' on ' + d.class_desc COLLATE DATABASE_DEFAULT + ' ' + ISNULL(OBJECT_NAME(d.major_id), '') + ' to ' + USER_NAME(d.grantee_principal_id)
    FROM sys.database_permissions d WHERE d.grantee_principal_id > 4 AND d.grantee_principal_id < 16384
  UNION ALL SELECT 'MEMBER ' + USER_NAME(m.member_principal_id) + ' of ' + USER_NAME(m.role_principal_id) FROM sys.database_role_members m WHERE m.member_principal_id <> 1
) x ORDER BY line
"@
Save-Query "09_database.txt" @"
SELECT line FROM (
  SELECT 'EXTENDED PROPERTY class=' + CAST(e.class AS VARCHAR) + ' ' + ISNULL(OBJECT_NAME(e.major_id), '') + ' minor=' + CAST(e.minor_id AS VARCHAR) + ' ' + e.name + '=' + CAST(e.value AS NVARCHAR(4000)) AS line FROM sys.extended_properties e
  UNION ALL SELECT 'OPTION ' + o.k + '=' + o.v FROM sys.databases d CROSS APPLY (VALUES
    ('compatibility_level', CAST(d.compatibility_level AS VARCHAR)), ('collation', CAST(d.collation_name AS VARCHAR(100)) COLLATE DATABASE_DEFAULT), ('recursive_triggers', CAST(d.is_recursive_triggers_on AS VARCHAR)),
    ('ansi_nulls', CAST(d.is_ansi_nulls_on AS VARCHAR)), ('ansi_padding', CAST(d.is_ansi_padding_on AS VARCHAR)), ('ansi_warnings', CAST(d.is_ansi_warnings_on AS VARCHAR)),
    ('arithabort', CAST(d.is_arithabort_on AS VARCHAR)), ('concat_null', CAST(d.is_concat_null_yields_null_on AS VARCHAR)), ('quoted_identifier', CAST(d.is_quoted_identifier_on AS VARCHAR)),
    ('read_committed_snapshot', CAST(d.is_read_committed_snapshot_on AS VARCHAR)), ('snapshot_isolation', CAST(d.snapshot_isolation_state AS VARCHAR)), ('recovery', CAST(d.recovery_model_desc AS VARCHAR(60)) COLLATE DATABASE_DEFAULT),
    ('auto_close', CAST(d.is_auto_close_on AS VARCHAR)), ('trustworthy', CAST(d.is_trustworthy_on AS VARCHAR)), ('broker', CAST(d.is_broker_enabled AS VARCHAR))
  ) o(k, v) WHERE d.name = DB_NAME()
) x ORDER BY line
"@
# The hashes are masked (they cover the build time), so the chain itself is recomputed here: a seed that edits a logged row shows.
Save-Query "10_audit_chain.txt" @"
SELECT 'audit ' + CAST(a.audit_id AS VARCHAR)
  + ' row_hash=' + IIF(a.row_hash = h.chain_hash, 'ok', 'BAD')
  + ' recomputed=' + IIF(LOWER(CONVERT(CHAR(64), HASHBYTES('SHA2_256', CONCAT(a.audit_id, '|', CONVERT(NVARCHAR(33), a.ts, 126), '|', a.actor_user_id, '|', a.action, '|', a.object_type, '|', a.object_id, '|', ISNULL(a.diff_json, N''), '|', h.prev_hash)), 2)) = h.chain_hash, 'ok', 'BAD')
  + ' link=' + IIF(h.prev_hash = LAG(h.chain_hash, 1, REPLICATE('0', 64)) OVER (ORDER BY h.anchor_id), 'ok', 'BAD') AS line
FROM AuditLog a LEFT JOIN HashChain h ON h.audit_id = a.audit_id ORDER BY a.audit_id
"@

# ---- modules: comments and white space gone, line breaks where we choose them, so a reformat never shows ----
$strip = [regex]"('(?:[^']|'')*')|(--[^\r\n]*)|(/\*[\s\S]*?\*/)|(\s+)"
$breaks = [regex]"('(?:[^']|'')*')|\b(BEGIN|END|IF|ELSE|WHILE|SELECT|FROM|WHERE|JOIN|LEFT JOIN|INSERT|UPDATE|DELETE|MERGE|DECLARE|SET|EXEC|THROW|RETURN|COMMIT|ROLLBACK|CASE|WHEN)\b"
$out = New-Object System.Text.StringBuilder
$mods = Get-Rows $conn "SELECT ISNULL(o.name, t.name) AS name, ISNULL(o.type_desc COLLATE DATABASE_DEFAULT, 'DATABASE_TRIGGER') AS type_desc, m.definition, m.uses_ansi_nulls, m.uses_quoted_identifier FROM sys.sql_modules m LEFT JOIN sys.objects o ON o.object_id = m.object_id LEFT JOIN sys.triggers t ON t.object_id = m.object_id ORDER BY ISNULL(o.name, t.name)"
foreach ($m in $mods.Rows) {
    $text = $strip.Replace([string]$m.definition, { param($x) if ($x.Groups[1].Success) { $x.Value } else { ' ' } }).Trim()
    # CREATE OR ALTER, ALTER and CREATE store different text for the same module
    $text = [regex]::Replace($text, '^(CREATE\s+OR\s+ALTER|ALTER|CREATE)\s+(PROCEDURE|PROC)\b', 'CREATE PROCEDURE', 'IgnoreCase')
    $text = [regex]::Replace($text, '^(CREATE\s+OR\s+ALTER|ALTER|CREATE)\s+(VIEW|FUNCTION|TRIGGER)\b', 'CREATE $2', 'IgnoreCase')
    # a line break inside a string literal is content: print it escaped, so the line handling below never reaches it
    $text = $breaks.Replace($text, { param($x) if ($x.Groups[1].Success) { $x.Value.Replace("`r", '\r').Replace("`n", '\n') } else { "`n" + $x.Value } })
    [void]$out.Append("=== $($m.type_desc) $($m.name) ansi_nulls=$($m.uses_ansi_nulls) quoted_identifier=$($m.uses_quoted_identifier)`n")
    # every line carries its module, so a diff line (and an accepted.txt line) says where it is
    [void]$out.Append((($text -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ } | ForEach-Object { "$($m.name): $_" }) -join "`n") + "`n")
}
Write-Utf8 (Join-Path $OutDir "07_modules.txt") $out.ToString()

# ---- data: every table, sorted by primary key (or by the whole line when it has none) ----
$mark = (Get-Rows $conn "SELECT DATEADD(MINUTE, DATEDIFF(MINUTE, GETDATE(), GETUTCDATE()), d.create_date) AS m FROM sys.databases d WHERE d.name = DB_NAME()").Rows[0].m
function Format-Cell($v, [string]$typeName, [string]$key) {
    if ($v -is [DBNull]) { return 'NULL' }
    if ($natural.ContainsKey($key) -and -not $RawNatural) { return "<natural:$(([string]$v).Length)$(if ([string]$v -match '^\d+$') { ':digits' })>" }
    if ($v -is [string] -and $v -match '^\d{4}-\d\d-\d\d[T ]\d\d:\d\d:\d\d(\.\d+)?$') { $v = [DateTime]::Parse($v, [Globalization.CultureInfo]::InvariantCulture) }
    if ($v -is [DateTime]) {
        if ($typeName -eq 'date') { return 'D' + [int]($v.Date - $mark.Date).TotalDays }
        # a seed row is "now minus N minutes"; the build takes a second or two, so round the offset to the minute
        return 'T' + [string][math]::Round(($v - $mark).TotalMinutes) + 'm'
    }
    if ($v -is [byte[]]) { return '0x' + [BitConverter]::ToString($v).Replace('-', '') }
    if ($v -is [double] -or $v -is [float]) { return $v.ToString('R', [Globalization.CultureInfo]::InvariantCulture) }
    if ($v -is [IFormattable]) { return $v.ToString($null, [Globalization.CultureInfo]::InvariantCulture) }
    # other control characters too: one NUL makes git call the whole file binary
    return [regex]::Replace(([string]$v).Replace('\', '\\').Replace("`r", '\r').Replace("`n", '\n'), '[\x00-\x1F]', { param($c) '\x{0:X2}' -f [int][char]$c.Value })
}
$tables = Get-Rows $conn "SELECT name FROM sys.tables WHERE is_ms_shipped = 0 ORDER BY name"
foreach ($tr in $tables.Rows) {
    $name = $tr.name
    $pk = Get-Rows $conn "SELECT COL_NAME(ic.object_id, ic.column_id) AS c FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id WHERE i.object_id = OBJECT_ID('$name') AND i.is_primary_key = 1 ORDER BY ic.key_ordinal"
    $order = if ($pk.Rows.Count) { " ORDER BY " + (($pk.Rows | ForEach-Object { "[$($_.c)]" }) -join ',') } else { "" }
    $cmd = $conn.CreateCommand(); $cmd.CommandText = "SELECT * FROM [$name]$order"; $cmd.CommandTimeout = 600
    $rd = $cmd.ExecuteReader()
    $cols = 0..($rd.FieldCount - 1)
    $names = $cols | ForEach-Object { $rd.GetName($_) }
    $types = $cols | ForEach-Object { $rd.GetDataTypeName($_) }
    $lines = New-Object System.Collections.Generic.List[string]
    while ($rd.Read()) {
        $cells = foreach ($i in $cols) { $names[$i] + '=' + (Format-Cell $rd.GetValue($i) $types[$i] "$name.$($names[$i])") }
        $lines.Add($cells -join ' | ')
    }
    $rd.Close()
    if (-not $pk.Rows.Count) { $lines.Sort([StringComparer]::Ordinal) }
    Write-Utf8 (Join-Path $OutDir "data\$name.txt") (($lines -join "`n") + "`n")
}
$conn.Close()
Assert-RealDbUntouched
