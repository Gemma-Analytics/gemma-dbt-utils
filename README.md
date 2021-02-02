# gemma-dbt-utils
Gemma Analytics utilities for dbt

This packages is expected to be used in addition to [dbt-utils](https://github.com/fishtown-analytics/dbt-utils) and expands upon it rather than replacing it.

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
