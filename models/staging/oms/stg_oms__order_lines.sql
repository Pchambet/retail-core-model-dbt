select
    order_id,
    line_id,
    sku_local as local_product_code,
    quantity as quantity_sales_units,
    unit_price_usd,
    line_amount_usd,
    loaded_at
from {{ source('us_oms', 'oms_order_lines') }}
