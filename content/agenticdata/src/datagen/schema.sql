-- Cymbal OLTP schema (Agentic Data Bootkon).
--
-- Every table has a single-column integer primary key: Datastream's BigQuery
-- merge mode requires primary keys (and forbids FLOAT/REAL keys).
--
-- There are deliberately NO foreign-key constraints: the seed data contains
-- planted referential drift (orphaned order_items) that is part of the
-- data-quality story told in the Dataform and Knowledge Catalog labs.

CREATE SCHEMA IF NOT EXISTS cymbal;

CREATE TABLE cymbal.customers (
    customer_id BIGINT PRIMARY KEY,
    full_name   TEXT NOT NULL,
    email       TEXT,
    phone       TEXT,
    address     TEXT,
    country     TEXT,
    created_at  TIMESTAMPTZ NOT NULL,
    updated_at  TIMESTAMPTZ NOT NULL
);

CREATE TABLE cymbal.products (
    product_id BIGINT PRIMARY KEY,
    sku        TEXT NOT NULL,
    name       TEXT NOT NULL,
    category   TEXT NOT NULL,
    price      NUMERIC(10, 2) NOT NULL,
    cost       NUMERIC(10, 2) NOT NULL
);

CREATE TABLE cymbal.orders (
    order_id    BIGINT PRIMARY KEY,
    customer_id BIGINT NOT NULL,
    status      TEXT NOT NULL,
    currency    TEXT NOT NULL,
    order_ts    TIMESTAMPTZ NOT NULL,
    updated_at  TIMESTAMPTZ NOT NULL
);

CREATE TABLE cymbal.order_items (
    order_item_id BIGINT PRIMARY KEY,
    order_id      BIGINT NOT NULL,
    product_id    BIGINT NOT NULL,
    qty           INTEGER NOT NULL,
    unit_price    NUMERIC(10, 2) NOT NULL
);

CREATE TABLE cymbal.payments (
    payment_id BIGINT PRIMARY KEY,
    order_id   BIGINT NOT NULL,
    method     TEXT NOT NULL,
    amount     NUMERIC(12, 2) NOT NULL,
    status     TEXT NOT NULL,
    paid_at    TIMESTAMPTZ
);

CREATE TABLE cymbal.reviews (
    review_id   BIGINT PRIMARY KEY,
    order_id    BIGINT NOT NULL,
    rating      INTEGER NOT NULL,
    review_text TEXT,
    created_at  TIMESTAMPTZ NOT NULL
);
