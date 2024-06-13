# gemma-dbt-utils
Gemma Analytics utilities for dbt

This packages is expected to be used in addition to [dbt-utils](https://github.com/fishtown-analytics/dbt-utils) and expands upon it rather than replacing it.

## Macros

The following macros are available in this package:
- select_star_except

### select_star_except

Use this model in a PostgreSQL DWH to emulate the `SELECT * EXCEPT(table_name [, table_names])` behavior. Only works when referencing another table, does not work within CTEs.

##### Arguments

| Name | Example | Meaning |
| --- | --- | --- |
| table_relation | ref("a_model") | a dbt relation object (source or ref macro)|
| exceptions_list | ["column_name_a", "column_name_b"] | an iterable that contains the names of columns to be excepted |
| return_query | TRUE | Boolean: returns a full SELECT query if TRUE, only the comma-separated list of columns otherwise |

##### Example usages

```sql

-- Variant with return_query = False
SELECT {{ gemma_dbt_utils.select_star_except(
      ref("data_test_numeric_constraints")
    , ["type", "vat_pct"]
    , False
  )}}
FROM ref("data_test_numeric_constraints")

-- Is equivalent to this:

{{ gemma_dbt_utils.select_star_except(
    ref("data_test_numeric_constraints")
  , ["type", "vat_pct"]
  , True
) }}

```

## Models

These models are deactivated by default, but can be activatd and configured using variables in your `dbt_project.yml` file.

### FX aka Exchange Rates

The `gemma_fx` model is a single model for exchange rates. It works best with raw data from Yahoo Finance, such as supplied by the FX operator by the EWAH library. It takes the data for one or multiple currencies and combines it in a table, filling in data for days that miss data (usually because the date was a bank holiday), so that there is an exchange rate for each currency for each day.

You can configure it using variables:

| Variables | Default | Purpose |
| --- | --- | -- |
| gemma:fx:currencies | --- | Required Dictionary. Dictionary of currencies and their source. |
| gemma:fx:base_currency | USD | String. Primary currency ticker. Model will calculate exchange rates relative to this currency. If not USD, must be a key in gemma:fx:currencies. |
| gemma:fx:enabled | false | Boolean. Set to true to activate the model. |

The `gemma:fx:currencies` variable takes the currency as key and the table as value. To use the sources macro, which is recommended, supply the name of another variable as value, and set the variable to use the sources macro. It may look like this in your project's `dbt_project.yml` file:

```yaml
vars:
  # Set variables to configure the Gemma dbt utils package
  'gemma:fx:currencies':
    EUR: 'gemma:fx:eur'  # Give name of another variable
    CHF: 'gemma:fx:chf'  # (One could also directly give a schema.table string instead)
  'gemma:fx:eur': "{{ source('fx', 'eur') }}"  # Must do this to use source macro, though
  'gemma:fx:chf': "{{ source('fx', 'chf') }}"  # as dicts don't compile macros in values!
  'gemma:fx:base_currency': EUR
  'gemma:fx:enabled': true
```
### (Dim) Dates

This model will create the table `gemma_dates` in the schema `YOUR_SCHEMA_gemma_dbt_utils`. Starting from a defined date it will create a date series with different date columns until a specified number of days, e.g. 30 days after the current date. It works for postgres and bigquery - specified through the target type in the `profiles.yml`.
To reference this model in other models, use always the default name `gemma_dates` even if an alias name is provided for the `gemma:dates:table` variable.

The configurations are:

| Variables | Default | Purpose |
| --- | --- | --- |
| gemma:dates:timezone | 'Europe/Berlin' | Optional String. Sets the timezone for this model. By defaul, it's set to 'Europe/Berlin' |
| gemma:dates:enabled | false | Required Boolean. Set to true to activate the model|
| gemma:dates:start_date | '2020-01-01' | Optional String. Sets the `start_date` for the date series. By defaul, it's set to '2020-01-01'  |
| gemma:dates:end_date | '30 day' | Optional String. It is an interval relative to current_date, which sets the `end_date` for the date series. By defaul, it's set to '30 day' |
| gemma:dates:table | 'gemma_dates' | Optional String. Sets an alias for the model. By default, it's set to 'gemma_dates' |
| gemma:dates:schema | 'gemma_dbt_utils' | Optional String. Sets the a custom schema for the model. By default, it's set to 'gemma_dbt_utils' |

Example `dbt_project.yml`:
```yaml
vars:
  'gemma:dates:timezone': 'Europe/Berlin' # overwrite to get a different default value
  'gemma:dates:enabled': false # overwrite this variable to enable the date model
  'gemma:dates:start_date': '2020-01-01' # overwrite to get a different default value
  'gemma:dates:end_date': '30 day' # 30 days after the current date
  'gemma:dates:table': 'gemma_dates' # overwrite to get a different default value
  'gemma:dates:schema': 'gemma_dbt_utils' # overwrite to get a different default value
```

## Schema Tests

### numeric_constraints ([source](macros/schema_tests/numeric_constraints.sql))
This schema test asserts that a column of numerical value is within specified bounds.

Usage:
```yaml
version: 2
models:
  - name: model_name
    columns:
      - name: a_number
        tests:
          - gemma_dbt_utils.numeric_constraints:
              gte: 0
              lt: 180
```

Possible options:
```
eq:   equal
ne:   not equal
gt:   greater than
gte:  greater than or equal
lt:   lower than
lte:  lower than or equal
```

The macro accepts an optional parameter `condition` that allows for asserting
the `expression` on a subset of all records.

Usage:
```yaml
version: 2
models:
  - name: model_name
    columns:
      - name: a_number
        tests:
          - gemma_dbt_utils.numeric_constraints:
              eq: 1
              condition: "status = 'success'"
```
