"""Agent memory: process-scoped key-value store.

Used later by the reflection loop to persist critiques across retries.
Contains no domain knowledge by design.
"""


class Memory:
    def __init__(self) -> None:
        self._data: dict = {}

    def get(self, key: str, default=None):
        return self._data.get(key, default)

    def set(self, key: str, value) -> None:
        self._data[key] = value

    def snapshot(self) -> dict:
        return dict(self._data)

    def clear(self) -> None:
        self._data.clear()


memory = Memory()
