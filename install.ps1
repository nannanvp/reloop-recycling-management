# Downloaded by Setup-ReLoop.bat; requires Windows PowerShell 5.1 or newer.
[CmdletBinding()]
param(
 [string]$Revision,
 [string]$InstallDir = $(if($env:RELOOP_INSTALL_DIR){$env:RELOOP_INSTALL_DIR}else{Join-Path $env:LOCALAPPDATA 'ReLoop'}),
 [int]$OraclePort = 1521,
 [switch]$NoBrowser = ($env:RELOOP_NO_BROWSER -eq '1'),
 [switch]$NonInteractive = ($env:RELOOP_NONINTERACTIVE -eq '1'),
 [switch]$LibraryOnly
)
$ErrorActionPreference='Stop'
$script:Repo='nannanvp/reloop-recycling-management'
$script:OracleUrl='https://download.oracle.com/otn-pub/otn_software/db-express/OracleXE213_Win64.zip'
# Published on https://www.oracle.com/database/technologies/xe-downloads.html
$script:OracleSha256='939742c3305c466566a55f607638621b6aa7033a183175f6bcd6cffb48e6bc3f'
$script:Headers=@{'User-Agent'='ReLoop-Setup'}

function Write-Utf8([string]$Path,[string]$Text){
 [IO.File]::WriteAllText($Path,$Text,(New-Object Text.UTF8Encoding($false)))
}
function Assert-Platform {
 if($env:OS -ne 'Windows_NT' -or -not [Environment]::Is64BitOperatingSystem){throw 'ReLoop setup requires 64-bit Windows.'}
 $arch=if($env:PROCESSOR_ARCHITEW6432){$env:PROCESSOR_ARCHITEW6432}else{$env:PROCESSOR_ARCHITECTURE}
 if($arch -ne 'AMD64'){throw 'This installer targets Intel/AMD x64 Windows. Oracle XE 21c is not packaged here for ARM or 32-bit Windows.'}
 if($PSVersionTable.PSVersion.Major -lt 5){throw 'Windows PowerShell 5.1 or newer is required.'}
 if(-not [Environment]::Is64BitProcess){throw 'Run the BAT with the normal 64-bit Windows command prompt, not a 32-bit shell.'}
}
function Assert-Https([string]$Url){if(([uri]$Url).Scheme -ne 'https'){throw 'Only HTTPS download sources are allowed.'}}
function Get-Json([string]$Url){Assert-Https $Url;Invoke-RestMethod -Uri $Url -Headers $script:Headers -TimeoutSec 60}
function Save-Download([string]$Url,[string]$Path,[string]$Hash='',[string]$Algorithm='SHA256'){
 Assert-Https $Url
 if($Hash -and (Test-Path -LiteralPath $Path) -and ((Get-FileHash -LiteralPath $Path -Algorithm $Algorithm).Hash -eq $Hash)){return}
 New-Item -ItemType Directory -Force -Path (Split-Path $Path -Parent) | Out-Null
 Write-Host ('Downloading '+[IO.Path]::GetFileName($Path)+' ...')
 # A partial download is never reused without a successful checksum.
 Invoke-WebRequest -Uri $Url -UseBasicParsing -Headers $script:Headers -OutFile $Path -TimeoutSec 3600
 if((Get-Item -LiteralPath $Path).Length -eq 0){throw 'Downloaded file is empty.'}
 if($Hash -and (Get-FileHash -LiteralPath $Path -Algorithm $Algorithm).Hash -ne $Hash){throw ('Checksum mismatch: '+$Path+'. Run setup again to redownload it.')}
}
function Expand-SafeZip([string]$Zip,[string]$Destination){
 Add-Type -AssemblyName System.IO.Compression.FileSystem
 $base=[IO.Path]::GetFullPath($Destination).TrimEnd('\')+'\'
 $archive=[IO.Compression.ZipFile]::OpenRead($Zip)
 try{
  foreach($entry in $archive.Entries){
   $name=$entry.FullName.Replace('/','\')
   if($name.Contains(':') -or [IO.Path]::IsPathRooted($name)){throw 'Archive contains an absolute or alternate-stream path.'}
   $target=[IO.Path]::GetFullPath((Join-Path $base $name))
   if(-not $target.StartsWith($base,[StringComparison]::OrdinalIgnoreCase)){throw 'Archive entry escapes its extraction directory.'}
   if((($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000){throw 'Symbolic links are not accepted in installation archives.'}
  }
 }finally{$archive.Dispose()}
 [IO.Compression.ZipFile]::ExtractToDirectory($Zip,$Destination)
}
function Get-Project([string]$Target,[string]$Commit,[string]$Cache){
 if($Commit -notmatch '^[0-9a-f]{40}$'){throw 'A valid pinned GitHub revision is required.'}
 $Target=[IO.Path]::GetFullPath($Target)
 $marker=Join-Path $Target '.local/install-state.json'
 if(Test-Path -LiteralPath $Target){
  if(Test-Path -LiteralPath $marker){
   $state=Get-Content -Raw -LiteralPath $marker | ConvertFrom-Json
   if($state.repository -ne $script:Repo){throw 'This directory belongs to another installer.'}
   foreach($needed in @('pom.xml','start.ps1','database/setup.ps1')){if(-not (Test-Path -LiteralPath (Join-Path $Target $needed))){throw 'Existing installation is incomplete. Preserve its .local folder and restore the missing project source before retrying.'}}
   Write-Host 'Reusing the existing ReLoop installation. Source files and local data will not be overwritten.'
   return $Target
  }
  if(@(Get-ChildItem -LiteralPath $Target -Force).Count -gt 0){throw ('Destination is not empty and is not a managed ReLoop installation: '+$Target+'. Choose an empty folder with RELOOP_INSTALL_DIR. No files were overwritten.')}
 }
 $zip=Join-Path $Cache ('source-'+$Commit+'.zip')
 Save-Download ('https://codeload.github.com/'+$script:Repo+'/zip/'+$Commit) $zip
 $stage=Join-Path $Cache ('source-'+[guid]::NewGuid().ToString('N'))
 Expand-SafeZip $zip $stage
 $source=Join-Path $stage ('reloop-recycling-management-'+$Commit)
 foreach($needed in @('pom.xml','start.ps1','database/setup.ps1')){if(-not (Test-Path -LiteralPath (Join-Path $source $needed))){throw 'The downloaded archive is missing required project files.'}}
 New-Item -ItemType Directory -Force -Path $Target | Out-Null
 Get-ChildItem -LiteralPath $source -Force | ForEach-Object {Copy-Item -LiteralPath $_.FullName -Destination $Target -Recurse}
 New-Item -ItemType Directory -Force -Path (Join-Path $Target '.local') | Out-Null
 Write-Utf8 $marker (@{repository=$script:Repo;revision=$Commit;installedAt=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json)
 return $Target
}
function Ensure-Java([string]$Target,[string]$Cache){
 $javaDir=Join-Path $Target '.local/java'
 $jdk=Get-ChildItem -LiteralPath $javaDir -Directory -ErrorAction SilentlyContinue | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'bin/javac.exe')} | Select-Object -First 1
 if(-not $jdk){
  $assets=@(Get-Json 'https://api.adoptium.net/v3/assets/latest/17/hotspot?architecture=x64&image_type=jdk&os=windows&vendor=eclipse')
  if($assets.Count -eq 0){throw 'No Java 17 Windows x64 package was returned by Adoptium.'}
  $package=$assets[0].binary.package
  if($package.checksum -notmatch '^[0-9a-fA-F]{64}$'){throw 'Missing Java download checksum.'}
  $zip=Join-Path $Cache 'java17.zip';Save-Download $package.link $zip $package.checksum
  $stage=Join-Path $Cache ('java-'+[guid]::NewGuid().ToString('N'));Expand-SafeZip $zip $stage
  $jdk=Get-ChildItem -LiteralPath $stage -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'bin/javac.exe')} | Select-Object -First 1
  if(-not $jdk){throw 'Java archive contains no JDK.'}
  New-Item -ItemType Directory -Force -Path $javaDir | Out-Null
  Copy-Item -LiteralPath $jdk.FullName -Destination $javaDir -Recurse
  $jdk=Get-Item -LiteralPath (Join-Path $javaDir $jdk.Name)
 }
 $output=& (Join-Path $jdk.FullName 'bin/javac.exe') -version 2>&1
 if($LASTEXITCODE -ne 0 -or "$output" -notmatch 'javac 17\.'){throw 'The local Java installation is not a functioning Java 17 JDK.'}
 $env:JAVA_HOME=$jdk.FullName;$env:PATH=(Join-Path $jdk.FullName 'bin')+';'+$env:PATH
 Write-Host "Java ready: $output"
}
function Ensure-Maven([string]$Target,[string]$Cache){
 $maven=Join-Path $Target '.local/maven/apache-maven-3.9.9/bin/mvn.cmd'
 if(-not (Test-Path -LiteralPath $maven)){
  $url='https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/3.9.9/apache-maven-3.9.9-bin.zip'
  $hashResponse=Invoke-WebRequest ($url+'.sha512') -UseBasicParsing -TimeoutSec 60
  $hash=([string]$hashResponse.Content).Trim().Split(' ')[0]
  if($hash -notmatch '^[0-9a-fA-F]{128}$'){throw 'Missing Maven SHA-512 checksum.'}
  $zip=Join-Path $Cache 'maven-3.9.9.zip';Save-Download $url $zip $hash 'SHA512'
  $stage=Join-Path $Cache ('maven-'+[guid]::NewGuid().ToString('N'));Expand-SafeZip $zip $stage
  New-Item -ItemType Directory -Force -Path (Join-Path $Target '.local/maven') | Out-Null
  Copy-Item -LiteralPath (Join-Path $stage 'apache-maven-3.9.9') -Destination (Join-Path $Target '.local/maven') -Recurse
 }
 & $maven -version | Out-Host
 if($LASTEXITCODE -ne 0){throw 'Maven failed its startup check.'}
}
function Find-SqlPlus {
 $candidates=New-Object 'System.Collections.Generic.List[string]'
 $service=Get-CimInstance Win32_Service -Filter "Name='OracleServiceXE'" -ErrorAction SilentlyContinue
 if($service -and $service.PathName -match '^"?(.+?oracle\.exe)"?(?:\s|$)'){$candidates.Add((Join-Path (Split-Path $Matches[1] -Parent) 'sqlplus.exe'))}
 foreach($key in @(Get-ChildItem 'HKLM:\SOFTWARE\ORACLE' -ErrorAction SilentlyContinue)){
  $homeValue=(Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction SilentlyContinue).ORACLE_HOME
  if($homeValue){$candidates.Add((Join-Path $homeValue 'bin/sqlplus.exe'))}
 }
 $onPath=Get-Command sqlplus.exe -ErrorAction SilentlyContinue
 if($onPath){$candidates.Add($onPath.Source)}
 foreach($candidate in $candidates){if(Test-Path -LiteralPath $candidate){return $candidate}}
 return $null
}
function Ensure-Oracle([string]$Cache,[bool]$Unattended){
 $service=Get-Service -Name OracleServiceXE -ErrorAction SilentlyContinue
 if(-not $service){
  if($Unattended){throw 'Oracle XE is missing. Interactive Oracle installation is required; rerun without NonInteractive.'}
  Write-Host 'Oracle Database XE 21c is not installed.' -ForegroundColor Yellow
  Write-Host 'Setup can download the official Oracle installer (~2 GB). Allow about 20 GB free for Oracle, tools and cached downloads.'
  Write-Host 'Its wizard needs administrator access, acceptance of Oracle terms, and a database password you choose.'
  Write-Host 'Oracle controls supported Windows editions. Existing databases will never be uninstalled or replaced.'
  if((Read-Host 'Download and open the Oracle setup wizard? [Y/N]') -notmatch '^(y|yes)$'){throw 'Oracle setup cancelled. Install Oracle XE 21c, then rerun this BAT.'}
  if($env:ORACLE_HOME -or $env:TNS_ADMIN){throw 'Oracle installation requires ORACLE_HOME and TNS_ADMIN to be unset. Review the Oracle installation guide and rerun; this script will not change global Oracle settings.'}
  $zip=Join-Path $Cache 'OracleXE213_Win64.zip';Save-Download $script:OracleUrl $zip $script:OracleSha256
  $stage=Join-Path $Cache ('oracle-'+[guid]::NewGuid().ToString('N'));Expand-SafeZip $zip $stage
  $setup=Get-ChildItem -LiteralPath $stage -Filter setup.exe -Recurse | Select-Object -First 1
  if(-not $setup){throw 'Oracle setup.exe was not found in its download.'}
  $signature=Get-AuthenticodeSignature -LiteralPath $setup.FullName
  if($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Oracle'){throw 'The Oracle installer signature could not be verified. Do not run it; download again from Oracle.'}
  # This is the interactive installer the user chose to see, not a background helper.
  $process=Start-Process -FilePath $setup.FullName -WorkingDirectory $setup.DirectoryName -Verb RunAs -WindowStyle Normal -Wait -PassThru
  if($process.ExitCode -notin @(0,3010)){throw ('Oracle installer returned '+$process.ExitCode+'. Read its installer log and rerun after successful installation.')}
  if($process.ExitCode -eq 3010){throw 'Oracle requests a Windows restart. Restart, then run this BAT again.'}
  [void](Read-Host 'When Oracle reports installation complete and you have closed its wizard, press Enter')
  $service=Get-Service -Name OracleServiceXE -ErrorAction SilentlyContinue
  if(-not $service){throw 'OracleServiceXE is still missing. Finish the Oracle installation before rerunning setup.'}
 }
 foreach($svc in @(Get-Service -Name 'OracleServiceXE','Oracle*Listener' -ErrorAction SilentlyContinue)){
  if($svc.Status -ne 'Running'){
   try{Start-Service -Name $svc.Name;$svc.WaitForStatus('Running',[TimeSpan]::FromSeconds(60))}
   catch{throw ('Cannot start '+$svc.Name+'. Right-click Setup-ReLoop.bat and choose Run as administrator, using the Windows account that installed Oracle.')}
  }
 }
 $sqlplus=Find-SqlPlus
 if(-not $sqlplus){throw 'Oracle XE exists but SQL*Plus was not found. Repair the Oracle installation; do not install over it.'}
 $version=& $sqlplus -V 2>&1
 if($LASTEXITCODE -ne 0 -or "$version" -notmatch 'Release 21\.'){throw 'This bootstrapper requires Oracle XE/SQL*Plus 21c. It will not upgrade or remove an existing Oracle installation.'}
 $env:ORACLE_SID='XE';$env:PATH=(Split-Path $sqlplus -Parent)+';'+$env:PATH
 $probe="WHENEVER SQLERROR EXIT SQL.SQLCODE`nSET HEADING OFF FEEDBACK OFF PAGESIZE 0`nSELECT status FROM v`$instance;`nEXIT`n"
 $probeOutput=@($probe | & $sqlplus -L -s '/ as sysdba' 2>&1)
 $probeCode=$LASTEXITCODE;$probeText=$probeOutput -join "`n"
 if($probeText -match 'ORA-01034|ORA-01012'){
  Write-Host 'Oracle service is running but its database instance is down. Starting the existing XE instance...'
  $startup="WHENEVER SQLERROR EXIT SQL.SQLCODE`nSTARTUP`nEXIT`n"
  $startupOutput=@($startup | & $sqlplus -L -s '/ as sysdba' 2>&1)
  if($LASTEXITCODE -ne 0 -or ($startupOutput -join "`n") -match '(?m)^\s*(ORA-|SP2-)'){throw ('Oracle could not start its existing instance: '+($startupOutput -join "`n"))}
  $startupOutput | Out-Host
 }elseif($probeCode -ne 0 -or $probeText -match '(?m)^\s*(ORA-|SP2-)'){
  throw ('Oracle OS authentication failed. Use the Windows account that installed Oracle; sign out and back in after a new install to refresh ORA_DBA membership. '+$probeText)
 }elseif($probeText.Trim() -ne 'OPEN'){
  throw ('Oracle XE is in state '+$probeText.Trim()+'. Ask the database administrator to open it normally before rerunning setup; this installer will not force recovery.')
 }
 return $sqlplus
}
function Write-Launchers([string]$Target){
 $body="@echo off`r`ncd /d `"%~dp0`"`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%~dp0start.ps1`"`r`nif errorlevel 1 (pause & exit /b 1)`r`nstart `"`" `"http://localhost:8080`"`r`n"
 Write-Utf8 (Join-Path $Target 'Start-ReLoop.bat') $body
 Write-Utf8 (Join-Path $Target 'Stop-ReLoop.bat') "@echo off`r`ncd /d `"%~dp0`"`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%~dp0stop.ps1`"`r`npause`r`n"
}
function Invoke-ReLoopInstall {
 Assert-Platform
 [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
 $ProgressPreference='SilentlyContinue'
 if($OraclePort -lt 1 -or $OraclePort -gt 65535){throw 'OraclePort must be between 1 and 65535.'}
 if(-not $Revision){$Revision=(Get-Json ('https://api.github.com/repos/'+$script:Repo+'/commits/main')).sha}
 $cache=Join-Path $env:LOCALAPPDATA 'ReLoop-InstallerCache'
 New-Item -ItemType Directory -Force -Path $cache | Out-Null
 $InstallDir=[IO.Path]::GetFullPath($InstallDir)
 Write-Host "Installing ReLoop in: $InstallDir" -ForegroundColor Cyan
 # A per-target lock prevents two installers from provisioning or building together.
 $hash=[Security.Cryptography.SHA256]::Create()
 try{$lockId=([BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($InstallDir.ToLowerInvariant())))).Replace('-','')}finally{$hash.Dispose()}
 $mutex=New-Object Threading.Mutex($false,('Local\ReLoopSetup'+$lockId))
 $locked=$false
 try{
  try{$locked=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$locked=$true}
  if(-not $locked){throw 'Another setup is already working on this installation. Wait for it to finish.'}
  $project=Get-Project $InstallDir $Revision $cache
  Write-Host '[1/4] Installing project-local Java and Maven'
  Ensure-Java $project $cache;Ensure-Maven $project $cache
  Write-Host '[2/4] Checking Oracle XE and SQL*Plus'
  $sqlplus=Ensure-Oracle $cache ([bool]$NonInteractive)
  Write-Host '[3/4] Preparing the application database'
  & (Join-Path $project 'database/setup.ps1') -SqlPlusPath $sqlplus -Port $OraclePort
  Write-Launchers $project
  Write-Host '[4/4] Building and starting ReLoop'
  # A child shell keeps start.ps1's early exit from skipping installer cleanup.
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $project 'start.ps1')
  if($LASTEXITCODE -ne 0){throw 'The application did not start. Check .local/server.log in the installation folder.'}
  $response=Invoke-WebRequest 'http://127.0.0.1:8080/api/auth/csrf' -UseBasicParsing -TimeoutSec 10
  if($response.StatusCode -ne 200){throw 'The server did not pass its HTTP readiness check.'}
  Write-Host "`nReLoop is ready: http://localhost:8080" -ForegroundColor Green
  Write-Host "Installation folder: $project"
  Write-Host "Logins: $(Join-Path $project '.local/demo-logins.txt')"
  Write-Host 'Next time, double-click Start-ReLoop.bat in this folder. Stop with Stop-ReLoop.bat.'
  if(-not $NoBrowser){Start-Process 'http://localhost:8080';if(Test-Path -LiteralPath (Join-Path $project '.local/demo-logins.txt')){Start-Process notepad.exe -WindowStyle Normal -ArgumentList ('"'+(Join-Path $project '.local/demo-logins.txt')+'"')}}
 }finally{if($locked){$mutex.ReleaseMutex()};$mutex.Dispose()}
}
if(-not $LibraryOnly){Invoke-ReLoopInstall}
