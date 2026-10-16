-- Recycling adaptation: all syntax below is Oracle SQL/PLSQL for SQL*Plus.
SET SERVEROUTPUT ON
SET LINESIZE 180
SET PAGESIZE 100
PROMPT Experiment 2 and 4: operators, clauses, single-row and aggregate functions
SELECT id,UPPER(TRIM(full_name)) display_name,LOWER(email) email,SUBSTR(full_name,1,12) short_name,LENGTH(full_name) name_length
FROM rc_users WHERE active=1 AND role IN('CITIZEN','STAFF') AND NOT email LIKE '%@invalid.test' ORDER BY full_name;
SELECT TO_CHAR(TRUNC(p.preferred_date,'MM'),'YYYY-MM') collection_month,COUNT(DISTINCT p.id) pickups,
 ROUND(SUM(NVL(i.accepted_kg,0)),2) accepted_kg,AVG(NVL(i.accepted_kg,0)) average_kg,MIN(i.accepted_kg) min_kg,MAX(i.accepted_kg) max_kg
FROM rc_pickups p JOIN rc_pickup_items i ON i.pickup_id=p.id
WHERE p.preferred_date BETWEEN ADD_MONTHS(TRUNC(SYSDATE),-12) AND TRUNC(SYSDATE)+31
GROUP BY TRUNC(p.preferred_date,'MM') HAVING COUNT(*)>0 ORDER BY collection_month;
PROMPT Experiment 5: scalar, correlated, EXISTS and NOT EXISTS subqueries
SELECT citizen_name,accepted_kg FROM vw_citizen_rewards WHERE accepted_kg>(SELECT AVG(accepted_kg) FROM vw_citizen_rewards);
SELECT m.name FROM rc_materials m WHERE NOT EXISTS(SELECT 1 FROM rc_pickup_items i JOIN rc_pickups p ON p.id=i.pickup_id WHERE i.material_id=m.id AND p.status='COLLECTED');
SELECT c.name FROM rc_centres c WHERE EXISTS(SELECT 1 FROM rc_pickups p WHERE p.centre_id=c.id AND p.status IN('REQUESTED','SCHEDULED'));
PROMPT Experiment 6: inner, left, right, full, cross, self and natural joins
SELECT pickup_id,citizen_name,centre_name,material_name FROM vw_pickup_details FETCH FIRST 20 ROWS ONLY;
SELECT c.name,COUNT(p.id) pickups FROM rc_centres c LEFT JOIN rc_pickups p ON p.centre_id=c.id GROUP BY c.name;
SELECT c.name,p.id FROM rc_pickups p RIGHT JOIN rc_centres c ON c.id=p.centre_id FETCH FIRST 20 ROWS ONLY;
SELECT u.full_name,p.id FROM rc_users u FULL OUTER JOIN rc_pickups p ON p.citizen_id=u.id FETCH FIRST 20 ROWS ONLY;
SELECT c.name centre,m.name material FROM rc_centres c CROSS JOIN rc_materials m;
SELECT a.full_name first_citizen,b.full_name second_citizen FROM rc_users a JOIN rc_users b ON a.id<b.id WHERE a.role='CITIZEN' AND b.role='CITIZEN' FETCH FIRST 10 ROWS ONLY;
-- Explicit projections ensure MATERIAL_ID is the only shared column in NATURAL JOIN.
SELECT material_id,material_name,item_id FROM(SELECT id material_id,name material_name FROM rc_materials)
NATURAL JOIN(SELECT material_id,id item_id FROM rc_pickup_items) FETCH FIRST 20 ROWS ONLY;
PROMPT Experiment 7: stored views
SELECT * FROM vw_centre_material_totals;
SELECT * FROM vw_citizen_rewards;
SELECT * FROM vw_batch_summary;
PROMPT Experiment 8: IF, CASE, basic LOOP, WHILE and FOR
DECLARE n NUMBER:=0; classification VARCHAR2(30); BEGIN
 LOOP n:=n+1; EXIT WHEN n=2; END LOOP;
 WHILE n<4 LOOP n:=n+1; END LOOP;
 FOR j IN 1..3 LOOP DBMS_OUTPUT.PUT_LINE('FOR iteration '||j); END LOOP;
 IF n<2 THEN classification:='small'; ELSIF n<5 THEN classification:='medium'; ELSE classification:='large'; END IF;
 DBMS_OUTPUT.PUT_LINE('IF classification: '||classification);
 DBMS_OUTPUT.PUT_LINE(CASE WHEN n=4 THEN 'CASE: four' ELSE 'CASE: other' END);
 DBMS_OUTPUT.PUT_LINE('Function: '||fn_reward_points(8,10)||' points');
END;
/
PROMPT Experiment 9: parameterized explicit OPEN/FETCH/CLOSE and attributes
DECLARE
 CURSOR c_materials(p_min_rate NUMBER) IS SELECT name,points_per_kg FROM rc_materials WHERE points_per_kg>=p_min_rate;
 r c_materials%ROWTYPE;
BEGIN
 OPEN c_materials(10);
 LOOP FETCH c_materials INTO r; EXIT WHEN c_materials%NOTFOUND;
 DBMS_OUTPUT.PUT_LINE(c_materials%ROWCOUNT||': '||r.name||' rate='||r.points_per_kg); END LOOP;
 CLOSE c_materials;
END;
/
VARIABLE report_cursor REFCURSOR
BEGIN pr_centre_collection_report(1,:report_cursor); END;
/
PRINT report_cursor
PROMPT Supplement: set operators
SELECT centre_id FROM rc_users WHERE role='STAFF' UNION SELECT centre_id FROM rc_pickups;
SELECT centre_id FROM rc_users WHERE role='STAFF' UNION ALL SELECT centre_id FROM rc_pickups;
SELECT id FROM rc_centres INTERSECT SELECT centre_id FROM rc_pickups;
SELECT id FROM rc_centres MINUS SELECT centre_id FROM rc_pickups;
