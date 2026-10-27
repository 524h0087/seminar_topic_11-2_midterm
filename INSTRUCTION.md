# Project Configuration Runbook

This project is a FastAPI API with local automation for:

- Build: create `.venv/`, install Python dependencies, verify app import.
- Test: run Newman against the API with Postman tests.
- Deploy: start the API locally with Uvicorn.
- Verify: check local and optional ngrok health endpoints.
- Stop: stop the background local API process.

Run all commands from the project root.

```text
seminar_topic_11-2_midterm/
  main.py
  requirements.txt
  package.json
  scripts/
  postman/
```

## 1. Prerequisites

Install:

- Python 3.13 or compatible Python 3
- Node.js and npm
- PowerShell
- ngrok, only for a public URL

Verify:

```powershell
python --version
node --version
npm --version
$PSVersionTable.PSVersion
```

## 2. First-Time Setup

Install Node.js dependencies:

```powershell
npm install
```

Build the Python environment:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

The build script:

1. Creates or reuses `.venv/`.
2. Installs packages from `requirements.txt`.
3. Verifies that `main.py` imports correctly.
4. Runs `pip check`.

## 3. Run This Project Locally

Start the API:

```powershell
npm run deploy:local
```

Default local URLs:

```text
API:    http://127.0.0.1:8080
Docs:   http://127.0.0.1:8080/docs
Health: http://127.0.0.1:8080/actuator/health
```

Verify health:

```powershell
Invoke-RestMethod http://127.0.0.1:8080/actuator/health
```

Expected response includes:

```text
status: UP
```

Stop the API:

```powershell
npm run stop:local
```

## 4. Run Tests

Run Newman API tests:

```powershell
npm run test:api
```

The test script:

1. Builds the Python environment.
2. Installs npm dependencies if needed.
3. Generates Newman files under `postman/newman/`.
4. Starts a temporary API server.
5. Waits for `/actuator/health`.
6. Runs Newman.
7. Writes reports under `reports/newman/`.
8. Stops the temporary server.

## 5. Run the Full Local Pipeline

Run Build, Test, Deploy, and local health verification:

```powershell
npm run cicd:local
```

Run on another port:

```powershell
npm run cicd:local -- -Port 8081
```

The `--` is required so npm passes `-Port 8081` to `scripts/pipeline.ps1`.

With port `8081`, use:

```text
API:    http://127.0.0.1:8081
Docs:   http://127.0.0.1:8081/docs
Health: http://127.0.0.1:8081/actuator/health
```

## 6. Use ngrok for a Public URL

Start ngrok in a separate terminal.

For port `8080`:

```powershell
ngrok http http://127.0.0.1:8080
```

For port `8081`:

```powershell
ngrok http http://127.0.0.1:8081
```

Use `127.0.0.1`, not `localhost`, to avoid Windows IPv4/IPv6 forwarding issues.

ngrok prints a forwarding URL:

```text
https://real-ngrok-url.ngrok-free.dev -> http://127.0.0.1:8081
```

Use the real URL shown by ngrok. Do not use placeholder text.

Run the pipeline with ngrok verification:

```powershell
npm run cicd:local -- -Port 8081 -NgrokUrl "https://real-ngrok-url.ngrok-free.dev"
```

Or store the URL in the current PowerShell session:

```powershell
$env:NGROK_PUBLIC_URL = "https://real-ngrok-url.ngrok-free.dev"
npm run cicd:local -- -Port 8081
```

Verify only ngrok:

```powershell
npm run verify:ngrok -- -NgrokUrl "https://real-ngrok-url.ngrok-free.dev"
```

## 7. API Details

Default base URL:

```text
http://127.0.0.1:8080
```

Demo credentials:

```text
Username: admin
Password: admin123
```

Important endpoints:

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/actuator/health` | Health check |
| `POST` | `/api/auth/login` | Login and receive token |
| `GET` | `/api/students` | List students |
| `POST` | `/api/students` | Create student |
| `PUT` | `/api/students/{id}` | Update student |
| `DELETE` | `/api/students/{id}` | Delete student |

Student endpoints require a bearer token from login.

## 8. Generated Files

Do not commit generated files.

| Path | Purpose |
|---|---|
| `.venv/` | Python virtual environment |
| `node_modules/` | npm dependencies |
| `.runtime/` | process IDs, URLs, logs, pipeline summaries |
| `postman/newman/` | generated Newman collection and environment |
| `reports/newman/` | Newman reports |

Recommended `.gitignore` entries:

```text
.venv/
node_modules/
.runtime/
reports/
postman/newman/
```

## 9. Configure This Automation for Your Own Project

Use this repository as a template when your own project is also a FastAPI API.

### 9.1 Set Your Python App Target

The current scripts run:

```text
main:app
```

That means:

- File: `main.py`
- FastAPI instance: `app`

If your project uses another target, update it in:

```text
scripts/test.ps1
scripts/deploy-local.ps1
```

Examples:

```text
main:app
app.main:app
src.server:api
```

Use the same target you would pass to Uvicorn:

```powershell
uvicorn app.main:app --host 127.0.0.1 --port 8080
```

### 9.2 Set Your Python Dependencies

Update:

```text
requirements.txt
```

It must contain every package needed to import and run your API.

Then update the import check in:

```text
scripts/build.ps1
```

Current project check:

```powershell
& $PythonInVenv -c "import main; assert main.app.title == 'Student Management API'; print('FastAPI app import OK')"
```

Generic check:

```powershell
& $PythonInVenv -c "import main; assert main.app; print('FastAPI app import OK')"
```

Package-style app check:

```powershell
& $PythonInVenv -c "from app.main import app; assert app; print('FastAPI app import OK')"
```

### 9.3 Set Your Health Endpoint

The scripts expect:

```text
GET /actuator/health
```

Expected JSON:

```json
{
  "status": "UP"
}
```

If your project uses another path, replace `/actuator/health` in:

```text
scripts/test.ps1
scripts/deploy-local.ps1
scripts/pipeline.ps1
scripts/verify-ngrok.ps1
```

### 9.4 Set Your Postman/Newman Tests

The test script currently uses:

```powershell
$CollectionPath = Resolve-FromProjectRoot "postman\newman\API Testing.postman_collection.json"
$EnvironmentPath = Resolve-FromProjectRoot "postman\newman\Test Subject 1.postman_environment.json"
```

For your own project, either:

- Export your Postman collection and environment to those paths.
- Change the paths in `scripts/test.ps1`.
- Update `scripts/export-postman-newman.mjs` to generate your files.

Your Postman requests should use:

```text
{{baseUrl}}
```

The test script injects it with:

```powershell
--env-var "baseUrl=$BaseUrl"
```

### 9.5 Keep or Copy npm Scripts

Required `package.json` scripts:

```json
{
  "scripts": {
    "cicd:local": "powershell -ExecutionPolicy Bypass -File ./scripts/pipeline.ps1",
    "verify:ngrok": "powershell -ExecutionPolicy Bypass -File ./scripts/verify-ngrok.ps1",
    "test:api": "powershell -ExecutionPolicy Bypass -File ./scripts/test.ps1",
    "deploy:local": "powershell -ExecutionPolicy Bypass -File ./scripts/deploy-local.ps1",
    "stop:local": "powershell -ExecutionPolicy Bypass -File ./scripts/stop-local.ps1"
  },
  "devDependencies": {
    "newman": "^6.2.2",
    "yaml": "^2.8.1"
  }
}
```

After editing `package.json`, run:

```powershell
npm install
```

### 9.6 Verify Your Own Project

Run these in order:

```powershell
npm install
```

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

```powershell
npm run test:api
```

```powershell
npm run deploy:local
```

```powershell
Invoke-RestMethod http://127.0.0.1:8080/actuator/health
```

```powershell
npm run stop:local
```

Then run everything together:

```powershell
npm run cicd:local
```

## 10. Troubleshooting

### PowerShell Blocks Scripts

Use this pattern:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

Replace `build.ps1` with the script you need.

### Port Is Busy

Use another port:

```powershell
npm run cicd:local -- -Port 8081
```

Or stop the existing deployment:

```powershell
npm run stop:local
```

### Local Health Works but ngrok Fails

Check that ngrok and the pipeline use the same port:

```text
ngrok:    http://127.0.0.1:8081
pipeline: -Port 8081
```

Check that you passed the real ngrok URL.

Wrong:

```powershell
npm run cicd:local -- -Port 8081 -NgrokUrl "https://your-url.ngrok-free.dev"
```

Correct:

```powershell
npm run cicd:local -- -Port 8081 -NgrokUrl "https://real-ngrok-url.ngrok-free.dev"
```

If ngrok returns `ERR_NGROK_3200`, the tunnel is offline. Keep the ngrok terminal open, copy the current forwarding URL, and rerun the command.

### Check Logs

Local deploy logs:

```text
.runtime/api.out.log
.runtime/api.err.log
```

Temporary test server logs:

```text
.runtime/test-server.out.log
.runtime/test-server.err.log
```

Pipeline summary:

```text
.runtime/pipeline-summary.txt
```

## 11. Quick Checklist

- Install Python, Node.js, npm, and PowerShell.
- Run `npm install`.
- Run `powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1`.
- Run `npm run test:api`.
- Run `npm run deploy:local`.
- Open `http://127.0.0.1:8080/docs`.
- Check `http://127.0.0.1:8080/actuator/health`.
- Stop with `npm run stop:local`.
- Run all phases with `npm run cicd:local`.
- For ngrok, start `ngrok http http://127.0.0.1:8080` and pass the real URL with `-NgrokUrl`.
