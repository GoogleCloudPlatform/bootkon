"""cymbal_analyst -- the analytics specialist agent.

It answers business questions by consulting Cymbal's published BigQuery data
agent (Conversational Analytics) and is exposed to other agents over the A2A
protocol by a2a_server.py.

All configuration (GOOGLE_CLOUD_PROJECT, GOOGLE_GENAI_USE_VERTEXAI,
CYMBAL_MODEL, DATA_AGENT_ID) comes from environment variables exported to
~/.bashrc by bk-bootstrap in Lab 1.
"""

import os

from google.adk.agents import Agent

from .ca_tool import ask_cymbal_data_agent

root_agent = Agent(
    name="cymbal_analyst",
    model=os.environ.get("CYMBAL_MODEL", "gemini-2.5-flash"),
    description=(
        "Analytics specialist for Cymbal's governed data warehouse. Answers "
        "aggregate business questions (revenue, trends, customer lifetime "
        "value, product performance) by querying the gold layer through "
        "Cymbal's BigQuery data agent."
    ),
    instruction=(
        "You are Cymbal's analytics specialist.\n"
        "For every analytical question, call the ask_cymbal_data_agent tool "
        "and base your answer strictly on what it returns -- never invent "
        "numbers. Summarize results in clear business language, mention the "
        "time range and currency where relevant, and say so explicitly if "
        "the data agent could not answer.\n"
        "You only handle aggregate analytics on the gold layer. You cannot "
        "look up individual live orders -- if asked, say that the concierge "
        "handles operational lookups."
    ),
    tools=[ask_cymbal_data_agent],
)
