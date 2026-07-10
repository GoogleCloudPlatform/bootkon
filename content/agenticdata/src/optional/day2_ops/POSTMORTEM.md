# Postmortem: bronze freeze — Datastream replication login lockout

*Reference example, shipped with the lab. Yours (written with agy from your
own incident timeline) will differ in times and detail — compare with
`git -C ~/bootkon diff content/agenticdata/src/optional/day2_ops/POSTMORTEM.md`.*

- **Status:** resolved
- **Severity:** SEV-2 — analytics data staleness; **no data loss**
- **Systems:** Cloud SQL `cymbal-oltp` → Datastream `cymbal-cdc-stream` → BigQuery `cymbal_bronze`

## Summary

The CDC stream `cymbal-cdc-stream` stopped replicating for roughly 15 minutes
after the replication role `datastream_user` was set to `NOLOGIN` and its
active replication connection was terminated. The source database remained
fully available; operational writes were never affected. Bronze (and every
layer built on it) served increasingly stale data until the role was restored
and Datastream reconnected. The replication slot `cymbal_slot` retained WAL
for the entire outage, so replication resumed from the exact position where
it stopped — zero events lost.

## Impact

- BigQuery `cymbal_bronze` data freshness degraded from <60 s to a peak of
  ~15 minutes. Downstream silver/gold marts and the Cymbal data agent served
  stale (not wrong) numbers.
- No impact on the order platform: Postgres accepted every write throughout.
- No data loss: post-recovery, `MAX(order_id)` in bronze caught up with the
  source within minutes.

## Timeline (UTC, T0 = chaos injection)

| Time | Event |
|---|---|
| T0 | `chaos.sh` sets `datastream_user` to `NOLOGIN` and terminates its backend. |
| T0+1m | Dashboard: *Datastream — data freshness* starts climbing; throughput drops to 0. Cloud SQL connections/CPU unchanged — first hint that the source is healthy. |
| T0+2m | Freshness crosses the 120 s SLO line on the dashboard. |
| T0+3–8m | Alerting policy `cymbal-freshness-slo` fires; incident opens on the Alerting page. |
| T0+5m | Datastream console shows the stream unhealthy; stream errors report a failed login for `datastream_user`. |
| T0+~10m | Diagnosis: agy (read-only, human-approved commands) correlates `gcloud datastream streams describe` state/errors with Cloud Logging entries: `role "datastream_user" is not permitted to log in`. Reading `chaos.sh` confirms root cause. |
| T0+~12m | Fix applied by on-call: `ALTER ROLE datastream_user LOGIN;` |
| T0+~15m | Datastream retry succeeds; stream returns to `RUNNING`; freshness falls back toward 0; bronze catches up losslessly from the replication slot. |
| T0+~20m | Freshness below SLO; the incident auto-resolves. |

## Root cause

The replication role `datastream_user` was altered to `NOLOGIN` and its active
session terminated (a controlled chaos drill). Datastream could neither keep
nor re-establish its source connection and entered a retry loop.

## Detection

The custom data-freshness alerting policy (threshold 120 s on
`datastream.googleapis.com/stream/freshness`) — created that same afternoon.
**Datastream ships no default alerts**; without this policy, detection would
have waited for a human to notice stale dashboards.

## What went well

- The dashboard localized the fault in seconds: stream metrics sick, source
  metrics healthy → the problem sits between them.
- The replication slot did its job: WAL was retained, recovery was lossless.
- The agent-assisted diagnosis loop (human authorizes, agent investigates)
  produced the root cause before the incident was 15 minutes old.

## What went poorly

- Alert latency (metric ingestion + evaluation) meant 3–8 quiet minutes
  before the page — the dashboard beat the pager.
- No log-based alert on Datastream error logs existed; it would have fired
  on the first failed login attempt.

## Action items

| # | Action | Type |
|---|---|---|
| 1 | Add a log-based alert on Datastream error logs (`resource.type="datastream.googleapis.com/Stream"`, severity ≥ ERROR). | detect |
| 2 | Document the `datastream_user` runbook: check role attributes (`\du`) before deeper debugging. | mitigate |
| 3 | Alert on `stream/unsupported_event_count` > 0 — the "silent partial failure" cousin of this incident. | detect |
| 4 | Review who can `ALTER ROLE` in production; replication roles should be change-controlled. | prevent |
