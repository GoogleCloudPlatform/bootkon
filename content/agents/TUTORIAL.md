<walkthrough-metadata>
  <meta name="title" content="DevEx Bootkon" />
  <meta name="description" content="These labs include detailed step-by-step instructions to guide you. In addition to the labs, you’ll face several challenges that you’ll need to solve on your own or with your group. Groups will be assigned by the event organizers at the start of the event." />
  <meta name="keywords" content="data, ai, bigquery, vertexai, genai, notebook" />
  <meta name="component_id" content="1734803" />
</walkthrough-metadata>


# AgentKon

<walkthrough-tutorial-duration duration="15"></walkthrough-tutorial-duration>
<walkthrough-tutorial-difficulty difficulty="1"></walkthrough-tutorial-difficulty>


## Introduction

{% if MY_NAME %}Hi **{{ MY_NAME }}! 👋** {% endif %}Welcome to AgentKon. We're delighted to have you! This sidebar contains parts of the labs you will work through. Before we get started, let's set up a few things:

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

If either shows `None` or looks wrong, open `vars.local.sh` <walkthrough-editor-open-file filePath="vars.local.sh">by clicking here</walkthrough-editor-open-file>, set the correct value (no spaces), save, and run `. bk` again. You can also set your (first) name in `MY_NAME`.

If neither is `None`, press the `START` button below to get started!

{% include 'agents/labs/1_environment_setup.md' %}
{% include 'agents/labs/2_adk.md' %}
{% include 'agents/labs/3_mcp.md' %}

## The end

You've made it! Congratulations and thank you for participating in this event.

### Credits
