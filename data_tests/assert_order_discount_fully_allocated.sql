-- Header grain to line grain: the shares of an order discount add up to the discount, to the cent.

with allocated as (
    select
        order_id,
        sum(allocated_discount_usd) as allocated_discount_usd
    from {{ ref('int_oms__order_lines_allocated') }}
    group by order_id
)

select
    orders.order_id,
    orders.order_discount_usd,
    allocated.allocated_discount_usd
from {{ ref('stg_oms__orders') }} as orders
inner join allocated on orders.order_id = allocated.order_id
where orders.order_discount_usd != allocated.allocated_discount_usd
