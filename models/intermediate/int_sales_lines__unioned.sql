{#
    The two platforms in one shape, one row per sale or return line:
    - POS: the latest export of each ticket line (older copies are duplicates); a negative quantity
      is a return; the business day is the store-local day of the sale.
    - OMS: order lines after allocation of the order discount, and returns from their own table,
      signed negative; UTC timestamps are converted to the local time of the e-commerce store.
#}

with pos_lines as (
    select * from {{ ref('stg_pos__sales_lines') }}
    where export_rank = 1
),

oms_lines as (
    select * from {{ ref('int_oms__order_lines_allocated') }}
),

oms_returns as (
    select * from {{ ref('stg_oms__returns') }}
),

ecommerce_store as (
    select
        store_code,
        time_zone
    from {{ ref('stg_reference__stores') }}
    where store_code = '{{ var("ecommerce_store_code") }}'
),

pos as (
    select
        'pos' as source_system,
        ticket_no as document_id,
        cast(line_no as varchar) as source_line_id,
        case when quantity_sales_units < 0 then 'return' else 'sale' end as line_kind,
        'pos|' || ticket_no || '|' || cast(line_no as varchar) as record_key,
        store_code,
        sold_at_local as occurred_at_local,
        local_product_code,
        quantity_sales_units,
        net_amount_usd,
        tax_amount_usd,
        false as is_header_mismatch,
        false as is_orphan_return,
        (quantity_sales_units < 0) != (net_amount_usd < 0) as is_sign_mismatch,
        loaded_at
    from pos_lines
),

oms_sales as (
    select
        'oms' as source_system,
        oms_lines.order_id as document_id,
        cast(oms_lines.line_id as varchar) as source_line_id,
        'sale' as line_kind,
        'oms|' || oms_lines.order_id || '|' || cast(oms_lines.line_id as varchar) as record_key,
        ecommerce_store.store_code,
        {{ utc_to_local('oms_lines.ordered_at_utc', 'ecommerce_store.time_zone') }} as occurred_at_local,
        oms_lines.local_product_code,
        oms_lines.quantity_sales_units,
        oms_lines.net_amount_usd,
        cast(null as decimal(18, 2)) as tax_amount_usd,
        oms_lines.is_header_mismatch,
        false as is_orphan_return,
        false as is_sign_mismatch,
        oms_lines.loaded_at
    from oms_lines
    cross join ecommerce_store
),

oms_return_lines as (
    select
        'oms' as source_system,
        oms_returns.order_id as document_id,
        oms_returns.return_id as source_line_id,
        'return' as line_kind,
        'oms|' || oms_returns.return_id as record_key,
        ecommerce_store.store_code,
        {{ utc_to_local('oms_returns.returned_at_utc', 'ecommerce_store.time_zone') }} as occurred_at_local,
        oms_lines.local_product_code,
        -oms_returns.quantity_returned as quantity_sales_units,
        {{ as_money('-oms_returns.refund_amount_usd') }} as net_amount_usd,
        cast(null as decimal(18, 2)) as tax_amount_usd,
        coalesce(oms_lines.is_header_mismatch, false) as is_header_mismatch,
        oms_lines.order_id is null as is_orphan_return,
        false as is_sign_mismatch,
        oms_returns.loaded_at
    from oms_returns
    cross join ecommerce_store
    left join oms_lines
        on
            oms_returns.order_id = oms_lines.order_id
            and oms_returns.line_id = oms_lines.line_id
),

unioned as (
    select * from pos
    union all
    select * from oms_sales
    union all
    select * from oms_return_lines
)

select
    *,
    cast(occurred_at_local as date) as business_date
from unioned
