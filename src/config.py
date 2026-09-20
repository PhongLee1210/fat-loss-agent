"""LLM configuration.

All supported providers expose OpenAI-compatible APIs, so a single
ChatOpenAI client covers them via environment variables:

| Provider     | LLM_BASE_URL                       | LLM_MODEL        |
|--------------|------------------------------------|------------------|
| Ollama (local Qwen, default) | http://localhost:11434/v1 | qwen3:8b |
| LM Studio (local Qwen)       | http://localhost:1234/v1   | qwen3-8b |
| OpenAI        | https://api.openai.com/v1          | gpt-4o-mini      |
| DeepSeek      | https://api.deepseek.com/v1        | deepseek-chat    |
"""

import os

from dotenv import load_dotenv
from langchain_openai import ChatOpenAI

load_dotenv()

DEFAULT_BASE_URL = "http://localhost:11434/v1"
DEFAULT_MODEL = "qwen3:8b"
DEFAULT_API_KEY = "ollama"


def get_model() -> ChatOpenAI:
    return ChatOpenAI(
        model=os.getenv("LLM_MODEL", DEFAULT_MODEL),
        base_url=os.getenv("LLM_BASE_URL", DEFAULT_BASE_URL),
        api_key=os.getenv("LLM_API_KEY", DEFAULT_API_KEY),
        temperature=0,
    )
