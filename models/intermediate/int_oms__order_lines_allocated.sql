{#
    Grain gap: the order discount lives on the header, the core model sells by the line.
    It is spread over the lines in proportion to their amount; the rounding remainder goes to the
    largest line so that the lines add up to the header to the cent.
#}

with orders as (
    select * from {{ ref('stg_oms__orders') }}
),

order_lines as (
    select * from {{ ref('stg_oms__order_lines') }}
),

shared as (
    select
        order_lines.order_id,
        order_lines.line_id,
        order_lines.local_product_code,
        order_lines.quantity_sales_units,
        order_lines.line_amount_usd,
        order_lines.loaded_at,
        orders.ordered_at_utc,
        orders.order_discount_usd,
        orders.merchandise_total_usd,
        sum(order_lines.line_amount_usd) over (partition by order_lines.order_id) as lines_amount_usd,
        row_number() over (
            partition by order_lines.order_id
            order by order_lines.line_amount_usd desc, order_lines.line_id asc
        ) as amount_rank
    from order_lines
    inner join orders on order_lines.order_id = orders.order_id
),

rounded as (
    select
        *,
        {{ as_money('order_discount_usd * line_amount_usd / nullif(lines_amount_usd, 0)') }}
            as discount_share_usd
    from shared
),

allocated as (
    select
        *,
        discount_share_usd + case
            when amount_rank = 1
                then order_discount_usd - sum(discount_share_usd) over (partition by order_id)
            else 0
        end as allocated_discount_usd
    from rounded
)

select
    order_id,
    line_id,
    local_product_code,
    quantity_sales_units,
    ordered_at_utc,
    line_amount_usd,
    {{ as_money('allocated_discount_usd') }} as allocated_discount_usd,
    {{ as_money('line_amount_usd - allocated_discount_usd') }} as net_amount_usd,
    merchandise_total_usd != lines_amount_usd - order_discount_usd as is_header_mismatch,
    loaded_at
from allocated
