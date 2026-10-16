@echo off
setlocal
title ReLoop - Local Setup
echo.
echo ReLoop local setup - Windows x64
echo This downloads the project from github.com/nannanvp/reloop-recycling-management.
echo Java and Maven are installed locally. Oracle setup may need administrator access.
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $file=Join-Path ([IO.Path]::GetTempPath()) ('reloop-install-'+[guid]::NewGuid().ToString('N')+'.ps1'); try { $commit=Invoke-RestMethod 'https://api.github.com/repos/nannanvp/reloop-recycling-management/commits/main' -Headers @{'User-Agent'='ReLoop-Setup'}; if($commit.sha -notmatch '^[0-9a-f]{40}$'){throw 'Invalid repository revision'}; Invoke-WebRequest ('https://raw.githubusercontent.com/nannanvp/reloop-recycling-management/'+$commit.sha+'/install.ps1') -UseBasicParsing -OutFile $file; & $file -Revision $commit.sha; if(-not $?){exit 1} } catch { Write-Host ('SETUP FAILED: '+$_.Exception.Message) -ForegroundColor Red; exit 1 } finally { if(Test-Path -LiteralPath $file){Remove-Item -LiteralPath $file -Force} }"
set "RELOOP_RESULT=%ERRORLEVEL%"
echo.
if not "%RELOOP_RESULT%"=="0" echo Setup did not finish. Read the message above, fix it, and run this file again.
if not defined RELOOP_NO_PAUSE pause
exit /b %RELOOP_RESULT%
