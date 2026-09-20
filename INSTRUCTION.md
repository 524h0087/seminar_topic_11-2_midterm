# Build-Test-Deploy Automation Guide

This project is a FastAPI Student Management API with an automated local workflow:

```text
Code base -> Build -> Test -> Deploy
Available -> Automated -> Automated with Newman -> Automated on Local Machine
```

The automation is designed for a Windows local machine using PowerShell, Python, Node.js, Postman assets, and Newman.

## Project Overview

The API source code is in `main.py`.

The application provides:

- `POST /api/auth/login`
- `GET /api/students`
- `GET /api/students/{id}`
- `POST /api/students`
- `PUT /api/students/{id}`
- `DELETE /api/students/{id}`
- `GET /actuator/health`

The local API port is `8080`.

The local base URL is:

```text
http://127.0.0.1:8080
```

The Swagger UI is:

```text
http://127.0.0.1:8080/docs
```

## Folder And File Roles

```text
main.py
```

FastAPI application source code.

```text
requirements.txt
```

Python dependency list used by the Build phase.

```text
scripts/build.ps1
```

Automates the Build phase.

```text
scripts/export-postman-newman.mjs
```

Converts the local Postman YAML workspace into Newman-compatible JSON files.

```text
scripts/test.ps1
```

Automates the Test phase with Newman.

```text
scripts/deploy-local.ps1
```

Automates the Deploy phase by starting the API as a persistent local background process.

```text
scripts/stop-local.ps1
```

Stops the locally deployed API process.

```text
postman/collections/
```

Postman local YAML request files.

```text
postman/environments/
```

Postman local YAML environment files.

```text
postman/newman/
```

Generated Newman-compatible collection and environment JSON files.

```text
reports/newman/
```

Generated Newman reports. This folder is ignored by Git.

```text
.runtime/
```

Runtime files for local deployment and temporary server logs. This folder is ignored by Git.

## Required Tools

Install these before running the automation:

1. Python 3.13 or compatible Python 3 version.
2. Node.js and npm.
3. PowerShell.

Newman does not need to be installed globally. The project installs Newman locally through `npm install`.

## One-Time Setup

From the project root:

```powershell
npm install
```

This installs local Node.js development dependencies:

- `newman`
- `yaml`

The Python virtual environment is created automatically by the Build phase, so you do not need to create `.venv` manually.

## Build Phase

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

What it does:

1. Checks that `requirements.txt` exists.
2. Checks that Python is available.
3. Creates `.venv` if it does not exist.
4. Reuses `.venv` if it already exists.
5. Upgrades `pip`.
6. Installs dependencies from `requirements.txt`.
7. Imports `main.py` and verifies the FastAPI app exists.
8. Runs `pip check` to detect broken Python dependency relationships.

Successful output ends with:

```text
Build phase completed successfully.
```

Optional parameters:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1 -PythonExe python
```

Use this if you need to point the script at another Python executable.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1 -SkipDependencyInstall
```

Use this only when dependencies are already installed and you want a faster validation run.

## Test Phase

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test.ps1
```

Or:

```powershell
npm run test:api
```

What it does:

1. Runs the Build phase.
2. Runs `npm install`, unless skipped.
3. Converts Postman YAML files into Newman JSON files.
4. Starts a temporary Uvicorn API server.
5. Waits until `GET /actuator/health` returns `UP`.
6. Runs Newman tests.
7. Writes Newman reports.
8. Stops the temporary API server.

Generated Newman files:

```text
postman/newman/API Testing.postman_collection.json
postman/newman/Test Subject 1.postman_environment.json
```

Generated reports:

```text
reports/newman/newman-report.json
reports/newman/newman-report.xml
```

Optional parameters:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test.ps1 -SkipBuild
```

Skips the Build phase.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test.ps1 -SkipNpmInstall
```

Skips `npm install`.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test.ps1 -HostName 127.0.0.1 -Port 8080
```

Runs the temporary test server on a custom host or port.

Expected Newman result:

```text
requests:   14 executed, 0 failed
assertions: 43 executed, 0 failed
```

## Deploy Phase

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy-local.ps1
```

Or:

```powershell
npm run deploy:local
```

What it does:

1. Runs the Build phase.
2. Starts Uvicorn as a background local process.
3. Saves the process ID to `.runtime/api.pid`.
4. Saves the deployed URL to `.runtime/api.url`.
5. Writes logs to `.runtime/api.out.log` and `.runtime/api.err.log`.
6. Waits until `GET /actuator/health` returns `UP`.
7. Leaves the API running after the command exits.

Successful output includes:

```text
Deploy phase completed successfully.
URL: http://127.0.0.1:8080
Docs: http://127.0.0.1:8080/docs
Health: http://127.0.0.1:8080/actuator/health
```

Optional parameters:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy-local.ps1 -SkipBuild
```

Skips the Build phase.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy-local.ps1 -Force
```

Stops the previous local deployment first, then starts a new one.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy-local.ps1 -HostName 127.0.0.1 -Port 8080
```

Deploys to a custom host or port.

## Stop Local Deployment

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\stop-local.ps1
```

Or:

```powershell
npm run stop:local
```

What it does:

1. Reads `.runtime/api.pid`.
2. Stops the recorded process if it is still running.
3. Removes `.runtime/api.pid` and `.runtime/api.url`.

If no deployment is running, the script exits safely.

## Full Manual Workflow

Use this sequence when demonstrating the whole automation:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
npm run test:api
npm run deploy:local
```

Then open:

```text
http://127.0.0.1:8080/docs
```

When finished:

```powershell
npm run stop:local
```

## How The Postman And Newman Automation Works

The original Postman requests are stored as YAML files under:

```text
postman/collections/API Testing/
```

Newman expects exported Postman JSON, not this local YAML workspace format.

The converter script:

```text
scripts/export-postman-newman.mjs
```

reads the YAML request files and generates:

```text
postman/newman/API Testing.postman_collection.json
postman/newman/Test Subject 1.postman_environment.json
```

The collection uses bearer authentication with:

```text
{{token}}
```

The valid login request saves the JWT token into the Postman environment. Later protected requests reuse that token automatically.

The request order is important:

1. Health check.
2. Invalid login.
3. Valid login.
4. Protected GET tests.
5. Protected POST tests.
6. Protected PUT tests.
7. Protected DELETE test.

Invalid login runs before valid login because it clears auth variables. Valid login must run before protected CRUD requests because it creates the JWT token.

## How To Configure The Workflow

### Change The Port

For testing:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test.ps1 -Port 8090
```

For local deployment:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy-local.ps1 -Port 8090
```

### Change The Host

For local-only access:

```powershell
-HostName 127.0.0.1
```

For LAN access from another machine on the same network:

```powershell
-HostName 0.0.0.0
```

Example:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy-local.ps1 -HostName 0.0.0.0 -Port 8080
```

### Change Python Executable

For Build:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1 -PythonExe py
```

or:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1 -PythonExe "C:\Path\To\python.exe"
```

## How To Build This Automation Yourself

To recreate this automation from scratch in another similar FastAPI project:

1. Create a `requirements.txt` file with all Python dependencies.
2. Create `scripts/build.ps1`.
3. In `build.ps1`, create or reuse `.venv`.
4. Install dependencies with:

```powershell
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

5. Add an import verification command:

```powershell
.\.venv\Scripts\python.exe -c "import main; print('App import OK')"
```

6. Add Postman request tests.
7. Export or generate a Newman-compatible Postman collection JSON.
8. Add `newman` as a local npm dev dependency.
9. Create `scripts/test.ps1`.
10. In `test.ps1`, start a temporary API server.
11. Wait for the health endpoint.
12. Run Newman.
13. Stop the temporary test server in a `finally` block.
14. Create `scripts/deploy-local.ps1`.
15. In `deploy-local.ps1`, start Uvicorn as a background process.
16. Save the process ID to `.runtime/api.pid`.
17. Verify the health endpoint.
18. Create `scripts/stop-local.ps1`.
19. In `stop-local.ps1`, read `.runtime/api.pid` and stop the process.
20. Add npm shortcuts in `package.json`.
21. Add `.venv`, `node_modules`, `.runtime`, and `reports` to `.gitignore`.
22. Document the workflow in README or an instruction file.

## Troubleshooting

### PowerShell Blocks Script Execution

Use:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

The same pattern works for the test, deploy, and stop scripts.

### Port 8080 Is Already In Use

Either stop the process using the port or deploy on another port:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy-local.ps1 -Port 8090
```

### Local Deployment Is Already Running

Run:

```powershell
npm run stop:local
```

Then deploy again:

```powershell
npm run deploy:local
```

Or force redeploy:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy-local.ps1 -Force
```

### Newman Dependency Warnings

`npm install` may report vulnerabilities in Newman-related development dependencies. These are part of the local test tooling dependency tree, not the FastAPI runtime dependency tree. For this seminar project, the important runtime validation is still handled by the Build phase and Newman test result.

### Test Server Does Not Become Healthy

Check:

```text
.runtime/test-server.out.log
.runtime/test-server.err.log
```

For deployed server logs, check:

```text
.runtime/api.out.log
.runtime/api.err.log
```

## Current Final State

The final automated workflow is:

```text
Build:
    Automated with scripts/build.ps1

Test:
    Automated with scripts/test.ps1 and Newman

Deploy:
    Automated locally with scripts/deploy-local.ps1

Stop:
    Automated with scripts/stop-local.ps1
```

The project can now be built, tested, and deployed locally with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
npm run test:api
npm run deploy:local
npm run stop:local
```
