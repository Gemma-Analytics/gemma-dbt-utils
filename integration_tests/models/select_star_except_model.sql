-- TODO: Only run on PostgreSQL
{{ gemma_dbt_utils.select_star_except(ref("gemma_fx"), ["base_currency", "fx_rate", "I do not exist"], True) }}
