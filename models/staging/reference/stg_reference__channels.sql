select
    channel_code,
    channel_name
from {{ source('reference', 'channels') }}
