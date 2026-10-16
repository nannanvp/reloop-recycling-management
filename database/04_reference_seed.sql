WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
MERGE INTO rc_centres t USING(SELECT 'Riverside Centre' name,'12 River Road - demonstration address' address FROM dual) s ON(t.name=s.name)
WHEN NOT MATCHED THEN INSERT(name,address) VALUES(s.name,s.address);
MERGE INTO rc_centres t USING(SELECT 'Green Park Centre' name,'48 Park Avenue - demonstration address' address FROM dual) s ON(t.name=s.name)
WHEN NOT MATCHED THEN INSERT(name,address) VALUES(s.name,s.address);
MERGE INTO rc_centres t USING(SELECT 'North Community Centre' name,'7 North Street - demonstration address' address FROM dual) s ON(t.name=s.name)
WHEN NOT MATCHED THEN INSERT(name,address) VALUES(s.name,s.address);
MERGE INTO rc_materials t USING(
 SELECT 'Paper' name,10 points_per_kg FROM dual UNION ALL SELECT 'Plastic',15 FROM dual UNION ALL
 SELECT 'Glass',8 FROM dual UNION ALL SELECT 'Aluminium',25 FROM dual UNION ALL SELECT 'Cardboard',10 FROM dual UNION ALL SELECT 'Electronics',30 FROM dual
) s ON(t.name=s.name) WHEN NOT MATCHED THEN INSERT(name,points_per_kg) VALUES(s.name,s.points_per_kg);
COMMIT;
