{{
    config(
      post_hook=[
      "{{ gemma_dbt_utils.grant_read('utils_test', 'integration_tests') }}"
      ]
    )
}}


select
*
from {{ref('gemma_fx')}}