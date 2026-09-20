"""Agent identity: who the agent is, independent of any business logic."""

IDENTITY: dict = {
    "name": "fat-loss-agent",
    "version": "0.1.0",
    "principal": "local-user",
}


def get_identity() -> dict:
    return dict(IDENTITY)
