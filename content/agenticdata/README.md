# Agentic Data Bootkon

Welcome to Agentic Data Bootkon!

Agentic Data Bootkon is an immersive half-day hackathon for data engineers, architects, and AI enthusiasts. In one afternoon (13:00–17:00) you build a complete **agentic data platform** on Google Cloud — from a live operational database all the way to AI agents that talk to each other about your data over an open protocol. Throughout the event, the **Antigravity CLI (`agy`)** works alongside you as an AI co-engineer: you run the infrastructure, agy writes the code, and the Cloud Console is where you verify what happened.

This event is comprised of the following code labs:

| Time | Duration | Topic | Details |
| --- | --- | --- | --- |
| 13:00 | 10min | Kickoff | Credentials, Cloud Shell, tutorial setup |
| 13:10 | 20min | Environment Setup & agy | IAM, network, async database build, seed data, meet your AI co-engineer |
| 13:30 | 40min | Live Replication | Cloud SQL for PostgreSQL → Datastream CDC → BigQuery bronze, with a live activity simulator |
| 14:10 | 40min | Dataform with agy | agy authors the bronze→silver→gold medallion pipeline; you compile, run, and verify it |
| 14:50 | 30min | Break | ☕ |
| 15:20 | 30min | Data Governance | Knowledge Catalog: tier aspects, auto data quality, PII policy tags, glossary, lineage |
| 15:50 | 20min | BigQuery Data Agent | A conversational analytics agent grounded on your governed gold layer |
| 16:10 | 45min | A2A Finale | Two ADK agents — analytics via A2A, live order lookups via Cloud SQL — in one conversation |
| 16:55 | 5min | Wrap-up | 🎉 |

You can navigate this handbook using the `<` and `>` buttons on the right and left hand side, respectively. To get started, please press the `>` button on the right hand side now.

## Use Case

Your role: you are a data platform engineer at **Cymbal**, a commerce company whose order platform runs on PostgreSQL. The analytics team is drowning in one-off CSV exports, nobody trusts the numbers, and management wants "AI on our data" — safely. Over one afternoon, you will give Cymbal:

1. **A live replica instead of exports.** Datastream captures every insert, update, and delete from Cloud SQL for PostgreSQL and merges it into BigQuery within moments — over Private Service Connect, with no public IPs anywhere.
2. **Numbers people can trust.** A medallion architecture (bronze → silver → gold) built with Dataform, where the SQL is authored by the Antigravity CLI under your direction, complete with data tests. The raw data contains real-world-style flaws (duplicates, typos, orphaned records) — cleaning them is the point.
3. **Governance before agents.** Knowledge Catalog labels the tiers, scans quality continuously, locks down PII with enforced column-level security, and gives business terms a home — the grounding layer that makes AI answers trustworthy.
4. **Agents on top.** A BigQuery conversational data agent over the gold layer, then an ADK multi-agent system: a concierge agent that answers live operational questions straight from Postgres and delegates analytical questions to the data agent over the **A2A protocol** — *agent-to-agent*, the open standard (governed by the Linux Foundation) that lets AI agents from any framework or vendor discover and call each other, the way HTTP lets services talk to each other.

## Architecture

<table align="center">
  <tr>
    <td align="center" width="130">
      <img src="https://icon.icepanel.io/GCP/svg/Cloud-SQL.svg" width="48" alt="Cloud SQL"/><br>
      <b>Cloud SQL</b><br>
      <sub>PostgreSQL, PSC-only<br>Cymbal's live order DB</sub>
    </td>
    <td align="center"><b>— CDC ▶</b></td>
    <td align="center" width="130">
      <img src="https://icon.icepanel.io/GCP/svg/Datastream.svg" width="48" alt="Datastream"/><br>
      <b>Datastream</b><br>
      <sub>backfill + streaming<br>merge mode</sub>
    </td>
    <td align="center"><b>—▶</b></td>
    <td align="center" width="180">
      <img src="https://icon.icepanel.io/GCP/svg/BigQuery.svg" width="48" alt="BigQuery"/><br>
      <b>BigQuery</b><br>
      <sub>bronze → silver → gold<br>Dataform SQLX, authored by agy</sub>
    </td>
    <td align="center"><b>—▶</b></td>
    <td align="center" width="150">
      <img src="https://icon.icepanel.io/GCP/svg/AI-Platform.svg" width="48" alt="BigQuery data agent"/><br>
      <b>Data agent</b><br>
      <sub>conversational analytics<br>grounded on gold</sub>
    </td>
  </tr>
  <tr>
    <td></td><td></td><td></td><td></td>
    <td align="center">
      <b>▲</b><br>
      <img src="https://icon.icepanel.io/GCP/svg/Dataplex.svg" width="40" alt="Knowledge Catalog"/><br>
      <b>Knowledge Catalog</b><br>
      <sub>tier aspects · data quality<br>PII policy tags · glossary · lineage</sub>
    </td>
    <td></td>
    <td align="center"><b>▲</b><br><b>A2A</b></td>
  </tr>
  <tr>
    <td align="center">
      <b>▲</b><br>
      <sub>live order<br>lookups</sub>
    </td>
    <td colspan="5" align="center"><b>◀————————————————</b></td>
    <td align="center">
      <img src="https://icon.icepanel.io/GCP/svg/Vertex-AI.svg" width="48" alt="ADK concierge agent"/><br>
      <b>cymbal_concierge</b><br>
      <sub>ADK agent, adk web</sub>
    </td>
  </tr>
  <tr>
    <td colspan="7" align="center">
      <img src="https://icon.icepanel.io/GCP/svg/Cloud-Shell.svg" width="40" alt="Cloud Shell"/><br>
      <b>Cloud Shell + Antigravity CLI (agy)</b><br>
      <sub>you operate the shell · agy authors the code · the console verifies</sub>
    </td>
  </tr>
</table>

## About the data set

There is no download: the **Cymbal orders** dataset is fully synthetic and generated *inside your own project* by a seeded generator — every participant gets identical data. It models a generic commerce platform (customers, products, orders, order items, payments, reviews; ~2.3M rows, well under 2 GB) and includes deliberately planted data-quality flaws — duplicate customers, invalid emails, a `shiped` status typo, mixed-case currencies, orphaned line items, negative payments, future timestamps — plus PII columns (names, emails, phones, addresses) for the governance lab. A simulator keeps inserting and updating rows during the event, so the change-data-capture pipeline always has something to show.

## Logging into Google Cloud

> [!CAUTION]
> Please follow the below steps exactly as written. Deviating from them has unintended consequences.

Let us set up your Google Cloud Console. Please:

1. Open a new browser window in **Incognito** mode.
2. Open this handbook in your newly opened incognito window and keep reading; close this window in your main browser window.
3. Open <a href="https://console.cloud.google.com" target="_blank">Google Cloud Console</a> and log in with the provided credentials.
4. Accept the Terms of Services.

    ![](../common/img/termsofservice.png)

5. Choose your **project id**. Click on select a project and select the project ID (example below)
    ![](../common/img/selectproject.png)


    ![](../common/img/selectproject2.png)


    ![](../common/img/selectproject3.png)

6. Go to [language settings](https://console.cloud.google.com/user-preferences/languages) and change your language to `English (US)`. This will help our tutorial engine recognize items on your screen and make our table captain be able to help you.

    ![](../common/img/select_language.png)

## Executing code labs

During this event, we will guide you through a series of labs using Google Cloud Shell.

Cloud Shell is a fully interactive, browser-based environment for learning, experimenting, and managing Google Cloud projects. It comes preloaded with the Google Cloud CLI, essential utilities, and a built-in code editor with Cloud Code integration, enabling you to develop, debug, and deploy cloud apps entirely in the cloud.

Below you can find a screenshot of Cloud Shell.

![](../common/img/cloud_shell_window.png)

It is based on Visual Studio Code and hence looks like a normal IDE. However, on the right hand side you see the tutorial you will be working through. When you encounter code chunks in the tutorial, there are two icons on the right hand side. One to copy the code chunk to your clipboard and the other one to insert it directly into the terminal of Cloud Shell.

## Working with labs (important)

> [!CAUTION]
> Please note the points in this section before you get started with the labs in the next section.

While going through the code labs, you will encounter two different terminals on your screen. Please only use the terminal from the IDE (white background) and do not use the non-IDE terminal (black background). In fact, just close the terminal with black background using the `X` button.

![](../common/img/code_terminals.png)

You will also find two buttons on your screen that might seem tempting. <font color="red">Please do not click the *Open Terminal* or *Open in new window* buttons</font> as they will destroy the integrated experience of Cloud Shell.

![](../common/img/code_newwindow.png)

Please double check that the URL in your browser reads `console.cloud.google.com` and <font color="red">not `shell.cloud.google.com`</font>.

![](../common/img/wrong_url.png)

Should you accidentally close the tutorial or the IDE, just type the following command into the terminal:

```bash
bk-start
```

> [!NOTE]
> This stream uses several terminal tabs at once — an IAP tunnel and a data simulator keep running in the background. Don't close those tabs; new tabs are ready to use right away (your configuration loads automatically from `~/.bashrc`).

## Start the lab

In your Google Cloud Console window, activate Cloud Shell.

![](../common/img/activate_cloud_shell.png)

Click into the terminal that has opened at the bottom of your screen.

![](../common/img/cloud_shell_terminal.png)

And copy & paste the following command and press return:

```bash
BK_STREAM=agenticdata BK_REPO=GoogleCloudPlatform/bootkon; . <(curl -fsSL https://raw.githubusercontent.com/${BK_REPO}/main/.scripts/bk)
```

Now, please go back to Cloud Shell and continue with the tutorial that has been opened on the right hand side of your screen!


## Authors

The authors of Agentic Data Bootkon are:
- [Fabian Hirschmann](https://www.linkedin.com/in/fhirschmann/) (maintainer; main author)
- [Florian Baumert](https://www.linkedin.com/in/florian-baumert/)
- [Cary Edwards](https://www.linkedin.com/in/cary-edwards-a3a557a6/)
