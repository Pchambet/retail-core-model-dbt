# retail-core-model-dbt

## Purpose
A public work sample for data-engineering applications: a dbt project that migrates two fictitious
local US retail platforms (a store POS and an e-commerce OMS) to a group core retail model, on
synthetic data. The point is the method: sources mapped to one model, every gap of definition or
grain written down and tested, the result reconciled with the legacy datamart. Done means a reader
can clone it, build it green in three commands and find every README number in a command output.

## Stack
dbt Core 1.12 with dbt-duckdb (local and CI); a Snowflake target written but not yet run. Python
3.13 with uv for the seeded data generator and the mapping page.

## Commands
- Install: `uv sync && uv run dbt deps`
- Build: `uv run dbt seed`, then `uv run dbt build --selector transform`
- Lint SQL: `uv run sqlfluff lint models data_tests`
- Regenerate the seeds: `uv run generate-data` · the mapping page: `uv run render-mapping`
- Docs: `uv run dbt docs generate && uv run dbt docs serve`

## Definition of done
Run all of these before saying a task is finished (work loop: ~/.claude/CLAUDE.md):
- `uv run ruff check .` and `uv run ruff format --check .` pass
- `uv run pytest -q` passes (seeds and mapping page are exactly what their scripts write)
- `uv run sqlfluff lint models data_tests` passes
- `uv run dbt seed` then `uv run dbt build --selector transform` are green, twice in a row
  (the second run takes the incremental path)
- CI (.github/workflows/ci.yml) runs the same checks on every push

## Rules
- Everything is synthetic and says so. No real company, brand, product or person; nothing from a
  client or an employer.
- A README number comes from a command that was run; what was not verified is said (Snowflake run,
  GitLab pipeline).
- A new rule on the data comes with its test, and the test is seen failing once.
- A change to the generator means regenerating the seeds and updating the README figures.
- No secret in the repository: `profiles.yml` reads Snowflake settings from the environment.
- Code, commits and file names in English; small, focused commits.
