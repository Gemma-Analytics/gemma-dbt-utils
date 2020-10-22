{%- macro post_hook_index(target_column, unique=none, method=none) -%}

  create {{ 'unique' if unique else '' }} index if not exists
  {{ this.table }}__index_on_{{ target_column }} on {{ this }}

  {%- if method in ('btree','brin','hash','spgist') -%}

    USING {{ method }}

  {%- endif -%}

  ({{ target_column }})

{%- endmacro -%}


--------------------------------------------------------------------------------


{%- macro post_hook_index_id() -%}

  {{ gemma_dbt_utils.post_hook_index('id', true) }}

{%- endmacro -%}



--------------------------------------------------------------------------------

{% macro create_index_if_col_exists(table_model, column) %}
  {#
    Create index function - allow setting a high level config by failing
    gracefully if the column to be indexed does not exist. E.g. we can
    configure all tables to have an index on "id", but not fail the dbt run if
    any one table does not have an id column.

    Arguments:
      table_model   relation    e.g. {{ this }}
      column        string      e.g. "id"

    Note: arg column is not quoted, if your column required quoting it needs
    to be quoted by the calling function, e.g. "'Id'"

    sample usage:
    {{ gemma_dbt_utils.create_index_if_col_exists(this, "id") }}
  #}
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
      CREATE INDEX IF NOT EXISTS "_dbt_idx_{{ table_model.table }}_{{ column }}"
        ON {{ table_model }} ({{ column }});
   END IF;
  END
  $$;

{% endmacro %}
