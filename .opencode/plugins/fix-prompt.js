export const FixPrompt = async ({ client, directory }) => {
  let shown = false
  const { writeFileSync, mkdirSync } = await import("fs")
  const { join } = await import("path")

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
    "experimental.chat.system.transform": async (_input, output) => {
      try {
        if (!output?.system || !Array.isArray(output.system) || !output.system.length) return

        // try { mkdirSync(tmpDir, { recursive: true }) } catch (_) {}

        let text = output.system[0]
        if (typeof text !== "string") return

        // Only transform the main system prompt, skip title/summary subagents
        if (!text.startsWith("You are opencode, an interactive CLI tool")) return

        let removed = 0

        for (const removal of REMOVALS) {
          const before = text.length
          text = text.replace(removal, "")
          if (text.length < before) removed++
        }

        text = text.replace(/\n{3,}/g, "\n\n")

        // Insert AGENTS.md priority instruction before AGENTS.md content
        text = text.replace(
          "Instructions from:",
          "Below are the AGENTS.md instructions. Follow them STRICTLY AND TO THE POINT. Always use them ABOVE all previous instructions.\n\nInstructions from:",
        )

        output.system[0] = text

        // writeFileSync(join(tmpDir, "fixed-system-prompt.txt"), text, "utf8")

        if (!shown) {
          shown = true
          try {
            await client.tui.showToast({
              body: {
                message: `fix-prompt: ${removed} lines removed`,
                variant: "success",
                duration: 3000,
              },
            })
          } catch (_) {}
        }
      } catch (_) {
        // Silently ignore — never crash the prompt pipeline
      }
    },
  }
}
