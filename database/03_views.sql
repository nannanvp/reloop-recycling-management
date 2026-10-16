WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
CREATE OR REPLACE VIEW vw_pickup_details AS
SELECT p.id pickup_id,i.id item_id,p.citizen_id,u.full_name citizen_name,p.centre_id,c.name centre_name,
 p.status,p.preferred_date,p.scheduled_date,p.pickup_address,p.notes,p.created_at,p.updated_at,
 i.material_id,m.name material_name,i.estimated_kg,i.collected_kg,i.accepted_kg,i.batch_id,NVL(l.points,0) points
FROM rc_pickups p JOIN rc_users u ON u.id=p.citizen_id JOIN rc_centres c ON c.id=p.centre_id
JOIN rc_pickup_items i ON i.pickup_id=p.id JOIN rc_materials m ON m.id=i.material_id
LEFT JOIN rc_reward_ledger l ON l.pickup_item_id=i.id;
CREATE OR REPLACE VIEW vw_centre_material_totals AS
SELECT c.id centre_id,c.name centre_name,m.id material_id,m.name material_name,
 NVL(SUM(CASE WHEN p.status='COLLECTED' THEN i.collected_kg ELSE 0 END),0) collected_kg,
 NVL(SUM(CASE WHEN p.status='COLLECTED' THEN i.accepted_kg ELSE 0 END),0) accepted_kg,
 NVL(SUM(CASE WHEN p.status='COLLECTED' AND i.batch_id IS NULL THEN i.accepted_kg ELSE 0 END),0) available_kg,
 COUNT(DISTINCT CASE WHEN p.status='COLLECTED' AND i.id IS NOT NULL THEN p.id END) pickup_count
FROM rc_centres c CROSS JOIN rc_materials m
LEFT JOIN rc_pickups p ON p.centre_id=c.id
LEFT JOIN rc_pickup_items i ON i.pickup_id=p.id AND i.material_id=m.id
GROUP BY c.id,c.name,m.id,m.name;
CREATE OR REPLACE VIEW vw_citizen_rewards AS
SELECT u.id citizen_id,u.full_name citizen_name,NVL(SUM(l.points),0) total_points,
 NVL(SUM(CASE WHEN p.status='COLLECTED' THEN i.accepted_kg ELSE 0 END),0) accepted_kg,
 COUNT(DISTINCT p.id) pickup_count
FROM rc_users u LEFT JOIN rc_pickups p ON p.citizen_id=u.id
LEFT JOIN rc_pickup_items i ON i.pickup_id=p.id LEFT JOIN rc_reward_ledger l ON l.pickup_item_id=i.id
WHERE u.role='CITIZEN' GROUP BY u.id,u.full_name;
CREATE OR REPLACE VIEW vw_batch_summary AS
SELECT b.id batch_id,b.centre_id,c.name centre_name,b.material_id,m.name material_name,
 b.output_kg,b.processed_by,u.full_name processed_by_name,b.processed_at,
 NVL(SUM(i.accepted_kg),0) input_kg,
 CASE WHEN SUM(i.accepted_kg)>0 THEN ROUND(100*b.output_kg/SUM(i.accepted_kg),2) ELSE 0 END recovery_percent
FROM rc_batches b JOIN rc_centres c ON c.id=b.centre_id JOIN rc_materials m ON m.id=b.material_id
JOIN rc_users u ON u.id=b.processed_by LEFT JOIN rc_pickup_items i ON i.batch_id=b.id
GROUP BY b.id,b.centre_id,c.name,b.material_id,m.name,b.output_kg,b.processed_by,u.full_name,b.processed_at;
