-- No line is lost between the platforms and the core model: every line a platform exported (a POS
-- ticket line, counted once however often it was re-exported, an OMS order line, an OMS return) is
-- either in the fact or in the quarantine, never in both and never in neither. The keys are
-- rebuilt from staging on purpose, so that a line dropped by the union itself is seen too.

with exported as (
    select distinct 'pos|' || ticket_no || '|' || cast(line_no as varchar) as record_key
    from {{ ref('stg_pos__sales_lines') }}
    union all
    select 'oms|' || order_id || '|' || cast(line_id as varchar) as record_key
    from {{ ref('stg_oms__order_lines') }}
    union all
    select 'oms|' || return_id as record_key
    from {{ ref('stg_oms__returns') }}
),

landed as (
    select source_record_key as record_key from {{ ref('fct_sales_lines') }}
    union all
    select record_key from {{ ref('audit_quarantined_lines') }}
),

landed_counts as (
    select
        record_key,
        count(*) as landings
    from landed
    group by record_key
)

select
    coalesce(exported.record_key, landed_counts.record_key) as record_key,
    landed_counts.landings
from exported
full outer join landed_counts on exported.record_key = landed_counts.record_key
where
    exported.record_key is null
    or landed_counts.record_key is null
    or landed_counts.landings != 1
