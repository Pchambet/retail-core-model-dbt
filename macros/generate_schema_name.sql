{#
    Use the schema declared in dbt_project.yml as it is, without the target-schema prefix dbt adds by
    default. The layers (raw_us_pos, staging, core, sales, migration_audit...) then carry the same
    names on DuckDB and on Snowflake, and the sources can point at the raw schemas by name.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {{ (custom_schema_name or target.schema) | trim }}
{%- endmacro %}
