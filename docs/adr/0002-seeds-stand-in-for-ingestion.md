# 0002. Seeds stand in for ingestion

## Decision

The exports of the two platforms are CSV files written by a seeded Python generator and loaded with
`dbt seed` into their own raw schemas (`raw_us_pos`, `raw_us_oms`, `raw_reference`). The models read
them through `source()`, never `ref()`. The build is therefore two commands: `dbt seed`, then
`dbt build --selector transform`.

## Why

- The subject of the sample is what happens after landing: mapping, gaps, tests. A real extract
  tool would add accounts and infrastructure without showing any of it.
- Reading through `source()` keeps the project honest about its boundary: descriptions, freshness
  and lineage start at the platforms, as they would with a real ingestion tool, and replacing the
  seeds by real tables would not touch a single model.
- A generator, not hand-written files: the planted defects come with a manifest, and a test checks
  that the committed seeds are exactly what the generator writes.

## Set aside

- **`ref()` on the seeds**: one command instead of two, but the lineage would start at CSV files
  and the sources, their freshness and their tests would disappear.
- **A Python loader writing straight into DuckDB**: would not run on Snowflake.

## Consequence

dbt does not know that a source is fed by a seed, so the seeds must be loaded before the build.
The build then selects models and tests by type (`selectors.yml`) rather than excluding the seeds:
with `--exclude resource_type:seed`, dbt also leaves out every test that reads a seed.
The manifest of the planted defects and the mapping table are seeds too, read with `ref()`: they
belong to the project, not to a platform.
