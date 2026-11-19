{# only valid for PostgreSQL targets #}
{{ config(
  materialized="table",
  enabled=(target.type == 'postgres')
) }}

{# Repurpose any existing model to test the macro select_star_except() #}
{% set src = ref("data_test_numeric_constraints") %}
{% set exceptions_list = ["type", "vat_pct"] %}

{# dbt v1 renders disabled models while it parses the project, and the macro raises an error outside PostgreSQL #}
{% if target.type == 'postgres' %}

{# check both modes: query and column returns! #}
  SELECT {{ gemma_dbt_utils.select_star_except(src, exceptions_list, False) }}
  FROM {{ src }}
UNION ALL
  {{ gemma_dbt_utils.select_star_except(src, exceptions_list, True) }}

{% endif %}
