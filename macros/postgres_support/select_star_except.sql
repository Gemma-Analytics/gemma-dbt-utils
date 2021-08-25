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

  {%- set query -%}
    {# Prepare query to get list of all columns, except exceptions #}
    SELECT column_name
    FROM information_schema.columns
    WHERE table_name = '{{ table_relation.name }}'
      AND table_schema = '{{ table_relation.schema }}'
      AND NOT column_name IN (
        {%- for field in exceptions_list -%}
          '{{ field }}' {%- if not loop.last %},{% endif %}
        {%- endfor -%}
      )
    ORDER BY ordinal_position ASC
  {%- endset -%}
  {%- if execute -%}
    {# set actual list of columns #}
    {%- set columns_list -%}
      {%- for column in run_query(query).columns[0].values() -%}
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
