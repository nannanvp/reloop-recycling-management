-- EXPLICITLY DESTRUCTIVE: removes only the two known RC_LAB practice tables/views.
-- Execute only while connected as RC_LAB. Never called on application startup.
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
BEGIN
 IF USER<>'RC_LAB' THEN RAISE_APPLICATION_ERROR(-20095,'Lab reset requires RC_LAB'); END IF;
 FOR r IN(SELECT view_name FROM user_views WHERE view_name IN('RC_POSITIVE','RC_READONLY')) LOOP
  EXECUTE IMMEDIATE 'DROP VIEW '||r.view_name;
 END LOOP;
 FOR r IN(SELECT table_name FROM user_tables WHERE table_name IN('RC_PRACTICE','RC_PRACTICE_RENAMED')) LOOP
  EXECUTE IMMEDIATE 'DROP TABLE '||r.table_name||' PURGE';
 END LOOP;
END;
/
