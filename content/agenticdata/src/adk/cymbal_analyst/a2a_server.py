"""Exposes cymbal_analyst as an A2A server.

Run from the project root (content/agenticdata/src/adk):

    uvicorn cymbal_analyst.a2a_server:a2a_app --host 127.0.0.1 --port 8001

to_a2a() auto-generates the agent card, served at
http://localhost:8001/.well-known/agent-card.json (A2A spec >= 0.3/1.0 --
older tutorials still show agent.json, which is stale).
The port passed to to_a2a() is baked into the card and MUST match uvicorn's
--port, or consumers will be pointed at the wrong address.
"""

from pathlib import Path

from dotenv import load_dotenv

load_dotenv(dotenv_path=Path(__file__).resolve().parent.parent / ".env")

from google.adk.a2a.utils.agent_to_a2a import to_a2a  # noqa: E402

from .agent import root_agent  # noqa: E402

a2a_app = to_a2a(root_agent, port=8001)
