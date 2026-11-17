{#
    One rate per calendar day: the latest fixing on or before the day, so that a weekend sale is
    converted at Friday's rate. The date of the fixing used is kept for traceability. A day before
    the first fixing has no row: its lines are quarantined, not converted at a guessed rate.
#}

with calendar as (
    select date_day from {{ ref('stg_reference__fiscal_calendar') }}
),

fx_rates as (
    select * from {{ ref('stg_reference__fx_rates') }}
)

select
    calendar.date_day,
    fx_rates.rate_date,
    fx_rates.usd_to_eur
from calendar
inner join fx_rates on calendar.date_day >= fx_rates.rate_date
qualify row_number() over (partition by calendar.date_day order by fx_rates.rate_date desc) = 1
