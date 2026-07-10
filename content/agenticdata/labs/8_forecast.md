## Lab 8: The Crystal Ball — Revenue Forecasting with AI.FORECAST and Data Canvas

<walkthrough-tutorial-duration duration="30"></walkthrough-tutorial-duration>
{{ author('Fabian Hirschmann', 'https://linkedin.com/in/fhirschmann') }}
<walkthrough-tutorial-difficulty difficulty="2"></walkthrough-tutorial-difficulty>
<bootkon-cloud-shell-note/>
<!-- Optional module: not wired into TUTORIAL.md. Renumber the "Lab N" title to match the event agenda when including. When wiring into TUTORIAL.md: merge src/optional/forecast/prompts.md into src/prompts.md and repoint the prompts.md link in "Materialize the forecast with Dataform". Not yet smoke-tested. -->

So far your platform explains the past. In this lab it starts predicting the future: you forecast Cymbal's daily revenue with a **single SQL function** — `AI.FORECAST`, backed by the **TimesFM** foundation model built into BigQuery — then let agy materialize the forecast as a proper gold mart in your Dataform project, and chart actuals against forecast in a **data canvas** using natural language.

Before you start: this lab assumes **Labs 1–3 are complete** — the medallion is built and `cymbal_gold.fct_daily_revenue` exists. Work in your main terminal as usual, and leave the tunnel (terminal 2) and the simulator (terminal 3) running untouched — everything here reads from BigQuery. The final section additionally needs the published `cymbal-data-agent` from Lab 5; it is clearly marked and skippable if you haven't done that lab.

### About TimesFM and AI.FORECAST

**TimesFM** is a foundation model for time series from Google Research, pre-trained on billions of time points — the forecasting equivalent of a pre-trained language model: it predicts new series *zero-shot*, without being trained on your data. BigQuery ML ships it **built in**, exposed through the GA table-valued function **`AI.FORECAST`**: no `CREATE MODEL`, no training job, no endpoint to deploy or manage — you hand it a query and get forecast rows back, accuracy comparable to classic statistical models like ARIMA. It has siblings: `AI.EVALUATE` scores forecasts against actuals, and `AI.DETECT_ANOMALIES` flags outliers — both wait for you in the challenge.

Learn more:
- [The AI.FORECAST function](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/bigqueryml-syntax-ai-forecast)
- [The built-in TimesFM model](https://docs.cloud.google.com/bigquery/docs/timesfm-model)
- [The AI.EVALUATE function](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/bigqueryml-syntax-ai-evaluate)
- [The AI.DETECT_ANOMALIES function](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/bigqueryml-syntax-ai-detect-anomalies)
- [BigQuery data canvas](https://docs.cloud.google.com/bigquery/docs/data-canvas)

### Ask for the future

How much history do you have to forecast from? Cymbal's seed data spans exactly **540 days** — 1 January 2025 through 24 June 2026 — and `fct_daily_revenue` holds one row per day *per currency*: 5 × 540 = 2,700 rows, plus a few partial rows for whatever the simulator had written by your last `dataform run`. Plenty (TimesFM needs only 3 points to say anything at all, and picks its context window automatically).

Open [BigQuery](https://console.cloud.google.com/bigquery) and run your first forecast — two weeks of EUR revenue:

```sql
SELECT *
FROM AI.FORECAST(
  (
    SELECT order_date, gross_revenue
    FROM `{{ PROJECT_ID }}.cymbal_gold.fct_daily_revenue`
    WHERE currency = 'EUR' AND order_date < CURRENT_DATE()
  ),
  data_col => 'gross_revenue',
  timestamp_col => 'order_date',
  horizon => 14)
ORDER BY forecast_timestamp
```

A word on the arguments: the first is just a query — the series to forecast; `data_col` and `timestamp_col` name the value and time columns; `horizon => 14` asks for 14 points into the future. The `WHERE` clause makes two deliberate choices: **one currency**, because a series that mixes euros and złoty is numeric nonsense (more on that in a minute), and **no current day**, because the simulator is still writing it — a half-finished day would drag the first forecast points down.

In a few seconds you get exactly 14 rows: `forecast_value` is the median prediction, flanked by `prediction_interval_lower_bound` and `_upper_bound` at the default 95% `confidence_level` (an empty `ai_forecast_status` means all went well). Note where the forecast starts: TimesFM continues the series from where your *data* ends — the day after the last complete day of history — not from today's wall-clock date.

❗ At a full-room event, a hundred first-ever `AI.FORECAST` calls can land at the same moment. If you see a transient error mentioning quota or rate limits, wait a few seconds and re-run the query — the function is stateless, and nothing is left half-built in your project.

### Materialize the forecast with Dataform

Ad-hoc queries convince you; marts serve everyone else — dashboards, colleagues, and (below) your data agent. Let's make the forecast a real gold table, produced by the same pipeline that builds the rest of the medallion. This time the whole table is forecast per currency in one call using `id_cols`, which tells TimesFM to treat each currency as its own independent series — the honest alternative to summing incompatible currencies into one. Writing SQLX is authoring work, so it goes to agy. Change into your Dataform project from Lab 3 and start your co-engineer:

```bash
cd ~/bootkon/content/agenticdata/src/dataform
agy
```

Then hand over the task (the prompt is also in <walkthrough-editor-open-file filePath="content/agenticdata/src/optional/forecast/prompts.md">prompts.md</walkthrough-editor-open-file>):

```
/goal Create definitions/fct_revenue_forecast.sqlx: a Dataform table in schema "cymbal_gold" carrying exactly one tag, "forecast" (not silver, not gold). It materializes a 14-day daily revenue forecast per currency from ${ref("fct_daily_revenue")} (columns order_date DATE, currency STRING, gross_revenue NUMERIC), excluding the current incomplete day (order_date < CURRENT_DATE()). Use BigQuery's GA table-valued function AI.FORECAST with its exact named arguments: the SELECT as first argument, then data_col => 'gross_revenue', timestamp_col => 'order_date', id_cols => ['currency'], horizon => 14, confidence_level => 0.95. From its output keep currency, forecast_timestamp cast to DATE as forecast_date, and forecast_value, prediction_interval_lower_bound, prediction_interval_upper_bound rounded to 2 decimals as forecast_revenue, lower_bound, upper_bound. Add a table description and column descriptions, then run `dataform compile` and fix any errors until it compiles cleanly.
```

**Review what agy wrote**: open <walkthrough-editor-open-file filePath="content/agenticdata/src/dataform/definitions/fct_revenue_forecast.sqlx">fct_revenue_forecast.sqlx</walkthrough-editor-open-file> and compare with the shipped reference <walkthrough-editor-open-file filePath="content/agenticdata/src/optional/forecast/fct_revenue_forecast.sqlx">in src/optional/forecast</walkthrough-editor-open-file>. If agy went off-script, the reference has your back:

```bash
cp ~/bootkon/content/agenticdata/src/optional/forecast/fct_revenue_forecast.sqlx ~/bootkon/content/agenticdata/src/dataform/definitions/
```

Exit agy and build it — the run finishes in well under a minute:

```bash
dataform run --tags forecast
```

The tag is the point: the new model carries *only* `forecast`, so your Lab 3 commands — `dataform run --tags silver` and `--tags gold` — still execute exactly what they did before, while the forecast refreshes only when asked. Re-run it any time; since bronze keeps moving and gold is one `dataform run` away, tomorrow's forecast can always ride on today's data.

Trust, but verify — back in the [BigQuery editor](https://console.cloud.google.com/bigquery):

```sql
SELECT currency, COUNT(*) AS days, MIN(forecast_date) AS first_day, MAX(forecast_date) AS last_day
FROM `{{ PROJECT_ID }}.cymbal_gold.fct_revenue_forecast`
GROUP BY currency
ORDER BY currency
```

Five currencies, 14 days each — 70 rows of future, starting the day after your history ends.

### Chart it in a data canvas

Numbers convince analysts; lines convince everyone. **Data canvas** is BigQuery's Gemini-powered analysis surface: you assemble tables, queries, and charts as connected nodes on a canvas and drive them with natural language.

In [BigQuery](https://console.cloud.google.com/bigquery), next to the **SQL query** button in the editor tab bar, click the **Create new** arrow, select **AI and knowledge**, then <walkthrough-spotlight-pointer locator="text('Data canvas')">Data canvas</walkthrough-spotlight-pointer>. Click **Search for data** and search in plain words:

```
cymbal revenue
```

The search reads the catalog's metadata (if you did Lab 4, that's the metadata you curated). Add both `fct_daily_revenue` and `fct_revenue_forecast` to the canvas. Then, on the `fct_daily_revenue` table node, click **Query** and describe what you want instead of writing it:

```
One row per day and series: the last 60 complete days of EUR actuals from fct_daily_revenue (order_date as day, gross_revenue as revenue, series = 'actual', excluding the current date), combined with all EUR rows of cymbal_gold.fct_revenue_forecast (forecast_date as day, forecast_revenue as revenue, series = 'forecast').
```

Gemini writes the SQL — **read it before you run it**, same as you review agy all day. If it took a wrong turn, replace the node's SQL with the known-good version:

```sql
WITH actuals AS (
  SELECT order_date, gross_revenue
  FROM `{{ PROJECT_ID }}.cymbal_gold.fct_daily_revenue`
  WHERE currency = 'EUR' AND order_date < CURRENT_DATE()
)
SELECT 'actual' AS series, order_date AS day, gross_revenue AS revenue
FROM actuals
WHERE order_date >= (SELECT DATE_SUB(MAX(order_date), INTERVAL 59 DAY) FROM actuals)
UNION ALL
SELECT 'forecast', forecast_date, forecast_revenue
FROM `{{ PROJECT_ID }}.cymbal_gold.fct_revenue_forecast`
WHERE currency = 'EUR'
ORDER BY day
```

(Why anchor the 60-day window on the *data's* `MAX(order_date)` rather than on today? Same lesson as the warm-up: the seed history ends on 24 June 2026, so a window counted back from today's date could miss the actuals entirely.)

Run the node, then click **Visualize** and pick the line chart. You can keep refining conversationally — try:

```
Line chart over day, one line per series, forecast in a different color
```

Look at the seam where the two series meet: the forecast picks up the level and the weekly rhythm of the actuals and carries them forward, with no model training anywhere in sight. Export the chart as a PNG if you want a souvenir.

❗ Data canvas is a **Gemini in BigQuery** feature, and some sandboxes gate it by org policy. If **Data canvas** doesn't appear under *Create new*, you lose the conversation but not the picture: run the known-good query above in the plain SQL editor and open the <walkthrough-spotlight-pointer locator="semantic({tab 'Visualization'})">Visualization</walkthrough-spotlight-pointer> tab (formerly *Chart*) in the query results pane — a line chart over `day` shows the same seam.

### Teach the data agent to see the future

**If you completed Lab 5**, your `cymbal-data-agent` is about to get an upgrade — otherwise skip ahead to the challenge; nothing below is needed there.

First, establish the "before". Open [BigQuery Agents](https://console.cloud.google.com/bigquery/agents_hub), on the **Agent Catalog** tab find the ``cymbal-data-agent`` card, open it, and start a conversation. Then stress-test it Lab 5 style with something forward-looking:

```
What will revenue look like next week?
```

The best it can do is admit its world ends at the latest `order_date` — or worse, improvise. That's the right behavior with nothing governed to stand on. Now there is something: a forecast mart, built by your pipeline, documented in your catalog. Wire it in:

1. Back on the **Agent Catalog** tab, open the agent for editing via the three-dot <walkthrough-spotlight-pointer locator="semantic({button 'Open actions'})">Open actions</walkthrough-spotlight-pointer> menu → **Edit**.
2. Under *Knowledge sources*, click <walkthrough-spotlight-pointer locator="semantic({button 'Add source'})">Add source</walkthrough-spotlight-pointer>, search for ``fct_revenue_forecast``, and add it as the fourth source.

Then append one rule to the agent instructions — it extends the "never sum across currencies" discipline into the future:

```
- fct_revenue_forecast: use for forward-looking questions ("what will", "next week", "forecast", "projection"). forecast_revenue is the median TimesFM forecast per currency and forecast_date; always report lower_bound and upper_bound alongside it, and never sum forecasts across currencies. For dates beyond the last forecast_date, say the forecast horizon ends there instead of guessing.
```

Click **Save**, then **Publish** — the published resource is what the API (and your Lab 6 analyst, if it's still running) sees. Now start a new conversation and ask for the future — anchored to the *data*, not the wall clock, same lesson as the warm-up:

```
What does our revenue forecast look like, per currency?
```

Watch the SQL it generates: a query against `cymbal_gold.fct_revenue_forecast`, per currency, medians with their intervals — governed data in, honest uncertainty out. That's the difference between an agent that *sounds* confident and one that has something to be confident about. (Re-ask the *"next week"* question too: if the seed's 14-day forecast window still covers next week, you now get numbers; at a later event, the agent tells you the horizon ends before then instead of guessing — the rule you just wrote, doing its job either way.)

### Challenge: interrogate the crystal ball

**\[TASK\]** Take up to 10 minutes — pick at least one:

1. **Backtest it**: how good would the forecast have been? `AI.EVALUATE` re-forecasts the past and scores it against what actually happened — hold out the last two seed weeks (11–24 June 2026) and measure. Run the shipped query <walkthrough-editor-open-file filePath="content/agenticdata/src/optional/forecast/challenge_backtest.sql">challenge_backtest.sql</walkthrough-editor-open-file> in the BigQuery editor and compare the five currencies: high-volume EUR usually beats thin PLN — volume smooths series, and smooth series forecast better. Discuss with your table how you would keep such a backtest honest in production (hint: it's one more tagged Dataform model).
2. **Upgrade the engine**: the default model is TimesFM 2.0. Re-run the warm-up query with `model => 'TimesFM 2.5'` — the newer generation with a much longer context window (up to 15,360 points vs 2,048). On 540 days of history the numbers will differ only modestly; ask agy when the difference *would* matter.
3. **Anomaly patrol**: `AI.DETECT_ANOMALIES` uses the same TimesFM machinery in reverse — forecast the past, then flag actuals that fall outside the prediction interval. Run <walkthrough-editor-open-file filePath="content/agenticdata/src/optional/forecast/challenge_anomalies.sql">challenge_anomalies.sql</walkthrough-editor-open-file> over the last 60 seed days: Cymbal's steady synthetic revenue should yield few flags — possibly none, which is itself the finding. If you did Lab 5, you already asked the agent about "days with unusually high revenue" — this puts that hunch on statistical footing.

Note: If you are stuck and cannot figure out how to proceed after a few minutes, ask your team captain.

### Success

🎉 Visionary{% if MY_NAME %}, {{ MY_NAME }}{% endif %}! One function call turned 540 days of governed history into a two-week revenue outlook — no model trained, no endpoint managed — and you shipped it properly: a tagged Dataform mart, a natural-language chart, and (if your agent got the upgrade) forward-looking answers with honest error bars. Cymbal no longer just knows what happened — it knows what's coming. 🔮
