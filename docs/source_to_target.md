# Source-to-target mapping of `fct_sales_lines`

Generated from [`seeds/meta/source_to_target.csv`](../seeds/meta/source_to_target.csv) by
`uv run render-mapping`; do not edit by hand. A dbt data test fails when a column of the fact has no
row here or when a row names a column that does not exist.

| Target column | From the POS (`pos_sales_lines`) | From the OMS (`oms_orders`, `oms_order_lines`, `oms_returns`) | Rule |
|---|---|---|---|
| `sales_line_id` | ticket_no, line_no | order_id, line_id or return_id | Hash of the source record key, so that a line exported again keeps its key |
| `source_record_key` | ticket_no, line_no | order_id, line_id or return_id | Readable key kept for traceability: pos|ticket|line, oms|order|line, oms|return |
| `source_system` | constant pos | constant oms | Platform of origin |
| `document_id` | ticket_no | order_id | A return of the OMS keeps the order it refers to |
| `line_kind` | sign of qty | table of origin | POS: negative quantity is a return. OMS: oms_order_lines are sales, oms_returns are returns |
| `business_date` | sold_at_local | ordered_at_utc or returned_at_utc | Store-local day. POS times are already local; OMS times are UTC and converted to the e-commerce store's time zone |
| `occurred_at_local` | sold_at_local | ordered_at_utc or returned_at_utc | Same conversion as business_date |
| `group_store_id` | store_code | constant WEB | Looked up in the group's store reference; an unknown store quarantines the line |
| `channel_code` | store_code | constant WEB | Channel of the store in the group reference |
| `group_sku` | item_code | sku_local | Looked up in the product cross-reference; an unmapped or ambiguous local code quarantines the line |
| `quantity_pieces` | qty | quantity or quantity_returned | Sales units times pieces per sales unit (a box of six plates is 6 pieces); negative for a return |
| `net_amount_usd` | amount_incl_tax_usd - tax_amount_usd | line_amount_usd - share of order_discount_usd or -refund_amount_usd | Without sales tax, after discounts. The OMS order discount is spread over the lines pro rata, remainder on the largest line. Shipping is not merchandise and is left out |
| `tax_amount_usd` | tax_amount_usd | (none) | The OMS exports amounts without tax: empty |
| `fx_rate_date` | sold_at_local | ordered_at_utc or returned_at_utc | Latest USD to EUR fixing on or before the business day |
| `fx_rate_usd_to_eur` | (reference) | (reference) | Rate of that fixing |
| `net_amount_eur` | derived | derived | net_amount_usd times the rate, rounded to the cent line by line |
| `loaded_at` | loaded_at | loaded_at | Landing time of the source row; drives the incremental load |
