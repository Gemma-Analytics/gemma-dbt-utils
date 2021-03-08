# gemma-dbt-utils
Gemma Analytics utilities for dbt

This packages is expected to be used in addition to [dbt-utils](https://github.com/fishtown-analytics/dbt-utils) and expands upon it rather than replacing it.

**Table of Contents**

- [Installation](#installation)
- [Contributing](#contributing)
  - [How to get started](#how-to-get-started)
  - [Requirements - Schema Tests](#requirements---schema-tests)
  - [Requirements - Models](#requirements---models)
- [Models](#models)
  - [FX aka Exchange Rates](#fx-aka-exchange-rates)
- [Schema Tests](#schema-tests)
  - [numeric_constraints](#numeric_constraints)

## Installation

Install this package in your project by adding it to your `packages.yml`:

```yaml
packages:
  - git: https://github.com/Gemma-Analytics/gemma-dbt-utils
    revision: v0.2.9  # Appropriate GitHub Release tag
```

## Contributing

Feel free to open PRs!

Make sure all contributions have the following:
- Sample data and usecases in the `integration_tests`
- Tests for correct behavior in the `integration_tests`
- Appropriate documentation in this README and, for models, in the appropriate schema.yml as well

### How to get started

Creating a dbt package can be unintuitive at first. This repository contains two dbt projects: the actual package and another, independent dbt project called `integration_tests` in the aptly identically named subfolder. The `integration_tests` project exists both for running the CICD pipeline and to help develop the package. When you develop the package locally, you will not run the package; instead, you should run the `integration_tests` project which uses the package as package. Only then can you be sure that the package actually works as expected.

Follow these steps to get started with developing the package:
1. Open a command prompt and `git clone` this repository, e.g. to `/dev/gemma-dbt-utils`
1. `cd /dev/gemma-dbt-utils/integration_tests` and create a virtual environment with `python -m venv env`
1. Activate the virtual environment (`env\scripts\activate` for windows or `source env/bin/activate` for Mac/Linux)
1. Install the appropriate dbt version, e.g. for dbt `0.19.0`: `pip install --upgrade dbt==0.19.0` (if you get an installation error, try updating pip first with `pip install --upgrade pip`)
1. Create a profile in your local `profiles.yml` called `integration_tests` that connects to a suitable development PostgreSQL database - note that the schema must be called `integration_tests`!
1. Windows: open a separate command prompt **with administrator priviliges**, cd to the `integration_tests` folder, activate the virtual environment, and run `dbt deps` - this is required to set the symlink* (you can close this command prompt afterwards, all other commands are in a normal command prompt)
1. Run `dbt seed && dbt run && dbt test` to check that it all works
1. Develop
    - Make changes to the package
    - Run `dbt seed && dbt run && dbt test`
    - See if you get the results you expect
    - Repeat
1. When ready, open a PR with your changes into `staging`
    - Make sure you have documented your models and added appropriate tests - take a look at the existing models and tests to get an idea how to proceed

*The package is installed via symlink -> the `integration_tests` project creates a symbolic link to the higher-level package and that way auto-updates whenever you make any changes to the package

### Requirements - Schema Tests

If you add a new schema test, you need at least the following:
- The test itself in `gemma-dbt-utils/macros/schema_tests`
- Dummy data to validate that the test works as expected in `gemma-dbt-utils/integration_tests/data/schema_tests/`
- Use the test on the dummy data by adding the appropriate lines of code in `gemma-dbt-utils/integration_tests/schema_tests/schema.yml`

### Requirements - Models

If you add new models, you need at least the following:
- The model(s) in `gemma-dbt-utils/models`
- A proper description of your model in this `README.md` below
- Activation of the model in the `integration_tests`
- Seed data in `integration_tests` as raw data to use for your model, if needed/assumed
- Seed data in `integration_tests` that is the expected result of your model as set up in `integration_tests`
- A data test in `gemma-dbt-utils/integration_tests/tests` to make sure your model works as expected

## Models

These models are deactivated by default, but can be activated and configured using variables in your `dbt_project.yml` file.

### FX aka Exchange Rates

The `gemma_fx` model is a single model for exchange rates. It works best with raw data from Yahoo Finance, such as supplied by the FX operator by the EWAH library. It takes the data for one or multiple currencies and combines it in a table, filling in data for days that miss data (usually because the date was a bank holiday), so that there is an exchange rate for each currency for each day.

You can configure it using variables:

| Variables | Default | Purpose |
| --- | --- | -- |
| gemma:fx:currencies | --- | Required Dictionary. Dictionary of currencies and their source.* |
| gemma:fx:base_currency | USD | String. Primary currency ticker. Model will calculate exchange rates relative to this currency. If not USD, must be a key in gemma:fx:currencies. |
| gemma:fx:enabled | false | Boolean. Set to true to activate the model. |
| gemma:fx:column_date | formatted_date::DATE | Date column in the source data.  |
| gemma:fx:column_rate | adjclose | FX Rate column in the source data. Data shall be in USD/XXX format. E.g. on 2021-02-02 the USD/EUR value was roughly 0.83. |

*The `gemma:fx:currencies` variable takes the currency as key and the table as value. To use the sources macro, which is recommended, supply the name of another variable as value, and set the variable to use the sources macro. It may look like this in your project's `dbt_project.yml` file:

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

### numeric_constraints

([source](macros/schema_tests/numeric_constraints.sql))

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
