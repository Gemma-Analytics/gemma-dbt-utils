{{
    config(
      materialized='table',
      post_hook=["{{ gemma_dbt_utils.post_hook_index_id() }}"]
    )
}}



select
1 as id
union
select
2
union
select
3
{#
select
'ok1' as id
union
select
'ok2'
union
select
'ok3' #}