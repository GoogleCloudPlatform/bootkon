<walkthrough-metadata>
  <meta name="title" content="Data & AI Bootkon" />
  <meta name="description" content="These labs include detailed step-by-step instructions to guide you. In addition to the labs, you’ll face several challenges that you’ll need to solve on your own or with your group. Groups will be assigned by the event organizers at the start of the event." />
  <meta name="keywords" content="data, ai, bigquery, vertexai, genai, notebook" />
  <meta name="component_id" content="1734803" />
</walkthrough-metadata>


# Data and AI Bootkon

<walkthrough-tutorial-duration duration="15"></walkthrough-tutorial-duration>
Author: <a href="https://linkedin.com/in/fhirschmann">Fabian Hirschmann</a>
<walkthrough-tutorial-difficulty difficulty="1"></walkthrough-tutorial-difficulty>


## Introduction

{% if MY_NAME %}Hi **{{ MY_NAME }}! 👋** {% endif %}Welcome to Data & AI Bootkon. We're delighted to have you! This sidebar contains parts of the labs you will work through. Before we get started, let's set up a few things:

### Working with labs

You can insert commands into the terminal using the following button on top of each code line in the tutorial:
<walkthrough-cloud-shell-icon></walkthrough-cloud-shell-icon>. The button will automatically open the terminal.
Please make sure you are using the terminal of the IDE.

Let's try:

```bash
echo "I'm ready to get started."
```

Execute by pressing the return key in the terminal that has been opened in the lower part of your screen.

### Set up your environment

Initialize bootkon. This sets your environment variables and auto-detects your
Google Cloud project and account from Cloud Shell:

```bash
. bk
```

Then reload the tutorial window on the right-hand side of your screen (run this
again any time you accidentally close the tutorial or the editor):

```bash
bk-start
```

New terminals load the environment automatically — you only re-run `. bk` after
changing your configuration.

Now, your

* `PROJECT_ID` is `{% if PROJECT_ID == "" %}None{% else %}{{ PROJECT_ID }}{% endif %}`

* `GCP_USERNAME` is `{% if GCP_USERNAME == "" %}None{% else %}{{ GCP_USERNAME }}{% endif %}`.

If `PROJECT_ID` is wrong, switch to your event project in the Cloud Shell project selector at the top of the window, then run `. bk` again. If `GCP_USERNAME` shows `None`, or your name is missing, open `vars.local.sh` <walkthrough-editor-open-file filePath="vars.local.sh">by clicking here</walkthrough-editor-open-file>, fix it (no spaces), save, and run `. bk` again.

If neither is `None`, press the `START` button below to get started!

{% include 'data/labs/1_environment_setup.md' %}

{% include 'data/labs/2_data_ingestion.md' %}

{% include 'data/labs/3_dataform.md' %}

{% include 'data/labs/4_ml.md' %}

{% include 'data/labs/5_dataplex.md' %}

{% include 'data/labs/6_data_agent.md' %}


## The end

You've made it! Congratulations and thank you for participating in this event.

### Credits

The authors of Data & AI Bootkon are:
- [Fabian Hirschmann](https://www.linkedin.com/in/fhirschmann/) (main author)
- [Cary Edwards](https://www.linkedin.com/in/cary-edwards-a3a557a6/) (contributor)
- [Daniel Holgate](https://www.linkedin.com/in/danielholgate/) (contributor)
- [Wissem Khlifi](https://www.linkedin.com/in/orawiss/) (original author)

Data & AI Bootkon received contributions from many people, including:
- [Christine Schulze](https://www.linkedin.com/in/christine-schulze-33822765/)
- [Daniel Quinlan](https://www.linkedin.com/in/%F0%9F%8C%8Ddaniel-quinlan-51126016/)
- [Dinesh Sandra](https://www.linkedin.com/in/sandradinesh/)
