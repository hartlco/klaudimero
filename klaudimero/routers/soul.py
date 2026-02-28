from __future__ import annotations

from fastapi import APIRouter
from pydantic import BaseModel

from ..config import WORKSPACE_CLAUDE_MD

router = APIRouter(prefix="/soul", tags=["soul"])


class SoulUpdate(BaseModel):
    content: str


@router.get("")
async def get_soul() -> dict:
    content = WORKSPACE_CLAUDE_MD.read_text() if WORKSPACE_CLAUDE_MD.exists() else ""
    return {"content": content}


@router.put("")
async def update_soul(data: SoulUpdate) -> dict:
    WORKSPACE_CLAUDE_MD.write_text(data.content)
    return {"content": data.content}
