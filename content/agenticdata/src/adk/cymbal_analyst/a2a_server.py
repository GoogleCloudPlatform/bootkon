"""Exposes cymbal_analyst as an A2A server.

Run from the project root (content/agenticdata/src/adk):

    uvicorn cymbal_analyst.a2a_server:a2a_app --host 127.0.0.1 --port 8001

Configuration comes from the environment (vars.local.sh, set by bk-bootstrap).

to_a2a() auto-generates the agent card, served at
http://localhost:8001/.well-known/agent-card.json (A2A spec >= 0.3/1.0 --
older tutorials still show agent.json, which is stale).
The port passed to to_a2a() is baked into the card and MUST match uvicorn's
--port, or consumers will be pointed at the wrong address.
"""

from google.adk.a2a.utils.agent_to_a2a import to_a2a

from .agent import root_agent

a2a_app = to_a2a(root_agent, port=8001)
