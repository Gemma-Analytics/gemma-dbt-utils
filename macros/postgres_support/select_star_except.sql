{%- macro select_star_except(table_relation, exceptions_list, return_query=True) -%}
  {#
   # This macro emulates the SELECT * EXCEPT (...) FROM table_relation behavior
   # for PostgreSQL. Can only be used with relations objects and not CTEs!
   #
   # Arguments:
   #  table_relation    a dbt relation object (source or ref macro call)
   #  exceptions_list   an iterable that contains the names of columns not to be used
   #  return_query      returns a full SELECT query if TRUE; only the comma-separated
   #                    list of columns otherwise
   #
   # Sample call:
   #  {{ select_star_except(ref("base_hs_hist_deals"), ["dbt_scd_id", "dbt_updated_at"]) }}
   #
   #}

  {%- if execute -%}
    {# set actual list of columns #}
    {%- set columns_list -%}
      {%- for column in get_columns(table_relation, exceptions_list) -%}
        "{{ column }}" {%- if not loop.last %},{% endif %}
      {% endfor -%}
    {%- endset -%}
  {%- else -%}
    {# required to avoid compilation failure #}
    {%- set columns_list = "*" -%}
  {%- endif -%}

  {# this is the final returned statement #}
  {%- if return_query -%}
    SELECT {{ columns_list }}
    FROM {{ table_relation }}
  {%- else -%}
    {{ columns_list }}
  {%- endif -%}

{%- endmacro -%}
