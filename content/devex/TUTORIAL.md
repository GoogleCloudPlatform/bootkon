<walkthrough-metadata>
  <meta name="title" content="DevEx Bootkon" />
  <meta name="description" content="These labs include detailed step-by-step instructions to guide you. In addition to the labs, you’ll face several challenges that you’ll need to solve on your own or with your group. Groups will be assigned by the event organizers at the start of the event." />
  <meta name="keywords" content="developer, devops, ai, gemini cli, genai" />
  <meta name="component_id" content="1734803" />
</walkthrough-metadata>


# DevEx Bootkon

<walkthrough-tutorial-duration duration="120"></walkthrough-tutorial-duration>
<walkthrough-tutorial-difficulty difficulty="3"></walkthrough-tutorial-difficulty>


## Introduction

{% if MY_NAME %}Hi **{{ MY_NAME }}! 👋** {% endif %}Welcome to DevEx Bootkon. We're delighted to have you! This sidebar contains parts of the labs you will work through. Before we get started, let's set up a few things:

### Working with labs

You can insert commands into the terminal using the following button on top of each code line in the tutorial:
<walkthrough-cloud-shell-icon></walkthrough-cloud-shell-icon>. The button will automatically open the terminal.
Please make sure you are using the terminal of the IDE.

Let's try:

```bash
echo "I'm ready to get started."
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

{% include 'devex/labs/2_devex_agy_cli.md' %}

## The end

You've made it! Congratulations and thank you for participating in this event.

### Credits
