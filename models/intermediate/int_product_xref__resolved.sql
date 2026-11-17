{#
    One row per local product code. A code with exactly one mapping resolves to its group SKU;
    a code mapped to several group SKUs keeps group_sku empty: the line is flagged, never guessed.
#}

with mappings as (
    select * from {{ ref('stg_reference__product_xref') }}
),

counted as (
    select
        source_system,
        local_product_code,
        count(distinct group_sku) as mapping_count,
        min(group_sku) as any_group_sku,
        min(pieces_per_sales_unit) as any_pieces_per_sales_unit
    from mappings
    group by source_system, local_product_code
)

select
    source_system,
    local_product_code,
    mapping_count,
    case when mapping_count = 1 then any_group_sku end as group_sku,
    case when mapping_count = 1 then any_pieces_per_sales_unit end as pieces_per_sales_unit
from counted
