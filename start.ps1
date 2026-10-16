param([switch]$BuildOnly)
$ErrorActionPreference='Stop'
Set-Location $PSScriptRoot
if(-not $BuildOnly -and (Test-Path -LiteralPath '.local/server.pid')){
 $taskExistingPid=[int](Get-Content -LiteralPath '.local/server.pid')
 $taskExisting=Get-CimInstance Win32_Process -Filter "ProcessId=$taskExistingPid" -ErrorAction SilentlyContinue
 if($taskExisting -and ($taskExisting.CommandLine -like '*reloop-1.0.0.jar*')){Write-Host 'ReLoop is already running: http://localhost:8080';Write-Host 'Use .\stop.ps1 before rebuilding changed source.';exit 0}
}
$taskJdk=Get-ChildItem -LiteralPath '.local/java' -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
if($taskJdk){$env:JAVA_HOME=$taskJdk.FullName;$env:PATH="$($taskJdk.FullName)\bin;$env:PATH"}
if(-not (Get-Command java -ErrorAction SilentlyContinue)){throw 'Java 17 is required. Install Java 17 and set JAVA_HOME, or place a JDK in .local/java/.'}
$taskMaven=Join-Path $PSScriptRoot '.local/maven/apache-maven-3.9.9/bin/mvn.cmd'
if(-not (Test-Path -LiteralPath $taskMaven)){$taskMaven='mvn'}
& $taskMaven -q -DskipTests package
if($LASTEXITCODE -ne 0){throw 'Build failed.'}
if(-not $BuildOnly){
 $taskJava=(Get-Command java).Source
 $taskJar=Join-Path $PSScriptRoot 'target/reloop-1.0.0.jar'
 $taskServer=Start-Process -FilePath $taskJava -ArgumentList @('-jar',('"'+$taskJar+'"')) -WorkingDirectory $PSScriptRoot -RedirectStandardOutput '.local/server.log' -RedirectStandardError '.local/server-error.log' -WindowStyle Hidden -PassThru
 $taskServer.Id | Set-Content -LiteralPath '.local/server.pid'
 $taskReady=$false
 for($taskAttempt=0;$taskAttempt -lt 30;$taskAttempt++){
  if($taskServer.HasExited){throw 'Application stopped. Read .local/server.log and .local/server-error.log.'}
  try{$taskResponse=Invoke-WebRequest 'http://127.0.0.1:8080/api/auth/csrf' -UseBasicParsing -TimeoutSec 2;if($taskResponse.StatusCode -eq 200){$taskReady=$true;break}}catch{}
  Start-Sleep -Milliseconds 500
 }
 if(-not $taskReady){throw 'Server did not become ready. Check .local/server.log.'}
 Write-Host 'ReLoop is ready: http://localhost:8080'
 Write-Host 'Demo logins: .local/demo-logins.txt'
 Write-Host 'Stop the server with .\stop.ps1'
}
