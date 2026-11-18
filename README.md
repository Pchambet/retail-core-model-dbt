# retail-core-model-dbt

A dbt project that migrates two local sales platforms to one core retail model. Every difference of
definition between the sources is written down and tested, no line is lost on the way, and the new
numbers match the old ones to the cent.

[![CI](https://github.com/Pchambet/retail-core-model-dbt/actions/workflows/ci.yml/badge.svg)](https://github.com/Pchambet/retail-core-model-dbt/actions/workflows/ci.yml)
![dbt Core 1.12](https://img.shields.io/badge/dbt%20Core-1.12-ff694b)
![DuckDB](https://img.shields.io/badge/runs%20on-DuckDB-0d9488)
[![License: MIT](https://img.shields.io/badge/license-MIT-64748b)](LICENSE)

A work sample on synthetic data (a fictitious house, « Maison Démo »). It runs on DuckDB; it has
**not run on Snowflake yet**.
**[Browse the models, the tests and the lineage](https://pchambet.github.io/retail-core-model-dbt/)**.

## What to take from it

| Question | Answer |
|---|---|
| Does every line arrive? | 3,509 lines exported: 3,489 loaded, 20 quarantined with a reason, **0 lost** |
| Does it catch bad data? | 24 defects planted on purpose: **24 found, nothing else flagged** |
| Do the new numbers match the old ones? | USD 2,698,208.42 of legacy sales explained **to the cent**, over 171 store days |
| Can the tests fail? | 94 data tests and 6 unit tests; 7 protections removed one at a time, **the build failed 7 times** |

## What it brings

The data is synthetic, so there is no business gain to claim. What the project shows is what this
way of working gives a migration:

- **Trust on the first day.** The business compares the new dashboard with the old one. Here the
  difference is explained line by line: `legacy = core + duplicates dropped + lines quarantined`.
- **No silent loss.** A line ends in the fact table or in a quarantine table with its reason. A test
  fails if one disappears between the export and the core model.
- **Definitions that do not live in someone's head.** Nine gaps between the sources (tax, business
  day, returns, discount, unit, product code, currency, re-exports, shipping) each have a written
  rule and a test that fails if the rule is removed.
- **A nightly run that can be replayed.** The fact is incremental: a line exported twice replaces
  its earlier version instead of doubling.
- **A project the next person can read.** Every model and every mart column is described, the
  lineage goes down to the dashboard, and the mapping is written column by column.

## Strengths

- **Measured against a known answer.** The planted defects have a manifest; a test compares it with
  what the pipeline flags, record by record, in both directions.
- **The tests were tested.** Each of seven protections was removed alone and the build failed each
  time ([the list](docs/technical_notes.md#seven-protections-broken-on-purpose)).
- **The tests found a real bug.** The line count failed on the first build: two web orders placed
  just after midnight UTC were dropped by a join without a word. They are now handled by name.
- **Reproducible.** Three commands, a fixed seed, and a CI that builds everything twice on every
  push (the second run takes the incremental path).
- **It says what it did not do.** See the next two sections.

## Weaknesses

- **Never run on Snowflake.** The target is written and parses with the Snowflake adapter. Two
  points stay open until a first run: a time zone read from a column, and a possible one-cent move
  in the discount split.
- **Small.** A few thousand lines. It shows nothing about speed, cost or clustering at real volume.
- **I planted the defects myself.** Real sources are dirtier and fail in ways nobody listed first.
- **The second-night scenario was checked by hand**, not in CI.
- **The GitLab pipeline is written but has not run on GitLab.** CI runs on GitHub Actions.

## Limits

Left out on purpose, to keep the sample readable:

- **No ingestion and no scheduler.** CSV seeds stand in for the exports of the two platforms.
- **Two sources, one region, one currency in.** The core model is a plausible one, not a real
  group's.
- **No history in the dimensions** (no slowly changing dimensions).
- **A correction of the reference data** (a pack size, a rate) needs a full refresh to reach lines
  already loaded.
- **The quarantine rules were decided alone.** A real migration agrees them with the business teams.

## What I would do next

1. Run it on Snowflake, close the two open points, and add that build to the CI.
2. Run the GitLab pipeline on GitLab.
3. Turn the second-night scenario into an automated test.
4. Replace the seeds with a real extract-and-load step and schedule the nightly run.
5. Keep the history of the dimensions with dbt snapshots.
6. Generate millions of lines, measure build time and cost, then choose clustering from the numbers.
7. Make source freshness a gate, and alert when the quarantine grows.

## How it works

```mermaid
flowchart LR
    subgraph local["Local US platforms (synthetic)"]
        pos["us_pos<br/>store POS, ticket lines"]
        oms["us_oms<br/>orders, lines, returns"]
    end
    ref["reference<br/>stores, products, FX,<br/>calendar, product x-ref"]

    pos --> stg["staging<br/>rename, type,<br/>tax restated"]
    oms --> stg
    ref --> stg

    stg --> int["intermediate<br/>discount allocation, union,<br/>checks against the reference"]

    int --> fct["fct_sales_lines<br/>+ dim_store, dim_product,<br/>dim_date, dim_channel"]
    int --> qua["audit_quarantined_lines<br/>audit_data_defects"]

    fct --> marts["mart_daily_store_sales<br/>mart_monthly_metier_sales"]
    fct --> parity["audit_migration_parity"]
    legacy["legacy daily datamart"] --> parity
    marts --> bi(["Power BI dashboard<br/>(exposure)"])
```

The nine gaps, the rule that settles each one and the test that guards it:

| Gap | Store POS | E-commerce OMS | Rule of the core model | Guarded by |
|---|---|---|---|---|
| Sales tax | Amounts include US sales tax | Amounts exclude tax | Net amounts exclude tax; the POS tax is kept in its own column | `assert_migration_parity_has_no_unexplained_difference` |
| Business day | Local time of the store | UTC | The store-local day; an order placed at 03:30 UTC belongs to the previous day in New York. 159 web sale lines change day | unit test `web_order_belongs_to_the_local_business_day` (both sides of the end of daylight saving time) |
| Returns | A negative line of a ticket | A separate table, on its own date | One row per return, negative quantity and amount, on the day it happened | `fct_sales_lines_sign_follows_line_kind` |
| Discount grain | On the line | On the order header (69 orders) | Spread over the lines pro rata, the rounding remainder on the largest line | unit test `order_discount_is_spread_to_the_cent`, `assert_order_discount_fully_allocated` |
| Unit of quantity | Sales units: a box of six plates is 1 | Mostly pieces | Pieces, through the cross-reference (`pieces_per_sales_unit`). 354 loaded lines change quantity | unit test `boxes_become_pieces_and_doubtful_codes_are_not_guessed` |
| Product code | Local POS code | Local web SKU | Group SKU through a cross-reference; a code mapped to two SKUs is not guessed, the same mapping written twice fails the build | same unit test, `relationships` to `dim_product`, planted-defects test, key of the cross-reference |
| Currency | USD | USD | USD kept, EUR added at the latest fixing on or before the business day (1,202 lines use an earlier fixing, weekends) | unit test `weekend_takes_fridays_fixing_and_no_rate_is_guessed`, `assert_datamarts_reconcile_with_fact` |
| Re-exports | The same line can arrive twice | n/a | The latest export wins; older copies are listed as defects | unit test `latest_export_of_a_pos_line_wins`, `unique` on `record_key`, parity test |
| Shipping fee | n/a | On the order header | Not merchandise: left out of net sales | header check in `int_oms__order_lines_allocated` |

The column-by-column version is the [source-to-target mapping](docs/source_to_target.md).

## Run it

Requires [uv](https://docs.astral.sh/uv/), nothing else:

```bash
uv sync && uv run dbt deps
uv run dbt seed                                   # land the synthetic exports
uv run dbt build --selector transform             # 26 models, 94 data tests, 6 unit tests
```

Then `uv run dbt docs generate && uv run dbt docs serve` for the documentation and the lineage.

## Go deeper

- [Technical notes](docs/technical_notes.md): what is simulated, the defects and the reconciliation
  table by table, how the project is built, the Snowflake target, what was verified and what was not.
- Decisions: [grain of the fact](docs/adr/0001-grain-of-the-sales-fact.md),
  [seeds as ingestion](docs/adr/0002-seeds-stand-in-for-ingestion.md),
  [tax and currency](docs/adr/0003-tax-and-currency-convention.md).

## About

Built by Pierre Chambet with Claude Code, to show how he would approach the migration of local data
platforms to a core model. It is not a product. Licence: [MIT](LICENSE).
