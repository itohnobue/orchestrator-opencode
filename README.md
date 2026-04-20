# GLM-OpenCode

An orchestration system for [OpenCode](https://opencode.ai) that turns the lead into an architect that delegates work to parallel GLM worker agents via [Z.ai](https://z.ai) GLM API.

Give it a task. It breaks it into subtasks, spawns specialized agents (code reviewers, security auditors, language experts), verifies their output, and delivers the result — all autonomously.

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

The installer copies everything into your project. After installation, open your project with OpenCode — GLM-OpenCode activates automatically.

## How It Works

```
You ──► Lead (orchestrator) ──► Plan ──► Spawn agents ──► Verify ──► Deliver
                                    │
                              ┌─────┼─────┐
                              ▼     ▼     ▼
                           Agent  Agent  Agent     (parallel workers, max 3)
                              │     │     │
                              │   ┌─┘     │
                              │   ▼       │        + optional 2nd opinion
                              │  Agent*   │          (different AI model)
                              │   │       │
                              ▼   ▼       ▼
                           Report Report Report    (tmp/{name}-report.md)
                              │     │     │
                              └─────┼─────┘
                                    ▼
                             Lead verifies
                             every finding
                                    │
                                    ▼
                              Final result
```

The **lead** is the orchestrator. It reads your task, plans the workflow, writes detailed prompts for each agent, spawns them in parallel, waits for completion, verifies every claim against actual code, fixes issues, and delivers.

**GLM agents** are workers. Each gets a focused prompt with an agent persona (e.g., `code-reviewer`, `python-pro`, `security-reviewer`), specific files to examine, questions to answer, and an explicit list of writable files. They write their findings to `tmp/{name}-report.md`.

Agents are spawned via `opencode run` — the OpenCode CLI runs each agent as a focused sub-session.

**Second opinion:** When a secondary LLM provider is configured in opencode (e.g. DeepSeek alongside your primary model), the lead spawns an additional agent per stage using a different model for independent analysis. This catches blind spots — different training data and architecture mean different strengths and weaknesses. Second opinion agents are added for review, research, security, and debugging stages (not for implementation or testing).

## Components

### Orchestration (GLM-OpenCode Core)

The workflow is defined in `AGENTS.md` and activates automatically when the lead receives a non-trivial task. The lead:

1. **Plans** — scopes the task, identifies files, picks agents, builds dependency graph
2. **Prepares** — writes the task block (key files, must-answer questions, writable files) and assembles the full prompt via `assemble-prompt.sh` (agent persona + templates + task)
3. **Spawns** — runs agents in batches (max 3 parallel) via `spawn-glm.sh`
4. **Waits** — monitors progress and detects stalled agents via `wait-glm.sh`
5. **Verifies** — reads every finding, checks cited files, labels VERIFIED/REJECTED/DOWNGRADED/UNABLE TO VERIFY
6. **Delivers** — synthesizes results, fixes issues, writes summary

Multi-stage workflows are supported — later stages use verified results from earlier stages. Stages can be **iterative** (mandatory for production checks, final audits) — agents run repeatedly with varied approaches until convergence (2 consecutive iterations with no new actionable findings). Agents have **abort conditions** — they stop and report blockers instead of retrying endlessly.

### Agents (110 Specialists)

Each agent is a `.md` file with a persona, focus area, approach, and safety rules. Categories:

| Category | Agents | Examples |
|----------|--------|----------|
| **Languages** | 25+ | python-pro, typescript-pro, golang-pro, rust-pro, java-pro, c-pro, cpp-pro |
| **Review** | 8 | code-reviewer, security-reviewer, go-reviewer, python-reviewer, database-reviewer |
| **Architecture** | 11 | backend-architect, cloud-architect, database-architect, microservices-architect |
| **DevOps** | 10 | deployment-engineer, kubernetes-architect, terraform-pro, sre-engineer, devops-troubleshooter |
| **Frontend** | 8 | react-pro, nextjs-pro, vue-pro, frontend-developer, ui-designer, ux-designer |
| **Data** | 6 | data-scientist, data-engineer, ml-engineer, database-optimizer, sql-pro, postgres-pro |
| **Mobile** | 5 | ios-pro, kotlin-pro, flutter-pro, swift-pro, mobile-developer |
| **Security** | 5 | penetration-tester, threat-modeling-pro, backend-security-coder, frontend-security-coder |
| **Docs & Planning** | 6 | technical-writer, documentation-pro, planner, product-manager, tutorial-engineer |
| **Other** | 25+ | debugger, build-error-resolver, refactor-cleaner, mcp-developer, prompt-engineer |

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
- **Z.ai API key** — [Get one](https://bigmodel.cn/usercenter/proj-mgmt/apikeys) (required for agent spawning)
- **uv** — Auto-installed by tools if missing (handles Python dependencies)

## Optional

- **Secondary LLM provider** — Configure a second model in opencode (e.g. `deepseek/deepseek-chat`) to enable cross-model second opinion agents. Not required — the workflow works with a single model.

## Configuration

### Custom Agents

Add your own agent definitions to `.opencode/agents/`:

```markdown
---
name: my-agent
description: What this agent does
tools: Read, Write, Edit, Bash, Grep, Glob
---

You are a specialist in [domain].

## Approach
[How to handle tasks]

## Common Pitfalls
[What to watch out for]
```

### Adjusting Quality Rules

Edit files in `.opencode/templates/` to change the boilerplate appended to agent prompts. For example, relax the severity guide for internal tools or tighten it for production codebases.

## Manual Installation

If you prefer not to use the installer:

1. Copy `.opencode/` directory to your project
2. Copy `AGENTS.md` to your project root (or append to existing)
3. Create `tmp/` directory
4. Add `tmp/` and `.opencode/knowledge.md` to `.gitignore`

## License

MIT
