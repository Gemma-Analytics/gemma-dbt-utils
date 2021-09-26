{#
 #  Tests whether the macro select_star_except works properly.
 #  Works by checking if a model that uses it really only has a reduced
 #  number of columns.
 #}

{% set src = ref("model_using_select_star_except") %}

SELECT *
FROM information_schema.columns
WHERE table_name = '{{ src.name }}'
  AND table_schema = '{{ src.schema }}'
  AND NOT column_name IN ('id', 'status') -- only these two columns are expected
