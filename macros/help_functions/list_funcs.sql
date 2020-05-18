{% macro arg_into_list(arg=none) %}
{# Method checks if arg is string, number or boolean
   and creates a list with that arg inside #}

  {%- if arg is string or arg is number or arg is boolean -%}

    {%- set temp = [] -%}

    {%- do temp.append(arg) -%}

    {%- set arg=temp -%}

  {%- endif -%}

  {{ return(arg) }}
  
{%- endmacro -%}
