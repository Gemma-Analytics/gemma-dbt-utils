{% macro create_index_if_col_exists(table_model, column, unique=none, method=none) %}
  {#
    Create index function - allow setting a high level config by failing
    gracefully if the column to be indexed does not exist. E.g. we can
    configure all tables to have an index on "id", but not fail the dbt run if
    any one table does not have an id column.

    Arguments:
      table_model   relation    e.g. {{ this }}
      column        string      e.g. "id"
      unique        boolean
      method        string      e.g. "brin" -> needs to be valid index type

    Notes:
      1. arg column is not quoted, if your column required quoting it needs
         to be quoted by the calling function, e.g. "'Id'"
      2. make sure to use index types on compatible data types,
         e.g. "brin" index type on an integer column will not fail the run
         but results in a missing index

    Sample usage:
    {{ gemma_dbt_utils.create_index_if_col_exists(this, "id", false, "brin") }}
  #}
  {% if target.type == 'postgres' | as_bool() %}
    {%- set hashing_query -%}
      {# Hash index column to avoid running into postgres 63 byte identifier limit #}
      SELECT md5('{{ table_model}}_{{ column }}')
    {%- endset -%}

    {%- if execute -%}
      {%- set index_name = run_query(hashing_query).columns[0].values()[0] -%}
    {%- else -%}
      {# required to avoid compilation failure #}
      {%- set index_name = "-" -%}
    {%- endif -%}

    DO
    $$
    BEGIN
    IF EXISTS (
        SELECT 1
        FROM {{ source('information_schema', 'columns') }}
        WHERE table_schema = '{{ table_model.schema }}'
          AND table_name = '{{ table_model.identifier }}'
          AND column_name = '{{ column }}'
      ) THEN
        CREATE {{ 'UNIQUE' if unique else '' }} INDEX IF NOT EXISTS
        "_dbt_idx_{{ index_name }}"
        ON {{ table_model }}

        {%- if method in ('btree','brin','hash','spgist', 'gist', 'gin') -%}

        USING {{ method }}

        {%- endif -%}

        ({{ column }});
    END IF;
    END
    $$;
  {% else %}
    {# BigQuery, Snowflake, Redshift will not require this macro #}
    {% do exceptions.raise_compiler_error("This macro only works for PostgreSQL") %}
  {% endif %}
{% endmacro %}

--------------------------------------------------------------------------------

{%- macro post_hook_index(target_column, unique=none, method=none) -%}

  {{ gemma_dbt_utils.create_index_if_col_exists(this, target_column, unique, method) }}

{%- endmacro -%}

--------------------------------------------------------------------------------

{%- macro post_hook_index_id() -%}

  {{ gemma_dbt_utils.post_hook_index('id', true) }}

{%- endmacro -%}
