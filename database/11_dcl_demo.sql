-- Run as SYS in XEPDB1 or another authorized administrator.
-- Temporary privilege is immediately revoked; RC_LAB retains no operational access.
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
GRANT SELECT ON rc_owner.rc_materials TO rc_lab;
SELECT grantee,owner,table_name,privilege FROM dba_tab_privs WHERE grantee='RC_LAB' AND owner='RC_OWNER';
REVOKE SELECT ON rc_owner.rc_materials FROM rc_lab;
SELECT COUNT(*) remaining_operational_grants FROM dba_tab_privs WHERE grantee='RC_LAB' AND owner='RC_OWNER';
