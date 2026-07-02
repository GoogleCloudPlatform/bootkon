// Bronze layer: the raw CDC replica maintained by Datastream (merge mode).
// Datastream's "single target dataset" mode names tables <schema>_<table>,
// hence cymbal_customers etc. inside the cymbal_bronze dataset.
// Declaring them here lets every model use ${ref(...)} so Dataform tracks
// the dependency graph (and BigQuery lineage sees the whole flow).
const BRONZE_TABLES = [
  "customers",
  "products",
  "orders",
  "order_items",
  "payments",
  "reviews",
];

BRONZE_TABLES.forEach((t) =>
  declare({
    schema: "cymbal_bronze",
    name: `cymbal_${t}`,
  })
);
