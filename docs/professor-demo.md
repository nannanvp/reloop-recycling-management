# Professor demonstration (about 8 minutes)

Before the demonstration, confirm Oracle XE and its listener are running, run `powershell -ExecutionPolicy Bypass -File .\database\setup.ps1` if this is a fresh installation, then launch with `start.ps1`. Open `http://localhost:8080`. Sign-in details are in the locally generated `.local\demo-logins.txt`; keep that file private.

1. **Minute 0–1 — roles:** Sign in as admin and show the dashboard, centre/material management, and seeded synthetic activity. Mention that staff scope is limited to their assigned centre and citizens see their own records.
2. **Minute 1–2 — citizen flow:** Sign in as a citizen, show pickup history and points, then create a small request with a centre, date, and material line. If retaining the fixture matters, use an existing seeded request for the remaining steps or delete the new request while it is still requested.
3. **Minute 2–4 — staff operations:** Sign in as staff assigned to that centre. Schedule a requested pickup, enter collected and accepted weights, and confirm collection. Explain the `0 ≤ accepted ≤ collected` rule and the status audit trigger.
4. **Minute 4–5 — points and processing:** Post rewards for the collected request, show the ledger/dashboard total, then process the available material with output no greater than available accepted input. Explain that repeating reward posting does not duplicate entries and processing consumes complete eligible lines.
5. **Minute 5–6 — SQL reports:** Show joined pickup details, centre/material totals, batches, and one subquery report such as above-average citizens or never-collected materials. Point out the stored views and SQL*Plus equivalents in `database/08_academic_queries.sql`.
6. **Minute 6–7 — data model:** Walk through the eight tables and their relationships using `docs/normalization.md`; explain why pickup address and reward-rate snapshots retain historical facts.
7. **Minute 7–8 — academic evidence:** Show the fixed lab sandbox/DDL evidence, then use SQL*Plus `database/06_verify.sql` and selected sections of `database/08_academic_queries.sql`. Explain that browser persistence is JDBC; SQL*Plus-only commands are not sent through JDBC.

The professor's source files remain in the local `Professor Material` folder and are not part of the Git repository. GitHub publication is deferred until evaluation has finished. Partial batch consumption is outside this version.
