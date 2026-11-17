-- No line is lost between the platforms and the core model: every checked line is either in the
-- fact or in the quarantine, never in both and never in neither.

with checked as (
    select record_key from {{ ref('int_sales_lines__checked') }}
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
    coalesce(checked.record_key, landed_counts.record_key) as record_key,
    landed_counts.landings
from checked
full outer join landed_counts on checked.record_key = landed_counts.record_key
where
    checked.record_key is null
    or landed_counts.record_key is null
    or landed_counts.landings != 1
