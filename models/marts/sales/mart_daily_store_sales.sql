with sales_lines as (
    select
        *,
        line_kind = 'return' as is_return
    from {{ ref('fct_sales_lines') }}
),

stores as (
    select * from {{ ref('dim_store') }}
)

select
    sales_lines.business_date,
    sales_lines.group_store_id,
    stores.store_name,
    sales_lines.channel_code,
    cast(count(distinct case when not sales_lines.is_return then sales_lines.document_id end) as integer)
        as sale_documents,
    cast(sum(case when sales_lines.is_return then 0 else sales_lines.quantity_pieces end) as integer)
        as pieces_sold,
    cast(sum(case when sales_lines.is_return then -sales_lines.quantity_pieces else 0 end) as integer)
        as pieces_returned,
    {{ as_money('sum(case when sales_lines.is_return then -sales_lines.net_amount_eur else 0 end)') }}
        as returns_eur,
    {{ as_money('sum(sales_lines.net_amount_usd)') }} as net_sales_usd,
    {{ as_money('sum(sales_lines.net_amount_eur)') }} as net_sales_eur
from sales_lines
inner join stores on sales_lines.group_store_id = stores.group_store_id
group by
    sales_lines.business_date,
    sales_lines.group_store_id,
    stores.store_name,
    sales_lines.channel_code
