## Lab 5: Data Governance with Knowledge Catalog

<walkthrough-tutorial-duration duration="60"></walkthrough-tutorial-duration>
{{ author('Daniel Holgate', 'https://www.linkedin.com/in/danielholgate/') }}
<walkthrough-tutorial-difficulty difficulty="2"></walkthrough-tutorial-difficulty>
<bootkon-cloud-shell-note/>

In this lab you will 
- Understand Knowledge Catalog capabilities.
- Leverage Knowledge Catalog to understand and govern your data and metadata.
- Build data quality checks on top of the fraud detection prediction results.

### About Knowledge Catalog

Knowledge Catalog is a data governance tool which helps you organize your data assets by overlaying the organizational concept of "Lakes" and "Zones". This organization is logical only and does not require any data movement. You can use lakes to define, for example, organizational boundaries (e.g. marketing lake/sales lake) or regional boundaries (i.e. US lake/ UK lake), while zones are used to group data within lakes by data readiness or by use cases (e.g. raw_zone/curated_zone or analytics_zone/data_science_zone).

Knowledge Catalog can also be used to build a data mesh architecture with decentralized data ownership among domain data owners.

### Security - Cloud Storage/BigQuery

With Knowledge Catalog you can apply data access permissions using IAM groups across multiple buckets and BigQuery datasets by granting permissions at a lake or zone-level. It will do the heavy lifting of propagating desired policies and updating access policies of the buckets/datasets that are part of that lake or data zone. 

Knowledge Catalog will also apply those permissions to any new buckets/datasets that get created under that data zone. This takes away the need to manually manage individual bucket permissions and also provides a way to automatically apply permissions to any new data added to your lakes.

Note that the permissions are applied in “Additive” fashion - Knowledge Catalog does not replace the existing permissions when pushing down permissions. Knowledge Catalog also provides “exclusive” permission push down as an opt-in feature.

### Discovery [semi-structured and structured data]

You can configure discovery jobs in Knowledge Catalog that can sample data on GCS, infer its schema, and automatically register it with the Knowledge Catalog so you can easily search and discover the data you have in your lakes.

In addition to registering metadata with Knowledge Catalog, for data in CSV, JSON, AVRO, ORC, and Parquet formats, discovery jobs also register technical metadata, including hive-style partitions, with a managed Hive metastore (Dataproc Metastore) & as external tables in BigQuery (BQ).  

Discovery jobs can be configured to run on a schedule to discover any new tables or partitions. For new partitions, discovery jobs incrementally scan new data, check for data and schema compatibility, and register only compatible schema to the Hive metastore/BQ so that your table definitions never go out of sync with your data.

### Actions - Profiling, Quality, Lineage, Discovery

Knowledge Catalog has the capability to profile data assets (BigQuery tables), auto detect data lineage for BigQuery transformations. You can also use it for data discovery across GCS, BigQuery, Spanner, PubSub, Dataproc metastore, Bigtable and Agent Platform models. 

You can automate the scanning of data, validate data against defined rules, and log alerts if your data doesn't meet quality requirements. In addition you can manage data quality rules and deployments as code, improving the integrity of data production pipelines.

--- 

### Create a Knowledge Catalog Lake

1. Go to [Knowledge Catalog](https://console.cloud.google.com/dataplex).
2. Navigate to <walkthrough-spotlight-pointer locator="text('Manage')">Manage</walkthrough-spotlight-pointer>.
3. Click <walkthrough-spotlight-pointer locator="semantic({link 'Create'})">Create</walkthrough-spotlight-pointer>.
4. Enter the following details:
    - Display name: `bootkon-lake`
    - Description: anything you like
    - Region: `us-central1`
    - Labels: Add labels to your lake. For example, use location for the key and berlin for the value over your data
    - Metastore: lets skip the metastore creation for now
5. Finally, click on <walkthrough-spotlight-pointer locator="semantic({button 'Create'})">Create</walkthrough-spotlight-pointer>. This should take around 2-3 minutes.

***

#### Add Zones

We will add two zones: one for raw data and another for curated data.

1. Click on the <walkthrough-spotlight-pointer locator="semantic({link 'bootkon-lake'})">bootkon-lake</walkthrough-spotlight-pointer> lake you just created.
2. In the Zones tab, click <walkthrough-spotlight-pointer locator="semantic({link 'Add zone'})">+ Add Zone</walkthrough-spotlight-pointer> and enter the following details:
    - Display name: `bootkon-raw-zone`
    - Type: Raw Zone
    - Description: anything you like
    - Data Locations: `Regional (us-central1)`
    - Discovery settings: Enable metadata discovery, which allows Knowledge Catalog to automatically scan and extract metadata from the data in your zone. Let's leave the default settings. Set time zone to Germany.

Finally, click <walkthrough-spotlight-pointer locator="semantic({button 'Create'})">create</walkthrough-spotlight-pointer>.
When the zone creation succeeds, the zone automatically enters in an active state. If it fails, then the lake is rolled back to its previous state.
After you create your zone, you can map data stored in Cloud Storage buckets and BigQuery datasets as assets in your zone.

Repeat the same steps but this time, change the display name to `bootkon-curated-zone` and choose  *Curated Zone* for the Type. You might also change the label and description values. 
The creation should take 2-3 minutes to finish.

---

### Add Zone Data Assets
Let's map data stored in Cloud Storage buckets and BigQuery datasets as assets in your zone.
1. Navigate to Zones and click on `bootkon-raw-zone`
2. Click <walkthrough-spotlight-pointer locator="semantic({link '+ Add assets'})">+ Add assets</walkthrough-spotlight-pointer>
3. Click <walkthrough-spotlight-pointer locator="semantic({button 'add an asset'})">Add an asset</walkthrough-spotlight-pointer>
4. Choose *Storage bucket* from the type dropdown
5. Display name : `bootkon-gcs-raw-asset`
6. Optionally add a description 
7. Browse the bucket name and choose `{{ PROJECT_ID }}-bucket`.
8. Select the bucket
9. Let's skip upgrading to the managed option. When you upgrade a Cloud Storage bucket asset, Knowledge Catalog removes the attached external tables and creates Lakehouse tables. We have already created a Lakehouse table in Lab 2 so this option is not necessary. 
10. Optionally add a label
11. Click <walkthrough-spotlight-pointer locator="semantic({button 'Continue'})">Continue</walkthrough-spotlight-pointer>
12. Leave the discovery setting to be inherited by the lake settings we have just created during lake creation steps. Click on <walkthrough-spotlight-pointer locator="semantic({button 'Continue'})">Continue</walkthrough-spotlight-pointer>.
13. Click <walkthrough-spotlight-pointer locator="semantic({button 'Submit'})">Submit</walkthrough-spotlight-pointer>.

Now let's add another data asset but for the bootkon-curated-zone:

14. Click on `bootkon-curated-zone`
15. Click on <walkthrough-spotlight-pointer locator="semantic({link 'Add assets'})">+ Add assets</walkthrough-spotlight-pointer>
16. Click <walkthrough-spotlight-pointer locator="semantic({button 'add an asset'})">Add an asset</walkthrough-spotlight-pointer>
17. Choose *BigQuery dataset* from the Type dropdown
18. Display name : `bootkon-bq-curated-asset`
19. Optionally add a description 
20. Browse the BigQuery dataset and choose the dataset created in lAB 1. If you followed the instructions, it should be named `{{ PROJECT_ID }}.ml_datasets`.
21. Select the BigQuery dataset
22. Optionally add a label
23. Click on <walkthrough-spotlight-pointer locator="semantic({button 'Continue'})">Continue</walkthrough-spotlight-pointer>.
24. Leave the discovery setting to be inherited by the lake settings we have just created during lake creation steps. Click <walkthrough-spotlight-pointer locator="semantic({button 'Continue'})">Continue</walkthrough-spotlight-pointer>.
25. Click <walkthrough-spotlight-pointer locator="semantic({button 'Submit'})">Submit</walkthrough-spotlight-pointer>. 

---

### Explore data assets with Knowledge Catalog Search 

During this lab go to the Search section of the Knowledge Catalog and search for the lakes, zones and assets you just created. Spend 5 minutes exploring before moving to the next section.

---

### Explore Lakehouse object tables created automatically by Knowledge Catalog in BigQuey

As a result of the data discovery (takes up to approximately 5 minutes), notice a new BigQuery dataset created called `bootkon_raw_zone` under the [BigQuery](https://console.cloud.google.com/bigquery) console section. New Lakehouse tables were automatically created by the Knowledge Catalog discovery jobs. During the next sections of the labs, we will be using the `data_predictions` Lakehouse table. 

---

### Data Profiling

Knowledge Catalog data profiling lets you identify common statistical characteristics of the columns in your BigQuery tables. This information helps you to understand and analyze your data more effectively.

Information like typical data values, data distribution, and null counts can accelerate analysis. When combined with data classification, data profiling can detect data classes or sensitive information that, in turn, can enable access control policies.
Knowledge Catalog also uses this information to recommend rules for data quality check and lets you better understand the profile of your data by creating a data profiling scan.

These are some of the options we will be dealing with when setting up data profiling.

**Configuration options**: This section describes the configuration options available for running data profiling scans.

**Scheduling options**: You can schedule a data profiling scan with a defined frequency or on demand through the API or the Google Cloud console.

**Scope**:
As part of the specification of a data profiling scan, you can specify the scope of a job as one of the following options:
* Full table: The entire table is scanned in the data profiling scan. Sampling, row filters, and column filters are applied on the entire table before calculating the profiling statistics.
* Incremental: Incremental data that you specify is scanned in the data profile scan. Specify a Date or Timestamp column in the table to be used as an increment. Typically, this is the column on which the table is partitioned. Sampling, row filters, and column filters are applied on the incremental data before calculating the profiling statistics.

**Filter data**:
You can filter the data to be scanned for profiling by using row filters and column filters. Using filters helps you reduce the execution time and cost, and exclude sensitive and unuseful data.
* Row filters: Row filters let you focus on data within a specific time period or from a specific segment, such as region. For example, you can filter out data with a timestamp before a certain date.
* Column filters: Column filters lets you include and exclude specific columns from your table to run the data profiling scan.

**Sample data**:
Knowledge Catalog lets you specify a percentage of records from your data to sample for running a data profiling scan. Creating data profiling scans on a smaller sample of data can reduce the execution time and cost of querying the entire dataset.

Let's get started:
1. Go to the <walkthrough-spotlight-pointer locator="semantic({link 'Data profiling &amp; quality, 1 of 1'})">Data profiling & quality</walkthrough-spotlight-pointer> section in [Knowledge Catalog](https://console.cloud.google.com/dataplex).
2. Click <walkthrough-spotlight-pointer locator="semantic({button 'Create data profile scan'})">Create data profile scan</walkthrough-spotlight-pointer>
3. Set Display Name to `bootkon-profile-fraud-prediction` for example 
4. Optionally add a description. For example, "data profile scans for fraud detection predictions"
5. Leave the “Browse within Knowledge Catalog Lakes” option turned off
6. Click on <walkthrough-spotlight-pointer locator="semantic({button 'Browse'})">Browse</walkthrough-spotlight-pointer> to select the `data_predictions` BigQuery table (Dataset: `bootkon_raw_zone`). 
7. <walkthrough-spotlight-pointer locator="semantic({button 'Select'})">SELECT</walkthrough-spotlight-pointer> `data_predictions` bigquery table
8. Choose "Entire data" in the dropdown as the <walkthrough-spotlight-pointer locator="semantic({combobox 'Scope'})">Scope</walkthrough-spotlight-pointer> for the data profiling job
9. Choose "All data" in the <walkthrough-spotlight-pointer locator="semantic({combobox 'Sampling size'})">Sampling size</walkthrough-spotlight-pointer> dropdown
10. Select the checkbox for "Publish results to Knowledge Catalog"
11. Choose "Service Account" for the Credential Type and select `Knowledge Catalog DQ Service Account` as the service account.
12. Choose On-demand schedule
13. Click <walkthrough-spotlight-pointer locator="semantic({button 'Continue'})">CONTINUE</walkthrough-spotlight-pointer>, leave the rest as default and click <walkthrough-spotlight-pointer locator="semantic({button 'Create'})">CREATE</walkthrough-spotlight-pointer>

  It will take a couple of minutes for the profiling to show up on the console.

14. Click on the `bootkon-profile-fraud-prediction` profile and then click <walkthrough-spotlight-pointer locator="semantic({button 'Run now'})">RUN NOW</walkthrough-spotlight-pointer> 
15. Click on the `Job Id` and monitor the job execution 
16. Notice what the job is doing. The job should succeed in less than 10 minutes
17. Explore the data profiling results of the `Class` column name. We have less than 0.1% of fraudulent transactions. Also notice that `predicted_class` of type `RECORD` were not fully profiled, only the percentage of null and unique values were correctly profiled. Refer to the supported data types [here]( https://cloud.google.com/dataplex/docs/data-profiling-overview#data-profile-result)

  ![](../img/lab5/dataprofileresultgraph.png)


18. As they train further continuously the fraud detection ML models, data professionals would like to set up an automatic check on data quality and be notified when there are huge discrepancies between `predicted_class` and `Class` values. This is where Knowledge Catalog data quality could help the team. 

---

### Setup Data Quality Jobs

After setting up the data profiling scan we have seen that we still have no clear visibility on fluctuation between `predicted_classes` vs actual `Class` ratio. Our goal is to have a percentage of matched values between `Class` and `predicted_classes` more than 99.99 %. Any lower percentage would indicate that we would have to further train the ML model or add more features or use another model architecture.

You can use the following SQL query in [BigQuery](https://console.cloud.google.com/bigquery) to check the percentage of matched values between `Class` and `predicted_classes`. 

```sql
WITH RankedPredictions AS (
 SELECT
   class,
   ARRAY(
     SELECT AS STRUCT classes, scores
     FROM UNNEST(predicted_class.classes) classes WITH OFFSET AS pos
     JOIN UNNEST(predicted_class.scores) scores WITH OFFSET AS pos2
     ON pos = pos2
     ORDER BY scores DESC
     LIMIT 1
   )[OFFSET(0)].* 
 FROM
   `{{ PROJECT_ID }}.bootkon_raw_zone.data_predictions`
)

SELECT
 SUM(CASE WHEN class = CAST(highest_score_class AS STRING) THEN 1 ELSE 0 END) * 100.0 / COUNT(*)  AS PercentageMatch
FROM (
 SELECT
  class,classes AS highest_score_class
 FROM
   RankedPredictions
)
```

We will set up the Knowledge Catalog automatic data quality, which lets you define and measure the quality of your data. You can automate the scanning of data, validate data against defined rules, and log alerts if your data doesn't meet quality requirements. You can manage data quality rules and deployments as code, improving the integrity of data production pipelines.

During the previous lab, we got started by using [Knowledge Catalog data profiling](https://cloud.google.com/dataplex/docs/data-profiling-overview) rule recommendations to drive initial conclusions on areas of attention. Knowledge Catalog provides monitoring, troubleshooting, and Cloud Logging alerting that's integrated with Knowledge Catalog auto data quality.

**Conceptual Model**

A data scan is a Knowledge Catalog job which samples data from BigQuery and Cloud Storage and infers various types of metadata. To measure the quality of a table using auto data quality, you create a DataScan object of type data quality. The scan runs on only one BigQuery table. The scan uses resources in a Google tenant project, so you don't need to set up your own infrastructure.
Creating and using a data quality scan consists of the following steps:
1. Rule definition
2. Rule execution
3. Monitoring and alerting
4. Troubleshooting

**Lab Instructions**

1. Go to the <walkthrough-spotlight-pointer locator="semantic({link 'Data profiling &amp; quality, 1 of 1'})">Data profiling & quality</walkthrough-spotlight-pointer> section in the left hand menu of Knowledge Catalog.

2. Click on <walkthrough-spotlight-pointer locator="semantic({button 'Create data quality scan'})">Create data quality scan</walkthrough-spotlight-pointer>
3. Display Name: `bootkon-dquality-fraud-prediction` for example 
4. Optionally add a description. For example, "data quality scans for fraud detection predictions"
5. Leave the "Browse within Knowledge Catalog Lakes" option turned off 
6. Click <walkthrough-spotlight-pointer locator="semantic({button 'Browse'})">BROWSE</walkthrough-spotlight-pointer> to filter on the `data_predictions` BigQuery table (Dataset: `bootkon_raw_zone`) 
7. <walkthrough-spotlight-pointer locator="semantic({button 'Select'})">SELECT</walkthrough-spotlight-pointer> `data_predictions` BigQuery table
8. Choose "Entire data" as the <walkthrough-spotlight-pointer locator="semantic({combobox 'Scope'})">Scope</walkthrough-spotlight-pointer> of the data profiling job
9. Choose "All data" for <walkthrough-spotlight-pointer locator="semantic({combobox 'Sampling size'})">Sampling size</walkthrough-spotlight-pointer> 
10. Leave on the option "Publish results to Knowledge Catalog"
11. Choose "Service Account" for the Credential Type and select `Knowledge Catalog DQ Service Account` as the service account.

12. Choose On-demand as the scan schedule
13. Click <walkthrough-spotlight-pointer locator="semantic({button 'Continue'})">CONTINUE</walkthrough-spotlight-pointer>

Now let's define quality rules. Click on the <walkthrough-spotlight-pointer locator="semantic({button 'Add Rules'})">ADD RULES</walkthrough-spotlight-pointer> dropdown and choose `SQL Assertion Rule`

14. Choose `Accuracy` as dimension 
15. Rule name: `bootkon-dquality-ml-fraud-prediction`
16. Description : `Regularly check the ML fraud detection prediction quality results`
17. Leave the column name empty
18. Provide the following SQL statement. Knowledge Catalog will utilize this to create a SQL clause of the form SELECT COUNT(*) FROM (sql statement) to return success/failure. The assertion rule is passed if the returned assertion row count is 0.

```sql
WITH RankedPredictions AS (
 SELECT
   class,
   ARRAY(
     SELECT AS STRUCT classes, scores
     FROM UNNEST(predicted_class.classes) classes WITH OFFSET AS pos
     JOIN UNNEST(predicted_class.scores) scores WITH OFFSET AS pos2
     ON pos = pos2
     ORDER BY scores DESC
     LIMIT 1
   )[OFFSET(0)].*,
 FROM
   `{{ PROJECT_ID }}.bootkon_raw_zone.data_predictions`
)

SELECT
 SUM(CASE WHEN class = CAST(highest_score_class AS STRING) THEN 1 ELSE 0 END) * 100.0 / COUNT(*)  AS PercentageMatch
FROM (
 SELECT
   class,
   classes AS highest_score_class
 FROM
   RankedPredictions
)
   HAVING PercentageMatch <= 99.99
```

19. Click <walkthrough-spotlight-pointer locator="semantic({button 'Add'})">ADD</walkthrough-spotlight-pointer>
20. Click <walkthrough-spotlight-pointer locator="semantic({button 'Continue'})">CONTINUE</walkthrough-spotlight-pointer>
21. <walkthrough-spotlight-pointer locator="semantic({button 'Run scan'})">RUN SCAN</walkthrough-spotlight-pointer> (The display name may take a moment to appear on the screen)
22. Monitor the job execution. Notice the job succeeded but the rule failed because our model accuracy percentage on the whole data predicted does not exceed the 99.99% threshold that we set
23. You may need to choose <walkthrough-spotlight-pointer locator="semantic({button 'Run now'})">RUN NOW</walkthrough-spotlight-pointer> in order to see the results of the `bootkon-dquality-fraud-prediction` data quality scan


### Success

🎉 Congratulations {% if MY_NAME %} {{ MY_NAME }}{% endif %}! 🚀

You've successfully completed the Data & AI Boot-Kon Knowledge Catalog lab! You've gained a solid understanding of Knowledge Catalog, creating lakes and zones, and adding assets from GCS and BigQuery.

You built data profiling and quality checks, exploring assets and setting up monitoring for fraud detection predictions. Even with the accuracy not yet at 99.99%, you've established monitoring for improvement – proactive data governance!

Bring on the next challenge – you've got this! 🚀
