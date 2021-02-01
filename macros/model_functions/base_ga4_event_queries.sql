{% macro base_ga4_events_postgres_query() %}

{{ config(enabled=var("gemma:ga4:enabled")) }}

  WITH events AS (

    SELECT 1

  ), transforms AS (

    SELECT
        {{ dbt_utils.surrogate_key(
          ["user_pseudo_id", "event_timestamp", "event_name", "event_params"]
        ) }} AS event_id
      , DATE(TO_TIMESTAMP(
          event_timestamp/1000000) AT TIME ZONE '{{ var('gemma:general:timezone') }}')
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

  {% for array in var('gemma:ga4:arrays') %}

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

    {% if array == 'user_properties' %}

      , jsonb_object_agg({{ array }}.value->>'key',
            {{ array }}.value->'value'->>'set_timestamp_micros'
        ) AS user_properties_timestamp

    {% endif %}

    FROM transforms
      LEFT JOIN jsonb_array_elements({{ array }})
        ON TRUE
    WHERE {{ array }}.value->>'key' IS NOT NULL

    GROUP BY 1

    {% endfor %}

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
      , (params.event_params->>'ga_session_id')::BIGINT AS session_id
      , (params.event_params->>'ga_session_number')::INT AS session_number
      , (params.event_params->>'engagement_time_msec')::BIGINT
        AS engagement_time_msec
      , params.event_params->>'gclid' AS gcl_id
      , params.event_params->>'campaign' AS session_campaign
      , params.event_params->>'content' AS session_content
      , params.event_params->>'medium' AS session_medium
      , params.event_params->>'source' AS session_source
      , params.event_params->>'search_term' AS session_search_term
      , params.event_params->>'term' AS session_term
      , params.event_params->>'page_referrer' AS page_referrer
      , params.event_params->>'page_path' AS page_path
      , params.event_params->>'page_location' AS page_location
      , params.event_params->>'page_title' AS page_title
      , params.event_params->>'link_url' AS link_url
      , (params.event_params->>'outbound')::BOOLEAN AS is_link_outbound
      , (params.event_params->>'session_engaged')::BOOLEAN
        AS is_engaged_session
      , (params.event_params->>'engaged_session_event')::BOOLEAN
        AS is_engaged_session_event
      , params.event_params
      , props.user_props->>'user_id' AS user_id
      , (props.user_properties_timestamp->>'user_id')::BIGINT AS user_id_timestamp
      , TO_TIMESTAMP(
          (props.user_properties_timestamp->>'user_id')::BIGINT/1000000)
        AS user_id_set_at

    FROM transforms
    {% for array in var('gemma:ga4:arrays') %}

      LEFT JOIN {{ array }}_cte
        ON transforms.event_id = {{ array }}.event_id

    {% endfor %}

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
      , CASE
          WHEN session_source = '(direct)' AND (session_medium = '(not set)'
            OR session_medium = '(none)') THEN 'Direct'
          WHEN session_medium = 'organic' THEN 'Organic search'
          WHEN session_medium ~ E'^(social|social-network|social-media|sm|)$'
            OR session_medium ~ E'^(social network|social media)$' THEN 'Social'
          WHEN session_medium = 'email' THEN 'Email'
          WHEN session_medium = 'affiliate' THEN 'Affiliates'
          WHEN session_medium = 'referral' THEN 'Referral'
          WHEN session_medium ~ E'^(cpc|ppc|paidsearch)$' THEN 'Paid Search'
          WHEN session_medium ~ E' ^(cpv|cpa|cpp|content-text)$'
            THEN 'Other Advertising'
          WHEN session_medium ~ E'^(display|cpm|banner)$' THEN 'Display'
          ELSE '(Other)'
        END AS session_default_channel_grouping
      , EXTRACT(EPOCH FROM
          MAX(event_at) OVER (PARTITION BY user_pseudo_id, session_id)
          - MIN(event_at) OVER (PARTITION BY user_pseudo_id, session_id))
        AS session_length_sec
      , CASE
          WHEN event_name = 'session_start' AND session_number = 1
            THEN 1
          ELSE 0
        END AS is_new_user
      , CASE
          WHEN is_engaged_session
            THEN CONCAT(user_pseudo_id, session_id)
          ELSE NULL
        END AS engaged_session_id
      , CONCAT(user_pseudo_id, session_id) AS unique_session_id

    FROM joins

  )

  SELECT * FROM calculations


{% endmacro %}
