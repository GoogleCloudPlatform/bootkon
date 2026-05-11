# Data & AI Bootkon

Welcome to Data & AI Bootkon!

Data & AI Bootkon is an immersive hackathon designed for tech enthusiasts, developers, and innovators to explore the power of Google Cloud products through hands-on learning. This event provides a unique, integrated experience using Google Cloud Shell tutorials, enabling participants to dive deep into cutting-edge cloud technologies.

This event is comprised of the following code labs:


| Duration | Topic | Details |
| --- | --- | --- |
| 30min | Environment Setup | Log into your GCP account and set up your environment. |
| 45min | Data Ingestion | Ingest data using three different methods: Lakehouse for Apache Iceberg (formerly BigLake), Pub/Sub, and Managed Service for Apache Spark (formerly Dataproc) |
| 45min | Dataform | Create version-controlled SQL workflows for BigQuery |
| 60min | Machine Learning | Train a model on fraud detection and create an automated ML pipeline | 
| 60min | Dataplex | Data governance at scale using Knowledge Catalog (formerly Dataplex) | 

You can navigate this handbook using the `<` and `>` buttons on the right and left hand side, respectively. To get started, please press the `>` button on the right hand side now.

## Use Case 

Your role: As a senior data analytics/AI engineer at an imaginary company called FraudFix Technologies, you will tackle the challenges of making financial transactions safer using machine learning. Your work will involve analyzing vast amounts of transaction data to detect and prevent fraud, as well as assessing customer sentiment regarding the quality of transaction services. You will leverage a unique dataset, which includes auto-generated data by Google Gemini and  public European credit card transactions that have been PCA transformed and anonymized. This dataset will be used to train your models, reflecting real-world applications of GCP Data & AI in enhancing financial safety.

![](img/bootkonarchitecture.png)

**Data Sources**.  
You’ll start by working with raw data that comes in different formats (csv , parquets). 
Those data files are stored in a github repository. Your first task is to store the raw data into your Google Cloud Storage (GCS) bucket.

**Data Ingestion Layer**  
You will bring this data into your [BigQuery AI Lakehouse](https://services.google.com/fh/files/emails/google-cloud-analytics-lakehouse_.pdf) environment. 
For batch data, you’ll use [Managed Service for Apache Spark](https://docs.cloud.google.com/dataproc-serverless/docs) and [Lakehouse for Apache Iceberg](https://docs.cloud.google.com/lakehouse/docs/introduction). 
For near real-time data, you’ll use [Pub/Sub](https://cloud.google.com/pubsub/docs/overview) to handle data as it comes in. 
Because we want to simulate data ingestion at scale, we will be using the raw data that you have stored in GCS to simulate both batch and real time ingestion.
These tools help you get the data ready for processing and analysis.


**BigQuery AI Lakehouse**
Think of this as the main camp where all your data hangs out. It’s a GCP product called BigQuery, and it’s designed to work with different types of data, whether it’s structured neatly in tables or unstructured like a pile of text documents. Here, you can run different data operations without moving data around.

**Data Governance Layer**
This is where you ensure that your data is clean, secure, and used properly. Using [Knowledge Catalog](https://cloud.google.com/products/knowledge-catalog), you’ll set rules and checks to maintain data quality and governance.

**Consumption Layer**   
Once you have your insights, you’ll use tools like [Gemini Enterprise Agent Platform](https://cloud.google.com/products/gemini-enterprise-agent-platform) (formerly Vertex AI) for machine learning tasks and [Data Studio](https://cloud.google.com/data-studio) (formerly Looker Studio) for creating reports and dashboards. This is where you turn data into something valuable, like detecting fraud or understanding customer sentiment.
Your goal is to share the results of your data predictions to your customers in a secure and private way. You will be using Analytics Hub for data sharing.

Throughout the event, you’ll be moving through these layers, using each tool to prepare, analyze, and draw insights from the data. You’ll see how they all connect to make a complete data analytics workflow on the cloud.


## About the data set
The datasets contain transactions made by credit cards in September 2013 by European cardholders, but also augmented by Google Gemini. This dataset presents transactions that occurred over two days, where there are a few hundred fraudulent transactions out of hundreds of thousands of transactions. It is highly unbalanced, with the positive class (frauds) accounting for less than 0.1% of all transactions (subject to testing in your notebooks). It contains only numeric input V* variables which are the result of a PCA transformation. Due to confidentiality issues, the owner of the dataset cannot provide the original features and more background information about the data. 

Features V1, V2, ... V28 are the principal components obtained with PCA, the only features which have not been transformed with PCA are ‘Time' , ‘Feedback’ and ‘Amount'. 

Feature ‘Time' contains the seconds elapsed between each transaction and the first transaction in the dataset. Feature ‘Amount' is the transaction Amount, this feature can be used for example-dependent cost-sensitive learning. Feature ‘Class' is the response variable and it takes value 1 in case of fraud and 0 otherwise. Feature ‘Feedback’ represents customer selection on service quality after submitting the transaction. This feature has been auto-generated by Google Gemini and added to the original dataset. 

During your machine learning experimentation using notebooks, one of the notebook cells will add your Google cloud account email address into the prediction dataset for traceability. This email address is treated as PII data and should not be shared externally outside of Fraudfix. The original dataset has been collected and analyzed during a research collaboration of [Worldline and the Machine Learning Group of ULB](http://mlg.ulb.ac.be) (Université Libre de Bruxelles) on big data mining and fraud detection. If you need more details on current and past projects on related topics are available here  and here.

## Logging into Google Cloud

> [!CAUTION]
> Please follow the below steps exactly as written. Deviating from them has unintended consequences.

Let us set your your Google Cloud Console. Please:

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

It is based on Visual Studio Code and hence looks like a normal IDE. However, on the right hand side you see the tutorial you will be working through. When you encouter code chunks in the tutorial, there are two icons on the right hand side. One to copy the code chunk to your clipboard and the other one to insert it directly into the terminal of Cloud Shell.

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

## Start the lab

In your Google Cloud Console window, activate Cloud Shell.

![](../common/img/activate_cloud_shell.png)

Click into the terminal that has opened at the bottom of your screen.

![](../common/img/cloud_shell_terminal.png)

And copy & paste the following command and press return:

```bash
BK_STREAM=data BK_REPO=fhirschmann/bootkon; . <(wget -qO- https://raw.githubusercontent.com/${BK_REPO}/main/.scripts/bk)
```

Now, please go back to Cloud Shell and continue with the tutorial that has been opened on the right hand side of your screen!


## Authors

This version is based on a [previous version](https://github.com/dace-de/google-data-ai-bootkon-docs) by Wissem Khlifi. 

The authors of Data & AI Bootkon are:
- [Fabian Hirschmann](https://www.linkedin.com/in/fhirschmann/) (maintainer; main author)
- [Cary Edwards](https://www.linkedin.com/in/cary-edwards-a3a557a6/) (contributor)
- [Daniel Holgate](https://www.linkedin.com/in/danielholgate/) (contributor)
- [Wissem Khlifi](https://www.linkedin.com/in/orawiss/) (original author)

Data & AI Bootkon received contributions from many people, including:
- [Christine Schulze](https://www.linkedin.com/in/christine-schulze-33822765/)
- [Daniel Quinlan](https://www.linkedin.com/in/%F0%9F%8C%8Ddaniel-quinlan-51126016/)
- [Dinesh Sandra](https://www.linkedin.com/in/sandradinesh/)
