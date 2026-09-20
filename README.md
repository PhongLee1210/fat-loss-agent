# fat-loss-agent

Single ReAct-style agent, one LangGraph `StateGraph`, no multi-agent. Real-world
MVP: nutrition + workout tracking against actual numbers. Built to learn the
Tier-1 patterns from [`awesome-agentic-patterns`](../awesome-agentic-patterns/patterns/).

## Layout (agent template, Python conventions)

```
fat-loss-agent/
├── instructions.md                 # Managed context: domain rules live here, not in code
├── skills/
│   └── tracking/SKILL.md           # Managed skill: logging procedure
├── src/
│   ├── agent.py                    # Core agent definition (plan -> execute -> reflect graph)
│   ├── state.py                    # Graph state (TypedDict + reducers)
│   ├── config.py                   # Model factory (env-driven, OpenAI-compatible)
│   ├── instructions.py             # Loads instructions.md
│   ├── identity.py                 # Agent identity (metadata only)
│   ├── memory.py                   # Process-scoped KV store (reflection memory later)
│   ├── tools/                      # Application code
│   │   ├── __init__.py             # Tool registry
│   │   └── mcp.py                  # MCP server declarations (placeholder)
│   ├── middleware/                 # Node hooks (placeholder)
│   ├── channels/                   # Managed configuration: entry points
│   │   └── cli.py                  # CLI channel
│   ├── schedules/                  # Time-triggered runs (placeholder)
│   └── sandbox/                    # Execution boundary (placeholder)
├── evals/                          # Harbor workspace
│   ├── harbor-job.json
│   └── log-meal/                   # Task: Task.md, instruction.md, environment/, tests/
├── supabase/                       # Database (Supabase CLI)
│   ├── config.toml
│   └── migrations/                 # fitness_schema.sql: 3-layer schema
├── pyproject.toml                  # Dependencies (uv)
└── .env.example                    # Local + deploy secrets template
```

Naming convention: code modules are structural (`agent`, `state`, `memory`,
`channels`) with relative imports inside `src/`; business naming and domain
rules live only in managed context (`instructions.md`, `skills/`, `evals/`).
Import root is `src` (e.g., `from src.agent import build_agent`).

## Graph

```
START -> plan -> execute -> reflect --(not satisfied & retries < 3)--> plan
                              |                  (satisfied | budget spent)
                              +------------------------------> END
```

## Pattern -> code map

| Pattern (patterns/*.md) | Construct | Code |
|---|---|---|
| plan-then-execute-pattern.md | `StateGraph`: plan node -> execute node, frozen plan | `src/agent.py` |
| structured-output-specification.md | `.with_structured_output()` + Pydantic (next: `Plan`, `Reflection`) | `src/agent.py` slots + `src/tools/` |
| reflection.md | conditional edge back to plan, retry budget 3 | `src/agent.py` (`should_retry`) |

## Setup

```bash
uv sync
cp .env.example .env   # defaults: local Qwen via Ollama
```

Providers (all OpenAI-compatible, switch via `.env`): Ollama (default),
LM Studio, OpenAI, DeepSeek — see `.env.example`.

## Database

Schema in `supabase/migrations/`, organized in three layers:

- **Reference** (shared knowledge): `metric_types`, `foods` (per-100g) +
  `portions`, `exercises`, `mets`
- **Facts** (immutable user events, insert-only): `users`, `goals`,
  `measurements` (generic metric observations), `meal_sessions`/`meal_items`
  (macros snapshotted at logging time), `workout_sessions` +
  `strength_sets`/`cardio_logs`
- **Derived** (recomputable): `daily_targets` (formula + frozen inputs),
  `daily_summaries` view (consumed/burned/remaining)

Scalability rule: new tracked metric = 1 insert into `metric_types`; new goal
type = 1 insert into `goals`; strength/cardio structure already in place.

```bash
supabase start      # local stack (Docker)
supabase db reset   # re-apply migrations from scratch
supabase stop       # stop the stack
```

## Run

```bash
uv run fat-loss-agent "log 2 eggs and a 30 min run"
```

Status: init skeleton — nodes are offline placeholders; managed context is
wired into the CLI channel as the system message. Next: Pydantic schemas,
real tools in `tools/`, LLM-backed nodes.
