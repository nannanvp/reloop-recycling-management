-- Run as RC_OWNER. Entire fixture rolls back; no production/demo records change.
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
SET SERVEROUTPUT ON
DECLARE
 c NUMBER; m NUMBER; a NUMBER; u NUMBER; p NUMBER; i NUMBER; b NUMBER; n NUMBER; points NUMBER;
BEGIN
 INSERT INTO rc_centres(name,address) VALUES('SQL smoke '||SYS_GUID(),'Synthetic test') RETURNING id INTO c;
 INSERT INTO rc_materials(name,points_per_kg) VALUES('SQL smoke '||SYS_GUID(),10) RETURNING id INTO m;
 INSERT INTO rc_users(full_name,email,password_hash,role) VALUES('Test Admin',LOWER(SYS_GUID())||'@test.invalid','disabled-test-hash','ADMIN') RETURNING id INTO a;
 INSERT INTO rc_users(full_name,email,password_hash,role) VALUES('Test Citizen',LOWER(SYS_GUID())||'@test.invalid','disabled-test-hash','CITIZEN') RETURNING id INTO u;
 INSERT INTO rc_pickups(citizen_id,centre_id,pickup_address,preferred_date,scheduled_date,status)
 VALUES(u,c,'Synthetic SQL smoke',TRUNC(SYSDATE),TRUNC(SYSDATE),'SCHEDULED') RETURNING id INTO p;
 INSERT INTO rc_pickup_items(pickup_id,material_id,estimated_kg,collected_kg,accepted_kg)
 VALUES(p,m,10,10,8) RETURNING id INTO i;
 pr_confirm_collection(p,a);
 pr_post_rewards(p,a,n);
 IF n<>1 THEN RAISE_APPLICATION_ERROR(-20080,'Initial reward row missing'); END IF;
 pr_post_rewards(p,a,n);
 IF n<>0 THEN RAISE_APPLICATION_ERROR(-20081,'Duplicate reward posted'); END IF;
 SELECT SUM(l.points) INTO points FROM rc_reward_ledger l WHERE pickup_item_id=i;
 IF points<>80 THEN RAISE_APPLICATION_ERROR(-20082,'Expected 80 points'); END IF;
 BEGIN
  pr_process_material(c,m,9,a,b);
  RAISE_APPLICATION_ERROR(-20083,'Invalid processing output accepted');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20007 THEN RAISE; END IF; END;
 pr_process_material(c,m,7,a,b);
 SELECT COUNT(*) INTO n FROM rc_pickup_items WHERE id=i AND batch_id=b;
 IF n<>1 THEN RAISE_APPLICATION_ERROR(-20084,'Cursor did not assign batch'); END IF;
 BEGIN
  pr_process_material(c,m,1,a,b);
  RAISE_APPLICATION_ERROR(-20085,'Already processed material consumed twice');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20006 THEN RAISE; END IF; END;
 SELECT COUNT(*) INTO n FROM rc_audit_log WHERE pickup_id=p AND new_status='COLLECTED';
 IF n<>1 THEN RAISE_APPLICATION_ERROR(-20086,'Audit trigger did not record collection'); END IF;
 ROLLBACK;
 DBMS_OUTPUT.PUT_LINE('PASS: collection, 80 points, duplicate prevention, invalid output rejection, cursor processing, no double processing, audit trigger. Fixture rolled back.');
EXCEPTION WHEN OTHERS THEN ROLLBACK; RAISE;
END;
/
