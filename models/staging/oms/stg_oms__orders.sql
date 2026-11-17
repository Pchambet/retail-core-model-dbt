select
    order_id,
    ordered_at_utc,
    merchandise_total_usd,
    order_discount_usd,
    shipping_fee_usd,
    order_total_usd,
    loaded_at
from {{ source('us_oms', 'oms_orders') }}
