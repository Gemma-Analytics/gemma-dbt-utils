{{ config(enabled=var("gemma:fx:enabled")) }}

WITH rates AS (

  {% for currency, source_table in var('gemma:fx:currencies').items() %}

    SELECT
        {{ var('gemma:fx:column_date') }} AS date
      , '{{ currency|upper() }}' AS currency
      , {{ var('gemma:fx:column_rate') }} AS fx_rate
    FROM {{ var(source_table, source_table) }}
    {# Checks if there is a variable called source_table. If there is not, source_table
    may already be the name of the table. #}

    {% if not loop.last %}

      UNION ALL

    {% endif %}

  {% endfor %}

), remove_nulls AS (

  SELECT
      date
    , currency
    , fx_rate
    , COALESCE( -- the GENERATE_SERIES below throws out the very last day otherwise!
          LEAD(date) OVER w
        , (NOW()::DATE + INTERVAL '1 day')::DATE
        -- use NOW() to ensure that date series runs to current date even on holidays!
      ) AS next_date
    , ROW_NUMBER() OVER w AS temp_partition
  FROM rates
  WHERE NOT NULLIF(fx_rate, 0) IS NULL -- throw out rows without proper fx rate
  WINDOW w AS (PARTITION BY currency ORDER BY date ASC)

), add_missing_dates AS (

  SELECT
      gs.gs::DATE AS date
    , rn.currency
    , FIRST_VALUE(rn.fx_rate) OVER w AS fx_rate
  FROM remove_nulls AS rn
    , GENERATE_SERIES(rn.date, rn.next_date - INTERVAL '1 day', INTERVAL '1 day') AS gs
  WINDOW w AS (PARTITION BY rn.currency, rn.temp_partition ORDER BY rn.date ASC)

), add_usd AS (

  WITH minmax AS (SELECT MIN(date) AS min, MAX(date) AS max FROM add_missing_dates)

  SELECT * FROM add_missing_dates
  UNION ALL
  SELECT
      GENERATE_SERIES(mm.min, mm.max, INTERVAL '1 day')::DATE AS date
    , 'USD'
    , 1
  FROM minmax AS mm

), base_currency AS (

  SELECT * FROM add_usd
  WHERE currency = '{{ var("gemma:fx:base_currency")|upper() }}'

), final AS (

  SELECT
      au.date
    , au.currency AS fx_currency
    , bc.currency AS base_currency
    , bc.fx_rate / au.fx_rate AS fx_rate
  FROM add_usd AS au
    LEFT JOIN base_currency AS bc
      ON bc.date = au.date

)

SELECT * FROM final
ORDER BY date DESC, fx_currency ASC
