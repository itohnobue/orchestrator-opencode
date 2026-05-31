# OpenCode Workflow

A parallel agent orchestration system for [OpenCode](https://opencode.ai) that turns the lead into an architect that decomposes tasks, spawns specialist AI agents, verifies their output, and delivers results — all autonomously. Works with any LLM provider configured in OpenCode.

## Quick Start

### macOS / Linux

```bash
git clone https://github.com/itohnobue/orchestrator-opencode
cd orchestrator-opencode
./install.sh /path/to/your/project
```

### Windows (PowerShell)

```powershell
git clone https://github.com/itohnobue/orchestrator-opencode
cd orchestrator-opencode
.\install.ps1 C:\path\to\your\project
```

The installer copies everything into your project. After installation, open your project with OpenCode — the workflow activates automatically.

## How It Works

```
You ──► Lead (orchestrator) ──► Planner (draft) ──► Plan review ──► Spawn agents ──► Adversarial verify ──► Deliver
                                      │
                                ┌─────┼─────┐
                                ▼     ▼     ▼
                             Agent  Agent  Agent     (parallel workers)
                                │     │     │
                                ▼     ▼     ▼
                              Report Report Report   (tmp/{name}-report.md)
                                 │     │     │
                                 └─────┼─────┘
                                       ▼
                             Adversarial pipeline
                             extraction → falsification → merge
                                       │
                                       ▼
                                 Final result
```

The **lead** is the orchestrator. It receives your task, deploys the agentic-planner to research the project and produce a draft plan, spawns a review agent to refine the plan, writes detailed prompts for each agent, spawns them in parallel, waits for completion, delegates verification to the adversarial verification pipeline, fixes issues via fix-agents, and delivers.

**Agents** are workers. Each gets a focused prompt with an agent persona (e.g., `code-reviewer`, `python-pro`, `security-reviewer`), specific files to examine, questions to answer, and an explicit list of writable files. They write their findings to `tmp/{name}-report.md`.

Agents are spawned via the `spawn-glm.sh` tool, which runs each agent as a focused OpenCode sub-session using the default model configured in OpenCode.

## Components

### Orchestration (Core)

The workflow is defined in `AGENTS.md` and activates automatically when the lead receives a non-trivial task. The lead:

1. **Deploys planner** — spawns the `agentic-planner` agent to research the project, identify domain areas, and produce a plan draft
2. **Reviews plan** — spawns the `code-reviewer` agent to review the draft for skeleton adherence, agent selection, and coverage gaps, then write the improved final plan
3. **Prepares** — writes the task block (key files, must-answer questions, writable files) and assembles the full prompt via `assemble-prompt.sh` (agent persona + templates + task)
4. **Spawns** — runs agents in batches (max 3 parallel) via `spawn-glm.sh`
5. **Waits** — monitors progress and detects stalled agents via `wait-glm.sh`
6. **Verifies** — spawns the adversarial verification pipeline: extraction agent (deduplicates findings) → adversarial falsification agent (falsifies each finding against source code) → merge agent (produces final verified checklist)
7. **Fixes** — spawns fix-agents split by domain for all verified findings, then runs post-fix review and fresh adversarial verification over the changes
8. **Delivers** — synthesizes results, confirms all stages complete, writes summary

Multi-stage workflows follow a mandatory 5-stage skeleton: Discovery → Adversarial verification → Fixes → Post-fix review → Adversarial verification. Stages are **iterative** (mandatory for all discovery stages) — agents run repeatedly with varied approaches until convergence (1 iteration with no new meaningful findings). Every code change must survive adversarial verification before delivery.

### Agents (110+ Specialists)

Each agent is a `.md` file with a persona, focus area, approach, and safety rules. Categories:

| Category | Count | Examples |
|----------|-------|----------|
| **Language Implementation** | 22 | python-pro, golang-pro, rust-pro, typescript-pro, java-pro, c-pro, cpp-pro |
| **Web Frameworks** | 10 | react-pro, nextjs-pro, django-pro, fastapi-pro, vue-pro, flutter-pro |
| **Architecture & Design** | 9 | backend-architect, api-designer, database-architect, microservices-architect |
| **DevOps & Infrastructure** | 11 | devops-engineer, kubernetes-architect, terraform-pro, sre-engineer, cloud-architect |
| **Security** | 6 | security-reviewer, penetration-tester, threat-modeling-pro, backend-security-coder |
| **Database** | 5 | postgres-pro, sql-pro, database-optimizer, database-reviewer |
| **Testing & Quality** | 5 | code-reviewer, tdd-guide, test-automator, e2e-runner, qa-pro |
| **AI & ML** | 5 | ai-engineer, ml-engineer, prompt-engineer, mcp-developer |
| **Frontend & Mobile** | 5 | frontend-developer, ios-pro, ui-designer, ux-designer |
| **Documentation** | 7 | documentation-pro, technical-writer, docs-architect, tutorial-engineer |
| **Incident & Troubleshooting** | 4 | incident-responder, debugger, devops-troubleshooter |
| **Specialized** | 21 | build-engineer, cli-developer, adversarial-reviewer, agentic-planner, research-analyst, agent-organizer |

Full agent directory with selection guide: `.opencode/agents/INDEX.md`

### Memory System

Persistent knowledge that survives across sessions:

```bash
# Save a discovery
.opencode/tools/memory.sh add gotcha "psycopg2 needs libpq-dev on Ubuntu" --tags postgres,ubuntu

# Recall context before starting work
.opencode/tools/memory.sh context "postgres connection"

# Track session progress
.opencode/tools/memory.sh session add todo "Implement auth middleware" --status pending
```

Two tiers:
- **Knowledge** (`knowledge.md`) — permanent facts, patterns, gotchas
- **Session** (`session.md`) — current task progress, checkpoints, plans

### Web Search

Deep web search with 50+ results per query (vs. the typical 10-20):

```bash
.opencode/tools/web_search.sh "React server components best practices" --tech
.opencode/tools/web_search.sh "CRISPR delivery methods" --sci --med
```

Features: DuckDuckGo + Brave fallback, anti-bot bypass, smart content extraction, sentence-level BM25 compression, cross-page dedup, domain-specific bonus sources (arXiv, PubMed, Hacker News, Stack Overflow).

## Requirements

- **OpenCode CLI** — [Install](https://opencode.ai)
- **An LLM provider** — Configure at least one provider in OpenCode (any supported provider with an API key)
- **uv** — Auto-installed by tools if missing (handles Python dependencies)

## Model Configuration

Agents use the default model configured in OpenCode. Configure your preferred provider in `~/.config/opencode/opencode.json`. The orchestrator itself runs on whatever model you launched OpenCode with.

## Manual Installation

If you prefer not to use the installer:

1. Copy `.opencode/` directory to your project
2. Copy `AGENTS.md` to your project root (or append to existing)
3. Create `tmp/` directory
4. Add `tmp/`, `knowledge.md`, and `session.md` to `.gitignore`

## License

MIT
