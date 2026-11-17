{#
    Does the new model say the same thing as the datamart the local teams read today?
    Per store and day of the POS platform, in the legacy definition (US dollars, tax included):

        legacy = core model + duplicates dropped + lines quarantined + unexplained

    The first two differences are explained and listed; the last one must be zero
    (data_tests/assert_migration_parity_has_no_unexplained_difference.sql).
#}

with legacy as (
    select * from {{ ref('stg_pos__legacy_daily_sales') }}
),

stores as (
    select * from {{ ref('dim_store') }}
),

core as (
    select
        stores.store_code,
        sales_lines.business_date,
        sum(sales_lines.net_amount_usd + sales_lines.tax_amount_usd) as amount_usd
    from {{ ref('fct_sales_lines') }} as sales_lines
    inner join stores on sales_lines.group_store_id = stores.group_store_id
    where sales_lines.source_system = 'pos'
    group by stores.store_code, sales_lines.business_date
),

duplicates as (
    select
        store_code,
        business_date,
        sum(net_amount_usd + tax_amount_usd) as amount_usd
    from {{ ref('stg_pos__sales_lines') }}
    where export_rank > 1
    group by store_code, business_date
),

quarantined as (
    select
        store_code,
        business_date,
        sum(net_amount_usd + tax_amount_usd) as amount_usd
    from {{ ref('audit_quarantined_lines') }}
    where source_system = 'pos'
    group by store_code, business_date
),

compared as (
    select
        legacy.store_code,
        legacy.business_date,
        legacy.sales_incl_tax_usd as legacy_sales_usd,
        coalesce(core.amount_usd, 0) as core_sales_usd,
        coalesce(duplicates.amount_usd, 0) as explained_duplicates_usd,
        coalesce(quarantined.amount_usd, 0) as explained_quarantine_usd
    from legacy
    left join core
        on legacy.store_code = core.store_code and legacy.business_date = core.business_date
    left join duplicates
        on legacy.store_code = duplicates.store_code and legacy.business_date = duplicates.business_date
    left join quarantined
        on legacy.store_code = quarantined.store_code and legacy.business_date = quarantined.business_date
)

select
    store_code,
    business_date,
    legacy_sales_usd,
    {{ as_money('core_sales_usd') }} as core_sales_usd,
    {{ as_money('explained_duplicates_usd') }} as explained_duplicates_usd,
    {{ as_money('explained_quarantine_usd') }} as explained_quarantine_usd,
    {{ as_money('legacy_sales_usd - core_sales_usd - explained_duplicates_usd - explained_quarantine_usd') }}
        as unexplained_usd
from compared
