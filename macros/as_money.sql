{#
    Round an amount to the cent and give it the one money type of the project. Contracts compare
    data types, so every amount of a mart goes through this macro instead of an ad hoc cast.
#}
{% macro as_money(expression) -%}
    cast(round({{ expression }}, 2) as decimal(18, 2))
{%- endmacro %}
