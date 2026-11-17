select
    date_day,
    fiscal_year,
    fiscal_month,
    fiscal_week,
    day_name,
    is_weekend
from {{ source('reference', 'fiscal_calendar') }}
