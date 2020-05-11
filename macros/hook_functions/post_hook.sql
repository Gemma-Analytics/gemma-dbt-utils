{%- macro post_hook_index(target_column, unique=none, method=none) -%}

  {%- set unique = 'unique' if unique == 'unique' or unique == true else '' -%}

  create {{ unique }} index if not exists
  {{ this.table }}__index_on_{{ target_column }} on {{ this }}

  {%- if method in ('btree','brin','hash','spgist') -%}

    USING {{ method }}

  {%- endif -%}

  ({{ target_column }})

{%- endmacro -%}




{%- macro post_hook_index_id() -%}

  {{ gemma_dbt_utils.post_hook_index('id', true) }}

{%- endmacro -%}