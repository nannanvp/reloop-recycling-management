$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$localDirectory = Join-Path $projectRoot '.local'
New-Item -ItemType Directory -Force $localDirectory | Out-Null
$secretPath = Join-Path $localDirectory 'db-secrets.json'
if (!(Test-Path -LiteralPath $secretPath)) {
    $config = [ordered]@{url='jdbc:oracle:thin:@//localhost:1521/XEPDB1'; ownerUsername='RC_OWNER'; ownerPassword=('RcO'+[guid]::NewGuid().ToString('N').Substring(0,24)); appUsername='RC_APP'; appPassword=('RcA'+[guid]::NewGuid().ToString('N').Substring(0,24)); labUsername='RC_LAB'; labPassword=('RcL'+[guid]::NewGuid().ToString('N').Substring(0,24))}
    $config | ConvertTo-Json | Set-Content -LiteralPath $secretPath -Encoding UTF8
}
$config = Get-Content -Raw -LiteralPath $secretPath | ConvertFrom-Json
function Invoke-Oracle([string]$Sql) {
    $output = $Sql | & sqlplus -L -s '/ as sysdba' 2>&1
    if ($LASTEXITCODE -ne 0) { throw ($output -join "`n") }
    $output | Write-Output
}
$provision = @"
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
SET VERIFY OFF
SET ECHO OFF
ALTER SESSION SET CONTAINER=XEPDB1;
DECLARE n NUMBER;
BEGIN
 SELECT COUNT(*) INTO n FROM dba_users WHERE username='RC_OWNER';
 IF n=0 THEN EXECUTE IMMEDIATE 'CREATE USER RC_OWNER IDENTIFIED BY "$($config.ownerPassword)" DEFAULT TABLESPACE USERS QUOTA 100M ON USERS'; END IF;
 SELECT COUNT(*) INTO n FROM dba_users WHERE username='RC_APP';
 IF n=0 THEN EXECUTE IMMEDIATE 'CREATE USER RC_APP IDENTIFIED BY "$($config.appPassword)"'; END IF;
 SELECT COUNT(*) INTO n FROM dba_users WHERE username='RC_LAB';
 IF n=0 THEN EXECUTE IMMEDIATE 'CREATE USER RC_LAB IDENTIFIED BY "$($config.labPassword)" DEFAULT TABLESPACE USERS QUOTA 10M ON USERS'; END IF;
END;
/
GRANT CREATE SESSION,CREATE TABLE,CREATE VIEW,CREATE PROCEDURE,CREATE TRIGGER,CREATE SEQUENCE TO RC_OWNER;
GRANT CREATE SESSION TO RC_APP;
GRANT CREATE SESSION,CREATE TABLE,CREATE VIEW TO RC_LAB;
SET HEADING OFF FEEDBACK OFF
SELECT COUNT(*) FROM dba_tables WHERE owner='RC_OWNER' AND table_name='RC_CENTRES';
EXIT
"@
$result = @(Invoke-Oracle $provision)
$hasSchema = (($result | Where-Object { "$_" -match '^\s*1\s*$' }).Count -gt 0)
$files = @()
if (!$hasSchema) { $files += '01_schema.sql' }
$files += @('02_routines.sql','03_views.sql','04_reference_seed.sql','05_grants.sql')
$commands = "WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK`nALTER SESSION SET CONTAINER=XEPDB1;`nALTER SESSION SET CURRENT_SCHEMA=RC_OWNER;`n"
# Connecting as owner makes USER_TABLES and object ownership unambiguous.
$commands += "CONNECT RC_OWNER/`"$($config.ownerPassword)`"@//localhost:1521/XEPDB1`n"
foreach($file in $files) { $commands += "@`"$(Join-Path $PSScriptRoot $file)`"`n" }
$commands += "EXIT`n"
Invoke-Oracle $commands
Write-Output 'Oracle schemas and reference data are ready. Credentials are in ignored .local/db-secrets.json.'
