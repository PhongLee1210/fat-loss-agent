"""Managed context loader.

The agent's domain behavior lives in ``instructions.md`` (project root),
not in code. This module only reads it.
"""

from pathlib import Path

_FILENAME = "instructions.md"


def load_instructions() -> str:
    candidates = (
        Path.cwd() / _FILENAME,
        Path(__file__).resolve().parents[2] / _FILENAME,
    )
    for candidate in candidates:
        if candidate.is_file():
            return candidate.read_text(encoding="utf-8")
    return ""
