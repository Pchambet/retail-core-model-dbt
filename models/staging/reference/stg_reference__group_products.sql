select
    group_sku,
    product_name,
    metier
from {{ source('reference', 'group_products') }}
