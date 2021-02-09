# gemma-dbt-utils
Gemma Analytics utilities for dbt. Right now supports only PostgreSQL.

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

### GA4 Events

The `gemma_ga4_events` is a model for Google Analytics 4 events. GA4 properties
have a direct data connection to BigQuery, which is the main source for this data.
Running this model will create a `YOUR_SCHEMA_gemma_dbt_utils` schema and `gemma_ga4_events` table.

| Variables | Default | Purpose |
| --- | --- | --- |
| gemma:ga4:enabled | false | Required Boolean. Set to true to activate the model. |
| gemma:ga4:source | "{{ source('bq', 'events') }}" | Required String. Should point to the BigQuery row data source table |
| gemma:ga4:properties | -- | Dictionary. To select specific event columns add a new key with the correct name. There are following properties: `app_info`, `device`, `ecommerce`, `event_dimensions`, `geo`, `traffic_source`, `user_ltv`. Selecting a key will create multiple columns related to the property ([link](https://support.google.com/firebase/answer/7029846?hl=en)) |
| gemma:ga4:arrays | -- | Dictionary. Creates from selected parameters columns. We have two arrays: `event_params` and `user_properties`. Both have multiple parameters, for `event_params` the most prominent is `ga_session_id` and for `user_properties` the `user_id`. There are automatically ([link](https://support.google.com/analytics/answer/9234069)) and manually added parameters that can be choosen. There is a third array column that is called `items` but that should be unnested in a later and separate model. If known, we can cast the extracted parameter to a specific type e.g. `ga_session_id: BIGINT`. |

Example `dbt_project.yml`:
```yaml
vars:
  'gemma:ga4:enabled': true
  'gemma:ga4:source': "{{ source('bigquery', 'ga_events') }}" # not default source
  'gemma:ga4:properties': # remove or comment out if not needed, dont forget sub-dicts
    app_info: # every property can be removed
    traffic_source:
  'gemma:ga4:arrays': # remove or comment out if not needed, dont forget sub-dicts
    event_params:
      ga_session_id: BIGINT
      ga_session_number: # no column type needed
    user_properties:
      user_id: # leave this empty and the result column will be String type
```

### (Dim) Dates

This model will create the table `gemma_dates` in the schema `YOUR_SCHEMA_gemma_dbt_utils`. Starting from a date it will create a date series with different date columns until 30 days from running date.
The configurations are:

| Variables | Default | Purpose |
| --- | --- | --- |
| gemma:dates:timezone | "Europe/Berlin" | Required String. Sets the timezone for this model |
| gemma:dates:enabled | false | Required Boolean. Set to true to activate the model|
| gemma:dates:start_date | '2020-01-01' | Required String. Sets the `start_date` for the date series |

Example `dbt_project.yml`:
```yaml
vars:
  'gemma:dates:timezone': 'Europe/Berlin'
  'gemma:dates:enabled': true
  'gemma:dates:start_date': '2000-01-01'
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
