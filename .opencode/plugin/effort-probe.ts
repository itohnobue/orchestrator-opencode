import type { Plugin } from "@opencode-ai/plugin"
import { appendFileSync } from "node:fs"

export default async (): Promise<Plugin> => {
  return {
    "chat.params": async (input, output) => {
      try {
        const line = JSON.stringify({
          ts: new Date().toISOString(),
          sessionID: input.sessionID,
          agent: input.agent,
          options: output.options,
        })
        appendFileSync(
          "/Users/itohnobue/Git/orchestrator-opencode/tmp/effort-probe.log",
          line + "\n",
        )
      } catch {
        // probe must never break the request
      }
    },
  }
}
