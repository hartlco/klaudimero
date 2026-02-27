from __future__ import annotations

import asyncio
import logging
import re

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from apscheduler.triggers.interval import IntervalTrigger

from .models import Job
from .storage import load_all_jobs

logger = logging.getLogger("klaudimero.scheduler")

_scheduler: AsyncIOScheduler | None = None


def get_scheduler() -> AsyncIOScheduler:
    global _scheduler
    if _scheduler is None:
        _scheduler = AsyncIOScheduler()
    return _scheduler


def parse_schedule(schedule: str) -> CronTrigger | IntervalTrigger:
    """Parse a schedule string into an APScheduler trigger.

    Supports:
    - Standard cron: "0 7 * * *"
    - Interval: "every 30m", "every 2h", "every 1d"
    - Daily at: "daily at 09:00"
    """
    schedule = schedule.strip()

    # "every Xm", "every Xh", "every Xd"
    interval_match = re.match(r"every\s+(\d+)\s*(m|h|d)", schedule, re.IGNORECASE)
    if interval_match:
        amount = int(interval_match.group(1))
        unit = interval_match.group(2).lower()
        if unit == "m":
            return IntervalTrigger(minutes=amount)
        elif unit == "h":
            return IntervalTrigger(hours=amount)
        elif unit == "d":
            return IntervalTrigger(days=amount)

    # "daily at HH:MM"
    daily_match = re.match(r"daily\s+at\s+(\d{1,2}):(\d{2})", schedule, re.IGNORECASE)
    if daily_match:
        hour = int(daily_match.group(1))
        minute = int(daily_match.group(2))
        return CronTrigger(hour=hour, minute=minute)

    # Standard cron expression
    parts = schedule.split()
    if len(parts) == 5:
        return CronTrigger.from_crontab(schedule)

    raise ValueError(f"Cannot parse schedule: {schedule!r}")


def _make_job_runner(job: Job):
    """Create a sync wrapper that schedules the async run_job."""
    def runner():
        from .executor import run_job
        loop = asyncio.get_event_loop()
        loop.create_task(run_job(job))
    return runner


def add_scheduled_job(job: Job) -> None:
    scheduler = get_scheduler()
    trigger = parse_schedule(job.schedule)
    scheduler.add_job(
        _make_job_runner(job),
        trigger=trigger,
        id=job.id,
        name=job.name,
        replace_existing=True,
    )
    logger.info(f"Scheduled job {job.name!r} ({job.id}) with schedule {job.schedule!r}")


def remove_scheduled_job(job_id: str) -> None:
    scheduler = get_scheduler()
    try:
        scheduler.remove_job(job_id)
    except Exception:
        pass


def load_and_schedule_all_jobs() -> None:
    jobs = load_all_jobs()
    for job in jobs:
        if job.enabled:
            try:
                add_scheduled_job(job)
            except Exception as e:
                logger.error(f"Failed to schedule job {job.name!r}: {e}")
    logger.info(f"Loaded {len(jobs)} jobs from storage")
