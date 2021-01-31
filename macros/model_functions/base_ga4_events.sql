{% macro create_ga4_events_base_model() %}

  {% if target.type == "postgres" %}

    {{ base_ga4_events_postgres_query() }}

  {% elif target.type == "bigquery" %}
    'bigquery2'
  {% else %}
    'rest3'
  {% endif %}

{% endmacro %}
