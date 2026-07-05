# Brief: the Cymbal Day-2 Ops dashboard (Cloud Monitoring, as code)

Written for an AI coding agent. Your task: create **`dashboard.json`** in THIS
directory (`content/agenticdata/src/optional/day2_ops/`) — a Cloud Monitoring
dashboard definition that a human deploys with
`gcloud monitoring dashboards create --config-from-file=dashboard.json`.

The dashboard watches one CDC pipeline end to end:
Cloud SQL Postgres (`cymbal-oltp`) → Datastream (`cymbal-cdc-stream`) →
BigQuery (`cymbal_bronze`). It must answer, at a glance and at 3 a.m.:
*is data flowing, and if not, which hop is broken?*

## Output contract

- Valid **JSON only**: double quotes, no comments, no trailing commas.
- Use the **Cloud Monitoring Dashboard API v1** shape, exactly this skeleton:

```json
{
  "displayName": "Cymbal Day-2 Ops",
  "gridLayout": {
    "columns": "2",
    "widgets": [
      {
        "title": "<per the table below>",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"...\" resource.type=\"...\"",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "<per the table below>"
                  }
                }
              },
              "plotType": "LINE"
            }
          ],
          "yAxis": { "label": "<unit>", "scale": "LINEAR" }
        }
      }
    ]
  }
}
```

- `filter` is a single string: `metric.type="..." resource.type="..."`,
  space-separated. Do not add per-resource filters — this project contains
  exactly one stream and one instance, so project scope is enough.
- Do not invent widgets, fields, or metric types beyond this brief.

## The six widgets, in exactly this order

`gridLayout` places widgets row by row (2 columns), so this order pairs each
pipeline hop with its source-side counterpart:

| # | title | metric.type | resource.type | aligner | yAxis label |
|---|---|---|---|---|---|
| 1 | `Datastream - data freshness (s)` | `datastream.googleapis.com/stream/freshness` | `datastream.googleapis.com/Stream` | `ALIGN_MAX` | `seconds` |
| 2 | `Cloud SQL - PostgreSQL connections` | `cloudsql.googleapis.com/database/postgresql/num_backends` | `cloudsql_database` | `ALIGN_MEAN` | `connections` |
| 3 | `Datastream - throughput (events/s)` | `datastream.googleapis.com/stream/event_count` | `datastream.googleapis.com/Stream` | `ALIGN_RATE` | `events/s` |
| 4 | `Cloud SQL - CPU utilization` | `cloudsql.googleapis.com/database/cpu/utilization` | `cloudsql_database` | `ALIGN_MEAN` | `utilization (0-1)` |
| 5 | `BigQuery Storage Write API - ingested rows/min` | `bigquerystorage.googleapis.com/write/uploaded_row_count` | `bigquery_project` | `ALIGN_SUM` | `rows/min` |
| 6 | `Datastream - unsupported events` | `datastream.googleapis.com/stream/unsupported_event_count` | `datastream.googleapis.com/Stream` | `ALIGN_SUM` | `events` |

These metric types are **verified against the July 2026 metrics list** — use
them character for character, even if you believe a different name. In
particular: Datastream metrics live under `datastream.googleapis.com/stream/*`
(singular `stream`), and the Datastream monitored resource type is the full
string `datastream.googleapis.com/Stream`.

## Widget 1 extra: the SLO line

Widget 1 (data freshness) additionally gets a threshold line, as a sibling of
`dataSets` inside its `xyChart`:

```json
"thresholds": [
  { "value": 120, "label": "Freshness SLO (120 s)" }
]
```

Do NOT add `color` or `direction` fields — the API rejects both inside an
xyChart threshold (`INVALID_ARGUMENT`, verified live against the API; those
fields belong to scorecard thresholds). `value` and `label` are enough; the
console draws the line red on its own.

`stream/freshness` is a GAUGE in **seconds**: how far Datastream lags behind
the source WAL (0 when fully caught up). 120 seconds is Cymbal's freshness
SLO — the same threshold the on-call alert uses.

## Done when

- `dashboard.json` parses as JSON (`python3 -m json.tool dashboard.json`).
- It contains exactly 6 widgets in the order above, with the exact metric
  types, aligners, and the one threshold from this brief.
