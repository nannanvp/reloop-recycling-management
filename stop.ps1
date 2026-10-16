$ErrorActionPreference='Stop'
Set-Location $PSScriptRoot
if(Test-Path -LiteralPath '.local/server.pid'){
 $taskServerPid=[int](Get-Content -LiteralPath '.local/server.pid')
 $taskServer=Get-CimInstance Win32_Process -Filter "ProcessId=$taskServerPid" -ErrorAction SilentlyContinue
 if($taskServer -and $taskServer.Name -eq 'java.exe' -and $taskServer.CommandLine -like '*reloop-1.0.0.jar*'){
  Stop-Process -Id $taskServerPid -Force
  Write-Host 'ReLoop server stopped. Oracle remains running.'
 }else{Write-Host 'No matching ReLoop server is running.'}
}else{Write-Host 'No ReLoop process record found.'}
