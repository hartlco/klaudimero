from __future__ import annotations

from fastapi import APIRouter, HTTPException

from ..models import Execution
from ..storage import load_execution, load_executions_for_job, load_latest_execution

router = APIRouter(tags=["executions"])


@router.get("/jobs/{job_id}/executions")
async def list_executions(job_id: str, limit: int = 50) -> list[Execution]:
    return load_executions_for_job(job_id, limit=limit)


@router.get("/executions/latest")
async def get_latest_execution() -> Execution:
    ex = load_latest_execution()
    if not ex:
        raise HTTPException(404, "No executions found")
    return ex


@router.get("/executions/{execution_id}")
async def get_execution(execution_id: str) -> Execution:
    ex = load_execution(execution_id)
    if not ex:
        raise HTTPException(404, "Execution not found")
    return ex
