select
    rate_date,
    usd_to_eur
from {{ source('reference', 'fx_rates') }}
