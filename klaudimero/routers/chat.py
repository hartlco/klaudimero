from __future__ import annotations

import asyncio
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, UploadFile, File
from fastapi.responses import FileResponse

from ..config import UPLOADS_DIR, WORKSPACE_DIR
from ..models import ChatSession, ChatMessage, ChatRequest
from ..storage import (
    save_chat_session,
    load_chat_session,
    load_all_chat_sessions,
    delete_chat_session as storage_delete_chat_session,
)

router = APIRouter(prefix="/chat", tags=["chat"])


@router.get("/sessions")
async def list_sessions() -> list[dict]:
    sessions = load_all_chat_sessions()
    return [
        {
            "id": s.id,
            "title": s.title,
            "source_type": s.source_type,
            "updated_at": s.updated_at.isoformat(),
        }
        for s in sessions
    ]


@router.post("/sessions", status_code=201)
async def create_session() -> ChatSession:
    session = ChatSession()
    save_chat_session(session)
    return session


@router.get("/sessions/{session_id}")
async def get_session(session_id: str) -> ChatSession:
    session = load_chat_session(session_id)
    if not session:
        raise HTTPException(404, "Session not found")
    return session


@router.delete("/sessions/{session_id}", status_code=204)
async def delete_session(session_id: str) -> None:
    if not storage_delete_chat_session(session_id):
        raise HTTPException(404, "Session not found")


@router.post("/sessions/{session_id}/upload")
async def upload_image(session_id: str, file: UploadFile = File(...)) -> dict:
    session = load_chat_session(session_id)
    if not session:
        raise HTTPException(404, "Session not found")

    filename = f"{uuid.uuid4()}_{file.filename}"
    file_path = UPLOADS_DIR / filename
    content = await file.read()
    file_path.write_bytes(content)

    return {"file_path": str(file_path), "filename": file.filename}


@router.get("/uploads/{filename}")
async def serve_upload(filename: str) -> FileResponse:
    file_path = UPLOADS_DIR / filename
    if not file_path.exists():
        raise HTTPException(404, "File not found")
    return FileResponse(file_path)


@router.post("/sessions/{session_id}/message")
async def send_message(session_id: str, data: ChatRequest) -> dict:
    session = load_chat_session(session_id)
    if not session:
        raise HTTPException(404, "Session not found")

    # Append user message
    session.messages.append(ChatMessage(role="user", content=data.content, images=data.images))

    # Auto-set title from first user message
    if not session.title:
        session.title = data.content[:50].strip()

    # Build prompt from conversation history
    prompt_parts = []
    for msg in session.messages:
        if msg.role == "user":
            text = msg.content
            for img_path in msg.images:
                text += f"\n[Attached image: {img_path} — read this file to see the image]"
            prompt_parts.append(f"User: {text}")
        else:
            prompt_parts.append(f"Assistant: {msg.content}")
    prompt_parts.append("Assistant:")
    full_prompt = "\n\n".join(prompt_parts)

    # Run claude
    cmd = [
        "claude",
        "-p",
        full_prompt,
        "--output-format", "text",
        "--max-turns", str(data.max_turns),
        "--dangerously-skip-permissions",
    ]

    try:
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            cwd=str(WORKSPACE_DIR),
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
        )
        try:
            stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=3600)
        except asyncio.TimeoutError:
            proc.kill()
            await proc.wait()
            raise HTTPException(504, "Claude timed out after 1 hour")

        if proc.returncode != 0:
            output = stdout.decode("utf-8", errors="replace") if stdout else ""
            raise HTTPException(502, f"Claude exited with code {proc.returncode}: {output[:500]}")

        response = stdout.decode("utf-8", errors="replace").strip() if stdout else ""
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(502, f"Error running Claude: {e}")

    # Append assistant response and save
    session.messages.append(ChatMessage(role="assistant", content=response))
    session.updated_at = datetime.now(timezone.utc)
    save_chat_session(session)

    return {"response": response}
