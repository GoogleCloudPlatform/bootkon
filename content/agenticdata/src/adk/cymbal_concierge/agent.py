"""cymbal_concierge -- the root agent participants chat with in `adk web`.

It spans two planes:
  * analytical: delegates aggregate questions over A2A to cymbal_analyst
    (which consults the BigQuery data agent on the governed gold layer);
  * operational: looks up individual live orders directly in Cloud SQL
    Postgres through the IAP tunnel (localhost:5432).

All configuration (model, database password, hosts) comes from environment
variables written to vars.local.sh by bk-bootstrap in Lab 1.
"""

import os

import psycopg
from google.adk.agents import Agent
from google.adk.agents.remote_a2a_agent import (
    AGENT_CARD_WELL_KNOWN_PATH,
    RemoteA2aAgent,
)

cymbal_analyst = RemoteA2aAgent(
    name="cymbal_analyst",
    description=(
        "Remote analytics specialist (via the A2A protocol). Handles "
        "aggregate business questions: revenue, trends, customer lifetime "
        "value, product performance -- anything answered from the governed "
        "gold layer in BigQuery."
    ),
    agent_card=f"http://localhost:8001{AGENT_CARD_WELL_KNOWN_PATH}",
)


def check_order_status(order_id: int) -> dict:
    """Look up ONE order in Cymbal's LIVE operational Postgres database.

    Use this for questions about a specific order (status, when it was
    placed, its total, number of items, payment state). Do NOT use it for
    aggregate/analytical questions.

    Args:
        order_id: The numeric order id, e.g. 421337.

    Returns:
        A dict with the order's live status, or found=False if it does not
        exist (it may have been abandoned and deleted).
    """
    conn = psycopg.connect(
        host=os.environ.get("BK_CYMBAL_DB_HOST", "localhost"),
        port=int(os.environ.get("BK_CYMBAL_DB_PORT", "5432")),
        dbname="cymbal",
        user="postgres",
        password=os.environ["BK_DB_PASSWORD"],
        connect_timeout=10,
    )
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    o.order_id,
                    o.status,
                    o.currency,
                    o.order_ts,
                    o.updated_at,
                    COUNT(i.order_item_id) AS items,
                    COALESCE(SUM(CASE WHEN i.qty > 0 THEN i.qty * i.unit_price END), 0) AS order_total,
                    MAX(p.status) AS payment_status
                FROM cymbal.orders o
                LEFT JOIN cymbal.order_items i USING (order_id)
                LEFT JOIN cymbal.payments p USING (order_id)
                WHERE o.order_id = %s
                GROUP BY o.order_id, o.status, o.currency, o.order_ts, o.updated_at
                """,
                (order_id,),
            )
            row = cur.fetchone()
    finally:
        conn.close()

    if row is None:
        return {"found": False, "order_id": order_id,
                "note": "No such order in the live database (it may have been abandoned and deleted)."}
    return {
        "found": True,
        "order_id": row[0],
        "status": row[1],
        "currency": row[2],
        "ordered_at": row[3].isoformat(),
        "last_updated": row[4].isoformat(),
        "items": row[5],
        "order_total": float(row[6]),
        "payment_status": row[7],
    }


root_agent = Agent(
    name="cymbal_concierge",
    model=os.environ.get("BK_CYMBAL_MODEL", "gemini-2.5-flash"),
    description="Cymbal's front-desk agent: live order lookups plus delegated analytics.",
    instruction=(
        "You are the Cymbal concierge.\n"
        "Routing rules:\n"
        "1. Questions about a SPECIFIC order (status, total, payment of order "
        "N) -> call the check_order_status tool. This reads the LIVE "
        "operational database.\n"
        "2. AGGREGATE or analytical questions (revenue, trends, best "
        "customers, product performance, forecasts) -> delegate to the "
        "cymbal_analyst sub-agent. It queries the governed gold layer via "
        "the BigQuery data agent, so its numbers are as fresh as the CDC "
        "pipeline.\n"
        "3. If ONE question mixes both planes (a specific order AND an "
        "aggregate part), FIRST call check_order_status and answer that part "
        "yourself, and only THEN transfer the remaining analytics part to "
        "cymbal_analyst.\n"
        "Never invent data. If a lookup finds nothing, say so plainly. Keep "
        "answers short and business-friendly, and mention which plane "
        "(live database vs analytics warehouse) an answer came from."
    ),
    tools=[check_order_status],
    sub_agents=[cymbal_analyst],
)
