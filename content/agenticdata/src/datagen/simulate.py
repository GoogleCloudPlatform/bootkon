#!/usr/bin/env python3
"""Live-activity simulator for the Cymbal orders platform.

Continuously INSERTs new orders (with items and a payment), UPDATEs order
statuses and customer emails, and occasionally DELETEs an abandoned pending
order -- so Datastream always has change events to replicate. Run it in its
own terminal and leave it running for the rest of the event.

It connects through the IAP tunnel, so the tunnel terminal must stay open:

    python3 content/agenticdata/src/datagen/simulate.py

Environment: BK_DB_PASSWORD (required), BK_CYMBAL_DB_HOST (default localhost),
BK_CYMBAL_DB_PORT (default 5432).
"""

import os
import random
import sys
import time
from datetime import datetime, timezone

import psycopg

CURRENCIES = ["EUR", "USD", "GBP", "CHF", "PLN"]
PAY_METHODS = ["card", "paypal", "bank_transfer", "gift_card"]
STATUS_NEXT = {"pending": "paid", "paid": "shipped", "shipped": "delivered"}
EMAIL_DOMAINS = ["example.com", "example.org", "mail.example.net"]


def now():
    return datetime.now(timezone.utc)


def log(action, detail):
    print(f"[{now().strftime('%H:%M:%S')}] {action:<14} {detail}", flush=True)


def main():
    password = os.environ.get("BK_DB_PASSWORD")
    if not password:
        sys.exit("BK_DB_PASSWORD is not set. Run '. bk' to reload it (written to vars.local.sh by bk-bootstrap).")
    host = os.environ.get("BK_CYMBAL_DB_HOST", "localhost")
    port = int(os.environ.get("BK_CYMBAL_DB_PORT", "5432"))

    conn = psycopg.connect(host=host, port=port, dbname="cymbal", user="postgres",
                           password=password, connect_timeout=10, autocommit=True)
    rnd = random.Random()  # intentionally unseeded: every run produces new events

    with conn.cursor() as cur:
        cur.execute("SELECT COALESCE(MAX(order_id), 0), "
                    "(SELECT COALESCE(MAX(order_item_id), 0) FROM cymbal.order_items), "
                    "(SELECT COALESCE(MAX(payment_id), 0) FROM cymbal.payments), "
                    "(SELECT COALESCE(MAX(customer_id), 0) FROM cymbal.customers) "
                    "FROM cymbal.orders")
        next_order, next_item, next_payment, max_customer = cur.fetchone()
    print(f"Connected to {host}:{port}/cymbal -- simulating live activity. Ctrl+C to stop.")

    inserted = updated = deleted = 0
    try:
        while True:
            r = rnd.random()
            with conn.cursor() as cur:
                if r < 0.60:  # new order
                    next_order += 1
                    next_payment += 1
                    customer_id = rnd.randint(1, max_customer)
                    currency = rnd.choice(CURRENCIES)
                    cur.execute(
                        "INSERT INTO cymbal.orders VALUES (%s, %s, 'pending', %s, %s, %s)",
                        (next_order, customer_id, currency, now(), now()))
                    total = 0.0
                    for _ in range(rnd.randint(1, 3)):
                        next_item += 1
                        product_id = rnd.randint(1, 5000)
                        qty = rnd.randint(1, 4)
                        cur.execute("SELECT price FROM cymbal.products WHERE product_id = %s",
                                    (product_id,))
                        row = cur.fetchone()
                        unit_price = round(float(row[0]) * rnd.uniform(0.9, 1.1), 2) if row else 19.99
                        cur.execute("INSERT INTO cymbal.order_items VALUES (%s, %s, %s, %s, %s)",
                                    (next_item, next_order, product_id, qty, unit_price))
                        total += qty * unit_price
                    cur.execute("INSERT INTO cymbal.payments VALUES (%s, %s, %s, %s, 'pending', NULL)",
                                (next_payment, next_order, rnd.choice(PAY_METHODS), round(total, 2)))
                    inserted += 1
                    log("INSERT order", f"order_id={next_order} total={total:.2f} {currency}")

                elif r < 0.85:  # progress an order status
                    cur.execute(
                        "SELECT order_id, status FROM cymbal.orders "
                        "WHERE status IN ('pending', 'paid', 'shipped') "
                        "ORDER BY order_id DESC LIMIT 50")
                    rows = cur.fetchall()
                    if rows:
                        order_id, status = rnd.choice(rows)
                        new_status = STATUS_NEXT[status]
                        cur.execute(
                            "UPDATE cymbal.orders SET status = %s, updated_at = %s "
                            "WHERE order_id = %s", (new_status, now(), order_id))
                        if new_status == "paid":
                            cur.execute(
                                "UPDATE cymbal.payments SET status = 'captured', paid_at = %s "
                                "WHERE order_id = %s", (now(), order_id))
                        updated += 1
                        log("UPDATE status", f"order_id={order_id} {status} -> {new_status}")

                elif r < 0.95:  # customer changes their email
                    customer_id = rnd.randint(1, max_customer)
                    new_email = f"user{customer_id}.{rnd.randint(100, 999)}@{rnd.choice(EMAIL_DOMAINS)}"
                    cur.execute(
                        "UPDATE cymbal.customers SET email = %s, updated_at = %s "
                        "WHERE customer_id = %s", (new_email, now(), customer_id))
                    updated += 1
                    log("UPDATE email", f"customer_id={customer_id} -> {new_email}")

                else:  # abandon (delete) a recent pending order
                    cur.execute(
                        "SELECT order_id FROM cymbal.orders WHERE status = 'pending' "
                        "ORDER BY order_id DESC LIMIT 20")
                    rows = cur.fetchall()
                    if rows:
                        order_id = rnd.choice(rows)[0]
                        cur.execute("DELETE FROM cymbal.order_items WHERE order_id = %s", (order_id,))
                        cur.execute("DELETE FROM cymbal.payments WHERE order_id = %s", (order_id,))
                        cur.execute("DELETE FROM cymbal.orders WHERE order_id = %s", (order_id,))
                        deleted += 1
                        log("DELETE order", f"order_id={order_id} (abandoned)")

            time.sleep(rnd.uniform(1.0, 3.0))
    except KeyboardInterrupt:
        print(f"\nStopped. {inserted} orders inserted, {updated} updates, {deleted} deletes.")


if __name__ == "__main__":
    main()
