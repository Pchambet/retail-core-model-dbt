{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='sales_line_id',
        on_schema_change='fail',
        post_hook="
            delete from {{ this }}
            where source_record_key in (
                select record_key from {{ ref('int_sales_lines__checked') }}
                where quarantine_reason is not null
            )"
    )
}}

{#
    Grain: one row per sale or return line of a ticket or an order (docs/adr/0001). The key is the
    source record, so a line exported again replaces its earlier version instead of doubling.

    Incremental. A nightly run reads the accepted lines that landed since the last load (new lines
    and new versions of loaded ones), plus every accepted line the fact does not hold yet: a line
    released from quarantine once its reference is fixed, or one that landed with an older load
    time. The post-hook removes a loaded line that a later export sends to quarantine. On a first
    or full run, `loaded` is empty and every accepted line is read.
#}

with loaded as (
    {% if is_incremental() %}
        select
            source_record_key,
            loaded_at
        from {{ this }}
    {% else %}
        select
            record_key as source_record_key,
            loaded_at
        from {{ ref('int_sales_lines__checked') }}
        where false
    {% endif %}
),

sales_lines as (
    select * from {{ ref('int_sales_lines__checked') }}
    where
        quarantine_reason is null
        and (
            loaded_at >= (select max(loaded.loaded_at) from loaded)
            or record_key not in (select loaded.source_record_key from loaded)
        )
)

select
    {{ dbt_utils.generate_surrogate_key(['sales_lines.record_key']) }} as sales_line_id,
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
