{#
    Every line resolved against the group reference, with the one reason that keeps it out of the
    core model, if any. This is the only place where a line is accepted or quarantined.
#}

with sales_lines as (
    select * from {{ ref('int_sales_lines__unioned') }}
),

stores as (
    select * from {{ ref('stg_reference__stores') }}
),

products as (
    select * from {{ ref('int_product_xref__resolved') }}
),

fx_rates as (
    select * from {{ ref('int_fx__daily_rates') }}
)

select
    sales_lines.source_system,
    sales_lines.document_id,
    sales_lines.source_line_id,
    sales_lines.line_kind,
    sales_lines.record_key,
    sales_lines.store_code,
    stores.group_store_id,
    stores.channel_code,
    sales_lines.occurred_at_local,
    sales_lines.business_date,
    sales_lines.local_product_code,
    products.group_sku,
    sales_lines.quantity_sales_units,
    sales_lines.quantity_sales_units * products.pieces_per_sales_unit as quantity_pieces,
    sales_lines.net_amount_usd,
    sales_lines.tax_amount_usd,
    fx_rates.rate_date as fx_rate_date,
    fx_rates.usd_to_eur as fx_rate_usd_to_eur,
    sales_lines.loaded_at,
    case
        when sales_lines.is_header_mismatch then 'HEADER_LINES_MISMATCH'
        when sales_lines.is_orphan_return then 'ORPHAN_RETURN'
        when stores.store_code is null then 'UNKNOWN_STORE'
        when sales_lines.is_sign_mismatch then 'SIGN_MISMATCH'
        when products.mapping_count is null then 'UNMAPPED_PRODUCT'
        when products.mapping_count > 1 then 'AMBIGUOUS_PRODUCT'
        when fx_rates.usd_to_eur is null then 'MISSING_FX_RATE'
    end as quarantine_reason
from sales_lines
left join stores on sales_lines.store_code = stores.store_code
left join products
    on
        sales_lines.source_system = products.source_system
        and sales_lines.local_product_code = products.local_product_code
left join fx_rates on sales_lines.business_date = fx_rates.date_day
