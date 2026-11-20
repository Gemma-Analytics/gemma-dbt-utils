{% test numeric_constraints(model, column_name, condition='true', eq=none, ne=none, gt=none, gte=none, lt=none, lte=none) %}

with meet_condition as (

    select * from {{ model }} where {{ condition }}

),
validation_errors as (

    select
        *
    from meet_condition
    where not (true
      {% if eq is not none %} and {{ column_name }} = {{ eq }} {% endif %}
      {% if ne is not none %} and {{ column_name }} <> {{ ne }} {% endif %}
      {% if gt is not none %} and {{ column_name }} > {{ gt }} {% endif %}
      {% if gte is not none %} and {{ column_name }} >= {{ gte }} {% endif %}
      {% if lt is not none %} and {{ column_name }} < {{ lt }} {% endif %}
      {% if lte is not none %} and {{ column_name }} <= {{ lte }} {% endif %}
    )

)

-- the test fails if any row is returned
select *
from validation_errors

{% endtest %}
