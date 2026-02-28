from __future__ import annotations

import asyncio
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException

from ..models import Job, JobCreate, JobUpdate
from ..storage import save_job, load_job, load_all_jobs, delete_job as storage_delete_job

router = APIRouter(prefix="/jobs", tags=["jobs"])


@router.get("")
async def list_jobs() -> list[dict]:
    from ..scheduler import get_scheduler

    jobs = load_all_jobs()
    scheduler = get_scheduler()
    result = []
    for job in jobs:
        data = job.model_dump(mode="json")
        # Include next_run from the scheduler if available
        aps_job = scheduler.get_job(job.id)
        if aps_job and aps_job.next_run_time:
            data["next_run"] = aps_job.next_run_time.isoformat()
        else:
            data["next_run"] = None
        result.append(data)
    return result


@router.post("", status_code=201)
async def create_job(data: JobCreate) -> Job:
    from ..scheduler import add_scheduled_job, parse_schedule

    try:
        parse_schedule(data.schedule)
    except ValueError as e:
        raise HTTPException(400, str(e))

    job = Job(**data.model_dump())
    save_job(job)
    if job.enabled:
        add_scheduled_job(job)
    return job


@router.get("/{job_id}")
async def get_job(job_id: str) -> dict:
    from ..scheduler import get_scheduler

    job = load_job(job_id)
    if not job:
        raise HTTPException(404, "Job not found")
    data = job.model_dump(mode="json")
    scheduler = get_scheduler()
    aps_job = scheduler.get_job(job.id)
    if aps_job and aps_job.next_run_time:
        data["next_run"] = aps_job.next_run_time.isoformat()
    else:
        data["next_run"] = None
    return data


@router.put("/{job_id}")
async def update_job(job_id: str, data: JobUpdate) -> Job:
    from ..scheduler import add_scheduled_job, remove_scheduled_job

    job = load_job(job_id)
    if not job:
        raise HTTPException(404, "Job not found")

    updates = data.model_dump(exclude_unset=True)
    for key, value in updates.items():
        setattr(job, key, value)
    job.updated_at = datetime.now(timezone.utc)
    save_job(job)

    # Validate schedule if changed
    if "schedule" in updates:
        from ..scheduler import parse_schedule
        try:
            parse_schedule(job.schedule)
        except ValueError as e:
            raise HTTPException(400, str(e))

    # Re-register with scheduler
    remove_scheduled_job(job.id)
    if job.enabled:
        add_scheduled_job(job)

    return job


@router.delete("/{job_id}", status_code=204)
async def delete_job(job_id: str) -> None:
    from ..scheduler import remove_scheduled_job

    if not storage_delete_job(job_id):
        raise HTTPException(404, "Job not found")
    remove_scheduled_job(job_id)


@router.post("/{job_id}/trigger")
async def trigger_job(job_id: str) -> dict:
    from ..executor import run_job

    job = load_job(job_id)
    if not job:
        raise HTTPException(404, "Job not found")

    asyncio.get_event_loop().create_task(run_job(job))
    return {"status": "triggered", "job_id": job_id}
