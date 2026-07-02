#!/usr/bin/env python3
"""Deterministic synthetic OLTP data generator for the Cymbal orders platform.

Writes header-less CSV files (one per table, column order matching schema.sql)
suitable for `gcloud sql import csv` (server-side COPY ... CSV). With the fixed
seed and pinned dependency versions, every participant generates *identical*
data, so lab instructions, data-quality thresholds and verified queries can
reference exact values.

The data contains PLANTED FLAWS on purpose -- they are the raw material for
the silver layer and the Knowledge Catalog data-quality lab:

  * duplicate customers (same email, different letter case, new customer_id)
  * invalid email addresses
  * NULL countries
  * order status typo: 'shiped'
  * mixed-case currency codes ('eur' next to 'EUR')
  * zero/negative order_items.qty
  * orphaned order_items (order_id that does not exist)
  * orders with a future order_ts
  * negative payment amounts

Usage:
    python3 generate.py --out ~/seed_data [--scale 1.0]
"""

import argparse
import csv
import os
import random
from datetime import datetime, timedelta, timezone

from faker import Faker

SEED = 42
WINDOW_START = datetime(2025, 1, 1, tzinfo=timezone.utc)
WINDOW_DAYS = 540  # Jan 2025 .. mid 2026

N_CUSTOMERS = 50_000
N_PRODUCTS = 5_000
N_ORDERS = 500_000
N_REVIEWS = 50_000

CATEGORIES = [
    "Home & Kitchen", "Electronics", "Outdoor", "Office", "Toys & Games",
    "Beauty", "Sports", "Automotive", "Pet Supplies", "Grocery",
    "Apparel", "Garden",
]
COUNTRIES = [
    "Germany", "France", "Netherlands", "Spain", "Italy", "Poland",
    "Belgium", "Austria", "Switzerland", "Sweden", "Portugal", "Ireland",
]
EMAIL_DOMAINS = ["example.com", "example.org", "mail.example.net", "inbox.example.dev"]
CURRENCIES = ["EUR", "USD", "GBP", "CHF", "PLN"]
CURRENCY_WEIGHTS = [50, 25, 10, 10, 5]
STATUSES = ["pending", "paid", "shipped", "delivered", "cancelled", "returned"]
STATUS_WEIGHTS = [5, 10, 15, 55, 10, 5]
PAY_METHODS = ["card", "paypal", "bank_transfer", "gift_card"]
PRODUCT_ADJECTIVES = [
    "Ultra", "Compact", "Deluxe", "Eco", "Smart", "Classic", "Portable",
    "Premium", "Foldable", "Wireless", "Heavy-Duty", "Mini",
]
PRODUCT_NOUNS = [
    "Blender", "Lamp", "Backpack", "Speaker", "Notebook", "Bottle", "Chair",
    "Charger", "Kettle", "Tent", "Keyboard", "Mat", "Drill", "Mug", "Router",
]
REVIEW_TEMPLATES = [
    "Absolutely love this {noun}. {extra}",
    "The {noun} arrived quickly and works as described. {extra}",
    "Not what I expected. The {noun} feels cheap. {extra}",
    "Great value for money, would buy this {noun} again. {extra}",
    "The {noun} stopped working after a week. Support was {support}.",
    "Five stars. Best {noun} I have owned so far. {extra}",
    "Mediocre {noun}. Delivery was {support}, though.",
]
REVIEW_EXTRAS = [
    "Highly recommended.", "Shipping took longer than promised.",
    "Packaging was damaged but the product is fine.", "My whole family uses it.",
    "Will order again.", "Returned it the next day.", "Setup took two minutes.",
]
SUPPORT_WORDS = ["helpful", "slow", "excellent", "unresponsive", "friendly"]

# Planted-flaw rates
P_DUP_CUSTOMER = 0.010
P_INVALID_EMAIL = 0.005
P_NULL_COUNTRY = 0.015
P_STATUS_TYPO = 0.040   # applied to 'shipped' orders only
P_CURRENCY_LOWER = 0.030
P_BAD_QTY = 0.003
P_ORPHAN_ITEM = 0.002
P_FUTURE_TS = 0.001
P_NEGATIVE_PAYMENT = 0.002

ORPHAN_ORDER_BASE = 90_000_000


def fmt(dt):
    return dt.strftime("%Y-%m-%d %H:%M:%S+00")


def rand_ts(rnd):
    return WINDOW_START + timedelta(seconds=rnd.randint(0, WINDOW_DAYS * 86400 - 1))


def writer(out_dir, name):
    f = open(os.path.join(out_dir, name), "w", newline="")
    return f, csv.writer(f)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default="./seed_data", help="output directory for CSV files")
    parser.add_argument("--scale", type=float, default=1.0,
                        help="scale factor for row counts (use e.g. 0.1 for a quick re-run)")
    args = parser.parse_args()

    os.makedirs(args.out, exist_ok=True)
    rnd = random.Random(SEED)
    Faker.seed(SEED)
    fake = Faker()

    n_customers = int(N_CUSTOMERS * args.scale)
    n_products = int(N_PRODUCTS * args.scale)
    n_orders = int(N_ORDERS * args.scale)
    n_reviews = min(int(N_REVIEWS * args.scale), n_orders)

    # Small Faker-built pools; rows are assembled from pools (fast + deterministic).
    print("Building value pools ...")
    first_names = [fake.first_name() for _ in range(600)]
    last_names = [fake.last_name() for _ in range(600)]
    streets = [fake.street_name() for _ in range(300)]
    cities = [fake.city() for _ in range(200)]

    # ------------------------------------------------------------- customers
    print(f"Generating {n_customers} customers (+ ~{P_DUP_CUSTOMER:.0%} duplicates) ...")
    f, w = writer(args.out, "customers.csv")
    duplicates = []
    for cid in range(1, n_customers + 1):
        fn, ln = rnd.choice(first_names), rnd.choice(last_names)
        full_name = f"{fn} {ln}"
        email = f"{fn}.{ln}{cid}@{rnd.choice(EMAIL_DOMAINS)}".lower()
        if rnd.random() < P_INVALID_EMAIL:
            email = email.replace("@", " at ")
        phone = f"+{rnd.randint(1, 49)} {rnd.randint(100, 999)} {rnd.randint(1_000_000, 9_999_999)}"
        address = f"{rnd.randint(1, 999)} {rnd.choice(streets)}, {rnd.choice(cities)}"
        country = "" if rnd.random() < P_NULL_COUNTRY else rnd.choice(COUNTRIES)
        created = rand_ts(rnd)
        updated = created + timedelta(seconds=rnd.randint(0, 90 * 86400))
        w.writerow([cid, full_name, email, phone, address, country, fmt(created), fmt(updated)])
        if rnd.random() < P_DUP_CUSTOMER:
            duplicates.append((full_name, email, phone, country, created))
    # Duplicate customers: same person, email in a different letter case, new id.
    next_id = n_customers + 1
    for full_name, email, phone, country, created in duplicates:
        dup_email = email.upper() if rnd.random() < 0.5 else email.title()
        address = f"{rnd.randint(1, 999)} {rnd.choice(streets)}, {rnd.choice(cities)}"
        created2 = created + timedelta(seconds=rnd.randint(3600, 200 * 86400))
        w.writerow([next_id, full_name, dup_email, phone, address, country,
                    fmt(created2), fmt(created2)])
        next_id += 1
    total_customers = next_id - 1
    f.close()

    # -------------------------------------------------------------- products
    print(f"Generating {n_products} products ...")
    f, w = writer(args.out, "products.csv")
    prices = [0.0] * (n_products + 1)
    for pid in range(1, n_products + 1):
        name = f"{rnd.choice(PRODUCT_ADJECTIVES)} {rnd.choice(PRODUCT_NOUNS)}"
        price = round(min(999.0, max(3.0, rnd.lognormvariate(3.2, 0.7))), 2)
        cost = round(price * rnd.uniform(0.4, 0.8), 2)
        prices[pid] = price
        w.writerow([pid, f"CYM-{pid:05d}", name, rnd.choice(CATEGORIES), price, cost])
    f.close()

    # ------------------------------------- orders + order_items + payments
    print(f"Generating {n_orders} orders (+ items, payments) ...")
    fo, wo = writer(args.out, "orders.csv")
    fi, wi = writer(args.out, "order_items.csv")
    fp, wp = writer(args.out, "payments.csv")
    item_id = 0
    orphan_count = 0
    for oid in range(1, n_orders + 1):
        customer_id = rnd.randint(1, total_customers)
        order_ts = rand_ts(rnd)
        if rnd.random() < P_FUTURE_TS:
            order_ts = datetime(2027, 1, 1, tzinfo=timezone.utc) + timedelta(
                seconds=rnd.randint(0, 180 * 86400))
        status = rnd.choices(STATUSES, weights=STATUS_WEIGHTS, k=1)[0]
        if status == "shipped" and rnd.random() < P_STATUS_TYPO:
            status = "shiped"
        currency = rnd.choices(CURRENCIES, weights=CURRENCY_WEIGHTS, k=1)[0]
        if rnd.random() < P_CURRENCY_LOWER:
            currency = currency.lower()
        updated = order_ts + timedelta(seconds=rnd.randint(0, 14 * 86400))
        wo.writerow([oid, customer_id, status, currency, fmt(order_ts), fmt(updated)])

        n_items = rnd.choices([1, 2, 3, 4, 5], weights=[30, 30, 20, 12, 8], k=1)[0]
        order_total = 0.0
        for _ in range(n_items):
            item_id += 1
            product_id = rnd.randint(1, n_products)
            qty = rnd.randint(1, 5)
            if rnd.random() < P_BAD_QTY:
                qty = rnd.choice([0, -1, -2])
            unit_price = round(prices[product_id] * rnd.uniform(0.9, 1.1), 2)
            parent = oid
            if rnd.random() < P_ORPHAN_ITEM:
                orphan_count += 1
                parent = ORPHAN_ORDER_BASE + orphan_count
            wi.writerow([item_id, parent, product_id, qty, unit_price])
            if parent == oid and qty > 0:
                order_total += qty * unit_price

        amount = round(order_total, 2)
        if rnd.random() < P_NEGATIVE_PAYMENT:
            amount = -amount
        pay_status = "captured" if status in ("paid", "shipped", "shiped", "delivered", "returned") else (
            "void" if status == "cancelled" else "pending")
        paid_at = fmt(order_ts + timedelta(minutes=rnd.randint(1, 240))) if pay_status == "captured" else ""
        wp.writerow([oid, oid, rnd.choice(PAY_METHODS), amount, pay_status, paid_at])

        if oid % 100_000 == 0:
            print(f"  ... {oid} orders")
    fo.close(); fi.close(); fp.close()

    # --------------------------------------------------------------- reviews
    print(f"Generating {n_reviews} reviews ...")
    f, w = writer(args.out, "reviews.csv")
    reviewed = rnd.sample(range(1, n_orders + 1), n_reviews)
    for rid, order_id in enumerate(sorted(reviewed), start=1):
        rating = rnd.choices([1, 2, 3, 4, 5], weights=[6, 8, 16, 35, 35], k=1)[0]
        text = rnd.choice(REVIEW_TEMPLATES).format(
            noun=rnd.choice(PRODUCT_NOUNS).lower(),
            extra=rnd.choice(REVIEW_EXTRAS),
            support=rnd.choice(SUPPORT_WORDS),
        )
        created = rand_ts(rnd)
        w.writerow([rid, order_id, rating, text, fmt(created)])
    f.close()

    print(f"\nDone. CSV files written to {os.path.abspath(args.out)}")
    print(f"  customers:   {total_customers} (incl. {total_customers - n_customers} planted duplicates)")
    print(f"  products:    {n_products}")
    print(f"  orders:      {n_orders}")
    print(f"  order_items: {item_id} (incl. {orphan_count} planted orphans)")
    print(f"  payments:    {n_orders}")
    print(f"  reviews:     {n_reviews}")


if __name__ == "__main__":
    main()
