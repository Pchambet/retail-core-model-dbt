select
    store_code,
    group_store_id,
    store_name,
    city,
    state,
    timezone as time_zone,
    channel_code,
    sales_tax_rate
from {{ source('reference', 'stores') }}
