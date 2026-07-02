## Lab 5: The BigQuery Data Agent

<walkthrough-tutorial-duration duration="25"></walkthrough-tutorial-duration>
{{ author('Fabian Hirschmann', 'https://linkedin.com/in/fhirschmann') }}
<walkthrough-tutorial-difficulty difficulty="2"></walkthrough-tutorial-difficulty>
<bootkon-cloud-shell-note/>

Time for the first agent. **Conversational analytics data agents** live inside BigQuery: you point one at your governed gold tables, give it context, and business users chat with the data in natural language — the agent writes and runs the SQL. In Lab 6 this same agent becomes a *service* that other agents call over A2A, so make it good.

Note the payoff of your work so far: the agent will only ever see the **gold** layer — cleaned by your silver models, quality-scanned, PII-tagged, and documented. Grounded agents start with governed data.

### About data agents

A conversational analytics **data agent** bundles three things: the *knowledge sources* it may query (your gold tables), *context* that teaches it your business language (the system instructions you are about to write), and *verified queries* — blessed question/SQL pairs it prefers over improvising. When a user asks a question, Gemini translates it into SQL against exactly those sources, runs it as a regular BigQuery job — so IAM and your column-level security from Lab 4 fully apply — and summarizes the result, showing its SQL as it goes. And because the underlying **Conversational Analytics API** is GA, a *published* agent is not just a console toy: it is a callable resource with its own IAM — which is precisely what Lab 6 exploits.

Learn more:
- [Create and use data agents in BigQuery](https://docs.cloud.google.com/bigquery/docs/create-data-agents)
- [Conversational Analytics API](https://docs.cloud.google.com/gemini/data-agents/conversational-analytics-api/overview)

### Draft the instructions with agy

A data agent is only as good as its context. That context is derived from your schemas — authoring work, so it goes to agy. Run this in a terminal (non-interactive mode; the prompt is also in <walkthrough-editor-open-file filePath="content/agenticdata/src/prompts.md">prompts.md</walkthrough-editor-open-file>):

```bash
agy -p "Read the table schemas: bq show --schema {{ PROJECT_ID }}:cymbal_gold.fct_daily_revenue ; bq show --schema {{ PROJECT_ID }}:cymbal_gold.dim_customer_360 ; bq show --schema {{ PROJECT_ID }}:cymbal_gold.fct_product_performance. Then draft system instructions for a BigQuery conversational data agent over these three tables: synonyms business users might use (revenue, sales, LTV, best sellers), which table answers which kind of question, default groupings (order_date, currency, category), and columns to exclude from summaries (email). Output only the instructions text."
```

Review the output — you are about to make it the agent's world-view. A solid baseline, if you prefer to use it directly or to compare:

```
Tables and their roles:
- fct_daily_revenue: revenue, sales, turnover questions. Group by order_date and currency by default. gross_revenue is SUM(qty * unit_price) excluding cancelled orders.
- dim_customer_360: customer questions. "LTV", "lifetime value", "best customers" -> lifetime_value. One row per deduplicated customer.
- fct_product_performance: product questions. "best sellers" -> units_sold; "most profitable" -> gross_margin. Group by category for overviews.

Rules:
- Amounts are per currency; never sum across currencies without saying so.
- Exclude the email column from any output or summary.
- "Orders" means non-cancelled orders unless the user asks otherwise.
- Data freshness: near real time via CDC + Dataform runs; mention the latest order_date when answering trend questions.
```

### Create the agent

1. Go to the [BigQuery Console](https://console.cloud.google.com/bigquery).
2. Expand <walkthrough-spotlight-pointer locator="semantic({treeitem 'Toggle node {{ PROJECT_ID }}'} {button 'Toggle node'})">{{ PROJECT_ID }}</walkthrough-spotlight-pointer> and click <walkthrough-spotlight-pointer locator="text('Agents')">Agents</walkthrough-spotlight-pointer>.
3. Click <walkthrough-spotlight-pointer locator="semantic({button 'Create agent'})">Create agent</walkthrough-spotlight-pointer>.
4. Name it ``cymbal-data-agent`` — Lab 6 refers to it by exactly this name — and add a description like *"Analytics over Cymbal's gold layer"*.
5. Click *Add Source* and select the three gold tables: ``fct_daily_revenue``, ``dim_customer_360``, ``fct_product_performance``.
6. Paste your instructions (agy's draft, reviewed, or the baseline above) into the instructions box.

### Add a verified query

Verified queries are blessed SQL the agent prefers over improvising — your accuracy anchor. Add one for the most common question, total revenue by day:

```sql
SELECT order_date, currency, SUM(gross_revenue) AS revenue
FROM `{{ PROJECT_ID }}.cymbal_gold.fct_daily_revenue`
GROUP BY order_date, currency
ORDER BY order_date DESC
```

with the natural-language question: ``What was our revenue by day?``

### Publish and converse

In the top bar:
1. Click ``Save``
2. Then ``Publish`` — publishing is what makes the agent callable via the Conversational Analytics API, which Lab 6 depends on.

Now click ``Create conversation`` and interrogate your platform. Try these, then improvise:

- What was our total revenue in EUR in the last 30 days?
- Who are our top 10 customers by lifetime value, and which countries are they from?
- Which product category has the best gross margin?
- Are there any days with unusually high revenue? What might explain them?

Watch what comes back: the agent shows the SQL it generated against your gold tables. You spent three labs making those tables mean something — this is where it pays off. (Also try asking for customer *emails* — the agent queries gold, where governance applies.)

### Challenge: stress-test the grounding

**\[TASK\]** Take up to 5 minutes: try to make the agent say something wrong.

- Ask about data it doesn't have ("What's our warehouse inventory?") — does it admit ignorance or hallucinate?
- Ask an ambiguous question ("How are sales?") — does it apply your default groupings from the instructions?
- Refine the instructions based on what you find and re-publish. Iterating on agent context *is* data work now.

### Success

🎉 Excellent{% if MY_NAME %}, {{ MY_NAME }}{% endif %}! Cymbal now has a published data agent: natural language in, governed SQL out, grounded in the gold layer you built and documented. One agent down — in the finale, it gets a colleague. 🤖
