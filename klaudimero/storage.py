from __future__ import annotations

import json
from pathlib import Path

from .config import JOBS_DIR, EXECUTIONS_DIR, DEVICES_FILE
from .models import Job, Execution, Device


# --- Jobs ---

def save_job(job: Job) -> None:
    path = JOBS_DIR / f"{job.id}.json"
    path.write_text(job.model_dump_json(indent=2))


def load_job(job_id: str) -> Job | None:
    path = JOBS_DIR / f"{job_id}.json"
    if not path.exists():
        return None
    return Job.model_validate_json(path.read_text())


def load_all_jobs() -> list[Job]:
    jobs = []
    for path in sorted(JOBS_DIR.glob("*.json")):
        jobs.append(Job.model_validate_json(path.read_text()))
    return jobs


def delete_job(job_id: str) -> bool:
    path = JOBS_DIR / f"{job_id}.json"
    if path.exists():
        path.unlink()
        return True
    return False


# --- Executions ---

def save_execution(execution: Execution) -> None:
    job_dir = EXECUTIONS_DIR / execution.job_id
    job_dir.mkdir(parents=True, exist_ok=True)
    ts = execution.started_at.strftime("%Y%m%dT%H%M%S")
    path = job_dir / f"{ts}_{execution.id}.json"
    path.write_text(execution.model_dump_json(indent=2))


def load_execution(execution_id: str) -> Execution | None:
    for job_dir in EXECUTIONS_DIR.iterdir():
        if not job_dir.is_dir():
            continue
        for path in job_dir.glob("*.json"):
            if execution_id in path.name:
                return Execution.model_validate_json(path.read_text())
    return None


def load_executions_for_job(job_id: str, limit: int = 50) -> list[Execution]:
    job_dir = EXECUTIONS_DIR / job_id
    if not job_dir.exists():
        return []
    executions = []
    for path in sorted(job_dir.glob("*.json"), reverse=True):
        executions.append(Execution.model_validate_json(path.read_text()))
        if len(executions) >= limit:
            break
    return executions


def load_latest_execution() -> Execution | None:
    latest: Execution | None = None
    latest_path: Path | None = None
    for job_dir in EXECUTIONS_DIR.iterdir():
        if not job_dir.is_dir():
            continue
        for path in job_dir.glob("*.json"):
            if latest_path is None or path.stat().st_mtime > latest_path.stat().st_mtime:
                latest_path = path
    if latest_path:
        latest = Execution.model_validate_json(latest_path.read_text())
    return latest


# --- Devices ---

def _load_devices_raw() -> list[dict]:
    if DEVICES_FILE.exists():
        return json.loads(DEVICES_FILE.read_text())
    return []


def _save_devices_raw(devices: list[dict]) -> None:
    DEVICES_FILE.write_text(json.dumps(devices, indent=2, default=str))


def load_all_devices() -> list[Device]:
    return [Device.model_validate(d) for d in _load_devices_raw()]


def save_device(device: Device) -> None:
    devices = _load_devices_raw()
    # Replace if token already exists
    devices = [d for d in devices if d.get("token") != device.token]
    devices.append(device.model_dump())
    _save_devices_raw(devices)


def delete_device(token: str) -> bool:
    devices = _load_devices_raw()
    filtered = [d for d in devices if d.get("token") != token]
    if len(filtered) == len(devices):
        return False
    _save_devices_raw(filtered)
    return True
