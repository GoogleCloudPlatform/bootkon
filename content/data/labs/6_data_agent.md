## Lab 5: Conversational Analytics in BigQuery

<walkthrough-tutorial-duration duration="30"></walkthrough-tutorial-duration>
{{ author('Fabian Hirschmann', 'https://linkedin.com/in/fhirschmann') }}
<walkthrough-tutorial-difficulty difficulty="2"></walkthrough-tutorial-difficulty>
<bootkon-cloud-shell-note/>

{% set DATASET_NAME = "ulb_fraud_detection_biglake" %}

In this lab, we will use BigQuery's built-in generative AI capabilities to explore the `ulb_fraud_detection_biglake` dataset. We will configure and use the Conversational Agent to query our fraud data using natural language, drastically speeding up the time to insight.

### About Conversational Analytics

Conversational analytics in BigQuery lets you chat with agents about your data using natural language. To get answers about your data, you can do the following:

- Create data agents that automatically define data context and query processing instructions for a set of knowledge sources, such as tables, views, graphs, or user-defined functions (UDFs) that you select.
- If needed, you can create context and instructions for an agent in the form of custom table and field metadata, instructions to the agent for interpreting and querying the data, or by creating verified queries (previously known as golden queries) to configure the data agent to effectively answer questions for specific use cases.

### Create an Agent

Let us create your first conversational agent.

1. Go to the [BigQuery Console](https://console.cloud.google.com/bigquery)
3. Expand <walkthrough-spotlight-pointer locator="semantic({treeitem 'Toggle node {{ PROJECT_ID }}'} {button 'Toggle node'})">{{ PROJECT_ID }}</walkthrough-spotlight-pointer>
2. Click <walkthrough-spotlight-pointer locator="css(span[id$=ProjectTreeDatasource-{{ PROJECT_ID }}-bucket-conva-agent])">Agents</walkthrough-spotlight-pointer>
3. Click <walkthrough-spotlight-pointer locator="semantic({button 'Create agent'})">Create Agent</walkthrough-spotlight-pointer>
4. Use ``bootkon-agent`` as name and fill out the description according to your needs.
5. Click *Add Source*  and select ``ulb_fraud_detection_biglake``.
6. For instructions, add the following into the text box
```
Synonyms: 
- "Class": Fraud, Fraudulent, Is Fraud, Fraud Indicator
- "Amount": Transaction Value, Purchase Size
- "Time": Elapsed Seconds

Key fields: 
- Class, Amount, Time, Feedback. 
- IMPORTANT: When returning time, always convert the "Time" FLOAT column into a proper TIMESTAMP named "Transaction_Timestamp". The "Time" column represents seconds elapsed since "2013-09-01 00:00:00".

Excluded Fields: 
- V1 through V28. These are anonymized PCA-transformed ML features and should be excluded from all natural language business summaries and reports unless explicitly requested.

Filtering and grouping: 
- When summarizing data, default to grouping by "Class" to compare fraud vs. non-fraud. 
- When looking for trends, filter and group by the derived "Transaction_Timestamp".

Join relationships: 
- This is a single denormalized lakehouse table. No joins are necessary for standard fraud analysis.
``` 

To get the most out of the BigQuery Conversational Agent, we provided it with context about our dataset. Our `Time` column, for example, currently contains a `FLOAT` representing the number of seconds elapsed since **September 1, 2013, at 00:00:00**. We can instruct the agent to automatically convert this for us, along with defining synonyms and exclusions.