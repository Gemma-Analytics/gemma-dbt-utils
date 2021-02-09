{% macro base_ga4_event_postgres_query() %}

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
            AT TIME ZONE '{{ var('gemma:dates:timezone') }}')
        AS event_date
      , TO_TIMESTAMP(event_timestamp/1000000) AS event_at
      , event_timestamp
      , TO_TIMESTAMP(user_first_touch_timestamp/1000000) AS user_first_touch_at
      , user_first_touch_timestamp
      , user_pseudo_id
      , event_name
      , stream_id::BIGINT AS stream_id
      , event_bundle_sequence_id
      , items
      , event_params
      , user_properties
      , platform
  {# extract values from event properties #}
{%- if var('gemma:ga4:properties') -%}
  {%- for property in var('gemma:ga4:properties') -%}
    {%- if property == 'app_info' %}
      , {{ property }}->>'id' AS {{ property}}_id
      , {{ property }}->>'version' AS {{ property}}_version
      , {{ property }}->>'install_store' AS {{ property}}_install_store
      , {{ property }}->>'firebase_app_id' AS {{ property}}_firebase_app_id
      , {{ property }}->>'install_source' AS {{ property}}_install_source

    {%- elif property == 'device' %}
      , {{ property }}->>'browser' AS {{ property }}_browser
      , {{ property }}->>'category' AS {{ property }}_category
      , {{ property }}->>'language' AS {{ property }}_language
      , {{ property }}->>'vendor_id' AS {{ property }}_vendor_id
      , {{ property }}->>'advertising_id' AS {{ property }}_advertising_id
      , {{ property }}->>'browser_version' AS {{ property }}_browser_version
      , {{ property }}->>'operating_system' AS {{ property }}_operating_system
      , {{ property }}->>'mobile_brand_name' AS {{ property }}_mobile_brand_name
      , {{ property }}->>'mobile_model_name' AS {{ property }}_mobile_model_name
      , {{ property }}->>'mobile_marketing_name' AS {{ property }}_mobile_marketing_name
      , {{ property }}->>'is_limited_ad_tracking' AS {{ property }}_is_limited_ad_tracking
      , {{ property }}->>'mobile_os_hardware_model' AS {{ property }}_mobile_os_hardware_model
      , {{ property }}->>'operating_system_version' AS {{ property }}_operating_system_version
      , {{ property }}->>'time_zone_offset_seconds' AS {{ property }}_time_zone_offset_seconds
      , {{ property }}->'web_info'->>'browser' AS {{ property }}_web_info_browser
      , {{ property }}->'web_info'->>'browser_version' AS {{ property }}_web_info_browser_version
      , {{ property }}->'web_info'->>'hostname' AS {{ property }}_web_info_hostname

    {%- elif property == 'ecommerce' %}
      , {{ property }}->>'total_item_quantity' AS {{ property }}_total_item_quantity
      , {{ property }}->>'purchase_revenue_in_usd' AS {{ property }}_purchase_revenue_in_usd
      , {{ property }}->>'purchase_revenue' AS {{ property }}_purchase_revenue
      , {{ property }}->>'refund_value_in_usd' AS {{ property }}_refund_value_in_usd
      , {{ property }}->>'refund_revenue' AS {{ property }}_refund_value
      , {{ property }}->>'shipping_value_in_usd' AS {{ property }}_shipping_value_in_usd
      , {{ property }}->>'shipping_value' AS {{ property }}_shipping_value
      , {{ property }}->>'tax_value_in_usd' AS {{ property }}_tax_value_in_usd
      , {{ property }}->>'tax_value' AS {{ property }}_tax_value
      , {{ property }}->>'unique_items' AS {{ property }}_unique_items
      , {{ property }}->>'transaction_id' AS {{ property }}_transaction_id

    {%- elif property == 'event_dimensions' %}
      , {{ property }}

    {%- elif property == 'geo' %}
      , {{ property }}->>'city' AS {{ property }}_city
      , {{ property }}->>'metro' AS {{ property }}_metro
      , {{ property }}->>'region' AS {{ property }}_region
      , {{ property }}->>'country' AS {{ property }}_country
      , {{ property }}->>'continent' AS {{ property }}_continent
      , {{ property }}->>'sub_continent' AS {{ property }}_sub_continent

    {%- elif property == 'traffic_source' %}
      , {{ property }}->>'name' AS {{ property }}_campaign
      , {{ property }}->>'medium' AS {{ property }}_medium
      , {{ property }}->>'source' AS {{ property }}_source

    {%- elif property == 'user_ltv' %}
      , {{ property }}->>'revenue' AS {{ property }}_revenue
      , {{ property }}->>'currency' AS {{ property }}_currency

    {%- endif -%}
  {%- endfor -%}
{%- endif %}
    FROM events

  {# unnest arrays and put the elements later into a dictionary #}
{%- if var('gemma:ga4:arrays') -%}
  {%- for array in var('gemma:ga4:arrays') %}
    {% if array == 'items' -%}
     {# CATCH ITEMS ARRAY, items array should be unnested in an own model #}
    {% else -%}

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
      {# user_properties have two values in the same dictionary value of a key #}
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

    {%- endif -%}

  {%- endfor -%}
{%- endif %}

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
      , transforms.platform
  {# create columns based on the chosen properties #}
{%- if var('gemma:ga4:properties') -%}
  {%- for property in var('gemma:ga4:properties') -%}
    {%- if property == 'app_info' %}
      , transforms.{{ property }}_id
      , transforms.{{ property }}_version
      , transforms.{{ property }}_install_store
      , transforms.{{ property }}_firebase_app_id
      , transforms.{{ property }}_install_source

    {%- elif property == 'device' %}
      , transforms.{{ property }}_browser
      , transforms.{{ property }}_category
      , transforms.{{ property }}_language
      , transforms.{{ property }}_vendor_id
      , transforms.{{ property }}_advertising_id
      , transforms.{{ property }}_browser_version
      , transforms.{{ property }}_operating_system
      , transforms.{{ property }}_mobile_brand_name
      , transforms.{{ property }}_mobile_model_name
      , transforms.{{ property }}_mobile_marketing_name
      , transforms.{{ property }}_is_limited_ad_tracking
      , transforms.{{ property }}_mobile_os_hardware_model
      , transforms.{{ property }}_operating_system_version
      , transforms.{{ property }}_time_zone_offset_seconds

    {%- elif property == 'ecommerce' %}
      , transforms.{{ property }}_total_item_quantity
      , transforms.{{ property }}_purchase_revenue_in_usd
      , transforms.{{ property }}_purchase_revenue
      , transforms.{{ property }}_refund_value_in_usd
      , transforms.{{ property }}_refund_value
      , transforms.{{ property }}_shipping_value_in_usd
      , transforms.{{ property }}_shipping_value
      , transforms.{{ property }}_tax_value_in_usd
      , transforms.{{ property }}_tax_value
      , transforms.{{ property }}_unique_items
      , transforms.{{ property }}_transaction_id

    {%- elif property == 'event_dimensions' %}
      , transforms.{{ property }}

    {%- elif property == 'geo' %}
      , transforms.{{ property }}_city
      , transforms.{{ property }}_metro
      , transforms.{{ property }}_region
      , transforms.{{ property }}_country
      , transforms.{{ property }}_continent
      , transforms.{{ property }}_sub_continent

    {%- elif property == 'traffic_source' %}
      , transforms.{{ property }}_campaign
      , transforms.{{ property }}_medium
      , transforms.{{ property }}_source

    {%- elif property == 'user_ltv' %}
      , transforms.{{ property }}_revenue
      , transforms.{{ property }}_currency

    {%- endif -%}
  {%- endfor -%}
{%- endif %}
      , transforms.items
  {# create unnested array columns event_params, user properties but not items
     items should be unnested in an additional model later #}
{%- if var('gemma:ga4:arrays') -%}
  {%- for array_name in var('gemma:ga4:arrays') %}
    {%- if array_name == 'items' -%}
     {# CATCH ITEMS ARRAY, items array should be unnested in an own model #}
    {%- else %}
      , {{ array_name }}_cte.{{ array_name }}
    {% endif -%}
  {%- endfor -%}
{% endif -%}

  {# Interate over the chosen event parameters #}
{%- if var('gemma:ga4:arrays').0 -%}
  {%- for array_name, field in var('gemma:ga4:arrays').items() %}
    {% if array_name == 'items' -%}
     {# CATCH ITEMS ARRAY, items array should be unnested in an own model #}
    {% else -%}
    {%- for field_name, type in field.items() %}

      , ({{ array_name }}_cte.{{ array_name }}->>'{{ field_name }}')
            {%- if type -%} ::{{ type }} {%- endif %}
        AS {{ array_name }}_{{ field_name }}

     {%- endfor %}
     {%- endif %}
  {%- endfor -%}
{%- endif %}

    FROM transforms

  {%- if var('gemma:ga4:arrays') -%}
  {%- for array in var('gemma:ga4:arrays') %}

      LEFT JOIN {{ array }}_cte
        ON transforms.event_id = {{ array }}_cte.event_id

  {%- endfor -%}
  {%- endif %}

  ), final AS (

    SELECT
        *

    {%- if var('gemma:ga4:properties').traffic_source %}
      , CASE
          WHEN traffic_source_source = '(direct)'
            AND (traffic_source_medium = '(not set)'
              OR traffic_source_medium = '(none)')
            THEN 'Direct'
          WHEN traffic_source_medium = 'organic'
            THEN 'Organic search'
          WHEN traffic_source_medium ~ E'^(social|social-network|social-media|sm|)$'
              OR traffic_source_medium ~ E'^(social network|social media)$'
            THEN 'Social'
          WHEN traffic_source_medium = 'email'
            THEN 'Email'
          WHEN traffic_source_medium = 'affiliate'
            THEN 'Affiliates'
          WHEN traffic_source_medium = 'referral'
            THEN 'Referral'
          WHEN traffic_source_medium ~ E'^(cpc|ppc|paidsearch)$'
            THEN 'Paid Search'
          WHEN traffic_source_medium ~ E' ^(cpv|cpa|cpp|content-text)$'
            THEN 'Other Advertising'
          WHEN traffic_source_medium ~ E'^(display|cpm|banner)$'
            THEN 'Display'
          ELSE '(Other)'
        END AS default_channel_grouping
    {%- endif -%}

    {%- if var('gemma:ga4:arrays').ga_session_id %}
      , EXTRACT(EPOCH FROM MAX(event_at) OVER w - MIN(event_at) OVER w)
        AS session_length_sec
    {% endif -%}

    {%- if var('gemma:ga4:arrays').ga_session_number %}
      , CASE
          WHEN event_name = 'session_start'
            AND event_params_ga_session_number = 1
            THEN 1
          ELSE 0
        END AS is_new_user
    {%- endif %}

    FROM joins

  {%- if var('gemma:ga4:arrays').ga_session_id %}
    WINDOW w AS (PARTITION BY user_pseudo_id, event_params_ga_session_id)
  {%- endif %}
  )

  SELECT * FROM final


{% endmacro %}
