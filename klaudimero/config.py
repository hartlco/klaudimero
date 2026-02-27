import json
import os
from pathlib import Path


BASE_DIR = Path(os.path.expanduser("~/.klaudimero"))
JOBS_DIR = BASE_DIR / "jobs"
EXECUTIONS_DIR = BASE_DIR / "executions"
DEVICES_FILE = BASE_DIR / "devices.json"
APNS_CONFIG_FILE = BASE_DIR / "apns_config.json"
HEARTBEAT_CONFIG_FILE = BASE_DIR / "heartbeat_config.json"
HEARTBEAT_PROMPT_FILE = BASE_DIR / "HEARTBEAT.md"
HEARTBEAT_JOB_ID = "__heartbeat__"
CHAT_SESSIONS_DIR = BASE_DIR / "chat_sessions"

# Ensure directories exist
JOBS_DIR.mkdir(parents=True, exist_ok=True)
EXECUTIONS_DIR.mkdir(parents=True, exist_ok=True)
CHAT_SESSIONS_DIR.mkdir(parents=True, exist_ok=True)


def load_apns_config() -> dict | None:
    if APNS_CONFIG_FILE.exists():
        return json.loads(APNS_CONFIG_FILE.read_text())
    return None
