-- The source-to-target mapping (seeds/meta/source_to_target.csv) and the fact cannot drift apart:
-- every column of fct_sales_lines has a mapping row, and every mapping row names a real column.

{% set fact = ref('fct_sales_lines') %}

with fact_columns as (
    select lower(column_name) as column_name
    from information_schema.columns
    where
        lower(table_catalog) = lower('{{ fact.database }}')
        and lower(table_schema) = lower('{{ fact.schema }}')
        and lower(table_name) = lower('{{ fact.identifier }}')
),

mapped as (
    select lower(target_column) as column_name
    from {{ ref('source_to_target') }}
)

select coalesce(fact_columns.column_name, mapped.column_name) as column_name
from fact_columns
full outer join mapped on fact_columns.column_name = mapped.column_name
where fact_columns.column_name is null or mapped.column_name is null
