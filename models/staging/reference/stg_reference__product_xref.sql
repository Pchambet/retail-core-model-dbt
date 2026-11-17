select
    source_system,
    local_code as local_product_code,
    group_sku,
    pieces_per_sales_unit
from {{ source('reference', 'product_xref') }}
