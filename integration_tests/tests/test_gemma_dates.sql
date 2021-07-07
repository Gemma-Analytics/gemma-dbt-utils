WITH correct_results AS (

  SELECT
      date AS date
    , month_last_day AS month_last_day
    , previous_month_first_day AS previous_month_first_day

  FROM {{ ref('models_gemma_dates_sample_results') }}

), test AS (

  SELECT *
  FROM correct_results AS cr
    LEFT JOIN {{ ref('gemma_dates') }} AS gd
      ON gd.date = cr.date
  WHERE NOT COALESCE(gd.month_last_day = cr.month_last_day, FALSE)
     OR NOT COALESCE(
      gd.previous_month_first_day = cr.previous_month_first_day, FALSE)

)

SELECT * FROM test
