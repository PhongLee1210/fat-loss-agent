"""Graph state shared by all nodes.

Mirrors the plan-then-execute + reflection patterns:

- ``messages``: conversation history (appended via add_messages reducer)
- ``plan``: frozen step list produced by the plan node
- ``past_steps``: (step, result) pairs accumulated by the execute node
- ``reflection``: critique text produced by the reflect node
- ``satisfied``: rubric verdict that drives the conditional edge
- ``retries``: reflection loop budget (reflection.md: keep it small, 2-3)
"""

import operator
from typing import Annotated

from langchain.messages import AnyMessage
from langgraph.graph import add_messages
from typing_extensions import TypedDict


class AgentState(TypedDict):
    messages: Annotated[list[AnyMessage], add_messages]
    plan: list[str]
    past_steps: Annotated[list[tuple[str, str]], operator.add]
    reflection: str
    satisfied: bool
    retries: int
