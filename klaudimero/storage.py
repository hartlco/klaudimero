from __future__ import annotations

import json
import time
from pathlib import Path

from .config import JOBS_DIR, EXECUTIONS_DIR, DEVICES_FILE, HEARTBEAT_CONFIG_FILE, HEARTBEAT_PROMPT_FILE, CHAT_SESSIONS_DIR
from .models import Job, Execution, Device, HeartbeatConfig, ChatSession


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


def cleanup_old_executions(max_age_days: int = 3) -> int:
    """Delete execution logs older than max_age_days. Returns number of files removed."""
    cutoff = time.time() - (max_age_days * 86400)
    removed = 0
    for job_dir in EXECUTIONS_DIR.iterdir():
        if not job_dir.is_dir():
            continue
        for path in job_dir.glob("*.json"):
            if path.stat().st_mtime < cutoff:
                path.unlink()
                removed += 1
        # Remove empty directories
        if job_dir.is_dir() and not any(job_dir.iterdir()):
            job_dir.rmdir()
    return removed


# --- Heartbeat ---

def load_heartbeat_config() -> HeartbeatConfig:
    if HEARTBEAT_CONFIG_FILE.exists():
        return HeartbeatConfig.model_validate_json(HEARTBEAT_CONFIG_FILE.read_text())
    return HeartbeatConfig()


def save_heartbeat_config(config: HeartbeatConfig) -> None:
    HEARTBEAT_CONFIG_FILE.write_text(config.model_dump_json(indent=2))


def load_heartbeat_prompt() -> str:
    if HEARTBEAT_PROMPT_FILE.exists():
        return HEARTBEAT_PROMPT_FILE.read_text()
    return ""


def save_heartbeat_prompt(prompt: str) -> None:
    HEARTBEAT_PROMPT_FILE.write_text(prompt)


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


# --- Chat Sessions ---

def save_chat_session(session: ChatSession) -> None:
    path = CHAT_SESSIONS_DIR / f"{session.id}.json"
    path.write_text(session.model_dump_json(indent=2))


def load_chat_session(session_id: str) -> ChatSession | None:
    path = CHAT_SESSIONS_DIR / f"{session_id}.json"
    if not path.exists():
        return None
    return ChatSession.model_validate_json(path.read_text())


def load_all_chat_sessions() -> list[ChatSession]:
    sessions = []
    for path in CHAT_SESSIONS_DIR.glob("*.json"):
        sessions.append(ChatSession.model_validate_json(path.read_text()))
    sessions.sort(key=lambda s: s.updated_at, reverse=True)
    return sessions


def delete_chat_session(session_id: str) -> bool:
    path = CHAT_SESSIONS_DIR / f"{session_id}.json"
    if path.exists():
        path.unlink()
        return True
    return False
