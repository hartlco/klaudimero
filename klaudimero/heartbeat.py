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

IMPORTANT: Your response determines whether the user gets a push notification.
- If you respond with exactly "OK", NO push is sent. This is the default.
- Any other response WILL be sent as a push notification to the user's phone.

Rules:
- Only respond with something other than "OK" if there is something the user needs to know or act on.
- Routine status checks passing is NOT worth notifying about.
- If it is between 22:00 and 08:00 in the user's timezone, always respond "OK". Do not disturb nighttime.
- Do not repeatedly notify about the same thing. If you already reported something in a recent execution, do not mention it again unless the situation has changed. Check recent heartbeat executions: curl -s http://localhost:8585/heartbeat/executions?limit=5

Tasks:
- Verify Klaudimero API is responding: curl -s http://localhost:8585/
- Verify scheduled jobs are loaded: curl -s http://localhost:8585/jobs
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

        # Only send push if failed or output has something to report
        if execution.status == ExecutionStatus.failed:
            await notify_heartbeat_event(execution, "failed")
        elif execution.output.strip().upper() != "OK":
            await notify_heartbeat_event(execution, "completed")

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
