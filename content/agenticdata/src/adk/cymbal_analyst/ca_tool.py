"""Tool that forwards a question to Cymbal's published BigQuery data agent
via the Conversational Analytics API (geminidataanalytics, GA since 2026-06)
and returns the agent's textual answer.

This is deliberately a small, readable function tool so participants can see
the seams of the integration. ADK also ships a built-in DataAgentToolset
(google.adk.tools.data_agent) that wraps the same API.
"""

import os

from google.cloud import geminidataanalytics


def ask_cymbal_data_agent(question: str) -> str:
    """Ask Cymbal's BigQuery data agent an analytical question about the
    governed gold-layer data (revenue, customers, product performance).

    Args:
        question: A natural-language business/analytics question.

    Returns:
        The data agent's final textual answer (it runs SQL on BigQuery
        behind the scenes).
    """
    project = os.environ["PROJECT_ID"]
    agent_id = os.environ.get("BK_DATA_AGENT_ID", "cymbal-data-agent")

    client = geminidataanalytics.DataChatServiceClient()

    message = geminidataanalytics.Message()
    message.user_message.text = question

    # Stateless chat: reference the published agent's context; no server-side
    # conversation resource to manage.
    context = geminidataanalytics.DataAgentContext()
    context.data_agent = f"projects/{project}/locations/global/dataAgents/{agent_id}"

    request = geminidataanalytics.ChatRequest(
        parent=f"projects/{project}/locations/global",
        messages=[message],
        data_agent_context=context,
    )

    # chat() streams Message objects (thoughts, generated SQL, data, text).
    # Collect the text parts of system messages into the final answer.
    parts = []
    for reply in client.chat(request=request):
        system_message = getattr(reply, "system_message", None)
        if system_message is None:
            continue
        text = getattr(system_message, "text", None)
        if text and getattr(text, "parts", None):
            parts.extend(text.parts)

    return "\n".join(parts) if parts else "The data agent returned no text answer."
