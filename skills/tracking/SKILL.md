# Skill: tracking

Log meals and workouts against daily calorie/macro targets computed from
user stats.

## When to use

- The user reports eating something ("2 eggs and toast for breakfast")
- The user reports activity ("30 min run")
- The user asks for today's status or remaining budget

## Procedure

1. Extract items: food/amounts or activity/duration.
2. Resolve numbers via tools only (user-provided > tool estimate; never guess).
3. Call the logging tool once per item with explicit macros or duration.
4. Read back the daily summary and report consumed / burned / remaining.

## Estimation fallback

When the user cannot supply macros, the estimation tool may use standard
per-100g reference values and must state the assumption in its result.
