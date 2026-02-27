# Klaudimero

A self-hosted cron service for [Claude Code](https://claude.ai/code). Schedules jobs that execute `claude` CLI commands on a timer, logs every execution, and sends push notifications to an iOS app.

## Architecture

- **Backend**: Python/FastAPI with APScheduler, JSON file storage
- **iOS App**: SwiftUI app for managing jobs and viewing execution logs
- **Notifications**: APNs push notifications on job events

```
┌─────────────┐       REST API        ┌──────────────────────┐
│   iOS App   │ ◄──────────────────► │   FastAPI Service     │
│  (SwiftUI)  │                       │                       │
│             │ ◄── APNs push ─────── │  APScheduler          │
└─────────────┘                       │  Claude CLI executor  │
                                      │  JSON file storage    │
                                      └──────────────────────┘
```

## Getting Started

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn klaudimero.main:app --host 0.0.0.0 --port 8585
```

## API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/jobs` | List all jobs |
| POST | `/jobs` | Create job |
| GET | `/jobs/{id}` | Get job |
| PUT | `/jobs/{id}` | Update job |
| DELETE | `/jobs/{id}` | Delete job |
| POST | `/jobs/{id}/trigger` | Trigger immediate execution |
| GET | `/jobs/{id}/executions` | List executions for job |
| GET | `/executions/{id}` | Get single execution |
| GET | `/executions/latest` | Latest execution across all jobs |
| POST | `/devices` | Register APNs device token |
| DELETE | `/devices/{token}` | Unregister device |

## Scheduling

Jobs support standard cron expressions and simple intervals:

- `0 7 * * *` — standard cron (daily at 7am)
- `every 30m` — interval
- `every 2h` — interval
- `daily at 09:00` — daily at a specific time

## Storage

All data is stored as JSON files in `~/.klaudimero/`:

```
~/.klaudimero/
├── jobs/{job_id}.json
├── executions/{job_id}/{timestamp}.json
└── devices.json
```

## iOS App

Open `KlaudimeroApp/KlaudimeroApp.xcodeproj` in Xcode. Configure the server URL in Settings (e.g. your Tailscale hostname).

## Docker

```bash
docker build -t klaudimero .
docker run -p 8585:8585 -v ~/.klaudimero:/root/.klaudimero klaudimero
```
