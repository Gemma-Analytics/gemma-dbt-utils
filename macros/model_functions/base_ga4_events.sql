{% macro create_ga4_events_base_model() %}

    {{ base_ga4_event_postgres_query() }}

{% endmacro %}
