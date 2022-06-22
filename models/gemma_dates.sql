{{ config(alias = var("gemma:dates:table"),
          schema = var("gemma:dates:schema"),
          enabled = var("gemma:dates:enabled")
) }}

{% if target.type == 'postgres' | as_bool() %}

  WITH dates AS (

    SELECT
        GENERATE_SERIES(
          '{{ var('gemma:dates:start_date') }}',
          DATE(TIMEZONE('{{ var('gemma:dates:timezone') }}', CURRENT_TIMESTAMP))
            + INTERVAL '{{ var('gemma:dates:end_date') }}', '1 day'
        ) AS date

  ), final AS (

    SELECT
        TO_CHAR(date, 'YYYYMMDD') AS date_id
      , DATE(date) AS date
      , EXTRACT(DOY FROM date) AS year_day_num
      , DATE_PART('day', date - DATE_TRUNC('quarter', date)) + 1
        AS quarter_day_num
      , EXTRACT(DAY FROM date) AS month_day_num
      , EXTRACT(MONTH FROM date) AS month_num
      , TO_CHAR(date, 'Month') AS month_name
      , TO_CHAR(date, 'Mon') AS month_abbreviated
      , EXTRACT(DAY FROM DATE_TRUNC('month', date) + INTERVAL '1 month - 1 day')
        AS month_days
      , TO_CHAR(date, 'YYYY-MM') AS year_month
      , EXTRACT(QUARTER FROM date) AS quarter_num
      , DATE_PART('day',
        (DATE_TRUNC('quarter', date) + INTERVAL '3 month')
        - DATE_TRUNC('quarter', date)
        ) AS quarter_days
      , EXTRACT(YEAR FROM date) AS year
      , EXTRACT(ISOYEAR FROM date) AS iso_year
      , EXTRACT(YEAR FROM date - INTERVAL '1 year') AS previous_year
      , EXTRACT(QUARTER FROM date - INTERVAL '3 month') AS previous_quarter_num
      , EXTRACT(MONTH FROM date - INTERVAL '1 month') AS previous_month_num
      , EXTRACT(WEEK FROM date) AS year_week_num
      , EXTRACT(ISOYEAR FROM date) || TO_CHAR(date, '"-CW"IW') AS year_week_name
      , EXTRACT(ISODOW FROM date) AS weekday_num
      , TO_CHAR(date, 'Day') AS weekday_name
      , TO_CHAR(date, 'Dy') AS weekday_abbreviated
      , EXTRACT(ISODOW FROM date) NOT IN (6,7) AS is_weekday
      , DATE(DATE_TRUNC('year', date)) AS year_first_day
      , DATE(DATE_TRUNC('year', date) + INTERVAL '1 year - 1 day')
        AS year_last_day
      , DATE(DATE_TRUNC('quarter', date)) AS quarter_first_day
      , DATE(DATE_TRUNC('quarter', date) + INTERVAL '3 month - 1 day')
        AS quarter_last_day
      , DATE(DATE_TRUNC('month', date)) AS month_first_day
      , DATE(DATE_TRUNC('month', date) + INTERVAL '1 month - 1 day')
        AS month_last_day
      , DATE(DATE_TRUNC('week', date)) AS week_first_day
      , DATE(DATE_TRUNC('week', date) + INTERVAL '1 week - 1 day')
        AS week_last_day
      , DATE(DATE_TRUNC('month', date - INTERVAL '1 month'))
        AS previous_month_first_day
      , DATE(DATE_TRUNC('month', date) - INTERVAL '1 day')
        AS previous_month_last_day
      , DATE(DATE_TRUNC('month', date + INTERVAL '1 month'))
        AS next_month_first_day
      , DATE(DATE_TRUNC('month', date) + INTERVAL '2 month - 1 day')
        AS next_month_last_day
      , EXTRACT(YEAR FROM date) || '-Q' || EXTRACT(QUARTER FROM date) AS year_quarter
      , DENSE_RANK() OVER
        (ORDER BY
          EXTRACT(ISOYEAR FROM date) ||
          TO_CHAR(date, '"-CW"IW') ASC
        )
        AS week_id

    FROM dates

  )

  SELECT * FROM final

{% elif target.type == 'bigquery' | as_bool() %}

  WITH dates AS (

    SELECT * FROM UNNEST(
      GENERATE_DATE_ARRAY('{{ var('gemma:dates:start_date') }}'
        , DATE_ADD(current_date(), INTERVAL {{ var('gemma:dates:end_date') }})
        , INTERVAL 1 DAY)) AS date

  ), final AS (

    SELECT
        FORMAT_DATE('%Y%m%d', date) AS date_id
      , DATE(date) AS date
      , EXTRACT(DAYOFYEAR FROM date) AS year_day_num
      , DATE_DIFF(date, DATE_TRUNC(date, QUARTER), DAY) + 1 AS quarter_day_num
      , EXTRACT(YEAR FROM date) AS year
      , EXTRACT(ISOYEAR FROM date) AS iso_year
      , EXTRACT(WEEK FROM date) AS year_week_num
      , EXTRACT(ISOWEEK FROM date) AS year_isoweek_num
      , EXTRACT(DAY FROM date) month_day_num
      , FORMAT_DATE('%Q', date) AS quarter_num
      , EXTRACT(MONTH FROM date) AS month_num
      , FORMAT_DATE('%B', date) AS month_name
      , FORMAT_DATE('%b', date) AS month_abbreviated
      , EXTRACT(DAY FROM LAST_DAY(date, MONTH)) AS month_days
      , FORMAT_DATE('%A', date) AS weekday_name
      , FORMAT_DATE('%a', date) AS weekday_abbreviated
      , EXTRACT(DAYOFWEEK FROM date) NOT IN (1,7) AS is_weekday
      , EXTRACT(YEAR FROM DATE_SUB(date, INTERVAL 1 YEAR)) AS previous_year
      , FORMAT_DATE('%Q', DATE_SUB(date, INTERVAL 1 QUARTER))
        AS previous_quarter_num
      , EXTRACT(MONTH FROM DATE_SUB(date, INTERVAL 1 MONTH)) AS previous_month_num
      , DATE_TRUNC(date, YEAR) AS year_first_day
      , LAST_DAY(date, YEAR) AS year_last_day
      , DATE_TRUNC(date, QUARTER) AS quarter_first_day
      , LAST_DAY(date, QUARTER) AS quarter_last_day
      , DATE_TRUNC(date, MONTH) AS month_first_day
      , LAST_DAY(date, MONTH) AS month_last_day
      , DATE_TRUNC(date, WEEK(MONDAY)) AS week_first_day
      , LAST_DAY(date, WEEK(MONDAY)) AS week_last_day
      , DATE_TRUNC(date, ISOWEEK) AS isoweek_first_day
      , LAST_DAY(date, ISOWEEK) AS isoweek_last_day
      , DATE_TRUNC(DATE_SUB(date, INTERVAL 1 MONTH), MONTH)
        AS previous_month_first_day
      , LAST_DAY(DATE_SUB(date, INTERVAL 1 MONTH), MONTH)
        AS previous_month_last_day
      , DATE_TRUNC(DATE_ADD(date, INTERVAL 1 MONTH), MONTH)
        AS next_month_first_day
      , LAST_DAY(DATE_ADD(date, INTERVAL 1 MONTH), MONTH) AS next_month_last_day
      , EXTRACT(YEAR FROM date) || '-Q' || FORMAT_DATE('%Q', date) AS year_quarter
      , DENSE_RANK() OVER
        (ORDER BY
          CAST(EXTRACT(ISOYEAR FROM date) AS STRING) ||
          CAST(EXTRACT(WEEK FROM date) AS STRING) ASC
        )
        AS week_id

  FROM dates

  )

  SELECT * FROM final

{% elif target.type == 'snowflake' | as_bool() %}

  {% set timeframe_query %}
  SELECT
    CURRENT_DATE
    - '{{ var('gemma:dates:start_date') }}'::DATE
    + (DATEDIFF('day', CURRENT_DATE, CURRENT_DATE + INTERVAL '{{ var('gemma:dates:end_date') }}'))
    + 1
  {% endset %}

  {% set timeframe_result = run_query(timeframe_query) %}

  {% if execute %}

    {% set timeframe = timeframe_result.columns[0].values()[0] %}

  {% else %}

    {% set timeframe = 1 %}

  {% endif %}

  WITH dates AS (

    SELECT
      DATEADD(
        DAY,
        '-' || ROW_NUMBER() OVER (ORDER BY NULL) + 1,
         CURRENT_DATE + INTERVAL '{{ var('gemma:dates:end_date') }}'
      ) AS date
    FROM TABLE (generator(rowcount => {{ timeframe }} ))

  ), final AS (

    SELECT
        TO_CHAR(date, 'YYYYMMDD') AS date_id
      , DATE(date) AS date
      , EXTRACT(DOY FROM date) AS year_day_num
      , date - DATE_TRUNC('quarter', date) + 1
        AS quarter_day_num
      , EXTRACT(DAY FROM date) AS month_day_num
      , EXTRACT(MONTH FROM date) AS month_num
      , TO_CHAR(date,'MMMM') AS month_name
      , TO_CHAR(date, 'Mon') AS month_abbreviated
      , DAY(DATE_TRUNC('month', date) + INTERVAL '1 month' - interval ' 1 day')
        AS month_days
      , TO_CHAR(date, 'YYYY-MM') AS year_month
      , EXTRACT(QUARTER FROM date) AS quarter_num
      , DAY(DATE_TRUNC('quarter', date) + INTERVAL '1 month' - interval ' 1 day')
        + DAY(DATE_TRUNC('quarter', date) + INTERVAL '2 month' - interval ' 1 day')
        + DAY(DATE_TRUNC('quarter', date) + INTERVAL '3 month' - interval ' 1 day')
        AS quarter_days
      , EXTRACT(YEAR FROM date) AS year
      , YEAR(date) AS iso_year
      , EXTRACT(YEAR FROM date - INTERVAL '1 year') AS previous_year
      , EXTRACT(QUARTER FROM date - INTERVAL '3 month') AS previous_quarter_num
      , EXTRACT(MONTH FROM date - INTERVAL '1 month') AS previous_month_num
      , EXTRACT(WEEK FROM date) AS year_week_num
      , EXTRACT(YEAR FROM date) || TO_CHAR(date, '-CW') || WEEKOFYEAR(date) AS year_week_name
      , DAYOFWEEKISO(date) AS weekday_num
      , DECODE(EXTRACT ('dayofweek_iso', date),
        1, 'Monday',
        2, 'Tuesday',
        3, 'Wednesday',
        4, 'Thursday',
        5, 'Friday',
        6, 'Saturday',
        7, 'Sunday')  AS weekday_name
      , DAYNAME(date) AS weekday_abbreviated
      , DAYOFWEEKISO(date) NOT IN (6,7) AS is_weekday
      , DATE(DATE_TRUNC('year', date)) AS year_first_day
      , DATE(DATE_TRUNC('year', date) + INTERVAL '1 year' - INTERVAL '1 day')
        AS year_last_day
      , DATE(DATE_TRUNC('quarter', date)) AS quarter_first_day
      , DATE(DATE_TRUNC('quarter', date) + INTERVAL '3 month' - INTERVAL '1 day')
        AS quarter_last_day
      , DATE(DATE_TRUNC('month', date)) AS month_first_day
      , DATE(DATE_TRUNC('month', date) + INTERVAL '1 month' - INTERVAL '1 day')
        AS month_last_day
      , DATE(DATE_TRUNC('week', date)) AS week_first_day
      , DATE(DATE_TRUNC('week', date) + INTERVAL '1 week' - INTERVAL '1 day')
        AS week_last_day
      , DATE(DATE_TRUNC('month', date - INTERVAL '1 month'))
        AS previous_month_first_day
      , DATE(DATE_TRUNC('month', date) - INTERVAL '1 day')
        AS previous_month_last_day
      , DATE(DATE_TRUNC('month', date + INTERVAL '1 month'))
        AS next_month_first_day
      , DATE(DATE_TRUNC('month', date) + INTERVAL '2 month' - INTERVAL '1 day')
        AS next_month_last_day
      , EXTRACT(YEAR FROM date) || '-Q' || EXTRACT(QUARTER FROM date) AS year_quarter
      , DENSE_RANK() OVER
        (ORDER BY
          EXTRACT(ISOYEAR FROM date)::TEXT ||
          EXTRACT(WEEK FROM date)::TEXT ASC
        )
          AS week_id

    FROM dates

  )

  SELECT * FROM final

{% else %}

  {% do exceptions.raise_compiler_error("This DB is not supported in dim_dates model") %}

{% endif %}
