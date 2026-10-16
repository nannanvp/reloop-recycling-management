WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
BEGIN
 FOR r IN(SELECT table_name FROM user_tables WHERE table_name LIKE 'RC_%' AND table_name<>'RC_AUDIT_LOG') LOOP
 EXECUTE IMMEDIATE 'GRANT SELECT,INSERT,UPDATE,DELETE ON '||r.table_name||' TO RC_APP';
 END LOOP;
END;
/
GRANT SELECT ON rc_audit_log TO rc_app;
GRANT SELECT ON vw_pickup_details TO rc_app;
GRANT SELECT ON vw_centre_material_totals TO rc_app;
GRANT SELECT ON vw_citizen_rewards TO rc_app;
GRANT SELECT ON vw_batch_summary TO rc_app;
GRANT EXECUTE ON fn_reward_points TO rc_app;
GRANT EXECUTE ON pr_confirm_collection TO rc_app;
GRANT EXECUTE ON pr_post_rewards TO rc_app;
GRANT EXECUTE ON pr_process_material TO rc_app;
GRANT EXECUTE ON pr_centre_collection_report TO rc_app;
