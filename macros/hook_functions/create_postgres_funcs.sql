{% macro create_funcs(field_type_list=none, func_name_list=none) %}

  {% set type_list_len = field_type_list|length %}

  {% set name_list_len = func_name_list|length %}

  {% if name_list_len != type_list_len %}

    {{ exceptions.raise_compiler_error("Error: Name and type list dont have the same length.") }}

  {% endif %}

  {{ log("geschafft", info=True) }}

  {% for i in range(0, name_list_len) %}

      {{ create_func_is_type(field_type[i], func_name[i]) }}

  {% endfor %}

{% endmacro %}

-------------------------------------------------------------------------------

{% macro create_func_is_type(field_type, func_name=none) %}

  {% if not func_name %}

    {% set func_name = 'gemma_is_' ~ field_type.lower() %}

  {% endif %}
  -- Adapted from
  -- https://stackoverflow.com/questions/16195986/isnumeric-with-postgresql
  CREATE OR REPLACE FUNCTION {{ func_name }}(text) RETURNS BOOLEAN AS $$
  DECLARE x {{ field_type }};
  BEGIN
    x = $1::{{ field_type }};
    RETURN TRUE;
  EXCEPTION WHEN others THEN
    RETURN FALSE;
  END;
  $$
  STRICT
  LANGUAGE plpgsql IMMUTABLE;

{% endmacro %}
