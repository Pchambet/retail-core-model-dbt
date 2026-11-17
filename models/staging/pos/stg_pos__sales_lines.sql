with source as (
    select * from {{ source('us_pos', 'pos_sales_lines') }}
),

renamed as (
    select
        ticket_no,
        line_no,
        store_code,
        sold_at_local,
        cast(sold_at_local as date) as business_date,
        item_code as local_product_code,
        qty as quantity_sales_units,
        uom as sales_unit,
        {{ as_money('amount_incl_tax_usd - tax_amount_usd') }} as net_amount_usd,
        tax_amount_usd,
        discount_amount_usd,
        export_batch_id,
        loaded_at,
        row_number() over (
            partition by ticket_no, line_no
            order by loaded_at desc, export_batch_id desc
        ) as export_rank
    from source
)

select * from renamed
