# 0001. Grain and key of the sales fact

## Decision

`fct_sales_lines` holds **one row per sale or return line** of a store ticket or of a web order.
Its key, `sales_line_id`, is a hash of the source system, the document, the line and the kind
(sale or return). The fact is incremental on `loaded_at`, with `delete+insert` on that key.

## Why

- The two platforms do not share a grain. The POS exports ticket lines; the OMS exports headers,
  lines and returns. The line is the finest grain both can reach, and every datamart asked so far
  (by store and day, by product family and month) is a sum of lines.
- A return is its own row, on the day it happened, with negative quantity and amount. The POS
  already works that way; the OMS return table is turned into rows of the same shape. Netting a
  return against its sale would rewrite a day that was already reported.
- The order-level discount of the OMS is brought down to the line (pro rata, remainder on the
  largest line) so that no measure of the fact lives at another grain than the row.
- The key is the line itself, not a load sequence: when a platform exports a line again, the new
  version replaces the old one. `delete+insert` exists on both DuckDB and Snowflake.

## Set aside

- **Header grain** (one row per ticket or order): loses the product, so no sales by product family.
- **A snapshot of the dimensions** (history of stores and products): useful, not needed to show the
  migration; left as a limit in the README.
- **`merge` as the incremental strategy**: equivalent here; `delete+insert` was kept because it
  behaves the same on the two engines.

## Consequence

The incremental filter trusts `loaded_at`. A change of logic in an upstream model does not reach
rows already loaded: it needs `dbt build --full-refresh`, which CI gets for free by starting from an
empty warehouse.
