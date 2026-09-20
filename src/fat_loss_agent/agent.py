"""Core agent definition (single StateGraph, plan -> execute -> reflect).

Pattern mapping (Tier 1):

- plan-then-execute-pattern.md: ``plan_node`` commits to a frozen step list
  before any tool output is seen; ``execute_node`` runs that exact sequence
  (ReAct-style tool loop).
- structured-output-specification.md: ``plan_node`` will use
  ``model.with_structured_output(schema)``; tools return validated results.
- reflection.md: ``reflect_node`` critiques results; ``should_retry`` loops
  back to plan with the critique while retry budget remains.

Nodes are offline placeholders so topology is runnable without an LLM.
Domain behavior comes from managed context (instructions.md, skills/),
never from this module.
"""

from typing import Literal

from langgraph.graph import END, START, StateGraph

from fat_loss_agent.state import AgentState

MAX_RETRIES = 3


def plan_node(state: AgentState) -> dict:
    """Produce the frozen step list before execution."""
    plan = ["analyze request", "execute tools", "summarize outcome"]
    return {"plan": plan, "retries": state.get("retries", 0)}


def execute_node(state: AgentState) -> dict:
    """Execute the frozen plan step by step (tool loop goes here)."""
    past_steps = [(step, "pending") for step in state.get("plan", [])]
    return {"past_steps": past_steps}


def reflect_node(state: AgentState) -> dict:
    """Critique results against the rubric (structured output goes here)."""
    satisfied = bool(state.get("past_steps"))
    return {
        "satisfied": satisfied,
        "reflection": "all steps produced results",
        "retries": state.get("retries", 0) + 1,
    }


def should_retry(state: AgentState) -> Literal["plan", "__end__"]:
    """Loop back to plan on failure while retry budget remains."""
    if not state.get("satisfied") and state.get("retries", 0) < MAX_RETRIES:
        return "plan"
    return END


def build_agent():
    builder = StateGraph(AgentState)
    builder.add_node("plan", plan_node)
    builder.add_node("execute", execute_node)
    builder.add_node("reflect", reflect_node)
    builder.add_edge(START, "plan")
    builder.add_edge("plan", "execute")
    builder.add_edge("execute", "reflect")
    builder.add_conditional_edges("reflect", should_retry, ["plan", END])
    return builder.compile()
