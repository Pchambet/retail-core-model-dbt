with sales_lines as (
    select * from {{ ref('fct_sales_lines') }}
),

products as (
    select * from {{ ref('dim_product') }}
),

dates as (
    select * from {{ ref('dim_date') }}
)

select
    dates.fiscal_year,
    dates.fiscal_month,
    products.metier,
    sales_lines.channel_code,
    cast(sum(sales_lines.quantity_pieces) as integer) as net_pieces,
    {{ as_money('sum(sales_lines.net_amount_eur)') }} as net_sales_eur
from sales_lines
inner join products on sales_lines.group_sku = products.group_sku
inner join dates on sales_lines.business_date = dates.date_day
group by
    dates.fiscal_year,
    dates.fiscal_month,
    products.metier,
    sales_lines.channel_code
