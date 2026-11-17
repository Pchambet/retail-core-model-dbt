-- The legacy store datamart and the core model must agree once the explained differences
-- (duplicates dropped, lines quarantined) are set aside, and the core model must not hold a
-- store day the legacy datamart does not know.

with parity as (
    select * from {{ ref('audit_migration_parity') }}
),

core_store_days as (
    select distinct
        stores.store_code,
        sales_lines.business_date
    from {{ ref('fct_sales_lines') }} as sales_lines
    inner join {{ ref('dim_store') }} as stores on sales_lines.group_store_id = stores.group_store_id
    where sales_lines.source_system = 'pos'
)

select
    store_code,
    business_date,
    unexplained_usd
from parity
where unexplained_usd != 0

union all

select
    core_store_days.store_code,
    core_store_days.business_date,
    cast(null as decimal(18, 2)) as unexplained_usd
from core_store_days
left join parity
    on core_store_days.store_code = parity.store_code and core_store_days.business_date = parity.business_date
where parity.store_code is null
