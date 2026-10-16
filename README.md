# ReLoop

ReLoop is a locally hosted recycling-management demonstration for BACSE202. It uses Oracle XE 21c, Oracle SQL and PL/SQL, Java 17, Spring Boot 3.5.7, Maven, and JDBC. The app listens on `http://localhost:8080` and connects to the local `XEPDB1` service.

## Requirements

- Windows PowerShell
- Oracle Database XE 21c with the `XEPDB1` PDB open and listener available
- SQL*Plus available on `PATH` and an authorized Windows account able to connect as `SYSDBA` for initial setup
- Java 17 (available on `PATH` or placed under `.local/java/`)
- Maven 3.9.9 under `.local/maven/apache-maven-3.9.9/` or `mvn` available on `PATH`

## First-time setup

Clone the project and enter its directory:

```powershell
git clone https://github.com/nannanvp/reloop-recycling-management.git
cd reloop-recycling-management
```

Initialize the Oracle users and schema from an authorized PowerShell session **before starting the application**:

```powershell
powershell -ExecutionPolicy Bypass -File .\database\setup.ps1
```

`database\setup.ps1` connects through local SQL*Plus OS authentication as `/ as sysdba`, switches to `XEPDB1`, creates `RC_OWNER`, `RC_APP`, and `RC_LAB` if missing, builds the owner schema, installs procedures/views, seeds reference centres and materials, and grants the app its table/view/routine access. It creates `.local\db-secrets.json` on first use. Keep `.local` private and do not publish its contents.

Then start ReLoop:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\start.ps1
```

The launcher builds the Spring Boot JAR, starts the app as a hidden background process, and checks readiness at `http://127.0.0.1:8080`. Wait for `ReLoop is ready: http://localhost:8080`, then open the URL in your browser. It uses Java 17 from `PATH` or `.local/java/`; Maven is taken from `.local/maven/apache-maven-3.9.9/` or `PATH`. Java, Maven, Oracle and SQL*Plus are prerequisites; the launcher does not install them. Maven downloads dependencies on the first build.

`start.ps1` records the server process ID in `.local\server.pid`. If that matching ReLoop process is already running, it prints the local URL and exits without building again. Avoid running concurrent starts/builds. Stop the app before rebuilding changed source:

```powershell
.\stop.ps1
```

The stop script checks the recorded process and only stops the matching ReLoop JAR; Oracle remains running. Application output is written to ignored `.local\server.log` and `.local\server-error.log`. The first successful application boot creates synthetic demo users and records. Their shared generated password and usernames are written to `.local\demo-logins.txt`; open that local file to sign in. No credentials are listed here because the file is local runtime state. Citizen self-registration is also available.

Open [http://localhost:8080](http://localhost:8080). Use the admin login for centre/material/user administration, reports, and academic demonstrations; staff logins operate their assigned centre; citizen logins manage their own pending pickup requests and view their history and points.

## Database scripts

Run scripts from SQL*Plus, in the appropriate schema and PDB. The PowerShell setup script handles the normal initial owner-schema install.

| Script | Purpose |
|---|---|
| `database\01_schema.sql` | Normalized operational tables, keys, constraints, indexes, and comments |
| `database\02_routines.sql` | Reward function, collection/reward/processing procedures, report ref cursor, and status audit trigger |
| `database\03_views.sql` | Pickup details, centre/material totals, citizen rewards, and batch summary views |
| `database\04_reference_seed.sql` | Idempotent synthetic reference centres and materials |
| `database\05_grants.sql` | Runtime grants to `RC_APP` |
| `database\06_verify.sql` | Object compilation and schema/view checks |
| `database\07_transaction_smoke.sql` | Rollback-only synthetic procedure/trigger smoke fixture |
| `database\08_academic_queries.sql` | SQL examples for the experiments, joins, views, functions, subqueries, and cursors |
| `database\09_lab_demonstrations.sql` | Isolated `RC_LAB` DDL/DML, view restrictions, and TCL example |
| `database\10_lab_reset.sql` | Explicitly destructive cleanup of the known `RC_LAB` practice objects only |
| `database\11_dcl_demo.sql` | Temporary `GRANT`/`REVOKE` demonstration; requires authorized administrator access |

The application uses prepared JDBC statements and stored procedure calls. It does not use Hibernate/JPA or ODBC. The DDL practice identity is isolated from operational data.

## What the app demonstrates

- Session-based admin, staff, and citizen portals with role- and centre-scoped operations.
- Pickup request creation and editing/deletion while still requested; staff scheduling, weight entry, collection, reward posting, and material processing.
- Oracle-backed dashboards, pickup/reward/batch views, and centre/material reports.
- A sandbox of fixed academic actions instead of arbitrary SQL execution.
- Synthetic demonstration data generated only when the application schema has no users.

Processing currently assigns all eligible accepted lines for one centre/material to a batch. Partial consumption of a line is outside this version. Points are illustrative and are not redeemable. See [docs/experiments.md](docs/experiments.md), [docs/normalization.md](docs/normalization.md), [docs/professor-demo.md](docs/professor-demo.md), and [docs/verification.md](docs/verification.md) for scope and verification status.

## Repository and publication

The public repository contains application source, Oracle SQL*Plus scripts, tests, and documentation. The supplied professor materials and syllabus, internal planning draft, `.local` credentials, generated demo logins, logs, and build output are excluded from Git and remain local.

This is a local coursework demonstration. Publishing the source on GitHub does not host the Java application or its Oracle database. New installations generate their own database and demonstration-account credentials during setup.
