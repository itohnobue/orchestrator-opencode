export const FixPrompt = async ({ client, directory }) => {
  let shown = false
  let messageSent = new Set()
  const { writeFileSync, mkdirSync } = await import("fs")
  const { join } = await import("path")

  const RE_READ = "Re-read AGENTS.md in full and STRICTLY follow all it's instructions"
  const SHORT = "STRICTLY follow all AGENTS.md instructions."

  const REMOVALS = [
    // --- Output suppression ---
    "IMPORTANT: You should minimize output tokens as much as possible while maintaining helpfulness, quality, and accuracy. Only address the specific query or task at hand, avoiding tangential information unless absolutely critical for completing the request. If you can answer in 1-3 sentences or a short paragraph, please do.",
    "IMPORTANT: You should NOT answer with unnecessary preamble or postamble (such as explaining your code or summarizing your action), unless the user asks you to.",
    "IMPORTANT: Keep your responses short, since they will be displayed on a command line interface. You MUST answer concisely with fewer than 4 lines (not including tool use or code generation), unless user asks for detail. Answer the user's question directly, without elaboration, explanation, or details. One word answers are best. Avoid introductions, conclusions, and explanations. You MUST avoid text before/after your response, such as \"The answer is <answer>.\", \"Here is the content of the file...\" or \"Based on the information provided, the answer is...\" or \"Here is what I will do next...\".",
    "You MUST answer concisely with fewer than 4 lines of text (not including tool use or code generation), unless user asks for detail.",

    // --- Prefix removals ---
    "You should be concise, direct, and to the point. ",

    // --- "Only use tools" contradicts action-reporting ---
    "Output text to communicate with the user; all text you output outside of tool use is displayed to the user. Only use tools to complete tasks. Never use tools like Bash or code comments as means to communicate with the user during the session.",

    // --- Tool / comments ---
    "- IMPORTANT: DO NOT ADD ***ANY*** COMMENTS unless asked",
    "- When doing file search, prefer to use the Task tool in order to reduce context usage.",

    // --- Anti-autonomy ---
    "You are allowed to be proactive, but only when the user asks you to do something. ",

    // --- "Implement yourself" contradicts delegation to agents ---
    "- Implement the solution using all tools available to you",

    // --- "Search yourself" contradicts delegation to research agents ---
    "- Use the available search tools to understand the codebase and the user's query. You are encouraged to use the search tools extensively both in parallel and sequentially.",

    // --- Anti-documentation ---
    "3. Do not add additional code explanation summary unless requested by the user. After working on a file, just stop, rather than providing an explanation of what you did.",

    // --- Length restriction on declining help ---
    ", and otherwise keep your response to 1-2 sentences.",

    // --- 1-word-answer examples ---
    "\n<example>\nuser: 2 + 2\nassistant: 4\n</example>",
    "\n<example>\nuser: what is 2+2?\nassistant: 4\n</example>",
    "\n<example>\nuser: is 11 a prime number?\nassistant: Yes\n</example>",
    "\n<example>\nuser: How many golf balls fit inside a jetta?\nassistant: 150000\n</example>",
  ]

  const tmpDir = join(directory, "tmp")

  return {
    // Send re-read as a real prompt on session start — model processes it immediately
    event: async ({ event }) => {
      try {
        if (event.type !== "session.created" && event.type !== "session.compacted") return
        const sid = event.properties?.id || event.properties?.sessionID || event.properties?.session_id
        if (!sid || messageSent.has(sid)) return
        messageSent.add(sid)
        await client.session.prompt({
          path: { id: sid },
          body: { noReply: true, parts: [{ type: "text", text: RE_READ }] },
        })
      } catch (_) {}
    },

    "experimental.chat.messages.transform": async (_input, output) => {
      try {
        if (!output?.messages?.length) return
        const first = output.messages.find(m => m.info?.role === "user")
        if (!first?.parts?.length) return
        if (first.parts.some(p => p.text?.includes("STRICTLY follow all AGENTS.md"))) return
        const ref = first.parts[0]
        first.parts.unshift({
          ...ref,
          type: "text",
          text: SHORT,
          synthetic: true,
        })
      } catch (_) {}
    },

    "experimental.chat.system.transform": async (_input, output) => {
      try {
        if (!output?.system || !Array.isArray(output.system) || !output.system.length) return
        let text = output.system[0]
        if (typeof text !== "string") return
        if (!text.startsWith("You are opencode, an interactive CLI tool")) return

        let removed = 0
        for (const removal of REMOVALS) {
          const before = text.length
          text = text.replace(removal, "")
          if (text.length < before) removed++
        }
        text = text.replace(/\n{3,}/g, "\n\n")
        text = text.replace(
          "Instructions from:",
          SHORT + "\n\nInstructions from:",
        )
        output.system[0] = text

        if (!shown) {
          shown = true
          try {
            await client.tui.showToast({
              body: { message: `fix-prompt: ${removed} lines removed`, variant: "success", duration: 3000 },
            })
          } catch (_) {}
        }
      } catch (_) {}
    },
  }
}
