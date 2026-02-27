from __future__ import annotations

import uuid
from datetime import datetime, timezone
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _new_id() -> str:
    return str(uuid.uuid4())


# --- Job ---

class JobCreate(BaseModel):
    name: str
    prompt: str
    schedule: str
    enabled: bool = True
    max_turns: int = 50
    notify_on: list[str] = Field(default_factory=lambda: ["completed", "failed"])


class JobUpdate(BaseModel):
    name: Optional[str] = None
    prompt: Optional[str] = None
    schedule: Optional[str] = None
    enabled: Optional[bool] = None
    max_turns: Optional[int] = None
    notify_on: Optional[list[str]] = None


class Job(BaseModel):
    id: str = Field(default_factory=_new_id)
    name: str
    prompt: str
    schedule: str
    enabled: bool = True
    max_turns: int = 50
    notify_on: list[str] = Field(default_factory=lambda: ["completed", "failed"])
    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: datetime = Field(default_factory=_utcnow)


# --- Execution ---

class ExecutionStatus(str, Enum):
    running = "running"
    completed = "completed"
    failed = "failed"


class Execution(BaseModel):
    id: str = Field(default_factory=_new_id)
    job_id: str
    started_at: datetime = Field(default_factory=_utcnow)
    finished_at: Optional[datetime] = None
    status: ExecutionStatus = ExecutionStatus.running
    prompt: str
    output: str = ""
    exit_code: Optional[int] = None
    duration_seconds: Optional[float] = None


# --- Device ---

# --- Heartbeat ---

class HeartbeatConfig(BaseModel):
    enabled: bool = False
    interval_minutes: int = 30
    max_turns: int = 50


class HeartbeatConfigUpdate(BaseModel):
    enabled: Optional[bool] = None
    interval_minutes: Optional[int] = None
    max_turns: Optional[int] = None
    prompt: Optional[str] = None


class HeartbeatStatus(BaseModel):
    enabled: bool
    interval_minutes: int
    max_turns: int
    prompt: str


# --- Device ---

class DeviceRegister(BaseModel):
    token: str
    name: Optional[str] = None


class Device(BaseModel):
    token: str
    name: Optional[str] = None
    registered_at: datetime = Field(default_factory=_utcnow)


# --- Chat ---

class ChatMessage(BaseModel):
    role: str  # "user" or "assistant"
    content: str


class ChatRequest(BaseModel):
    content: str
    max_turns: int = 50


class ChatSession(BaseModel):
    id: str = Field(default_factory=_new_id)
    title: str = ""
    messages: list[ChatMessage] = []
    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: datetime = Field(default_factory=_utcnow)
