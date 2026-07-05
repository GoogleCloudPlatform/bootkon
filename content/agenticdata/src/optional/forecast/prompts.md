# Canonical agy prompts — optional forecast lab

Local mirror for the optional forecast lab, in the same format as
`content/agenticdata/src/prompts.md`. When the lab is wired into TUTORIAL.md,
merge this section into that file and repoint the lab's prompts.md link.

## Lab 8 — the forecast mart

Run inside `~/bootkon/content/agenticdata/src/dataform`:

```
/goal Create definitions/fct_revenue_forecast.sqlx: a Dataform table in schema
"cymbal_gold" carrying exactly one tag, "forecast" (not silver, not gold). It
materializes a 14-day daily revenue forecast per currency from
${ref("fct_daily_revenue")} (columns order_date DATE, currency STRING,
gross_revenue NUMERIC), excluding the current incomplete day
(order_date < CURRENT_DATE()). Use BigQuery's GA table-valued function
AI.FORECAST with its exact named arguments: the SELECT as first argument, then
data_col => 'gross_revenue', timestamp_col => 'order_date',
id_cols => ['currency'], horizon => 14, confidence_level => 0.95. From its
output keep currency, forecast_timestamp cast to DATE as forecast_date, and
forecast_value, prediction_interval_lower_bound,
prediction_interval_upper_bound rounded to 2 decimals as forecast_revenue,
lower_bound, upper_bound. Add a table description and column descriptions,
then run `dataform compile` and fix any errors until it compiles cleanly.
```

Fallback: `cp content/agenticdata/src/optional/forecast/fct_revenue_forecast.sqlx content/agenticdata/src/dataform/definitions/`
