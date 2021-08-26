{%- macro get_columns(table_relation, exceptions_list=[]) -%}
  {#
   # This macro returns a list of columns for the table_relation. It can ignore
   # columns if desired.
   #
   # Arguments:
   #  table_relation    a dbt relation object (source or ref macro call)
   #  exceptions_list   optional iterable that contains the name of columns to ignore
   #
   #
   # Sample call:
   #
   #  {% for column in get_columns(ref("base_hs_deal_snapshot"), ["dbt_scd_id", "dbt_updated_at"]) %}
   #    ...
   #  {% endfor %}
   #
   #}

  {%- set query -%}
    {# Prepare query to get list of all columns, except exceptions #}
    SELECT column_name
    FROM information_schema.columns
    WHERE table_name = '{{ table_relation.name }}'
      AND table_schema = '{{ table_relation.schema }}'
      {%- if exceptions_list -%}
        AND NOT column_name IN (
          {%- for field in exceptions_list -%}
            '{{ field }}' {%- if not loop.last %},{% endif %}
          {%- endfor -%}
        )
      {%- endif -%}
    ORDER BY ordinal_position ASC
  {%- endset -%}
  {%- if execute -%}
    {{ return(run_query(query).columns[0].values()) }}
  {%- else -%}
    {# play nice, return an empty list so other's don't have to deal with nones #}
    {{ return([]) }}
  {%- endif -%}

{%- endmacro -%}
