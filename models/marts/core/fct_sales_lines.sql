{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='sales_line_id',
        on_schema_change='fail'
    )
}}

{#
    Grain: one row per sale or return line of a ticket or an order (docs/adr/0001).
    Incremental on the load time: a nightly run only reads what landed since the last one. The key
    is the line itself, so a line exported again replaces its earlier version instead of doubling.
    A first or full run reads everything.
#}

{% set last_load %}
    {% if is_incremental() %}
        (select max(loaded.loaded_at) from {{ this }} as loaded)
    {% else %}
        cast('1900-01-01' as timestamp)
    {% endif %}
{% endset %}

with sales_lines as (
    select * from {{ ref('int_sales_lines__checked') }}
    where
        quarantine_reason is null
        and loaded_at >= {{ last_load | trim }}
)

select
    {{ dbt_utils.generate_surrogate_key([
        'sales_lines.source_system',
        'sales_lines.document_id',
        'sales_lines.source_line_id',
        'sales_lines.line_kind',
    ]) }} as sales_line_id,
    sales_lines.record_key as source_record_key,
    sales_lines.source_system,
    sales_lines.document_id,
    sales_lines.line_kind,
    sales_lines.business_date,
    sales_lines.occurred_at_local,
    sales_lines.group_store_id,
    sales_lines.channel_code,
    sales_lines.group_sku,
    cast(sales_lines.quantity_pieces as integer) as quantity_pieces,
    sales_lines.net_amount_usd,
    sales_lines.tax_amount_usd,
    sales_lines.fx_rate_date,
    sales_lines.fx_rate_usd_to_eur,
    {{ as_money('sales_lines.net_amount_usd * sales_lines.fx_rate_usd_to_eur') }} as net_amount_eur,
    sales_lines.loaded_at
from sales_lines
