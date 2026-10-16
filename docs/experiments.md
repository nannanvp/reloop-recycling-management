# Experiment map

These examples use Oracle SQL/PLSQL through SQL*Plus. Website writes use the corresponding Oracle operations through JDBC. The web sandbox exposes fixed actions and academic reports rather than arbitrary SQL text.

| Experiment | ReLoop evidence | Where to inspect |
|---|---|---|
| 1. DDL, DML, DQL | Admin centre/material/user forms and citizen pickup forms insert/update/delete records; dashboards and reports select records. The isolated lab script covers table/view DDL and data manipulation. | App portals; `database/09_lab_demonstrations.sql` |
| 2. Operators, functions, clauses | Search/filtering and reports apply predicates, ordering, grouping, and aggregate filters. | `database/08_academic_queries.sql`; report screens |
| 3. E-R diagram | The entity model and its keys/cardinalities are described with normalization in this documentation. | `docs/normalization.md` |
| 4. Single-row and group functions | Academic SQL uses string, null, date, and aggregate functions; the reward function applies `FLOOR` to accepted kilograms times the material rate. | `database/08_academic_queries.sql`; `database/02_routines.sql` |
| 5. Subqueries | Above-average citizen totals, never-collected materials (`NOT EXISTS`), and centres with pending pickups (`EXISTS`). | `database/08_academic_queries.sql`; report screens |
| 6. JOINs | Pickup details join citizen, centre, material, item, and reward data; totals preserve centres with no activity. SQL examples cover inner/outer, cross, self, and carefully projected natural joins. | `database/03_views.sql`; `database/08_academic_queries.sql` |
| 7. VIEWs | `VW_PICKUP_DETAILS`, `VW_CENTRE_MATERIAL_TOTALS`, `VW_CITIZEN_REWARDS`, and `VW_BATCH_SUMMARY` feed application reports. The lab demonstrates `WITH CHECK OPTION` and `WITH READ ONLY`. | `database/03_views.sql`; `database/09_lab_demonstrations.sql` |
| 8. PL/SQL | Collection confirmation, idempotent reward posting, and batch processing are stored procedures; points calculation is a stored function. Academic examples show branches and loops. | `database/02_routines.sql`; `database/08_academic_queries.sql` |
| 9. CURSORs | Reward posting uses a parameterized cursor; batch processing locks eligible lines and updates them with `WHERE CURRENT OF`; the reporting procedure returns `SYS_REFCURSOR`. | `database/02_routines.sql`; `database/08_academic_queries.sql`; JDBC report path in `OperationsController` |
| 10. JDBC/ODBC | The app uses JDBC `PreparedStatement`/`JdbcTemplate` for parameterized queries and `CallableStatement` for stored procedures and a ref cursor. ODBC is not used. | `src/main/java/com/reloop/app/OperationsController.java`; `Application.java` |

Supporting syllabus topics: `database/09_lab_demonstrations.sql` demonstrates savepoints and commit/rollback with DML; `database/11_dcl_demo.sql` temporarily grants and revokes a lab read privilege; `TRG_PICKUP_STATUS_AUDIT` records status changes; set operators appear in `database/08_academic_queries.sql`.

For command output, run SQL*Plus verification/query scripts against the configured `XEPDB1` database. `database/07_transaction_smoke.sql` creates a synthetic fixture and rolls it back; it does not validate the web UI.
