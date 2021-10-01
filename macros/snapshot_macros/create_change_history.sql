{% macro create_change_history(field, source_relation, pk="id") %}
  {#
   # This macro creates a table of field value changes akin to a historization table
   # given a dbt snapshot table.
   #
   # Arguments:
   #  field             name of the field that requires historization
   #  source_relation   relation object of the snapshot relation
   #  pk                name of the primary key of the original table (defaults to id)
   #
   # Sample call: {{ create_change_history("dealstage", ref('snap_hubspot_deals')) }}
   #
   #}

  WITH raw_data AS (
    SELECT
        "{{ pk }}"
      , "{{ field }}" AS field_value
      , dbt_valid_from::TIMESTAMP WITH TIME ZONE AS valid_from
    FROM {{ source_relation }}
  ), calculate_previous_value AS (
    SELECT
        *
      , LAG(field_value) OVER w AS previous_field_value
    FROM raw_data
    WINDOW w AS (PARTITION BY "{{ pk }}" ORDER BY valid_from ASC)
  )
  SELECT
      "{{ pk }}"
    , field_value
    , previous_field_value
    , valid_from
    , LEAD(valid_from) OVER w AS valid_until
  FROM calculate_previous_value
  WHERE COALESCE( -- must evaluate to true if one but not both are NULL
      NOT (field_value = previous_field_value)
    , NOT (field_value IS NULL AND previous_field_value IS NULL)
  )
  WINDOW w AS (PARTITION BY "{{ pk }}" ORDER BY valid_from ASC)

{% endmacro %}
