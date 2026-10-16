# Verification record

The following checks were run against the local Oracle-backed application on October 10, 2026. The project targets Java 17 and Spring Boot 3.5.7. Private local evidence paths below document the original run; their contents are not published. The tests were not rerun solely for the October 16 repository publication.

| Check | Result |
|---|---|
| Operational API smoke | 36 API checks passed, covering authenticated operations and role-scoped behavior. |
| Academic API smoke | 30 requests passed: admin login, all ten academic topic runs, and the full isolated sandbox lifecycle through final reset. The run log is ignored at `.local/academic-test.log`; rerun with `python tests/academic_smoke.py`. |
| SQL transactional smoke | `database/07_transaction_smoke.sql` passed its synthetic rollback-only fixture, covering collection confirmation, reward calculation and duplicate prevention, invalid output rejection, cursor processing, prevention of double processing, and the audit trigger. |
| Browser walkthrough | Passed in installed Chrome: all nine admin screens, four staff screens, citizen request create/edit/delete, and 390 px mobile viewport. No page errors or document overflow. Screenshots are in ignored `.local/qa/`. |
| Restart persistence | Passed: after a full application restart, the collected pickup, 8 kg accepted weight, 80 points and processing batch (8 kg input / 7 kg output) remained stored. Evidence: `.local/persistence-results.txt`. |
| Concurrent processing | Passed with two competing SQL*Plus sessions: one processing operation committed; the second waited for the centre lock and rejected already-consumed material. Exactly one batch and consumed line were verified. Rerun `tests/concurrent-processing.ps1`. |
| Academic SQL*Plus script | `database/08_academic_queries.sql` completed with exit code 0 and no ORA/SP2 errors. |
| Test cleanup | Tracked API and concurrency fixture IDs were removed with identity checks; normal seeded data was preserved. |
| Credential exclusion | `.local/db-secrets.json`, `.local/demo-logins.txt`, and build artifacts are ignored by Git. |

The application runs locally at `http://localhost:8080`. GitHub publication distributes the source; no cloud deployment is included.

The plan requested Spring Boot 3.5.16; the delivered build pins Spring Boot 3.5.7. The project was verified using that actual dependency set. Processing consumes complete material lines, rewards are illustrative points, and collected records are immutable in this version. A simulated Oracle outage was not tested; the backend handles connection failures without a mock-data fallback.
