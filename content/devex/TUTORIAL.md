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

### Setting environment variables
You can open files directly from this tutorial.
Open `vars.sh` <walkthrough-editor-open-file filePath="vars.sh">by clicking here</walkthrough-editor-open-file>
and set `GCP_USERNAME`, `PROJECT_ID` according to the information you received. Also let us know your (first?) name in `MY_NAME`. Don't forget to save it.

❗ Please do not include any whitespaces when setting these variablers.

Please reload bootkon and make sure there are no errors printed:

```bash
. bk
```


And restart the tutorial using the next command. You can also use the next command to continue bootkon in case you accidentally close the tutorial or the editor:

```bash
bk-start
```

Now, your

* `PROJECT_ID` is `{% if PROJECT_ID == "" %}None{% else %}{{ PROJECT_ID }}{% endif %}`

* `GCP_USERNAME` is `{% if GCP_USERNAME == "" %}None{% else %}{{ GCP_USERNAME }}{% endif %}`.


If neither is `None`, press the `START` button below to get started!

{% include 'devex/labs/1_devex_gemini_cli.md' %}
{% include 'devex/labs/2_devex_agy_cli.md' %}

## The end

You've made it! Congratulations and thank you for participating in this event.

### Credits
