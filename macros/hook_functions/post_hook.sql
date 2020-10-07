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
    Find out whether column exists at all. Only if it does, create the index.

    Arguments:
      table_model   relation    e.g. {{ this }}
      column        string      e.g. "id"

    sample usage:
    {{ gemma_dbt_utils.create_index_if_col_exists(this, "id") }}
  #}
  {% if execute %}
    {%- set column_list_query -%}
      SELECT COUNT(column_name)
      FROM {{ source('information_schema', 'columns') }}
      WHERE table_schema = '{{ table_model.schema }}'
        AND table_name = '{{ table_model.identifier }}'
        AND column_name = '{{ column }}'
    {%- endset -%}

    {% set cq = run_query(column_list_query) %}

    {% if cq.columns[0].values()[0] == 1 %}
      create index if not exists
        _dbt_idx_{{ table_model.table }}_{{ column }}
        on {{ table_model }} ("{{ column }}")
    {% endif %}
  {% endif %}
{% endmacro %}
