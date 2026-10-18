# Orchestration Workflow

A multi-agent orchestration workflow for [OpenCode](https://opencode.ai) (v1 & v2): the main session acts as a lead — it plans a task-specific workflow, delegates to specialized subagents running in parallel, adversarially verifies every finding, and applies only what survives. Works with any LLM provider.

## Quick Start

```bash
git clone https://github.com/itohnobue/orchestrator-opencode
cd orchestrator-opencode
./install.sh /path/to/your/project   # macOS/Linux
# or: .\install.ps1 C:\path\to\project   (Windows)
```

The installer copies `.opencode/` (agents, tools, templates, skills, plugin), `AGENTS.md`, and a minimal `opencode.json` into your project — an existing `AGENTS.md` or `opencode.json` is never overwritten — and creates `tmp/` for agent artifacts. Open the project with OpenCode and give it a task; the workflow activates automatically and runs autonomously: it displays the full plan and proceeds, without approval prompts.

## Default allowance

The shipped `opencode.json` allows all operations by default. Delete or tweak it if you need a different behaviour.

## How it works

- **Plan before work** — the task is sized, split into parallel-safe pieces, and every piece gets the questions it must answer; the full plan is displayed before execution starts.
- **Parallel by default** — independent pieces run concurrently; steps run in sequence only when one needs the previous result.
- **Counter-evidence, not agreement** — a separate pass tries to disprove each finding, with more effort the more severe the claim. Findings survive only if they hold up; overstated ones are downgraded.
- **Fix, verify, repeat** — fixes are validated, re-reviewed, and pinned with regression tests. Review repeats only while a confirmed high-severity problem remains; fix passes repeat until no confirmed defect is left.
- **Handoff on pause** — a fixed carry-over format lets a fresh session continue without re-discovery.
- **Compaction handoff (V2)** — compaction writes the same 8-section handoff to `.opencode/handoff/` and prompts a workspace check on the next turn.
- **Memory that survives** — knowledge and task state persist across sessions via `memory.sh`; confirmed findings are harvested after each run.

### Optional: DeepSeek search

`web_search.sh` can also query DeepSeek's in-house search index alongside DuckDuckGo — 20 extra pages per query, or 50 when DuckDuckGo is unavailable. DeepSeek returns each page's content with the search response, so those pages are written to the report without a local fetch; a result without usable content falls back to the local fetcher. Off by default; enable it in your shell:

```bash
export WEB_RESEARCH_DEEPSEEK=1
```

The API key is read from `provider.deepseek.options.apiKey` in `~/.config/opencode/opencode.json` (the config OpenCode already uses); `DEEPSEEK_API_KEY` overrides it.

## The 12 agents

`.opencode/agents/` — INDEX.md is the quick reference.

| Agent | Role |
|-------|------|
| `agentic-planner` | Researches the project, classifies the task, selects workflow bricks, produces the plan manifest (Research Coverage Map + Routing Table + per-agent tiers) |
| `volume-splitter` | Resolves file scopes to exact paths with line counts; applies mechanical split/merge rules |
| `agent-organizer` | Structural plan review: tiers, routing precision, FOCUS complementarity, MUST ANSWER redistribution |
| `executor` | The ONE generic executor — DISCOVER, IMPLEMENT, REVIEW, FIX, TEST, TEST-UPDATE, quick-fix, build-gate, final gate. PLAIN (task context as briefing) or researched (digest + full report path) |
| `postfix-reviewer` | Post-fix review ONLY (read-only) — verifies applied fixes against their design; verdict APPROVED / NEEDS-FIX |
| `verification-analyst` | Extraction + synthesis — dedup, confidence tags, verification grid |
| `knowledge-harvester` | Knowledge harvesting from verified findings — PATTERN/INCIDENT classification, dedup, prevention recommendations, supersede-evaluate; writes `tmp/knowledge-harvest-report.md` |
| `adversarial-reviewer` | Falsification gate — the single distinct quality gate; batch sizes CRITICAL (1:1), HIGH (1:3), MEDIUM (1:10) are volume controls |
| `web-searcher` | RESEARCH brick — internet research (standards, formats, versions, ecosystems, advisories) |
| `research-analyst` | RESEARCH brick — structured analysis/synthesis; mid-execution research |
| `data-researcher` | RESEARCH brick — dataset research |
| `prepare-agent` | (Single-session suite) research generation — full report + compact digest, `FOCUS:` defines the specialist |

## Single-session mode

The suite also ships a `single-session-workflow` skill that switches out of orchestrator mode on demand: the main session becomes the worker, delegating only when a subtask is big or context-heavy. Invoke it with "switch to single-session mode".

## Requirements

- [OpenCode CLI](https://opencode.ai) — **V1 1.18.29+** or **V2 2.0+**
- At least one LLM provider configured in `~/.config/opencode/opencode.json`
- `uv` — auto-installed repo-locally into `tmp/uv/` if missing (never system-wide, per the AGENTS.md tool-use policy); handles Python dependencies for the tools

## License

MIT
