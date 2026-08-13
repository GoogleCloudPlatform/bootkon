<walkthrough-metadata>
  <meta name="title" content="Agentic Data Bootkon" />
  <meta name="description" content="Build Cymbal's agentic data platform: Cloud SQL CDC into BigQuery with Datastream, an agy-authored bronze/silver/gold Dataform pipeline, Knowledge Catalog governance, a BigQuery data agent, and an ADK multi-agent finale over the A2A protocol." />
  <meta name="keywords" content="data, ai, agents, bigquery, datastream, cloudsql, dataform, dataplex, adk, a2a" />
  <meta name="component_id" content="1734803" />
</walkthrough-metadata>


# Agentic Data Bootkon

<walkthrough-tutorial-duration duration="15"></walkthrough-tutorial-duration>
Author: <a href="https://linkedin.com/in/fhirschmann">Fabian Hirschmann</a>
<walkthrough-tutorial-difficulty difficulty="2"></walkthrough-tutorial-difficulty>


## Introduction

{% if MY_NAME %}Hi **{{ MY_NAME }}! 👋** {% endif %}Welcome to Agentic Data Bootkon. We're delighted to have you! This sidebar contains parts of the labs you will work through. Before we get started, let's set up a few things:

### Working with labs

You can insert commands into the terminal using the following button on top of each code line in the tutorial:
<walkthrough-cloud-shell-icon></walkthrough-cloud-shell-icon>. The button will automatically open the terminal.
Please make sure you are using the terminal of the IDE.

Let's try:

```bash
echo "Lets go, Cymbal"
```

Execute by pressing the return key in the terminal that has been opened in the lower part of your screen.

### Check your environment

The setup command you pasted has already configured everything. Let's verify it:

* Your `PROJECT_ID` is `{% if PROJECT_ID == "" %}None{% else %}{{ PROJECT_ID }}{% endif %}`

* Your `GCP_USERNAME` is `{% if GCP_USERNAME == "" %}None{% else %}{{ GCP_USERNAME }}{% endif %}`

If both are correct, you are done — press the `START` button below to get started!
(Tip: if you ever close this tutorial or the editor, type `bk-start` in the
terminal to reopen them.)

Wrong project? Switch to your event project in the Cloud Shell project
selector at the top of the window, then refresh this page:

```bash
. bk && bk-start
```

{% include 'agenticdata/labs/1_environment_setup.md' %}

{% include 'agenticdata/labs/2_replication.md' %}

{% include 'agenticdata/labs/3_dataform.md' %}

{% include 'agenticdata/labs/4_governance.md' %}

{% include 'agenticdata/labs/5_data_agent.md' %}

{% include 'agenticdata/labs/6_a2a.md' %}


## The end

You've made it! Congratulations and thank you for participating in this event.

### Credits

The authors of Agentic Data Bootkon are:
- [Fabian Hirschmann](https://www.linkedin.com/in/fhirschmann/) (main author)
- [Florian Baumert](https://www.linkedin.com/in/florian-baumert/)
- [Cary Edwards](https://www.linkedin.com/in/cary-edwards-a3a557a6/)
