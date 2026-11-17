# 0001. Grain and key of the sales fact

## Decision

`fct_sales_lines` holds **one row per sale or return line** of a store ticket or of a web order.
Its key, `sales_line_id`, is a hash of the source record key (`pos|ticket|line`,
`oms|order|line`, `oms|return`). The fact is incremental on `loaded_at`, with `delete+insert` on
that key.

## Why

- The two platforms do not share a grain. The POS exports ticket lines; the OMS exports headers,
  lines and returns. The line is the finest grain both can reach, and every datamart asked so far
  (by store and day, by product family and month) is a sum of lines.
- A return is its own row, on the day it happened, with negative quantity and amount. The POS
  already works that way; the OMS return table is turned into rows of the same shape. Netting a
  return against its sale would rewrite a day that was already reported.
- The order-level discount of the OMS is brought down to the line (pro rata, remainder on the
  largest line) so that no measure of the fact lives at another grain than the row.
- The key is the source record itself, not a load sequence and not an attribute of the line: when
  a platform exports a line again, the new version replaces the old one, even when it turns a sale
  into a return. `delete+insert` exists on both DuckDB and Snowflake.
- Quarantine works both ways on the incremental path. A nightly run reads what landed since the
  last load, plus every accepted line the fact does not hold yet (a line released from quarantine
  once its reference is fixed, a line that landed with an older load time); a post-hook deletes a
  loaded line that a later export sends to quarantine.

## Set aside

- **Header grain** (one row per ticket or order): loses the product, so no sales by product family.
- **A snapshot of the dimensions** (history of stores and products): useful, not needed to show the
  migration; left as a limit in the README.
- **`merge` as the incremental strategy**: equivalent here; `delete+insert` was kept because it
  behaves the same on the two engines.

## Consequence

A line already loaded is only rewritten when it is exported again. A change of logic upstream, or a
correction of reference data that changes the values of loaded lines (a pack size, a rate, the
channel of a store), does not reach them: it needs `dbt build --full-refresh`, which CI gets for
free by starting from an empty warehouse.

Checked by hand on a simulated second night (a line released from quarantine, a loaded line sent
to quarantine by a re-export, a re-export that turns a sale into a return, two late lines): the
incremental build is green and its fact equals the one of a full refresh. This scenario is not in
CI; the unit test `incremental_run_reads_new_late_and_released_lines` is.
