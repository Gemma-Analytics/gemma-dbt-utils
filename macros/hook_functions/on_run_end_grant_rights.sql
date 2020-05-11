{%- macro grant_read(users, schemas_list=none, include_main_schema=true) -%}

  {% set users = gemma_dbt_utils.arg_into_list(users) %}

  {% set schemas_list = gemma_dbt_utils.arg_into_list(schemas_list) %}

  {%- do schemas_list.append(target.schema) if include_main_schema and schemas_list -%}

  {%- for user in users -%}

    {%- if schemas_list -%}
      {%- for schema in schemas_list %}

          {%- set schema = target.schema+'_'+schema if schema!=target.schema else schema %}

          grant usage on schema {{ schema }} to {{ user }};
          grant select on all tables in schema {{ schema }} to {{ user }};

      {%- endfor %}

    {%- else -%}

      {%- for schema in schemas -%}

        {%- if include_main_schema or
              (include_main_schema == false and schema != target.schema) -%}

          grant usage on schema {{ schema }} to {{ user }};
          grant select on all tables in schema {{ schema }} to {{ user }};

        {%- endif -%}

      {%- endfor %}

    {%- endif -%}

  {%- endfor -%}

{%- endmacro -%}
