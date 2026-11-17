select
    group_store_id,
    store_code,
    store_name,
    city,
    state,
    time_zone,
    channel_code,
    sales_tax_rate
from {{ ref('stg_reference__stores') }}
