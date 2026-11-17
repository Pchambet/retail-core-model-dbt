select
    record_key,
    source_system,
    document_id,
    source_line_id,
    line_kind,
    store_code,
    business_date,
    local_product_code,
    quantity_sales_units,
    net_amount_usd,
    tax_amount_usd,
    quarantine_reason
from {{ ref('int_sales_lines__checked') }}
where quarantine_reason is not null
