## Lab 2: Data Ingestion

<walkthrough-tutorial-duration duration="45"></walkthrough-tutorial-duration>
{{ author('Fabian Hirschmann', 'https://linkedin.com/in/fhirschmann') }}
<walkthrough-tutorial-difficulty difficulty="4"></walkthrough-tutorial-difficulty>

<bootkon-cloud-shell-note/>

Welcome back{% if MY_NAME %}, {{ MY_NAME }}{% endif %} 😍!

During this lab, you ingest fraudulent and non fraudulent transactions into BigQuery using three methods:
* **Method 1**: Using Lakehouse for Apache Iceberg with data stored in [Google Cloud Storage (GCS)](https://cloud.google.com/storage/docs)
* **Method 2**: Near real-time ingestion into BigQuery using [Cloud Pub/Sub](https://cloud.google.com/pubsub/docs)
* **Method 3**: Batch ingestion into BigQuery using [Managed Service for Apache Spark](https://docs.cloud.google.com/dataproc-serverless/docs)


For all methods, we are ingesting data from the bucket you have created in the previous lab.

***

### Method 1: External table using Lakehouse for Apache Iceberg (aka Lakehouse)

Lakehouse tables allow querying structured data in external data stores with access delegation. For an overview, refer to the [Lakehouse documentation](https://docs.cloud.google.com/lakehouse/docs/introduction). Access delegation decouples access to the Lakehouse table from access to the underlying data store. An external connection associated with a service account is used to connect to the data store.

Because the service account handles retrieving data from the data store, you only have to grant users access to the Lakehouse table. This lets you enforce fine-grained security at the table level, including row-level and column-level security.

First, we create the connection resource in BigQuery:
```bash
bq mk --connection --location=us --project_id={{ PROJECT_ID }} \
    --connection_type=CLOUD_RESOURCE fraud-transactions-conn
```

When you create a connection resource, BigQuery creates a unique system service account and associates it with the connection.
```bash
bq show --connection {{ PROJECT_ID }}.us.fraud-transactions-conn
```
Note the `serviceAccountID`.

To connect to Cloud Storage, you must give the new connection read-only access to Cloud Storage so that BigQuery can access files on behalf of users. Let's assign the service account to a variable:
```bash
CONN_SERVICE_ACCOUNT=$(bq --format=prettyjson show --connection ${PROJECT_ID}.us.fraud-transactions-conn | jq -r ".cloudResource.serviceAccountId")
echo $CONN_SERVICE_ACCOUNT
```

Let's double check the service account.
<walkthrough-spotlight-pointer locator="semantic({treeitem 'Toggle node astute-ace-336608'} {button 'Toggle node'})"></walkthrough-spotlight-pointer>
1. Go to the [BigQuery Console](https://console.cloud.google.com/bigquery).
2. Click <walkthrough-spotlight-pointer locator="semantic({tab 'Explorer'})">Explorer</walkthrough-spotlight-pointer>
3. Expand <walkthrough-spotlight-pointer locator="semantic({treeitem 'Toggle node {{ PROJECT_ID }}'} {button 'Toggle node'})">{{ PROJECT_ID }}</walkthrough-spotlight-pointer>
4. Click <walkthrough-spotlight-pointer locator="css(span[id$=ProjectTreeDatasource-{{ PROJECT_ID }}-bucket-connection])">Connections</walkthrough-spotlight-pointer>
5. Click <walkthrough-spotlight-pointer locator="semantic({button 'fraud-transactions-conn'})">fraud-transactions-conn</walkthrough-spotlight-pointer>

Is the service account equivalent to the one you got from the command line?


If so, let's grant the service account access to Cloud Storage:
```bash
gcloud storage buckets add-iam-policy-binding gs://{{ PROJECT_ID }}-bucket \
--role=roles/storage.objectViewer \
--member=serviceAccount:$CONN_SERVICE_ACCOUNT
```

Let's create a data set that contains the table and the external connection to Cloud Storage.

1. Go to the [BigQuery Console](https://console.cloud.google.com/bigquery)
2. Choose <walkthrough-spotlight-pointer locator="semantic({tab 'Explorer'})">Explorer</walkthrough-spotlight-pointer>
3. Hover your mouse over <walkthrough-spotlight-pointer locator="semantic({treeitem 'Toggle node {{ PROJECT_ID }}'} {button 'Toggle node'})">{{ PROJECT_ID }}</walkthrough-spotlight-pointer>
4. Click the three vertical dots (⋮) and go to `Create dataset`
5. Enter `ml_datasets` (plural) in the ID field. Region should be multi-region US.
6. Click `Create dataset`

Alternatively, you can create the data set on the command line:
```bash
bq --location=us mk -d ml_datasets
```

Next, we connect the data in Cloud Storage to BigQuery:
1. Choose <walkthrough-spotlight-pointer locator="semantic({tab 'Explorer'})">Explorer</walkthrough-spotlight-pointer>
2. Click <walkthrough-spotlight-pointer locator="spotlight(bigquery-add-data)">+ Add data</walkthrough-spotlight-pointer>
3. Click <walkthrough-spotlight-pointer locator="semantic({button 'Google Cloud Storage'})">Google Cloud Storage</walkthrough-spotlight-pointer>
4. Select `Load to BigQuery`
5. Enter the following details:
- Create table from: `Google Cloud Storage`
- Select file: `{{ PROJECT_ID }}-bucket/data/parquet/ulb_fraud_detection/*`
- File format: `Parquet`
- Project: `{{ PROJECT_ID }}`
- Dataset: `ml_datasets`
- Table: `ulb_fraud_detection_biglake`
- Table type: `External table`
- Check *Create a Lakehouse table using a Cloud Resource connection*
- Connection ID: Select `us.fraud-transactions-conn`
- Schema: `Auto detect`
6. Click on <walkthrough-spotlight-pointer locator="semantic({button 'Create table'})">Create table</walkthrough-spotlight-pointer>

Alternatively, you can also use the command line to create the table:

```bash
bq mk --table \
  --external_table_definition=@PARQUET="gs://${PROJECT_ID}-bucket/data/parquet/ulb_fraud_detection/*"@projects/${PROJECT_ID}/locations/us/connections/fraud-transactions-conn \
  ml_datasets.ulb_fraud_detection_biglake
```

Let's have a look at the data set:
1. Go to the [BigQuery Console](https://console.cloud.google.com/bigquery)
2. Choose <walkthrough-spotlight-pointer locator="semantic({tab 'Explorer'})">Explorer</walkthrough-spotlight-pointer>
3. Expand <walkthrough-spotlight-pointer locator="semantic({treeitem 'Toggle node {{ PROJECT_ID }}'} {button 'Toggle node'})">{{ PROJECT_ID }}</walkthrough-spotlight-pointer>
4. Click <walkthrough-spotlight-pointer locator="css(span[id$=ProjectTreeDatasource-{{ PROJECT_ID }}-bucket-dataset])">Datasets</walkthrough-spotlight-pointer>
5. Click <walkthrough-spotlight-pointer locator="semantic({button 'ml_datasets'})">ml_datasets</walkthrough-spotlight-pointer>
6. Click <walkthrough-spotlight-pointer locator="semantic({gridcell 'ulb_fraud_detection_biglake'})">ulb_fraud_detection_biglake</walkthrough-spotlight-pointer>
7. Click <walkthrough-spotlight-pointer locator="text('DETAILS')">Details</walkthrough-spotlight-pointer> 

Have a look at the external data configuration. You can see the Cloud Storage bucket (`gs://...`) your data
lives in.

Let's query it:

1. Click <walkthrough-spotlight-pointer locator="text('QUERY')">Query</walkthrough-spotlight-pointer>
2. Insert the following SQL query.

```sql
SELECT * FROM `{{ PROJECT_ID }}.ml_datasets.ulb_fraud_detection_biglake` LIMIT 1000;
```

Note that you can also execute a query using the `bq` tool:

```bash
bq --location=us query --nouse_legacy_sql "SELECT Time, V1, Amount, Class FROM {{ PROJECT_ID }}.ml_datasets.ulb_fraud_detection_biglake LIMIT 10;"
```

The data you are querying still resides on Cloud Storage and there are no copies stored in BigQuery. When using Lakehouse, BigQuery acts as query engine but not as storage layer.

***

### Method 2: Real time data ingestion into BigQuery using Pub/Sub

Pub/Sub enables real-time streaming into BigQuery. Learn more about [Pub/Sub integrations with BigQuery](https://cloud.google.com/pubsub/docs/bigquery).

We create an empty table and then stream data into it. For this to work, we need to specify a schema. Have a look at <walkthrough-editor-open-file filePath="content/data/src/data_ingestion/fraud_detection_bigquery_schema.json">`fraud_detection_bigquery_schema.json`</walkthrough-editor-open-file>. This is the schema we are going to use.

Create an empty table using this schema. We will use it to stream data into it:
```bash
bq --location=us mk --table \
{{ PROJECT_ID }}:ml_datasets.ulb_fraud_detection_pubsub content/data/src/data_ingestion/fraud_detection_bigquery_schema.json
```

We also need to create a Pub/Sub schema. We use Apache Avro, as it is better suited for appending row-wise:
```bash
gcloud pubsub schemas create fraud-detection-schema \
    --project=$PROJECT_ID  \
    --type=AVRO \
    --definition-file=content/data/src/data_ingestion/fraud_detection_pubsub_schema.json
```

And then create a Pub/Sub topic using this schema:
```bash
gcloud pubsub topics create fraud-detection-topic \
    --project=$PROJECT_ID  \
    --schema=fraud-detection-schema \
    --message-encoding=BINARY
```

{% set PUBSUB_SA = "service-{}@gcp-sa-pubsub.iam.gserviceaccount.com".format(PROJECT_NUMBER) %}

We also need to give Pub/Sub permissions to write data to BigQuery. The Pub/Sub service account is created automatically and
is comprised of the project number (not the id) and an identifier. In your case, it is ``{{ PUBSUB_SA }}``

And grant the service account access to BigQuery:

```bash
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=serviceAccount:{{ PUBSUB_SA }} --role=roles/bigquery.dataEditor

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=serviceAccount:{{ PUBSUB_SA }} --role=roles/bigquery.jobUser
```

Next, we create the Pub/Sub subscription:
```bash
gcloud pubsub subscriptions create fraud-detection-subscription \
    --project=$PROJECT_ID  \
    --topic=fraud-detection-topic \
    --bigquery-table=$PROJECT_ID.ml_datasets.ulb_fraud_detection_pubsub \
    --use-topic-schema  
```

Examine it in the console:
1. Go to the [Pub/Sub Console](https://console.cloud.google.com/cloudpubsub/subscriptions)
2. Click <walkthrough-spotlight-pointer locator="text('fraud-detection-subscription')">fraud-detection-subscription</walkthrough-spotlight-pointer>. Here you can see messages as they arrive.
3. Click <walkthrough-spotlight-pointer locator="text('projects/{{ PROJECT_ID }}/topics/fraud-detection-topic')">fraud-detection-topic</walkthrough-spotlight-pointer>. This is the topic you will be publishing messages to.

Please have a look at <walkthrough-editor-open-file filePath="content/data/src/data_ingestion/import_csv_to_bigquery_1.py">`import_csv_to_bigquery_1.py`</walkthrough-editor-open-file>. This script loads CSV files from Cloud Storage, parses it in Python, and sends it to Pub/Sub - row by row.

Let's execute it.
```bash
./content/data/src/data_ingestion/import_csv_to_bigquery_1.py
```

Each line you see on the screen corresponds to one transaction being sent to Pub/Sub and written to BigQuery. It would take approximately 40 to 60 minutes for it to finish. So, please cancel the command using ``CTRL + C``.

But why is it so slow?

Let's ask Gemini:

1. Open Gemini Code Assist
![](../img/code_assist.png)

2. Insert ``Why is import_csv_to_bigquery_1.py so slow?`` into the Gemini prompt.

<!-- 
We can make this faster by using different parameters for Pub/Sub. First, remove all rows you just ingested:
```bash
bq --location=$REGION query --nouse_legacy_sql "DELETE FROM {{ PROJECT_ID }}.ml_datasets.ulb_fraud_detection_pubsub WHERE true;"
```

Next, have a look at <walkthrough-editor-open-file filePath="src/data_ingestion/import_csv_to_bigquery_2.py">import_csv_to_bigquery_2.py</walkthrough-editor-open-file>. Can you make out the difference to the first script? Let's execute it:
```bash
./src/data_ingestion/import_csv_to_bigquery_2.py
```
-->

***

### Method 3: Ingestion using Managed Service for Apache Spark (aka Managed Apache Spark)

[Managed Apache Spark](https://docs.cloud.google.com/dataproc/docs/concepts/overview) is a fully managed and scalable service for running Apache Hadoop, Apache Spark, Apache Flink, Presto, and 30+ open source tools and frameworks. Managed Apache Spark allows data to be loaded and also transformed or pre-processed as it is brought in.

Create an empty BigQuery table:
```bash
bq --location=us mk --table \
{{ PROJECT_ID }}:ml_datasets.ulb_fraud_detection_dataproc content/data/src/data_ingestion/fraud_detection_bigquery_schema.json
```

Download the Spark connector for BigQuery and copy it to our bucket:
```bash
wget -qN https://github.com/GoogleCloudDataproc/spark-bigquery-connector/releases/download/0.37.0/spark-3.3-bigquery-0.37.0.jar
gsutil cp spark-3.3-bigquery-0.37.0.jar gs://${PROJECT_ID}-bucket/jar/spark-3.3-bigquery-0.37.0.jar
```

Open <walkthrough-editor-select-line filePath="content/data/src/data_ingestion/import_parquet_to_bigquery.py" startLine="4" endLine="4" startCharacterOffset="14" endCharacterOffset="31">import_parquet_to_bigquery.py</walkthrough-editor-select-line> in the Cloud Shell editor and replace the project id with your project id `{{ PROJECT_ID }}`. Don't forget to save.

{% if ON_ARGOLIS %}
❗ You are on Argolis. The next command requires to disable the 
`constraints/compute.requireOsLogin` constraint for your project in IAM.
{% endif %}

Execute it:
```bash
gcloud dataproc batches submit pyspark content/data/src/data_ingestion/import_parquet_to_bigquery.py \
    --project=$PROJECT_ID \
    --region=$REGION \
    --deps-bucket=gs://${PROJECT_ID}-bucket
```

While the command is still running, open the [Managed Apache Spark Console](https://console.cloud.google.com/dataproc/batches) and monitor the job.

After the Managed Apache Spark job completes, confirm that data has been loaded into the BigQuery table. You should see over 200,000 records, but the exact count isn't critical:
```bash
bq --location=us query --nouse_legacy_sql "SELECT count(*) as count FROM {{ PROJECT_ID }}.ml_datasets.ulb_fraud_detection_dataproc;"
```

❗ Please do not skip the above validation step. Data in the above table is needed for the following labs.

***

### Success

🎉 Congratulations{% if MY_NAME %}, {{ MY_NAME }}{% endif %}! 🚀

You’ve officially leveled up in data wizardry! By conquering the BigQuery Code Lab, you've shown your skills in not just one, but three epic methods: Lakehouse (riding the waves of data), Managed Apache Spark (processing like a boss), and Pub/Sub (broadcasting brilliance).

Your pipelines are now flawless, your tables well-fed, and your data destiny secured. Welcome to the realm of BigQuery heroes —{% if MY_NAME %}{{ MY_NAME }}, {% endif %} the Master of Ingestion! 🦾💻