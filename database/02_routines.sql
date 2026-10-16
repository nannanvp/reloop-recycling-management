WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
SET DEFINE OFF
CREATE OR REPLACE FUNCTION fn_reward_points(p_accepted_kg NUMBER,p_rate NUMBER) RETURN NUMBER IS
BEGIN
 IF p_accepted_kg IS NULL OR p_rate IS NULL OR p_accepted_kg<0 OR p_rate<0 THEN
  RAISE_APPLICATION_ERROR(-20001,'Weight and points rate must be nonnegative.');
 END IF;
 RETURN FLOOR(p_accepted_kg*p_rate);
END;
/
SHOW ERRORS
CREATE OR REPLACE PROCEDURE pr_confirm_collection(p_pickup_id NUMBER,p_actor_id NUMBER) IS
 v_centre NUMBER; v_lock NUMBER; v_status VARCHAR2(12); v_bad NUMBER; v_count NUMBER; v_allowed NUMBER;
BEGIN
 SELECT centre_id INTO v_centre FROM rc_pickups WHERE id=p_pickup_id;
 SELECT id INTO v_lock FROM rc_centres WHERE id=v_centre FOR UPDATE;
 SELECT status INTO v_status FROM rc_pickups WHERE id=p_pickup_id FOR UPDATE;
 SELECT COUNT(*) INTO v_allowed FROM rc_users WHERE id=p_actor_id AND active=1
  AND (role='ADMIN' OR (role='STAFF' AND centre_id=v_centre));
 IF v_allowed=0 THEN RAISE_APPLICATION_ERROR(-20002,'Actor cannot operate this centre.'); END IF;
 IF v_status<>'SCHEDULED' THEN RAISE_APPLICATION_ERROR(-20003,'Only scheduled pickups can be collected.'); END IF;
 SELECT COUNT(*),NVL(SUM(CASE WHEN collected_kg IS NULL OR accepted_kg IS NULL OR accepted_kg<0 OR accepted_kg>collected_kg THEN 1 ELSE 0 END),0)
 INTO v_count,v_bad FROM rc_pickup_items WHERE pickup_id=p_pickup_id;
 IF v_count=0 OR v_bad>0 THEN RAISE_APPLICATION_ERROR(-20004,'Every material needs valid collected and accepted weights.'); END IF;
 UPDATE rc_pickups SET status='COLLECTED',updated_at=SYSTIMESTAMP WHERE id=p_pickup_id;
END;
/
SHOW ERRORS
CREATE OR REPLACE PROCEDURE pr_post_rewards(p_pickup_id NUMBER,p_actor_id NUMBER,p_rows_added OUT NUMBER) IS
 v_status VARCHAR2(12); v_centre NUMBER; v_allowed NUMBER;
 CURSOR c_items(p_id NUMBER) IS
 SELECT i.id,i.accepted_kg,m.points_per_kg FROM rc_pickup_items i JOIN rc_materials m ON m.id=i.material_id
 WHERE i.pickup_id=p_id AND i.accepted_kg>0 AND NOT EXISTS(SELECT 1 FROM rc_reward_ledger l WHERE l.pickup_item_id=i.id);
BEGIN
 SELECT status,centre_id INTO v_status,v_centre FROM rc_pickups WHERE id=p_pickup_id FOR UPDATE;
 SELECT COUNT(*) INTO v_allowed FROM rc_users WHERE id=p_actor_id AND active=1
 AND(role='ADMIN' OR(role='STAFF' AND centre_id=v_centre));
 IF v_allowed=0 THEN RAISE_APPLICATION_ERROR(-20002,'Actor cannot operate this centre.'); END IF;
 IF v_status<>'COLLECTED' THEN RAISE_APPLICATION_ERROR(-20005,'Collect the pickup before posting points.'); END IF;
 p_rows_added:=0;
 FOR r IN c_items(p_pickup_id) LOOP
  INSERT INTO rc_reward_ledger(pickup_item_id,rate_snapshot,points,posted_by)
  VALUES(r.id,r.points_per_kg,fn_reward_points(r.accepted_kg,r.points_per_kg),p_actor_id);
  p_rows_added:=p_rows_added+1;
 END LOOP;
END;
/
SHOW ERRORS
CREATE OR REPLACE PROCEDURE pr_process_material(p_centre_id NUMBER,p_material_id NUMBER,p_output_kg NUMBER,p_actor_id NUMBER,p_batch_id OUT NUMBER) IS
 v_lock NUMBER; v_total NUMBER; v_allowed NUMBER;
 CURSOR c_available IS
 SELECT i.id,i.accepted_kg FROM rc_pickup_items i
 WHERE i.material_id=p_material_id AND i.batch_id IS NULL AND i.accepted_kg>0
 AND EXISTS(SELECT 1 FROM rc_pickups p WHERE p.id=i.pickup_id AND p.centre_id=p_centre_id AND p.status='COLLECTED')
 FOR UPDATE OF batch_id;
BEGIN
 SELECT id INTO v_lock FROM rc_centres WHERE id=p_centre_id FOR UPDATE;
 SELECT COUNT(*) INTO v_allowed FROM rc_users WHERE id=p_actor_id AND active=1
 AND(role='ADMIN' OR(role='STAFF' AND centre_id=p_centre_id));
 IF v_allowed=0 THEN RAISE_APPLICATION_ERROR(-20002,'Actor cannot operate this centre.'); END IF;
 SELECT NVL(SUM(i.accepted_kg),0) INTO v_total FROM rc_pickup_items i JOIN rc_pickups p ON p.id=i.pickup_id
 WHERE p.centre_id=p_centre_id AND i.material_id=p_material_id AND p.status='COLLECTED' AND i.batch_id IS NULL AND i.accepted_kg>0;
 IF v_total<=0 THEN RAISE_APPLICATION_ERROR(-20006,'There is no unprocessed accepted material.');
 ELSIF p_output_kg IS NULL OR p_output_kg<0 OR p_output_kg>v_total THEN
 RAISE_APPLICATION_ERROR(-20007,'Output must be between zero and the available input weight.'); END IF;
 INSERT INTO rc_batches(centre_id,material_id,output_kg,processed_by) VALUES(p_centre_id,p_material_id,p_output_kg,p_actor_id) RETURNING id INTO p_batch_id;
 FOR r IN c_available LOOP
  UPDATE rc_pickup_items SET batch_id=p_batch_id WHERE CURRENT OF c_available;
 END LOOP;
END;
/
SHOW ERRORS
CREATE OR REPLACE PROCEDURE pr_centre_collection_report(p_centre_id NUMBER,p_rows OUT SYS_REFCURSOR) IS
BEGIN
 OPEN p_rows FOR SELECT p.id pickup_id,u.full_name citizen_name,c.name centre_name,m.name material_name,
 p.status,p.preferred_date,i.collected_kg,i.accepted_kg
 FROM rc_pickups p JOIN rc_users u ON u.id=p.citizen_id JOIN rc_centres c ON c.id=p.centre_id
 JOIN rc_pickup_items i ON i.pickup_id=p.id JOIN rc_materials m ON m.id=i.material_id
 WHERE p.centre_id=p_centre_id ORDER BY p.id DESC;
END;
/
SHOW ERRORS
CREATE OR REPLACE TRIGGER trg_pickup_status_audit
AFTER UPDATE OF status ON rc_pickups FOR EACH ROW
BEGIN
 IF :OLD.status<>:NEW.status THEN
 INSERT INTO rc_audit_log(pickup_id,old_status,new_status,database_user,actor_identifier)
 VALUES(:NEW.id,:OLD.status,:NEW.status,SYS_CONTEXT('USERENV','SESSION_USER'),SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER'));
 END IF;
END;
/
SHOW ERRORS
