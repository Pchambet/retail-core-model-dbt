select
    channel_code,
    channel_name
from {{ ref('stg_reference__channels') }}
