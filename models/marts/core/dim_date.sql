select
    date_day,
    fiscal_year,
    fiscal_month,
    fiscal_week,
    day_name,
    is_weekend
from {{ ref('stg_reference__fiscal_calendar') }}
