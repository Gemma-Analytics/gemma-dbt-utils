{% macro base_ga4_event_postgres_query() %}

{{ config(enabled=var("gemma:ga4:enabled")) }}

  WITH events AS (

    SELECT * FROM {{ var("gemma:ga4:source") }}

  ), transforms AS (

    SELECT
        MD5(CAST(CONCAT(
          COALESCE(CAST(user_pseudo_id AS VARCHAR), ''), '-',
          COALESCE(CAST(event_timestamp AS VARCHAR), ''), '-',
          COALESCE(CAST(event_name AS VARCHAR), ''), '-',
          COALESCE(CAST(event_params AS VARCHAR), '')
        ) AS VARCHAR)) AS event_id
      , DATE(TO_TIMESTAMP(
          event_timestamp/1000000)
            AT TIME ZONE '{{ var('gemma:general:timezone') }}')
        AS event_date
      , TO_TIMESTAMP(event_timestamp/1000000) AS event_at
      , event_timestamp
      , TO_TIMESTAMP(user_first_touch_timestamp/1000000) AS user_first_touch_at
      , user_first_touch_timestamp
      , user_pseudo_id
      , event_name
      , stream_id::BIGINT AS stream_id
      , event_bundle_sequence_id
      , traffic_source->>'name' AS utm_campaign
      , traffic_source->>'medium' AS utm_medium
      , traffic_source->>'source' AS utm_source
      , platform
      , (user_ltv->>'revenue')::NUMERIC AS revenue
      , user_ltv->>'currency' AS currency
      , items
      , event_params
      , user_properties
      , device->>'browser' AS device_browser
      , device->>'category' AS device_category
      , device->>'language' AS device_language
      , device->>'vendor_id' AS device_vendor_id
      , device->>'advertising_id' AS device_advertising_id
      , device->>'browser_version' AS device_browser_version
      , device->>'operation_system' AS device_operating_system
      , device->>'mobile_brand_name' AS device_mobile_brand_name
      , device->>'mobile_model_name' AS device_mobile_model_name
      , device->>'mobile_marketing_name' AS device_mobile_marketing_name
      , device->>'is_limited_ad_tracking' AS is_limited_ad_tracking
      , device->>'mobile_os_hardware_model' AS device_mobile_os_hardware_model
      , device->>'operating_system_version' AS device_operating_system_version
      , device->>'time_zone_offset_seconds' AS device_time_zone_offset_seconds
      , geo->>'city' AS city
      , geo->>'metro' AS metro
      , geo->>'region' AS region
      , geo->>'country' AS country
      , geo->>'continent' AS continent
      , geo->>'sub_continent' AS sub_continent

    FROM events

  {%- for array in var('gemma:ga4:arrays') %}

), {{ array }}_cte AS (

    SELECT
        event_id

      , jsonb_object_agg({{ array }}.value->>'key', COALESCE(NULL
            , {{ array }}.value->'value'->>'int_value'
            , {{ array }}.value->'value'->>'float_value'
            , {{ array }}.value->'value'->>'double_value'
            , {{ array }}.value->'value'->>'string_value'
          )
        ) AS {{ array }}

    {%- if array == 'user_properties' %}

      , jsonb_object_agg({{ array }}.value->>'key',
            {{ array }}.value->'value'->>'set_timestamp_micros'
        ) AS {{ array }}_timestamp

    {%- endif %}

    FROM transforms
      LEFT JOIN jsonb_array_elements({{ array }}) AS {{ array }}
        ON TRUE
    WHERE {{ array }}.value->>'key' IS NOT NULL

    GROUP BY 1

    {% endfor -%}

  ), joins AS (

    SELECT
        transforms.event_id
      , transforms.event_date
      , transforms.event_at
      , transforms.event_timestamp
      , transforms.user_first_touch_at
      , transforms.user_first_touch_timestamp
      , transforms.user_pseudo_id
      , transforms.event_name
      , transforms.stream_id
      , transforms.event_bundle_sequence_id
      , transforms.utm_campaign
      , transforms.utm_medium
      , transforms.utm_source
      , transforms.platform
      , transforms.revenue
      , transforms.currency
      , transforms.items
      , transforms.device_browser
      , transforms.device_category
      , transforms.device_language
      , transforms.device_vendor_id
      , transforms.device_advertising_id
      , transforms.device_browser_version
      , transforms.device_operating_system
      , transforms.device_mobile_brand_name
      , transforms.device_mobile_model_name
      , transforms.device_mobile_marketing_name
      , transforms.is_limited_ad_tracking
      , transforms.device_mobile_os_hardware_model
      , transforms.device_operating_system_version
      , transforms.device_time_zone_offset_seconds
      , transforms.city
      , transforms.metro
      , transforms.region
      , transforms.country
      , transforms.continent
      , transforms.sub_continent
      {%- for array_name in var('gemma:ga4:arrays') %}

      , {{ array_name }}_cte.{{ array_name }}

      {%- endfor -%}

      {% for array_name, field in var('gemma:ga4:arrays').items() %}
        {%- for field_name, type in field.items() %}

      , ({{ array_name }}_cte.{{ array_name }}->>'{{ field_name }}')
            {%- if type -%} ::{{ type }} {%- endif %}
        AS {{ array_name }}_{{ field_name }}

         {%- endfor %}
      {%- endfor %}

    FROM transforms
    {% for array in var('gemma:ga4:arrays') %}

      LEFT JOIN {{ array }}_cte
        ON transforms.event_id = {{ array }}_cte.event_id

    {%- endfor %}

  ), calculations AS (

    SELECT
        *
      , CASE
          WHEN utm_source = '(direct)' AND (utm_medium = '(not set)'
            OR utm_medium = '(none)')
              THEN 'Direct'
          WHEN utm_medium = 'organic' THEN 'Organic search'
          WHEN utm_medium ~ E'^(social|social-network|social-media|sm|)$'
              OR utm_medium ~ E'^(social network|social media)$' THEN 'Social'
          WHEN utm_medium = 'email' THEN 'Email'
          WHEN utm_medium = 'affiliate' THEN 'Affiliates'
          WHEN utm_medium = 'referral' THEN 'Referral'
          WHEN utm_medium ~ E'^(cpc|ppc|paidsearch)$' THEN 'Paid Search'
          WHEN utm_medium ~ E' ^(cpv|cpa|cpp|content-text)$'
            THEN 'Other Advertising'
          WHEN utm_medium ~ E'^(display|cpm|banner)$' THEN 'Display'
          ELSE '(Other)'
        END AS default_channel_grouping
      , EXTRACT(EPOCH FROM
          MAX(event_at) OVER
            (PARTITION BY user_pseudo_id, event_params_ga_session_id)
          - MIN(event_at) OVER
            (PARTITION BY user_pseudo_id, event_params_ga_session_id)
        ) AS session_length_sec
      , CASE
          WHEN event_name = 'session_start'
            AND event_params_ga_session_number = 1
            THEN 1
          ELSE 0
        END AS is_new_user

    FROM joins

  )

  SELECT * FROM calculations


{% endmacro %}
