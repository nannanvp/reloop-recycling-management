$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'install.ps1') -LibraryOnly
$testRoot=Join-Path $root ('.local/bootstrap-tests/'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
$passed=0
function Assert-Test([bool]$Condition,[string]$Name){if(-not $Condition){throw "FAIL: $Name"};$script:passed++;Write-Host "PASS: $Name"}
function Expect-Failure([scriptblock]$Action,[string]$Pattern,[string]$Name){$message='';try{& $Action}catch{$message=$_.Exception.Message};Assert-Test ($message -match $Pattern) $Name}
foreach($name in @('install.ps1','database/setup.ps1','start.ps1','stop.ps1')){
 $tokens=$null;$errors=$null
 [void][Management.Automation.Language.Parser]::ParseFile((Join-Path $root $name),[ref]$tokens,[ref]$errors)
 Assert-Test ($errors.Count -eq 0) "$name parses"
}
Assert-Platform
Assert-Test ((Find-SqlPlus) -like '*sqlplus.exe') 'Oracle discovery locates the existing SQLPlus executable'
Expect-Failure {Assert-Https 'http://example.com/file.zip'} 'HTTPS' 'HTTP downloads are rejected'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$validZip=Join-Path $testRoot 'valid.zip'
$z=[IO.Compression.ZipFile]::Open($validZip,'Create')
$entry=$z.CreateEntry('folder/test.txt');$writer=New-Object IO.StreamWriter($entry.Open());$writer.Write('valid');$writer.Dispose();$z.Dispose()
Expand-SafeZip $validZip (Join-Path $testRoot 'valid')
Assert-Test ((Get-Content (Join-Path $testRoot 'valid/folder/test.txt')) -eq 'valid') 'Valid ZIP extracts correctly'
foreach($badName in @('../escape.txt','C:/escape.txt','file.txt:stream')){
 $badZip=Join-Path $testRoot ([guid]::NewGuid().ToString('N')+'.zip')
 $z=[IO.Compression.ZipFile]::Open($badZip,'Create');[void]$z.CreateEntry($badName);$z.Dispose()
 Expect-Failure {Expand-SafeZip $badZip (Join-Path $testRoot ([guid]::NewGuid().ToString('N')))} 'Archive' "Reject archive path $badName"
}
$cached=Join-Path $testRoot 'cached.zip';Copy-Item -LiteralPath $validZip -Destination $cached
Save-Download 'https://invalid.example.test/cached' $cached (Get-FileHash $cached -Algorithm SHA256).Hash
Assert-Test ((Get-FileHash $validZip).Hash -eq (Get-FileHash $cached).Hash) 'Correct cached checksum skips network download'

# Fixture repository keeps the real installation orchestration isolated from this PC's database.
$commit='a'*40;$fixture=Join-Path $testRoot 'repository.zip'
$z=[IO.Compression.ZipFile]::Open($fixture,'Create')
foreach($item in @('pom.xml','start.ps1','database/setup.ps1','README.md')){
 $entry=$z.CreateEntry("reloop-recycling-management-$commit/$item")
 $writer=New-Object IO.StreamWriter($entry.Open());$writer.Write('fixture source');$writer.Dispose()
}
$z.Dispose()
$originalDownloader=${function:Save-Download}
$script:downloadCalls=0
function Save-Download([string]$Url,[string]$Path,[string]$Hash='',[string]$Algorithm='SHA256'){
 $script:downloadCalls++;$script:lastDownload=$Url;Copy-Item -LiteralPath $fixture -Destination $Path -Force
}
$cache=Join-Path $testRoot 'cache';New-Item -ItemType Directory $cache | Out-Null
$target=Get-Project (Join-Path $testRoot "project with spaces & apostrophe's") $commit $cache
Assert-Test ($script:lastDownload.EndsWith('/'+$commit)) 'Source archive URL pins the exact commit'
Assert-Test (Test-Path -LiteralPath (Join-Path $target 'pom.xml')) 'Project source installed without Git'
$marker=Get-Content -Raw -LiteralPath (Join-Path $target '.local/install-state.json')|ConvertFrom-Json
Assert-Test ($marker.revision -eq $commit -and $marker.repository -eq 'nannanvp/reloop-recycling-management') 'Managed install records repository and revision'
Set-Content -LiteralPath (Join-Path $target 'README.md') -Value 'local modification'
Set-Content -LiteralPath (Join-Path $target '.local/keep.txt') -Value 'local state'
$again=Get-Project $target ('b'*40) $cache
Assert-Test ($script:downloadCalls -eq 1 -and (Get-Content -LiteralPath (Join-Path $target 'README.md')) -eq 'local modification') 'Rerun preserves source edits and avoids downloading an update'
Assert-Test ((Get-Content -LiteralPath (Join-Path $target '.local/keep.txt')) -eq 'local state') 'Rerun preserves local state'
$occupied=Join-Path $testRoot 'occupied';New-Item -ItemType Directory $occupied | Out-Null;Set-Content (Join-Path $occupied 'keep.txt') 'user file'
Expect-Failure {Get-Project $occupied $commit $cache} 'not empty' 'Nonempty unrelated destination is refused'
Expect-Failure {Get-Project (Join-Path $testRoot 'invalid') 'main' $cache} 'pinned' 'Unpinned revision is refused'
Write-Launchers $target
Assert-Test ((Get-Content -Raw -LiteralPath (Join-Path $target 'Start-ReLoop.bat')).Contains('"%~dp0start.ps1"')) 'Generated launcher quotes the project path'
Set-Item Function:Save-Download $originalDownloader

# Use a fake SQLPlus script for provisioning edge cases; it cannot execute database SQL.
$mockSql=Join-Path $testRoot 'fake-sqlplus.ps1'
@'
[CmdletBinding(PositionalBinding=$false)]
param([switch]$L,[switch]$s,[Parameter(ValueFromPipeline=$true)][string]$InputSql,[Parameter(ValueFromRemainingArguments=$true)]$Options)
process { }
end {
Write-Output 'RC_PDB_MODE=READ WRITE'
Write-Output ('RC_USERS_EXIST='+$env:RELOOP_TEST_USERS)
Write-Output ('RC_TABLES_EXIST='+$env:RELOOP_TEST_TABLES)
exit 0
}
'@ | Set-Content -LiteralPath $mockSql
function New-SetupFixture([string]$Name){
 $p=Join-Path $testRoot $Name;New-Item -ItemType Directory -Path (Join-Path $p 'database') | Out-Null
 Copy-Item -LiteralPath (Join-Path $root 'database/setup.ps1') -Destination (Join-Path $p 'database/setup.ps1')
 return $p
}
$collision=New-SetupFixture 'collision'
$env:RELOOP_TEST_USERS='3';$env:RELOOP_TEST_TABLES='8'
Expect-Failure {& (Join-Path $collision 'database/setup.ps1') -SqlPlusPath $mockSql} 'already exist' 'Existing Oracle accounts without credentials are not overwritten'
Assert-Test (-not (Test-Path (Join-Path $collision '.local/db-secrets.json'))) 'Collision does not create replacement credentials'
$incomplete=New-SetupFixture 'incomplete'
$env:RELOOP_TEST_TABLES='2'
Expect-Failure {& (Join-Path $incomplete 'database/setup.ps1') -SqlPlusPath $mockSql} 'incomplete' 'Partial Oracle schema stops without reset'
$fresh=New-SetupFixture 'fresh'
$env:RELOOP_TEST_USERS='0';$env:RELOOP_TEST_TABLES='0'
& (Join-Path $fresh 'database/setup.ps1') -SqlPlusPath $mockSql -Port 1541 | Out-Null
$secret=Join-Path $fresh '.local/db-secrets.json'
$bytes=[IO.File]::ReadAllBytes($secret)
Assert-Test (-not ($bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191)) 'Windows PowerShell writes JSON without UTF-8 BOM'
$config=Get-Content -Raw -LiteralPath $secret|ConvertFrom-Json
Assert-Test ($config.url -eq 'jdbc:oracle:thin:@//localhost:1541/XEPDB1') 'Custom listener port is recorded'
$before=(Get-FileHash -LiteralPath $secret).Hash
$env:RELOOP_TEST_USERS='3';$env:RELOOP_TEST_TABLES='8'
& (Join-Path $fresh 'database/setup.ps1') -SqlPlusPath $mockSql | Out-Null
Assert-Test ((Get-FileHash -LiteralPath $secret).Hash -eq $before) 'Existing credentials remain byte-for-byte unchanged on rerun'
Remove-Item Env:\RELOOP_TEST_USERS,Env:\RELOOP_TEST_TABLES
Write-Host "`n$passed bootstrap checks passed. No real database was provisioned or reset."
