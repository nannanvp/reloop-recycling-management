$ErrorActionPreference='Stop'
$base='http://localhost:8080/api'
$pass=((Get-Content .local/demo-logins.txt | Where-Object {$_ -like 'Password for all seeded accounts:*'}) -split ': ',2)[1]
$evidence=[System.Collections.Generic.List[string]]::new()
function Request($session,$method,$path,$body=$null) {
 $headers=@{}
 if($method -ne 'GET'){$csrf=Invoke-RestMethod "$base/auth/csrf" -WebSession $session;$headers[$csrf.headerName]=$csrf.token}
 $args=@{Uri="$base$path";Method=$method;WebSession=$session;Headers=$headers;SkipHttpErrorCheck=$true}
 if($null-ne $body){$args.Body=$body|ConvertTo-Json -Depth 8 -Compress;$args.ContentType='application/json'}
 $r=Invoke-WebRequest @args
 $data=$null;try{$data=$r.Content|ConvertFrom-Json}catch{}
 return @{status=[int]$r.StatusCode;data=$data}
}
function Expect($result,$code,$label){if($result.status-ne $code){throw "$label failed: HTTP $($result.status), $($result.data.message)"};$evidence.Add("PASS $label (HTTP $code)")}
function Login($email){$s=New-Object Microsoft.PowerShell.Commands.WebRequestSession;$csrf=Invoke-RestMethod "$base/auth/csrf" -WebSession $s;$h=@{};$h[$csrf.headerName]=$csrf.token;$r=Invoke-WebRequest "$base/auth/login" -Method POST -WebSession $s -Headers $h -Body @{username=$email;password=$pass} -SkipHttpErrorCheck;Expect @{status=[int]$r.StatusCode;data=$null} 200 "Login $email";return $s}
$admin=Login 'admin@reloop.test';$citizen=Login 'citizen@reloop.test';$other=Login 'citizen2@reloop.test';$staff=Login 'staff@reloop.test';$staff2=Login 'staff2@reloop.test'
$me=(Request $staff GET '/auth/me').data
$material=Request $admin POST '/materials' @{name=('API smoke '+[Guid]::NewGuid().ToString('N').Substring(0,8));pointsPerKg=10};Expect $material 200 'Create material'
$materialId=$material.data.id; $otherMaterialId=((Request $citizen GET '/materials').data.items | Where-Object {$_.id-ne $materialId} | Select-Object -First 1).id
$payload=@{centreId=$me.centreId;pickupAddress='Synthetic API smoke address';preferredDate=(Get-Date -Format yyyy-MM-dd);notes='Temporary acceptance fixture';items=@(@{materialId=$materialId;estimatedKg=10},@{materialId=$otherMaterialId;estimatedKg=1})}
$p=Request $citizen POST '/pickups' $payload;Expect $p 200 'Citizen creates pickup';$pickupId=$p.data.id;$itemId=$p.data.items[0].id;$otherItemId=$p.data.items[1].id
Expect (Request $other GET "/pickups/$pickupId") 404 'Foreign citizen cannot read pickup'
Expect (Request $other PATCH "/pickups/$pickupId" @{notes='Unauthorized'}) 404 'Foreign citizen cannot edit pickup'
Expect (Request $staff2 POST "/pickups/$pickupId/schedule" @{scheduledDate=(Get-Date -Format yyyy-MM-dd)}) 404 'Other centre staff cannot schedule pickup'
Expect (Request $citizen POST '/academic/sandbox/create' @{}) 403 'Citizen cannot access sandbox'
Expect (Request $citizen PATCH "/pickups/$pickupId" @{notes='Updated synthetic fixture'}) 200 'Citizen updates pending pickup'
$d=Request $citizen POST '/pickups' $payload;Expect $d 200 'Create deletion fixture'
Expect (Request $citizen DELETE "/pickups/$($d.data.id)") 200 'Delete pending pickup'
Expect (Request $staff POST "/pickups/$pickupId/schedule" @{scheduledDate=(Get-Date -Format yyyy-MM-dd)}) 200 'Staff schedules pickup'
Expect (Request $staff POST "/pickups/$pickupId/collect" @{items=@(@{itemId=$itemId;collectedKg=10;acceptedKg=8},@{itemId=$otherItemId;collectedKg=1;acceptedKg=2})}) 400 'Reject accepted weight above collected'
$unchanged=(Request $staff GET "/pickups/$pickupId").data
if($unchanged.status-ne 'SCHEDULED'-or $null-ne $unchanged.items[0].acceptedKg-or $null-ne $unchanged.items[1].acceptedKg){throw 'Invalid collection changed persisted weights'}
$evidence.Add('PASS invalid collection preserves scheduled state and null weights')
Expect (Request $staff POST "/pickups/$pickupId/collect" @{items=@(@{itemId=$itemId;collectedKg=-1;acceptedKg=0},@{itemId=$otherItemId;collectedKg=1;acceptedKg=0})}) 400 'Reject negative collection'
Expect (Request $staff POST "/pickups/$pickupId/collect" @{items=@(@{itemId=$itemId;collectedKg=10;acceptedKg=8},@{itemId=$otherItemId;collectedKg=1;acceptedKg=0})}) 200 'Collect 10 kg with 8 accepted'
$r=Request $staff POST "/pickups/$pickupId/post-rewards" @{};Expect $r 200 'Post rewards';if($r.data.rowsAdded-ne 1){throw 'Reward missing'}
$r=Request $staff POST "/pickups/$pickupId/post-rewards" @{};Expect $r 200 'Repeat rewards';if($r.data.rowsAdded-ne 0){throw 'Duplicate reward'}
$rewards=(Request $citizen GET '/rewards').data.items|Where-Object pickupItemId -eq $itemId
if($rewards.points-ne 80){throw 'Expected 80 points'};$evidence.Add('PASS precisely 80 points and no duplicate ledger row')
Expect (Request $staff POST '/batches' @{centreId=$me.centreId;materialId=$materialId;outputKg=9}) 409 'Reject processing above input'
$b=Request $staff POST '/batches' @{centreId=$me.centreId;materialId=$materialId;outputKg=7};Expect $b 200 'Process material';$batchId=$b.data.id
Expect (Request $staff POST '/batches' @{centreId=$me.centreId;materialId=$materialId;outputKg=1}) 409 'Reject processing same material twice'
foreach($report in @('centre-materials','pickup-details','batches','available','above-average','unused-materials','pending-centres','functions','cursor')){Expect (Request $staff GET "/reports/$report") 200 "Report $report"}
Expect (Request $citizen POST '/auth/logout' @{}) 200 'Logout'
Expect (Request $citizen GET '/dashboard') 401 'Logout ends access'
$evidence|Set-Content .local/api-smoke-results.txt -Encoding UTF8
@{materialId=$materialId;pickupId=$pickupId;batchId=$batchId}|ConvertTo-Json|Set-Content .local/api-smoke-fixture.json
$evidence
