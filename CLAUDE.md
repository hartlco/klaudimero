# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Klaudimero is a self-hosted cron service for Claude Code. It schedules jobs that execute `claude` CLI commands periodically, logs executions, exposes a REST API, and sends APNs push notifications.

## Quick Start

```bash
# Backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn klaudimero.main:app --host 0.0.0.0 --port 8585
```

## Project Structure

- `klaudimero/` — Python/FastAPI backend
  - `main.py` — App entry, lifespan, scheduler startup
  - `config.py` — Paths and APNs config
  - `models.py` — Pydantic models (Job, Execution, Device)
  - `storage.py` — JSON file storage in `~/.klaudimero/`
  - `executor.py` — Runs `claude -p` subprocess
  - `scheduler.py` — APScheduler integration
  - `notifications.py` — APNs push sender
  - `routers/` — FastAPI route handlers (jobs, executions, devices)
- `KlaudimeroApp/` — SwiftUI iOS app
- `Dockerfile` — Container build
- `requirements.txt` — Python dependencies

## Storage

All data stored as JSON files in `~/.klaudimero/` (jobs/, executions/, devices.json).

## API

Runs on port 8585. Key endpoints: `/jobs` (CRUD), `/jobs/{id}/trigger`, `/jobs/{id}/executions`, `/executions/{id}`, `/devices`.
