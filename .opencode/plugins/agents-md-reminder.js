export const AgentsMdReminder = async ({ client }) => {
  const PROMPT = "re-read AGENTS.md and STRICTLY follow it's instructions"

  const sendReminder = async (sessionId) => {
    if (!sessionId) return
    await client.session.prompt({
      path: { id: sessionId },
      body: {
        noReply: true,
        parts: [{ type: "text", text: PROMPT }],
      },
    })
  }

  return {
    event: async ({ event }) => {
      await client.app.log({
        body: {
          service: "agents-md-reminder",
          level: "info",
          message: `Event: ${event.type}`,
          extra: event.properties,
        },
      })

      if (event.type === "session.created" || event.type === "session.compacted") {
        const sessionId = event.properties?.id || event.properties?.sessionID || event.properties?.session_id
        await client.tui.showToast({
          body: { message: `AGENTS.md reminder triggered (${event.type})`, variant: "info" },
        })
        await sendReminder(sessionId)
      }
    },
  }
}
