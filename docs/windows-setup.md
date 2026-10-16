# Windows bootstrapper

Download [Setup-ReLoop.bat](https://raw.githubusercontent.com/nannanvp/reloop-recycling-management/main/Setup-ReLoop.bat), then double-click it. This is a standalone entry point: it fetches `install.ps1` from the same pinned GitHub commit as the project archive. Git is not required. Network access to GitHub, Adoptium, Maven Central and (if needed) Oracle is required.

## Requirements and user interaction

- Intel/AMD x64 Windows, Windows PowerShell 5.1 or later, and an Oracle-supported Windows edition. ARM, 32-bit Windows, macOS and Linux are not supported by this BAT.
- Internet access, sufficient disk space, and permission to run downloaded software. Allow about 20 GB free when Oracle is not already installed, including Oracle, tools, dependencies and cached/extracted downloads. Oracle's own prerequisite checks remain authoritative.
- Oracle XE 21c is the database target. Existing incompatible Oracle installations are not removed or upgraded.
- A new Oracle installation uses Oracle's visible wizard. The user must approve Windows elevation, review/accept Oracle's terms and choose an administrator password. Windows Home is not supported by the documented XE installer. The Oracle installer may require a restart or a Windows sign-out/sign-in to refresh `ORA_DBA` group membership.
- Application and schema passwords are generated separately on that PC. They are never downloaded from the developer's PC or committed to GitHub.

References: [Oracle XE installation instructions](https://docs.oracle.com/en/database/oracle/oracle-database/21/xeinw/installing-oracle-database-xe.html), [Oracle XE download and SHA-256](https://www.oracle.com/database/technologies/xe-downloads.html), [Adoptium](https://adoptium.net/), [Maven download verification](https://maven.apache.org/download.cgi).

## What setup does

1. Resolves the current `main` commit and downloads the corresponding installer and source archive over HTTPS.
2. Installs to `%LOCALAPPDATA%\ReLoop`. A marker in `.local\install-state.json` records the repository revision. Existing managed installations are reused without source replacement; other nonempty directories are refused.
3. Downloads Java 17 and Maven 3.9.9 into `.local`, verifies their published checksums, and checks that both run. No global PATH or Java settings are changed.
4. Finds Oracle XE and SQL*Plus through Windows service/registry information. If absent, offers to download Oracle's official checksum-verified installation archive and launch its signed installer. No license acceptance is automated.
5. Starts existing XE/listener services where permitted. An administrator is needed if Windows denies service control.
6. Connects locally using SQL*Plus OS authentication, opens a mounted `XEPDB1`, and provisions the ReLoop schema without deleting data or resetting existing account passwords. Existing incomplete schemas and missing credentials stop setup with a recovery message.
7. Builds and launches the Java application, confirms HTTP readiness, writes `Start-ReLoop.bat` and `Stop-ReLoop.bat` into the project folder, and opens the browser and the local login note.

The project still runs locally. This installer does not deploy a cloud website, configure port forwarding, add firewall rules or enable Windows auto-start.

## Custom destination

From Command Prompt, set a destination before running the downloaded file:

```bat
set "RELOOP_INSTALL_DIR=D:\Projects\ReLoop"
Setup-ReLoop.bat
```

The folder must be empty or an installation previously created by this installer. Paths with spaces are supported. A normal Git clone is not treated as an installer-managed folder; use the manual README setup for an existing clone.

For advanced use, run the repository's PowerShell installer directly:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -InstallDir "D:\Projects\ReLoop" -OraclePort 1521 -NoBrowser
```

`-NonInteractive` refuses to install a missing Oracle database rather than opening its wizard. `RELOOP_NO_PAUSE=1` disables the BAT's final keypress pause. `-LibraryOnly` is reserved for the installer tests and does not perform installation.

## Troubleshooting

| Message/problem | Action |
|---|---|
| File opens as text | Save the download as `Setup-ReLoop.bat` with file type All Files; check that Windows did not append `.txt`. |
| Download blocked or GitHub rate limit | Check network/proxy access and retry later. No GitHub token is required or requested. |
| Oracle missing | Allow the offered download and finish Oracle's wizard, or install XE 21c yourself and rerun. |
| Cannot start Oracle service | Right-click the BAT and choose Run as administrator, using the same Windows account that owns the installation. |
| SQL*Plus OS authentication fails | Use an account in Oracle's local DBA group. After installing Oracle, sign out of Windows and back in; reboot if requested by the installer. |
| Existing accounts, missing credentials | Keep the existing database. Privately copy the original project's `.local\db-secrets.json` to the new installation's `.local` folder, or keep using the original project. Never publish the file. |
| Partial schema detected | Stop and repair/restore it with the database administrator. The bootstrapper will not drop tables to recover automatically. |
| Listener uses another port | Use `install.ps1 -OraclePort <port>` on a fresh installation. An existing config retains its saved port. |
| Port 8080 busy | Stop the other service or the previous ReLoop instance, then rerun. Do not run two project copies against the same local port. |
| Build/server failure | Read `.local\server.log` and `.local\server-error.log` in the installation folder; rerun after addressing the error. |

Repeated setup does not fetch updates into an existing managed installation. This deliberately preserves edited source and local credentials. Back up private configuration and data before manually updating source.

## Validation limits

Installer tests cover archive-path validation, pinned downloads, existing-directory protection, rerun preservation, Oracle-account collision handling, incomplete-schema refusal, credential preservation and BOM-free JSON generation under Windows PowerShell. Fresh Oracle installation needs a separate clean Windows machine and interactive wizard; it has not been simulated by uninstalling or replacing the developer's working Oracle instance.

Run the isolated tests with `powershell -NoProfile -ExecutionPolicy Bypass -File tests\bootstrap-tests.ps1`. They use a fake SQL*Plus process for provisioning scenarios and never reset the real database.
