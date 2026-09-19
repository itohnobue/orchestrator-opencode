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

The shipped `opencode.json` sets only `permission: allow` — **no model pin**: the model and provider come from your machine's global OpenCode config (`~/.config/opencode/opencode.json`). Edit the project `opencode.json` for a per-machine override. Reasoning effort is configured in the global config (agents do not pin their own).

## How it works

- **Three-agent planning pipeline (always)** — `agentic-planner` researches the codebase and classifies the task (size, domains, ambiguity, severity, change type), then selects the workflow bricks; `volume-splitter` resolves file scopes to exact files with line counts and applies mechanical size caps; `agent-organizer` reviews the plan, fixes structural violations, and redistributes the questions each agent must answer. The final plan is displayed before any stage agent starts.
- **Parallel execution from a custom manifest** — the workflow is assembled per task from bricks (research, discovery, implementation, review, verification, fix, test), not a fixed skeleton. Independent subtasks run as parallel agents (up to 10 per batch); stages are sequential only when one consumes the previous stage's verified output.
- **Research-defined specialists** — specialist identity comes from research FOCUS angles, not static personas. Each agent receives exactly the research covering its scope: a compact digest in its prompt plus the full report path on demand. At MEDIUM+ severity, discovery and post-implementation review get a second opinion with a complementary standpoint — never the same lens twice.
- **Adversarial verification** — findings are extracted, deduplicated, and tagged, then routed by severity to falsification agents (CRITICAL 1:1, HIGH 1 per 3, MEDIUM 1 per 10) that try to disprove them with evidence; dismissed suspicions are re-examined too. Every finding ends CONFIRMED (fix list), REJECTED (dropped), or WEAKENED (downgraded) — the verified grid decides what gets fixed.
- **Findings-driven convergence** — discovery/review stages repeat only when the verified grid holds a confirmed HIGH/CRITICAL finding (ceiling: ONCE default, LOOP rare). Fix passes repeat — fix → build-gate → post-fix review — until no confirmed code defects remain; regression tests pinning the fixes are added.
- **Continuation handoff** — a fixed 8-section carry-over so a fresh agent or later session resumes without re-discovery; the `handoff` skill retires subagent runs at the reuse threshold and checkpoints sessions on demand.
- **Memory that survives** — two-tier knowledge/session memory via `memory.sh`; confirmed findings are harvested into `knowledge.md` after each run.

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
