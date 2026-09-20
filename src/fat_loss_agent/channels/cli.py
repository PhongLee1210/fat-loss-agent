"""CLI channel: invoke the agent from the command line."""

import sys

from langchain.messages import HumanMessage, SystemMessage

from fat_loss_agent.agent import build_agent
from fat_loss_agent.instructions import load_instructions


def main() -> None:
    prompt = " ".join(sys.argv[1:]) or "hello"
    agent = build_agent()
    messages = []
    instructions = load_instructions()
    if instructions:
        messages.append(SystemMessage(content=instructions))
    messages.append(HumanMessage(content=prompt))
    result = agent.invoke({"messages": messages})
    print(f"\nsatisfied: {result['satisfied']} | retries: {result['retries']}")
    print(f"steps: {len(result['past_steps'])}")
