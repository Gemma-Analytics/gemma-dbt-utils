WITH dates AS(

  SELECT
    GENERATE_SERIES(
      '{{ var('gemma:dates:start_date') }}',
      DATE(TIMEZONE('{{ var('gemma:dates:timezone') }}', CURRENT_TIMESTAMP))
        + INTERVAL '30 day',
      '1 day'
    ) AS date

), combined AS (

  SELECT
    ROW_NUMBER() OVER (ORDER BY date ASC) AS date_id
    , DATE(date) AS date
    , DATE(DATE_TRUNC('year', date)) AS year_start
    , EXTRACT(year FROM date) AS year
    , EXTRACT(isoyear FROM date) AS iso_year
    , DATE(DATE_TRUNC('quarter', date)) AS quarter_start
    , EXTRACT(quarter FROM date) AS quarter
    , DATE(DATE_TRUNC('month', date)) AS month_start
    , EXTRACT(month FROM date) AS month
    , DATE(DATE_TRUNC('week', date)) AS week_start
    , EXTRACT(week FROM date) AS week
    , TO_CHAR(date, 'IYYY-IW') AS iso_week
    , EXTRACT(isodow FROM date) AS iso_weekday
    , EXTRACT(day FROM date) AS day
    , TO_CHAR(date, 'dy') AS day_name
    , EXTRACT(doy FROM date) AS day_num
    , EXTRACT(dow FROM date) AS weekday

  FROM dates

), final AS(

  SELECT
    *
    , DENSE_RANK() OVER(ORDER BY month ASC) AS month_num
    , DENSE_RANK() OVER(ORDER BY week ASC) AS week_num

  FROM combined

)

SELECT * FROM final
