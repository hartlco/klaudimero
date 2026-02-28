from __future__ import annotations

import logging
from importlib import resources

from .config import WORKSPACE_CLAUDE_MD

logger = logging.getLogger("klaudimero.soul")


def ensure_soul_prompt() -> None:
    """Create workspace CLAUDE.md with default content if it doesn't exist."""
    if not WORKSPACE_CLAUDE_MD.exists():
        default = resources.files("klaudimero.defaults").joinpath("CLAUDE.md").read_text()
        WORKSPACE_CLAUDE_MD.write_text(default)
        logger.info("Created default workspace CLAUDE.md")
