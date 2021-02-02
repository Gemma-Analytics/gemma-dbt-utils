{%- macro create_is_type_funcs(field_type_list, func_name_list=none) -%}

  {%- set field_type_list = gemma_dbt_utils.arg_into_list(field_type_list) -%}

  {%- set func_name_list = gemma_dbt_utils.arg_into_list(func_name_list) -%}

  {%- set type_list_len = field_type_list|length -%}

  {%- set name_list_len = func_name_list|length
      if func_name_list is not none else 0 -%}

  {%- if func_name_list and name_list_len != type_list_len -%}

    {{ exceptions.raise_compiler_error(
      "Error: Name and type lists dont have the same length.") }}

  {%- endif -%}

  {%- for i in range(0, type_list_len) %}

    {% if func_name_list %}

      {{ gemma_dbt_utils.create_is_type_func(field_type_list[i],
        func_name_list[i] )}}

    {% else %}

      {{ gemma_dbt_utils.create_is_type_func(field_type_list[i]) }}

    {%- endif -%}

  {%- endfor -%}

{%- endmacro -%}

-------------------------------------------------------------------------------

{%- macro create_is_type_func(field_type, func_name=none) -%}

  {%- if not func_name -%}

    {%- set func_name = 'gemma_is_' ~ field_type.lower() -%}

  {%- endif -%}
  -- Adapted from
  -- https://stackoverflow.com/questions/16195986/isnumeric-with-postgresql
  CREATE SCHEMA IF NOT EXISTS "{{ target.schema }}";
  CREATE OR REPLACE FUNCTION "{{ target.schema }}"."{{ func_name }}"(text) RETURNS BOOLEAN AS $$
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

{%- endmacro -%}
