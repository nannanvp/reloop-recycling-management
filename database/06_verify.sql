WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
SET SERVEROUTPUT ON
SET LINESIZE 160
SET PAGESIZE 100
PROMPT === Object compilation ===
SELECT object_name,object_type,status FROM user_objects WHERE object_name LIKE 'RC_%' OR object_name LIKE 'PR_%' OR object_name LIKE 'FN_%' OR object_name LIKE 'VW_%' OR object_name LIKE 'TRG_%' ORDER BY object_type,object_name;
DECLARE n NUMBER; BEGIN
 SELECT COUNT(*) INTO n FROM user_objects WHERE status='INVALID';
 IF n>0 THEN RAISE_APPLICATION_ERROR(-20050,'Invalid schema objects exist.'); END IF;
 IF fn_reward_points(8,10)<>80 THEN RAISE_APPLICATION_ERROR(-20051,'Reward function failed.'); END IF;
 DBMS_OUTPUT.PUT_LINE('Compilation and 8kg x 10 = 80 function check passed.');
END;
/
SELECT COUNT(*) centres FROM rc_centres;
SELECT COUNT(*) materials FROM rc_materials;
SELECT * FROM vw_centre_material_totals ORDER BY centre_id,material_id;
SELECT * FROM vw_citizen_rewards ORDER BY citizen_id;
SELECT * FROM vw_batch_summary ORDER BY batch_id;
SELECT * FROM user_errors;
