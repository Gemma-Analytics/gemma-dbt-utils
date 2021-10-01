-- TODO: only run on PostgreSQL
SELECT *
FROM information_schema.columns
WHERE table_name = 'select_star_except_model'
  AND table_schema = '{{ ref("select_star_except_model").schema }}'
  AND NOT column_name IN ('date', 'fx_currency') -- the other two shan't exist!
