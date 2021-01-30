WITH correct_results AS (

  SELECT
      date::DATE AS date
    , fx_rate::NUMERIC AS fx_rate
  FROM {{ ref('models_gemma_fx_result_eur_chf') }}

), minmax AS (

  SELECT MIN(date), MAX(date) FROM correct_results

), test AS (

  SELECT *
  FROM correct_results AS cr
    LEFT JOIN {{ ref('gemma_fx') }} AS gf
      ON gf.date = cr.date
      AND gf.fx_currency = 'CHF'
      AND gf.base_currency = 'EUR'
  WHERE NOT COALESCE(gf.fx_rate::NUMERIC = cr.fx_rate, FALSE)

)
SELECT * FROM test
