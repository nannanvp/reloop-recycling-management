$ErrorActionPreference='Stop'
$config=Get-Content -Raw .local/db-secrets.json|ConvertFrom-Json
$connect="SET ECHO OFF`nSET VERIFY OFF`nCONNECT $($config.ownerUsername)/`"$($config.ownerPassword)`"@//localhost:1521/XEPDB1`nWHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK`nSET SERVEROUTPUT ON`n"
$setup=@'
DECLARE c NUMBER;m NUMBER;p NUMBER;a NUMBER;u NUMBER;
BEGIN
 SELECT MIN(id) INTO a FROM rc_users WHERE role='ADMIN';
 SELECT MIN(id) INTO u FROM rc_users WHERE role='CITIZEN';
 INSERT INTO rc_centres(name,address) VALUES('Concurrency probe '||SYS_GUID(),'Temporary test centre') RETURNING id INTO c;
 INSERT INTO rc_materials(name,points_per_kg) VALUES('Concurrency probe '||SYS_GUID(),10) RETURNING id INTO m;
 INSERT INTO rc_pickups(citizen_id,centre_id,pickup_address,preferred_date,scheduled_date,status,notes) VALUES(u,c,'Temporary concurrency fixture',TRUNC(SYSDATE),TRUNC(SYSDATE),'SCHEDULED','Temporary concurrency fixture') RETURNING id INTO p;
 INSERT INTO rc_pickup_items(pickup_id,material_id,estimated_kg,collected_kg,accepted_kg) VALUES(p,m,10,10,8);
 pr_confirm_collection(p,a);
 COMMIT;
 DBMS_OUTPUT.PUT_LINE('FIXTURE|'||c||'|'||m||'|'||p||'|'||a);
END;
/
EXIT
'@
$result=($connect+$setup)|& sqlplus -L -s /nolog 2>&1
if($LASTEXITCODE-ne 0){throw ($result -join "`n")}
$line=($result|Where-Object {$_ -like 'FIXTURE|*'})-split '\|'
$c=[long]$line[1];$m=[long]$line[2];$p=[long]$line[3];$a=[long]$line[4]
@{centreId=$c;materialId=$m;pickupId=$p}|ConvertTo-Json|Set-Content .local/concurrent-fixture.json
$first=$connect+"DECLARE b NUMBER; BEGIN pr_process_material($c,$m,7,$a,b); DBMS_SESSION.SLEEP(3); COMMIT; DBMS_OUTPUT.PUT_LINE('PASS first processing committed'); EXCEPTION WHEN OTHERS THEN ROLLBACK; RAISE; END;`n/`nEXIT`n"
$second=$connect+"DECLARE b NUMBER; BEGIN pr_process_material($c,$m,7,$a,b); RAISE_APPLICATION_ERROR(-20090,'Double consumption accepted'); EXCEPTION WHEN OTHERS THEN IF SQLCODE=-20006 THEN DBMS_OUTPUT.PUT_LINE('PASS competing processing rejected after lock'); ROLLBACK; ELSE ROLLBACK; RAISE; END IF; END;`n/`nEXIT`n"
$job1=Start-Job -ScriptBlock {param($sql) $r=$sql|& sqlplus -L -s /nolog 2>&1; @{code=$LASTEXITCODE;output=($r -join "`n")}} -ArgumentList $first
Start-Sleep -Milliseconds 1000
$job2=Start-Job -ScriptBlock {param($sql) $r=$sql|& sqlplus -L -s /nolog 2>&1; @{code=$LASTEXITCODE;output=($r -join "`n")}} -ArgumentList $second
$results=@($job1,$job2)|Wait-Job|Receive-Job
$results|ForEach-Object {if($_.code-ne 0){throw $_.output};$_.output}
$check=$connect+"DECLARE n NUMBER;BEGIN SELECT COUNT(*) INTO n FROM rc_batches WHERE centre_id=$c AND material_id=$m;IF n<>1 THEN RAISE_APPLICATION_ERROR(-20091,'Expected one batch');END IF;SELECT COUNT(*) INTO n FROM rc_pickup_items WHERE pickup_id=$p AND batch_id IS NOT NULL;IF n<>1 THEN RAISE_APPLICATION_ERROR(-20092,'Expected one assignment');END IF;DBMS_OUTPUT.PUT_LINE('PASS exactly one batch and one consumed line');END;`n/`nEXIT`n"
$r=$check|& sqlplus -L -s /nolog 2>&1;if($LASTEXITCODE-ne 0){throw ($r -join "`n")};$r
@($results|ForEach-Object {$_.output})+$r|Set-Content .local/concurrent-processing-results.txt
