# Canonical agy prompts — optional managed Dataform lab

Local mirror for the optional managed Dataform lab, in the same format as
`content/agenticdata/src/prompts.md`. When the lab is wired into TUTORIAL.md,
merge this section into that file. Both prompts are explain-only (no `/goal`,
nothing authored), so no restore command is needed.

## Lab 7 — managed Dataform, explained

Plain question. Ask while the scheduler waits for its first quarter-hour tick:

```
Explain the managed Dataform model like I run data platforms for a living: what exactly is frozen in a compilation result, why does re-executing the same compilation result still pick up new bronze rows, and when would I schedule release compilations more often than daily?
```

Fallback: concept question — the answer is in
https://docs.cloud.google.com/dataform/docs/release-configurations and
https://docs.cloud.google.com/dataform/docs/workflow-configurations.

## Lab 7 challenge — policy tags that survive rebuilds

```
stg_customers is rebuilt by managed Dataform every 15 minutes. Explain why a BigQuery policy tag attached by hand to its email column disappears on rebuild, and show how to declare it in the SQLX config with bigqueryPolicyTags so every rebuild reapplies it.
```

Fallback: https://docs.cloud.google.com/dataform/docs/policy-tags (the
`bigqueryPolicyTags` column setting; the full tag path comes from the
`cymbal-governance` taxonomy created in Lab 4).
