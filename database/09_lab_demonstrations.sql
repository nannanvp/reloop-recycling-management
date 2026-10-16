-- Connect ONLY as RC_LAB. This script uses disposable RC_PRACTICE objects.
-- Oracle DDL commits implicitly; the later TCL sequence contains DML only.
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
SET SERVEROUTPUT ON
CREATE TABLE rc_practice(id NUMBER PRIMARY KEY,label VARCHAR2(40),amount NUMBER(10,2));
INSERT INTO rc_practice VALUES(1,'Paper',10);
MERGE INTO rc_practice d USING(SELECT 2 id,'Glass' label,8 amount FROM dual) s ON(d.id=s.id)
WHEN MATCHED THEN UPDATE SET d.amount=s.amount WHEN NOT MATCHED THEN INSERT(id,label,amount) VALUES(s.id,s.label,s.amount);
UPDATE rc_practice SET amount=amount+2 WHERE id=1;
SELECT * FROM rc_practice ORDER BY id;
ALTER TABLE rc_practice ADD(note VARCHAR2(30));
ALTER TABLE rc_practice MODIFY(note VARCHAR2(60));
ALTER TABLE rc_practice RENAME COLUMN note TO remarks;
ALTER TABLE rc_practice DROP COLUMN remarks;
COMMENT ON TABLE rc_practice IS 'Isolated Oracle DDL and DML demonstration';
SELECT comments FROM user_tab_comments WHERE table_name='RC_PRACTICE';
CREATE OR REPLACE VIEW rc_positive AS SELECT * FROM rc_practice WHERE amount>=0 WITH CHECK OPTION;
CREATE OR REPLACE VIEW rc_readonly AS SELECT * FROM rc_practice WITH READ ONLY;
BEGIN
 BEGIN UPDATE rc_positive SET amount=-1 WHERE id=1; RAISE_APPLICATION_ERROR(-20090,'CHECK OPTION did not reject');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-1402 THEN RAISE; END IF; DBMS_OUTPUT.PUT_LINE('PASS: CHECK OPTION rejected negative amount'); END;
 BEGIN EXECUTE IMMEDIATE 'UPDATE rc_readonly SET amount=0 WHERE id=1'; RAISE_APPLICATION_ERROR(-20091,'READ ONLY did not reject');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-42399 THEN RAISE; END IF; DBMS_OUTPUT.PUT_LINE('PASS: READ ONLY rejected update'); END;
END;
/
COMMIT;
PROMPT TCL: savepoint and rollback affect DML only
INSERT INTO rc_practice VALUES(3,'Temporary before savepoint',1);
SAVEPOINT after_first;
INSERT INTO rc_practice VALUES(4,'Temporary after savepoint',1);
ROLLBACK TO after_first;
SELECT * FROM rc_practice;
ROLLBACK;
SELECT * FROM rc_practice;
DELETE FROM rc_practice WHERE id=2;
COMMIT;
DROP VIEW rc_positive;
DROP VIEW rc_readonly;
RENAME rc_practice TO rc_practice_renamed;
TRUNCATE TABLE rc_practice_renamed;
DROP TABLE rc_practice_renamed PURGE;
