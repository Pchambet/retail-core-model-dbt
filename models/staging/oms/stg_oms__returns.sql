select
    return_id,
    order_id,
    line_id,
    returned_at_utc,
    quantity_returned,
    refund_amount_usd,
    loaded_at
from {{ source('us_oms', 'oms_returns') }}
