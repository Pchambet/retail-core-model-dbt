select
    store_code,
    business_date,
    sales_incl_tax_usd,
    line_count
from {{ source('us_pos', 'legacy_daily_sales') }}
