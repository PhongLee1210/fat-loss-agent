"""Tool registry (application code).

Domain behaviors are defined in managed context (skills/, instructions.md)
and implemented as deterministic functions registered here.
"""

from .mcp import mcp_servers

tools: list = []
tools_by_name: dict = {tool.name: tool for tool in tools}

__all__ = ["tools", "tools_by_name", "mcp_servers"]
