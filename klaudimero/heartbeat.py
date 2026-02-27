from __future__ import annotations

import asyncio
import logging
import os
import time
from datetime import datetime, timezone

from apscheduler.triggers.interval import IntervalTrigger

from .config import HEARTBEAT_JOB_ID
from .models import Execution, ExecutionStatus, HeartbeatConfig
from .storage import (
    load_heartbeat_config,
    load_heartbeat_prompt,
    save_heartbeat_prompt,
    save_execution,
)

logger = logging.getLogger("klaudimero.heartbeat")

_heartbeat_lock = asyncio.Lock()

DEFAULT_HEARTBEAT_PROMPT = """\
You are a workspace heartbeat agent. Your job is to periodically review the workspace and help keep things tidy.

Instructions:
1. Read ~/CLAUDE.md to understand the workspace and available projects.
2. Pick one or two projects and do a quick review — look for obvious issues, outdated TODOs, broken configs, etc.
3. If you find small, safe fixes (typos, stale comments, minor cleanups), go ahead and fix them.
4. For bigger discoveries or suggestions, send a push notification using:
   cd ~/code/klaudimero && source .venv/bin/activate && python3 ~/clawd/tools/notify.py "Heartbeat" "Description of finding"
5. Keep your output concise — summarize what you checked and any actions taken.
"""


def ensure_heartbeat_prompt() -> None:
    """Create HEARTBEAT.md with default prompt if it doesn't exist."""
    prompt = load_heartbeat_prompt()
    if not prompt:
        save_heartbeat_prompt(DEFAULT_HEARTBEAT_PROMPT)
        logger.info("Created default HEARTBEAT.md")


async def run_heartbeat() -> Execution:
    """Run a heartbeat execution. Uses a lock to prevent concurrent runs."""
    from .notifications import notify_heartbeat_event

    async with _heartbeat_lock:
        prompt = load_heartbeat_prompt()
        config = load_heartbeat_config()

        execution = Execution(
            job_id=HEARTBEAT_JOB_ID,
            prompt=prompt,
            status=ExecutionStatus.running,
        )
        save_execution(execution)

        start = time.monotonic()

        try:
            cmd = [
                "claude",
                "-p",
                prompt,
                "--output-format", "text",
                "--max-turns", str(config.max_turns),
            ]

            proc = await asyncio.create_subprocess_exec(
                *cmd,
                cwd=os.path.expanduser("~"),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
            )

            try:
                stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=3600)
            except asyncio.TimeoutError:
                proc.kill()
                await proc.wait()
                execution.status = ExecutionStatus.failed
                execution.output = "Heartbeat timed out after 1 hour"
                execution.exit_code = -1
            else:
                execution.output = stdout.decode("utf-8", errors="replace") if stdout else ""
                execution.exit_code = proc.returncode
                execution.status = (
                    ExecutionStatus.completed if proc.returncode == 0 else ExecutionStatus.failed
                )
        except Exception as e:
            execution.status = ExecutionStatus.failed
            execution.output = f"Error launching process: {e}"
            execution.exit_code = -1

        elapsed = time.monotonic() - start
        execution.duration_seconds = round(elapsed, 2)
        execution.finished_at = datetime.now(timezone.utc)
        save_execution(execution)

        event = "completed" if execution.status == ExecutionStatus.completed else "failed"
        await notify_heartbeat_event(execution, event)

        return execution


def schedule_heartbeat(config: HeartbeatConfig) -> None:
    """Add heartbeat to the scheduler with an interval trigger."""
    from .scheduler import get_scheduler

    scheduler = get_scheduler()
    trigger = IntervalTrigger(minutes=config.interval_minutes)

    async def runner():
        await run_heartbeat()

    scheduler.add_job(
        runner,
        trigger=trigger,
        id=HEARTBEAT_JOB_ID,
        name="Heartbeat",
        replace_existing=True,
    )
    logger.info(f"Scheduled heartbeat every {config.interval_minutes} minutes")


def unschedule_heartbeat() -> None:
    """Remove heartbeat from the scheduler."""
    from .scheduler import get_scheduler

    scheduler = get_scheduler()
    try:
        scheduler.remove_job(HEARTBEAT_JOB_ID)
        logger.info("Unscheduled heartbeat")
    except Exception:
        pass
