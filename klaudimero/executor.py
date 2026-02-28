from __future__ import annotations

import asyncio
import os
import time
from datetime import datetime, timezone

from .models import ChatMessage, ChatSession, Execution, ExecutionStatus, Job
from .storage import load_chat_session, save_chat_session, save_execution, save_job


async def run_job(job: Job) -> Execution:
    from .notifications import notify_job_event

    execution = Execution(
        job_id=job.id,
        prompt=job.prompt,
        status=ExecutionStatus.running,
    )
    save_execution(execution)

    if "started" in job.notify_on:
        await notify_job_event(job, execution, "started")

    start = time.monotonic()

    try:
        cmd = [
            "claude",
            "-p",
            job.prompt,
            "--output-format", "text",
            "--max-turns", str(job.max_turns),
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
            execution.output = "Execution timed out after 1 hour"
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

    # Append output to job's chat thread
    _append_to_job_thread(job, execution)

    event = "completed" if execution.status == ExecutionStatus.completed else "failed"
    if event in job.notify_on:
        await notify_job_event(job, execution, event)

    return execution


def _append_to_job_thread(job: Job, execution: Execution) -> None:
    """Create or load the job's chat session and append the execution output."""
    session = None
    if job.chat_session_id:
        session = load_chat_session(job.chat_session_id)

    if not session:
        session = ChatSession(
            title=job.name,
            source_type="job",
            source_id=job.id,
            messages=[ChatMessage(role="user", content=job.prompt)],
        )
        job.chat_session_id = session.id
        save_job(job)

    session.messages.append(ChatMessage(role="assistant", content=execution.output))
    session.updated_at = datetime.now(timezone.utc)
    save_chat_session(session)
