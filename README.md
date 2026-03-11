# Opus-GLM

An orchestration system for [Claude Code](https://claude.ai/download) that turns Opus into a lead architect that delegates work to parallel GLM 4.7 worker agents via [Z.ai](https://z.ai) GLM API.

Give Opus a task. It breaks it into subtasks, spawns specialized agents (code reviewers, security auditors, language experts), verifies their output, and delivers the result — all autonomously.

## Quick Start

### macOS / Linux

```bash
git clone https://git.aoizora.ru/nobu/opus-glm.git
cd opus-glm
./install.sh /path/to/your/project
```

### Windows (PowerShell)

```powershell
git clone https://git.aoizora.ru/nobu/opus-glm.git
cd opus-glm
.\install.ps1 C:\path\to\your\project
```

The installer copies everything into your project and optionally sets up the [claude-glm](claude-glm/) wrapper for Z.ai API access.

After installation, open your project with Claude Code — Opus-GLM activates automatically.

## How It Works

```
You ──► Opus (lead) ──► Plan ──► Spawn agents ──► Verify ──► Deliver
                           │
                     ┌─────┼─────┐
                     ▼     ▼     ▼
                  Agent  Agent  Agent     (parallel GLM 4.7 workers)
                     │     │     │
                     ▼     ▼     ▼
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

**Opus** is the orchestrator. It reads your task, plans the workflow, writes detailed prompts for each agent, spawns them in parallel, waits for completion, verifies every claim against actual code, fixes issues, and delivers.

**GLM 4.7 agents** are workers. Each gets a focused prompt with an agent persona (e.g., `code-reviewer`, `python-pro`, `security-reviewer`), specific files to examine, and questions to answer. They write their findings to `tmp/{name}-report.md`.

Agents are spawned via `claude-glm` — a wrapper that redirects Claude Code to the Z.ai GLM API, where agents run on `glm-4.7`.

## What's Included

```
your-project/
├── CLAUDE.md                          Workflow instructions (auto-loaded by Claude Code)
├── .claude/
│   ├── agents/                        110 specialized agent definitions
│   │   ├── code-reviewer.md
│   │   ├── security-reviewer.md
│   │   ├── python-pro.md
│   │   ├── typescript-pro.md
│   │   ├── architect.md
│   │   ├── web-searcher.md
│   │   └── ... (105 more)
│   ├── tools/
│   │   ├── spawn-glm.sh              Spawn a GLM agent in background
│   │   ├── wait-glm.sh               Wait for agents with progress monitoring
│   │   ├── memory.sh / memory.bat    Persistent memory across sessions
│   │   ├── memory.py                 Memory backend (auto-installed via uv)
│   │   ├── web_search.sh / .bat      Deep web search (50+ results per query)
│   │   ├── web_research.py           Search backend (auto-installed via uv)
│   │   └── completions/              Shell completions for memory tool
│   └── templates/
│       ├── quality-rules-review.txt   Boilerplate for review agents
│       ├── quality-rules-code.txt     Boilerplate for code agents
│       ├── severity-guide.txt         CRITICAL/HIGH/MEDIUM/LOW definitions
│       ├── coordination-review.txt    Report format for reviews
│       └── coordination-code.txt      Report format for code changes
└── tmp/                               Agent working directory (gitignored)
```

## Components

### Orchestration (Opus-GLM Core)

The workflow is defined in `CLAUDE.md` and activates automatically when Opus receives a non-trivial task. The lead:

1. **Plans** — scopes the task, identifies files, picks agents
2. **Prepares** — writes prompts with agent persona + key files + must-answer questions + quality rules
3. **Spawns** — runs agents in parallel via `spawn-glm.sh`
4. **Waits** — monitors progress and detects stalled agents via `wait-glm.sh`
5. **Verifies** — reads every finding, checks cited files, labels VERIFIED/REJECTED
6. **Delivers** — synthesizes results, fixes issues, writes summary

Multi-stage workflows are supported — later stages use verified results from earlier stages.

### Agents (110 Specialists)

Each agent is a `.md` file with a persona, focus area, approach, and safety rules. Categories:

| Category | Agents | Examples |
|----------|--------|----------|
| **Languages** | 25+ | python-pro, typescript-pro, golang-pro, rust-pro, java-pro, c-pro, cpp-pro |
| **Review** | 8 | code-reviewer, security-reviewer, go-reviewer, python-reviewer, database-reviewer |
| **Architecture** | 12 | architect, backend-architect, cloud-architect, database-architect, microservices-architect |
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
.claude/tools/memory.sh add gotcha "psycopg2 needs libpq-dev on Ubuntu" --tags postgres,ubuntu

# Recall context before starting work
.claude/tools/memory.sh context "postgres connection"

# Track session progress
.claude/tools/memory.sh session add todo "Implement auth middleware" --status pending
```

Two tiers:
- **Knowledge** (`knowledge.md`) — permanent facts, patterns, gotchas
- **Session** (`session.md`) — current task progress, checkpoints, plans

### Web Search

Deep web search with 50+ results per query (vs. the typical 10-20):

```bash
.claude/tools/web_search.sh "React server components best practices" --tech
.claude/tools/web_search.sh "CRISPR delivery methods" --sci --med
```

Features: DuckDuckGo + Brave fallback, anti-bot bypass, smart content extraction, sentence-level BM25 compression, cross-page dedup, domain-specific bonus sources (arXiv, PubMed, Hacker News, Stack Overflow).

### Claude-GLM Wrapper

Redirects Claude Code to the Z.ai GLM API. Required for spawning agents.

```bash
# Install separately
cd claude-glm
./install.sh          # macOS/Linux
.\install.ps1         # Windows
```

See [claude-glm/docs/TROUBLESHOOTING.md](claude-glm/docs/TROUBLESHOOTING.md) for common issues.

## Requirements

- **Claude Code** — [Download](https://claude.ai/download)
- **Z.ai API key** — [Get one](https://bigmodel.cn/usercenter/proj-mgmt/apikeys) (required for agent spawning)
- **Z.ai GLM Coding Plan** — [Subscribe](https://z.ai/subscribe)
- **uv** — Auto-installed by tools if missing (handles Python dependencies)

## Models & Plans

### Default Setup: Opus + GLM 4.7

Out of the box, Opus-GLM uses **Opus** as the lead orchestrator and **GLM 4.7** (Sonnet-equivalent) for all spawned agents. This is the most cost-effective setup — Opus plans and verifies while cheaper GLM 4.7 workers do the heavy lifting in parallel.

### GLM-5 + GLM 4.7 (Max Plan)

With the **Max** GLM Coding Plan, the lead remains **Opus** (running natively via Claude Code) while agents use **GLM 4.7** through the Z.ai API. The Max plan allows up to **5 parallel agents** per stage instead of 3, enabling wider parallelism for large tasks.

### GLM Coding Plans

The installer asks which Z.ai GLM Coding Plan you have and configures agent limits accordingly:

| Plan | Lead Model | Agent Model | Max Parallel Agents |
|------|-----------|-------------|---------------------|
| **Max** | Opus (native) | GLM 4.7 (Z.ai) | 5 |
| **Pro** | Opus (native) | GLM 4.7 (Z.ai) | 3 |
| **Lite** | Opus (native) | GLM 4.7 (Z.ai) | 3 |

The lead always runs as your native Claude Code instance (Opus). Only the spawned agents go through the Z.ai GLM API.

## Configuration

### Using with Anthropic API (No Z.ai)

The orchestration instructions work with native Anthropic API too. In `spawn-glm.sh`, change the `GLM_WRAPPER` variable (near the top) from `claude-glm` to `claude` to use your Anthropic subscription directly.

### Custom Agents

Add your own agent definitions to `.claude/agents/`:

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

Edit files in `.claude/templates/` to change the boilerplate appended to agent prompts. For example, relax the severity guide for internal tools or tighten it for production codebases.

## Manual Installation

If you prefer not to use the installer:

1. Copy `.claude/` directory to your project
2. Copy `CLAUDE.md` to your project root (or append to existing)
3. Create `tmp/` directory
4. Install [claude-glm](claude-glm/) wrapper
5. Add `tmp/` and `.claude/knowledge.md` to `.gitignore`

## License

MIT
