# Canonical agy prompts — Lab: Day-2 Ops

The prompts quoted in the day-2 ops lab, collected in one place so table
captains can copy them quickly. agy output varies by design — every artifact
has a reference in this folder that participants can fall back to. This file
lives next to the lab's other assets while the module is optional; merge it
into `content/agenticdata/src/prompts.md` when the lab is wired into
TUTORIAL.md.

## Author the dashboard

Run from `~/bootkon`:

```
/goal Read content/agenticdata/src/optional/day2_ops/AGENTS.md and create content/agenticdata/src/optional/day2_ops/dashboard.json exactly as it specifies: valid Cloud Monitoring Dashboard API JSON, six widgets in the given order, the exact metric types from the brief, and the 120-second threshold line on the freshness chart. No comments, no trailing commas.
```

Fallback: `git -C ~/bootkon restore content/agenticdata/src/optional/day2_ops/dashboard.json`

## Diagnose the incident (read-only co-responder)

```
Our BigQuery bronze dataset stopped receiving new rows a few minutes ago, and data freshness on the Datastream stream cymbal-cdc-stream (location us-central1) keeps climbing. The source Postgres itself is healthy and still taking writes. Investigate the Datastream side with read-only commands only (gcloud datastream streams describe, gcloud logging read) and tell me your diagnosis. Ask me before each command, and do not change anything.
```

Fallback — the two commands that hold the answer, run by hand:

```
gcloud datastream streams describe cymbal-cdc-stream --location=us-central1 --format='yaml(state, errors)'
gcloud logging read 'resource.type="datastream.googleapis.com/Stream" severity>=WARNING' --freshness=15m --limit=5 --format='yaml(timestamp, severity, jsonPayload)'
```

## Explain the chaos script

```
Read content/agenticdata/src/optional/day2_ops/chaos.sh and explain, statement by statement, how it broke replication -- and why the simulator kept writing happily the whole time.
```

Fallback: the header comment of `chaos.sh` explains itself, statement by statement.
