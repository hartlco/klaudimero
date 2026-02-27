from __future__ import annotations

import asyncio

from fastapi import APIRouter, HTTPException

from ..config import HEARTBEAT_JOB_ID
from ..models import HeartbeatConfigUpdate, HeartbeatStatus, Execution
from ..storage import (
    load_heartbeat_config,
    save_heartbeat_config,
    load_heartbeat_prompt,
    save_heartbeat_prompt,
    load_executions_for_job,
)

router = APIRouter(prefix="/heartbeat", tags=["heartbeat"])

ALLOWED_INTERVALS = {10, 30, 60}


@router.get("")
async def get_heartbeat() -> HeartbeatStatus:
    config = load_heartbeat_config()
    prompt = load_heartbeat_prompt()
    return HeartbeatStatus(
        enabled=config.enabled,
        interval_minutes=config.interval_minutes,
        max_turns=config.max_turns,
        prompt=prompt,
    )


@router.put("")
async def update_heartbeat(data: HeartbeatConfigUpdate) -> HeartbeatStatus:
    from ..heartbeat import schedule_heartbeat, unschedule_heartbeat

    config = load_heartbeat_config()

    if data.interval_minutes is not None and data.interval_minutes not in ALLOWED_INTERVALS:
        raise HTTPException(400, f"interval_minutes must be one of {sorted(ALLOWED_INTERVALS)}")

    if data.enabled is not None:
        config.enabled = data.enabled
    if data.interval_minutes is not None:
        config.interval_minutes = data.interval_minutes
    if data.max_turns is not None:
        config.max_turns = data.max_turns

    save_heartbeat_config(config)

    if data.prompt is not None:
        save_heartbeat_prompt(data.prompt)

    # Reschedule
    unschedule_heartbeat()
    if config.enabled:
        schedule_heartbeat(config)

    prompt = load_heartbeat_prompt()
    return HeartbeatStatus(
        enabled=config.enabled,
        interval_minutes=config.interval_minutes,
        max_turns=config.max_turns,
        prompt=prompt,
    )


@router.get("/executions")
async def list_heartbeat_executions(limit: int = 50) -> list[Execution]:
    return load_executions_for_job(HEARTBEAT_JOB_ID, limit=limit)


@router.post("/trigger")
async def trigger_heartbeat() -> dict:
    from ..heartbeat import run_heartbeat

    asyncio.get_event_loop().create_task(run_heartbeat())
    return {"status": "triggered"}
