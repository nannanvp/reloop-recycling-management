param([string]$SqlPlusPath='sqlplus',[ValidateRange(1,65535)][int]$Port=1521)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$localDirectory = Join-Path $projectRoot '.local'
New-Item -ItemType Directory -Force $localDirectory | Out-Null
$secretPath = Join-Path $localDirectory 'db-secrets.json'
$config=$null
function Invoke-Oracle([string]$Sql) {
    $output = @($Sql | & $SqlPlusPath -L -s '/ as sysdba' 2>&1)
    $code=$LASTEXITCODE
    $safe=$output -join "`n"
    if($config){foreach($key in @('ownerPassword','appPassword','labPassword')){if($config.$key){$safe=$safe.Replace([string]$config.$key,'[redacted]')}}}
    if ($code -ne 0 -or $safe -match '(?m)^\s*(ORA-|SP2-)') { throw ($safe+"`nOracle setup stopped. Use the Windows account that installed Oracle (ORA_DBA membership). After a new Oracle installation, sign out of Windows and back in if OS authentication fails. No existing password is reset by this script.") }
    $safe -split "`n" | Write-Output
}
$preflight=@'
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
SET HEADING OFF FEEDBACK OFF PAGESIZE 0
DECLARE v_mode VARCHAR2(20);
BEGIN
 SELECT open_mode INTO v_mode FROM v$pdbs WHERE name='XEPDB1';
 IF v_mode='MOUNTED' THEN
  EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE XEPDB1 OPEN';
  EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE XEPDB1 SAVE STATE';
 END IF;
END;
/
SELECT 'RC_PDB_MODE='||open_mode FROM v$pdbs WHERE name='XEPDB1';
ALTER SESSION SET CONTAINER=XEPDB1;
SELECT 'RC_USERS_EXIST='||COUNT(*) FROM dba_users WHERE username IN('RC_OWNER','RC_APP','RC_LAB');
SELECT 'RC_TABLES_EXIST='||COUNT(*) FROM dba_tables WHERE owner='RC_OWNER' AND table_name IN('RC_CENTRES','RC_USERS','RC_MATERIALS','RC_PICKUPS','RC_PICKUP_ITEMS','RC_BATCHES','RC_REWARD_LEDGER','RC_AUDIT_LOG');
EXIT
'@
$preflightResult=@(Invoke-Oracle $preflight) -join "`n"
if($preflightResult -notmatch 'RC_PDB_MODE=READ WRITE'){throw 'XEPDB1 must be open READ WRITE. Open it through your Oracle administrator, then rerun setup.'}
if($preflightResult -notmatch 'RC_USERS_EXIST=(\d+)'){throw 'Could not determine existing Oracle schema identities.'}
$existingUsers=[int]$Matches[1]
if($preflightResult -notmatch 'RC_TABLES_EXIST=(\d+)'){throw 'Could not determine existing Oracle tables.'}
$existingTables=[int]$Matches[1]
if($existingTables -gt 0 -and $existingTables -lt 8){throw 'An incomplete RC_OWNER schema already exists. Setup will not overwrite or reset it. Restore the schema or ask your database administrator to repair it.'}
if (!(Test-Path -LiteralPath $secretPath)) {
    if($existingUsers -gt 0){throw 'ReLoop database accounts already exist on this PC, but this folder has no credentials. Reuse your existing project folder, or privately copy its .local/db-secrets.json into this installation. Setup will not reset passwords or data.'}
    $config = [ordered]@{url="jdbc:oracle:thin:@//localhost:$Port/XEPDB1"; ownerUsername='RC_OWNER'; ownerPassword=('RcO'+[guid]::NewGuid().ToString('N').Substring(0,24)); appUsername='RC_APP'; appPassword=('RcA'+[guid]::NewGuid().ToString('N').Substring(0,24)); labUsername='RC_LAB'; labPassword=('RcL'+[guid]::NewGuid().ToString('N').Substring(0,24))}
    # Windows PowerShell 5.1 Set-Content -Encoding UTF8 adds a BOM; Jackson's String reader rejects it.
    [IO.File]::WriteAllText($secretPath,($config|ConvertTo-Json),(New-Object Text.UTF8Encoding($false)))
}
$config = Get-Content -Raw -LiteralPath $secretPath | ConvertFrom-Json
if($config.url -notmatch '^jdbc:oracle:thin:@//localhost:(\d+)/XEPDB1$'){throw 'This local setup script only provisions localhost/XEPDB1. Preserve your existing config and set up other databases manually.'}
$Port=[int]$Matches[1]
if($Port -lt 1 -or $Port -gt 65535){throw 'Invalid Oracle port in local configuration.'}
foreach($key in @('ownerPassword','appPassword','labPassword')){if($config.$key -notmatch '^[A-Za-z0-9!#_.$-]{12,100}$'){throw 'Local database password configuration is missing or uses unsupported setup-script characters. No credentials were changed.'}}
if($config.ownerUsername -ne 'RC_OWNER' -or $config.appUsername -ne 'RC_APP' -or $config.labUsername -ne 'RC_LAB'){throw 'Unexpected schema names in existing local configuration.'}
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
$hasSchema = ($existingTables -eq 8)
$files = @()
if (!$hasSchema) { $files += '01_schema.sql' }
$files += @('02_routines.sql','03_views.sql')
if(!$hasSchema){$files += '04_reference_seed.sql'}
$files += '05_grants.sql'
$commands = "WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK`nALTER SESSION SET CONTAINER=XEPDB1;`nALTER SESSION SET CURRENT_SCHEMA=RC_OWNER;`n"
# Connecting as owner makes USER_TABLES and object ownership unambiguous.
$commands += "CONNECT RC_OWNER/`"$($config.ownerPassword)`"@//localhost:$Port/XEPDB1`n"
foreach($file in $files) { $commands += "@`"$(Join-Path $PSScriptRoot $file)`"`n" }
$commands += "@`"$(Join-Path $PSScriptRoot '06_verify.sql')`"`n"
$commands += "EXIT`n"
Invoke-Oracle $commands
Write-Output 'Oracle schemas and reference data are ready. Credentials are in ignored .local/db-secrets.json.'
