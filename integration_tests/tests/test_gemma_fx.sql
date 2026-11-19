WITH correct_results AS (

  SELECT
      date::DATE AS date
    , CAST(fx_rate AS DECIMAL(38, 20)) AS fx_rate
  FROM {{ ref('models_gemma_fx_result_eur_chf') }}

), test AS (

  SELECT *
  FROM correct_results AS cr
    LEFT JOIN {{ ref('gemma_fx') }} AS gf
      ON gf.date = cr.date
      AND gf.fx_currency = 'CHF'
      AND gf.base_currency = 'EUR'
  -- tolerance instead of exact equality: the rates are floats
  WHERE NOT COALESCE(ABS(gf.fx_rate - cr.fx_rate) < 0.000001, FALSE)

)
SELECT * FROM test
