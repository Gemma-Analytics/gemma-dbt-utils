{% macro get_current_table_from_snap_model(base_relation) %}
  {#
   # This macro returns a SELECT statement that returns the current version of a table
   # that is being snapshotted by dbt. It expects the base_relation to either have a
   # column called "dbt_valid_to" (as snapshot tables do) or a boolean called
   # "is_current", which is a best practice if using a table derived from a snapshot.
   #
   # Arguments:
   #  base_relation   a dbt relation object (source of ref macro call)
   #
   # Sample call:
   #
   #  {{ get_current_table_from_snap_base(ref("snap_hubspot_deals")) }}
   #
   #}

  {%- set ignore_columns = ["valid_from", "valid_to", "is_current", "dbt_scd_id", "dbt_updated_at", "dbt_valid_from", "dbt_valid_to"] -%}
  {{ select_star_except(base_relation, ignore_columns, True) }}

  {%- set base_rel_cols = get_columns(base_relation) -%}

  {%- if "is_current" in base_rel_cols -%}
    WHERE is_current
  {%- elif "dbt_valid_to" in base_rel_cols -%}
    WHERE dbt_valid_to IS NULL
  {%- else -%}
    {{ exceptions.raise_compiler_error(
      "Error: neither columns is_current or dbt_valid_to exist in model!"
    ) }}
  {%- endif -%}

{% endmacro %}
