{#
    Convert a UTC timestamp without time zone into the wall-clock time of an IANA time zone
    (daylight saving included). The two engines spell it differently, so the model code calls this
    macro and each adapter gets its own implementation.

    Arguments are SQL expressions: a timestamp column and a column or literal holding the zone name.
#}
{% macro utc_to_local(utc_timestamp, time_zone) -%}
    {{ return(adapter.dispatch('utc_to_local', 'retail_core')(utc_timestamp, time_zone)) }}
{%- endmacro %}

{% macro duckdb__utc_to_local(utc_timestamp, time_zone) -%}
    timezone({{ time_zone }}, timezone('UTC', {{ utc_timestamp }}))
{%- endmacro %}

{% macro snowflake__utc_to_local(utc_timestamp, time_zone) -%}
    convert_timezone('UTC', {{ time_zone }}, {{ utc_timestamp }})
{%- endmacro %}

{% macro default__utc_to_local(utc_timestamp, time_zone) -%}
    {{ exceptions.raise_compiler_error("utc_to_local is not implemented for adapter " ~ adapter.type()) }}
{%- endmacro %}
