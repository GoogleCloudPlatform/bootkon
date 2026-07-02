# Cymbal agents project — agent context

An ADK project (google-adk 2.x is installed) with two agents:

## cymbal_analyst/ — the analytics specialist (built in Lab 6)

- `agent.py` defines `root_agent = Agent(name="cymbal_analyst", model=...)`
  with exactly ONE function tool: it sends a natural-language question to the
  published BigQuery data agent via the `google-cloud-geminidataanalytics`
  `DataChatServiceClient` (stateless chat with a `DataAgentContext` pointing
  at `projects/$GOOGLE_CLOUD_PROJECT/locations/global/dataAgents/$BK_DATA_AGENT_ID`)
  and returns the streamed text parts joined together.
- `a2a_server.py` exposes it over the A2A protocol via
  `google.adk.a2a.utils.agent_to_a2a.to_a2a(root_agent, port=8001)` as the
  module attribute `a2a_app` (served with uvicorn).
- `__init__.py` must do `from . import agent`.
- Instruction: answer only aggregate analytics questions from the gold layer,
  strictly based on the tool result; individual live orders are the
  concierge's job.

## cymbal_concierge/ — the root agent (pre-built, do not rewrite)

`RemoteA2aAgent` sub-agent for the analyst (agent card on localhost:8001)
plus a `check_order_status` tool that queries live Postgres through the IAP
tunnel on localhost:5432.

## Conventions

- All configuration comes from environment variables:
  `GOOGLE_CLOUD_PROJECT`, `GOOGLE_GENAI_USE_VERTEXAI`, `GOOGLE_CLOUD_LOCATION`,
  `BK_CYMBAL_MODEL` (default `gemini-2.5-flash`), `BK_DATA_AGENT_ID`,
  `BK_CYMBAL_DB_HOST`/`BK_CYMBAL_DB_PORT`, `BK_DB_PASSWORD`.
  Never create config files and never hardcode credentials.
- Read the model as `os.environ.get("BK_CYMBAL_MODEL", "gemini-2.5-flash")`.
- Keep tools small and readable; docstrings are the tool documentation the
  model reasons over.
