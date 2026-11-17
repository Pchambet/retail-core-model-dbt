select
    group_sku,
    product_name,
    metier
from {{ ref('stg_reference__group_products') }}
