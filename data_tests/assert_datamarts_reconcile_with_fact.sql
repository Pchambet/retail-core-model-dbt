-- The two datamarts carry the same euros as the fact they are built on.

with totals as (
    select
        (select sum(net_amount_eur) from {{ ref('fct_sales_lines') }}) as fact_eur,
        (select sum(net_sales_eur) from {{ ref('mart_daily_store_sales') }}) as daily_eur,
        (select sum(net_sales_eur) from {{ ref('mart_monthly_metier_sales') }}) as monthly_eur
)

select *
from totals
where fact_eur != daily_eur or fact_eur != monthly_eur
