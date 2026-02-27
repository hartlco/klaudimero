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
    cleanup_old_executions,
    load_heartbeat_config,
    load_heartbeat_prompt,
    save_heartbeat_prompt,
    save_execution,
)

logger = logging.getLogger("klaudimero.heartbeat")

_heartbeat_lock = asyncio.Lock()

DEFAULT_HEARTBEAT_PROMPT = """\
You are the Klaudimero heartbeat agent. The user's timezone is Europe/Berlin.

Rules:
- If it is between 22:00 and 08:00 in the user's timezone, skip all tasks and go straight to the status line.
- Do not repeatedly notify about the same thing. Check recent heartbeat executions first: curl -s http://localhost:8585/heartbeat/executions?limit=5
- Only notify about things the user needs to know or act on. Routine checks passing is NOT worth notifying.

Tasks:
- Verify Klaudimero API is responding: curl -s http://localhost:8585/
- Verify scheduled jobs are loaded: curl -s http://localhost:8585/jobs
"""

HEARTBEAT_SUFFIX = """
---
IMPORTANT — OUTPUT FORMAT (do not ignore):
Your ENTIRE response must end with a status line on its own line.
If there is nothing for the user to act on: end with exactly "STATUS:OK"
If there is something the user should know: end with exactly "STATUS:NOTIFY"
Everything before the status line will be sent as a push notification if STATUS:NOTIFY.
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
        # Clean up execution logs older than 3 days
        removed = cleanup_old_executions(max_age_days=3)
        if removed:
            logger.info(f"Cleaned up {removed} old execution logs")

        user_prompt = load_heartbeat_prompt()
        full_prompt = user_prompt + HEARTBEAT_SUFFIX
        config = load_heartbeat_config()

        execution = Execution(
            job_id=HEARTBEAT_JOB_ID,
            prompt=user_prompt,
            status=ExecutionStatus.running,
        )
        save_execution(execution)

        start = time.monotonic()

        try:
            cmd = [
                "claude",
                "-p",
                full_prompt,
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

        # Parse status code from output and strip it
        output = execution.output.strip()
        should_notify = False
        if execution.status == ExecutionStatus.failed:
            should_notify = True
        elif output.endswith("STATUS:NOTIFY"):
            output = output[: -len("STATUS:NOTIFY")].strip()
            should_notify = True
        elif output.endswith("STATUS:OK"):
            output = output[: -len("STATUS:OK")].strip()

        execution.output = output
        save_execution(execution)

        if should_notify:
            event = "completed" if execution.status != ExecutionStatus.failed else "failed"
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
