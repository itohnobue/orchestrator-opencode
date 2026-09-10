# Orchestration Workflow

A parallel AI agent orchestrator for [OpenCode](https://opencode.ai). Instead of doing work itself, the lead decomposes your task, spawns specialized agents to work in parallel, verifies their output through an adversarial pipeline, and delivers production-ready results — automatically. Works with any LLM provider.

## Quick Start

```bash
git clone https://github.com/itohnobue/orchestrator-opencode
cd orchestrator-opencode
./install.sh /path/to/your/project   # macOS/Linux
# or: .\install.ps1 C:\path\to\project   (Windows)
```

The installer copies `.opencode/` (agents, tools, templates) into your project and creates `AGENTS.md` with workflow instructions — an existing `.opencode/` or `AGENTS.md` is merged, never overwritten. Open the project with OpenCode and give it a task.

## Default allowance

The shipped `opencode.json` sets only `permission: allow` — **no model pin**: the model and provider come from your machine's global OpenCode config (`~/.config/opencode/opencode.json`). Edit the project `opencode.json` for a per-machine override. Agent reasoning effort is set per-agent in `.opencode/agents/*.md`.

## How it works

- **Three-agent planning pipeline** — agentic-planner researches the codebase, classifies your task on 5 axes (size, domains, ambiguity, severity, change type), and assembles a custom workflow from a brick catalog (PLAN / RESEARCH / DISCOVER / IMPLEMENT / REVIEW / VERIFY / CONVERGE / FIX / TEST). A cosmetic fix gets a handful of agents; a critical multi-domain refactor gets the full treatment.
- **Parallel execution** — up to 10 agents work simultaneously, each on its own scope. Stages fan out by default; sequential stages only when one consumes another's verified output.
- **Research-defined specialists** — a RESEARCH stage gathers external facts (standards, formats, versions, advisories). Each agent receives exactly the research covering its scope: a compact digest in the prompt plus the full report path for on-demand depth. Specialist standpoint comes from the research's FOCUS angles, not static personas. At MEDIUM+ severity, every discovery and post-implementation review gets a research-backed second opinion with a complementary FOCUS.
- **Adversarial verification** — before any finding becomes a fix, adversarial agents try to falsify it (1:1 for CRITICAL, 1 per 3 for HIGH, 1 per 10 for MEDIUM), reading full source context and searching for counter-evidence at every level — function guards, callers, framework protections, type invariants, tests. Only survivors become fixes.
- **Iterative convergence** — discovery/review stages iterate only when the verified grid contains a CONFIRMED HIGH/CRITICAL finding; each pass uses genuinely different FOCUS angles. Converged = zero CONFIRMED HIGH+ in the grid.
- **Fix convergence + build-gate** — confirmed findings are applied by fix agents, gated by a build/test tripwire, and re-reviewed until clean; regression tests are written for the fixes.
- **Session continuation** — long tasks checkpoint a structured `handoff` that a replacement lead picks up; the same skill (shared with single-session mode) also retires subagent runs and supports `/handoff` checkpoints.
- **Memory that survives** — two-tier knowledge/session memory via `memory.sh`.

## The 12 agents

`.opencode/agents/` — INDEX.md is the quick reference.

| Agent | Role |
|-------|------|
| `agentic-planner` | Researches the project, classifies the task, selects workflow bricks, produces the plan manifest (Research Coverage Map + Routing Table + per-agent tiers) |
| `volume-splitter` | Resolves file scopes to exact paths with line counts; applies mechanical split/merge rules |
| `agent-organizer` | Structural plan review (always MAX effort): tiers, routing precision, FOCUS complementarity, MUST ANSWER redistribution |
| `executor` | The ONE generic executor — DISCOVER, IMPLEMENT, REVIEW, FIX, TEST, TEST-UPDATE, quick-fix, build-gate, final gate. PLAIN (task context as briefing) or researched (digest + full report path) |
| `postfix-reviewer` | Post-fix review ONLY (always MAX effort, read-only) — verifies applied fixes against their design; verdict APPROVED / NEEDS-FIX |
| `verification-analyst` | Extraction + synthesis — dedup, confidence tags, verification grid |
| `knowledge-harvester` | Knowledge harvesting from verified findings — PATTERN/INCIDENT classification, dedup, prevention recommendations, supersede-evaluate; writes `tmp/knowledge-harvest-report.md` |
| `adversarial-reviewer` | Falsification gate (always MAX effort) — the single distinct quality gate; batch sizes CRITICAL (1:1), HIGH (1:3), MEDIUM (1:10) are volume controls |
| `web-searcher` | RESEARCH brick — internet research (standards, formats, versions, ecosystems, advisories) |
| `research-analyst` | RESEARCH brick — structured analysis/synthesis; mid-execution research |
| `data-researcher` | RESEARCH brick — dataset research |
| `prepare-agent` | (Single-session suite) research generation — full report + compact digest, `FOCUS:` defines the specialist |

## Single-session mode

The repo ships a `single-session-workflow` skill that switches out of orchestrator mode on demand: the model works directly in dialog with you, delegating only when a subtask is big or context-heavy. Invoke it with "switch to single-session mode". The protocol is tracked at `skills/single-session-workflow/SKILL.md` (synced from single-session-opencode) and symlinked into `.opencode/skills/` — see `skills/README.md`.

## Requirements

- [OpenCode CLI](https://opencode.ai)
- At least one LLM provider configured in `~/.config/opencode/opencode.json`
- `uv` — auto-installed repo-locally into `tmp/uv/` if missing (never system-wide, per the AGENTS.md tool-use policy); handles Python dependencies for the tools

## License

MIT
