-- Fitness domain schema, organized in three layers:
--   1. Facts        immutable user events (insert-only)
--   2. Reference    shared world knowledge with source attribution
--   3. Derived      recomputable from layers 1+2 (targets snapshot, summary view)
-- Rule: anything in the derived layer must be rebuildable from facts + reference.

create extension if not exists pg_trgm;

-- =============================================================
-- Reference layer
-- =============================================================

create table metric_types (
    code        text primary key,
    domain      text not null check (domain in ('body', 'lifestyle', 'vitals')),
    name        text not null,
    unit        text not null,
    min_value   numeric,
    max_value   numeric
);

create table foods (
    id          uuid primary key default gen_random_uuid(),
    name        text not null,
    brand       text,
    kcal        numeric(6,2) not null check (kcal >= 0),
    protein_g   numeric(6,2) not null check (protein_g >= 0),
    carbs_g     numeric(6,2) not null check (carbs_g >= 0),
    fat_g       numeric(6,2) not null check (fat_g >= 0),
    source      text not null default 'seed',
    verified    boolean not null default false,
    created_at  timestamptz not null default now()
);
comment on table foods is 'Macros normalized per 100g';

create table portions (
    id          uuid primary key default gen_random_uuid(),
    food_id     uuid not null references foods(id) on delete cascade,
    label       text not null,
    grams       numeric(7,2) not null check (grams > 0),
    unique (food_id, label)
);

create table exercises (
    id            uuid primary key default gen_random_uuid(),
    name          text not null,
    modality      text not null check (modality in ('strength', 'cardio', 'mobility', 'sport')),
    muscle_groups text[],
    equipment     text
);

create table mets (
    exercise_id uuid not null references exercises(id) on delete cascade,
    intensity   text not null default 'general',
    met_value   numeric(4,2) not null check (met_value > 0),
    primary key (exercise_id, intensity)
);

-- =============================================================
-- Fact layer
-- =============================================================

create table users (
    id            uuid primary key default gen_random_uuid(),
    name          text,
    sex           text not null check (sex in ('male', 'female')),
    date_of_birth date not null,
    height_cm     numeric(5,1) check (height_cm > 0),
    timezone      text not null default 'UTC',
    created_at    timestamptz not null default now()
);

create table goals (
    id           uuid primary key default gen_random_uuid(),
    user_id      uuid not null references users(id) on delete cascade,
    goal_type    text not null check (goal_type in ('fat_loss', 'muscle_gain', 'strength', 'endurance', 'maintenance')),
    metric       text,
    target_value numeric,
    params       jsonb not null default '{}',
    start_date   date not null default current_date,
    target_date  date,
    status       text not null default 'active' check (status in ('active', 'achieved', 'abandoned')),
    created_at   timestamptz not null default now()
);

create table measurements (
    id          uuid primary key default gen_random_uuid(),
    user_id     uuid not null references users(id) on delete cascade,
    metric_code text not null references metric_types(code),
    value       numeric not null check (value > 0),
    measured_at timestamptz not null default now(),
    source      text not null default 'user',
    notes       text
);

create table meal_sessions (
    id         uuid primary key default gen_random_uuid(),
    user_id    uuid not null references users(id) on delete cascade,
    started_at timestamptz not null default now(),
    meal_type  text check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack')),
    notes      text
);

create table meal_items (
    id          uuid primary key default gen_random_uuid(),
    session_id  uuid not null references meal_sessions(id) on delete cascade,
    food_id     uuid references foods(id) on delete set null,
    description text not null,
    grams       numeric(7,2) not null check (grams > 0),
    kcal        numeric(7,2) not null check (kcal >= 0),
    protein_g   numeric(6,2) not null default 0 check (protein_g >= 0),
    carbs_g     numeric(6,2) not null default 0 check (carbs_g >= 0),
    fat_g       numeric(6,2) not null default 0 check (fat_g >= 0),
    resolution  text not null check (resolution in ('user_provided', 'estimated')),
    assumption  text
);
comment on column meal_items.kcal is 'Snapshot at logging time; never recomputed from foods';

create table workout_sessions (
    id         uuid primary key default gen_random_uuid(),
    user_id    uuid not null references users(id) on delete cascade,
    started_at timestamptz not null default now(),
    ended_at   timestamptz,
    title      text,
    notes      text
);

create table strength_sets (
    id          uuid primary key default gen_random_uuid(),
    session_id  uuid not null references workout_sessions(id) on delete cascade,
    exercise_id uuid not null references exercises(id),
    set_no      int not null check (set_no > 0),
    reps        int not null check (reps > 0),
    weight_kg   numeric(6,2) not null default 0 check (weight_kg >= 0),
    rpe         numeric(3,1) check (rpe between 1 and 10)
);

create table cardio_logs (
    id          uuid primary key default gen_random_uuid(),
    session_id  uuid not null references workout_sessions(id) on delete cascade,
    exercise_id uuid not null references exercises(id),
    duration_s  int not null check (duration_s > 0),
    distance_m  numeric(8,1) check (distance_m > 0),
    avg_hr      int check (avg_hr between 30 and 250),
    kcal_est    numeric(7,2) check (kcal_est >= 0)
);

-- =============================================================
-- Derived layer
-- =============================================================

create table daily_targets (
    user_id          uuid not null references users(id) on delete cascade,
    goal_id          uuid not null references goals(id),
    for_date         date not null,
    bmr              numeric(7,2) not null check (bmr > 0),
    tdee             numeric(7,2) not null check (tdee > 0),
    kcal_target      numeric(7,2) not null,
    protein_target_g numeric(6,2) not null check (protein_target_g >= 0),
    formula_used     text not null,
    inputs           jsonb not null,
    created_at       timestamptz not null default now(),
    primary key (user_id, for_date)
);
comment on column daily_targets.inputs is 'Formula inputs frozen at compute time (weight, age, activity) for audit';

create view daily_summaries as
select
    t.user_id,
    t.for_date,
    t.kcal_target,
    t.protein_target_g,
    coalesce(n.kcal, 0)        as kcal_consumed,
    coalesce(n.protein_g, 0)   as protein_consumed,
    coalesce(n.carbs_g, 0)     as carbs_consumed,
    coalesce(n.fat_g, 0)       as fat_consumed,
    coalesce(e.kcal_burned, 0) as kcal_burned,
    t.kcal_target - coalesce(n.kcal, 0) + coalesce(e.kcal_burned, 0) as kcal_remaining
from daily_targets t
left join (
    select ms.user_id,
           (ms.started_at at time zone u.timezone)::date as for_date,
           sum(mi.kcal)      as kcal,
           sum(mi.protein_g) as protein_g,
           sum(mi.carbs_g)   as carbs_g,
           sum(mi.fat_g)     as fat_g
    from meal_sessions ms
    join users u on u.id = ms.user_id
    join meal_items mi on mi.session_id = ms.id
    group by ms.user_id, (ms.started_at at time zone u.timezone)::date
) n on n.user_id = t.user_id and n.for_date = t.for_date
left join (
    select ws.user_id,
           (ws.started_at at time zone u.timezone)::date as for_date,
           sum(cl.kcal_est) as kcal_burned
    from workout_sessions ws
    join users u on u.id = ws.user_id
    join cardio_logs cl on cl.session_id = ws.id
    group by ws.user_id, (ws.started_at at time zone u.timezone)::date
) e on e.user_id = t.user_id and e.for_date = t.for_date;

-- =============================================================
-- Indexes
-- =============================================================

create index idx_measurements_user_metric_time on measurements (user_id, metric_code, measured_at desc);
create index idx_goals_user_status on goals (user_id, status);
create index idx_meal_sessions_user_time on meal_sessions (user_id, started_at desc);
create index idx_meal_items_session on meal_items (session_id);
create index idx_workout_sessions_user_time on workout_sessions (user_id, started_at desc);
create index idx_strength_sets_session on strength_sets (session_id);
create index idx_cardio_logs_session on cardio_logs (session_id);
create index idx_foods_name_trgm on foods using gin (name gin_trgm_ops);
create index idx_exercises_name_trgm on exercises using gin (name gin_trgm_ops);
