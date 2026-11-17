-- The generator plants record-level defects and writes their manifest (seeds/ground_truth).
-- The pipeline must flag every one of them, with the right code, and nothing else.

with planted as (
    select
        defect_code,
        record_key
    from {{ ref('planted_defects') }}
),

detected as (
    select
        defect_code,
        record_key
    from {{ ref('audit_data_defects') }}
)

select
    coalesce(planted.record_key, detected.record_key) as record_key,
    planted.defect_code as planted_code,
    detected.defect_code as detected_code
from planted
full outer join detected on planted.record_key = detected.record_key
where
    planted.record_key is null
    or detected.record_key is null
    or planted.defect_code != detected.defect_code
