{{
    config(
      materialized='table',
      post_hook=["{{ gemma_dbt_utils.create_index_if_col_exists(this, 'id', false, 'brin') }}"]
    )
}}


{#
select
1 as id
union
select
2
union
select
3 #}

select
'ok1' as id
union
select
'ok2'
union
select
'ok3'