{%- macro grant_read(users=none, schemas_list=none, include_main_schema=true) -%}

  {% for user in users %}

    {% if schemas_list %}

      {% if include_main_schema %}

        {% do schemas_list.append(target.schema) %}

      {% endif %}

      {% for schema in schemas_list %}

          grant usage on schema {{ schema }} to {{ user }};
          grant select on all tables in schema {{ schema }} to {{ user }};

      {% endfor %}

    {% else %}

      {% for schema in schemas %}

        {% if include_main_schema or
              (include_main_schema == false and schema != target.schema) %}

          grant usage on schema {{ schema }} to {{ user }};
          grant select on all tables in schema {{ schema }} to {{ user }};

        {% endif %}

      {% endfor %}

    {% endif %}

  {% endfor %}

{%- endmacro -%}
