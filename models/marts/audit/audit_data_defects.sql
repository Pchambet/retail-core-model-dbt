{#
    Every record-level defect the pipeline detects, one row per defective record:
    - a POS line exported more than once (the older copies are dropped);
    - an order whose header does not add up to its lines (all its lines are quarantined);
    - any other quarantined line.
#}

with pos_lines as (
    select * from {{ ref('stg_pos__sales_lines') }}
),

quarantined as (
    select * from {{ ref('audit_quarantined_lines') }}
),

duplicates as (
    select distinct
        'DUPLICATE_LINE' as defect_code,
        'pos' as source_system,
        'pos|' || ticket_no || '|' || cast(line_no as varchar) as record_key
    from pos_lines
    where export_rank > 1
),

mismatched_orders as (
    select distinct
        quarantine_reason as defect_code,
        source_system,
        source_system || '|' || document_id as record_key
    from quarantined
    where quarantine_reason = 'HEADER_LINES_MISMATCH'
),

quarantined_lines as (
    select
        quarantine_reason as defect_code,
        source_system,
        record_key
    from quarantined
    where quarantine_reason != 'HEADER_LINES_MISMATCH'
)

select * from duplicates
union all
select * from mismatched_orders
union all
select * from quarantined_lines
