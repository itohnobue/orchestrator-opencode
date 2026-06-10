# OpenCode Workflow

A parallel AI agent orchestrator for [OpenCode](https://opencode.ai). Instead of doing work itself, the lead decomposes your task, spawns specialist agents to do the actual work in parallel, verifies their output through an adversarial pipeline, and delivers production-ready results — all automatically. Works with any LLM provider.

## Why use it

OpenCode is great at single-file edits, but complex tasks overwhelm a single context window. This workflow solves that:

- **Parallel execution** — Up to 3 specialist agents work simultaneously on different parts of your task
- **Built-in verification** — Every finding is adversarially checked against source code before it becomes a fix. False positives are caught and dropped automatically
- **Smart scoping** — The planner researches your project first, classifies the task on 5 axes (size, domain breadth, ambiguity, severity, change type), then builds a custom workflow selecting only the stages the task actually needs. A cosmetic fix uses a handful of agents; a critical multi-file refactor gets full adversarial verification
- **Domain experts** — 110+ specialized agents (from `python-pro` to `security-reviewer` to `ios-pro`), each with domain-specific checklists and anti-patterns

## Quick Start

```bash
git clone https://github.com/itohnobue/orchestrator-opencode
cd orchestrator-opencode
./install.sh /path/to/your/project   # macOS/Linux
# or: .\install.ps1 C:\path\to\project   (Windows)
```

The installer copies the orchestration files into your project. Open your project with OpenCode — the workflow activates automatically when you give it a non-trivial task.

## How it works

```
You ask: "Add dark mode to settings" or "Fix the payment race condition"
         │
         ▼
      Planner     Researches your codebase, finds relevant files,
         │        classifies the task, builds a custom workflow
         ▼
    Specialist    Multiple agents run in parallel — each gets a focused
     Agents       prompt with specific files, a domain persona, and
         │        questions they must answer
         ▼
   Verification   Every finding is adversary-checked against source code.
         │        Only confirmed issues survive. False positives are dropped.
         ▼
      Fixes       Confirmed issues are fixed by domain specialists,
         │        then independently reviewed for regressions
         ▼
   Deliverable    Clean commits, passing tests, verified code
```

Everything runs autonomously — the lead coordinates, agents do the work, verification catches mistakes.

## Key concepts

**Lead** — The orchestrator. It doesn't write code. It researches your task, picks the right agents, writes their prompts, spawns them, and routes their findings through verification.

**Agents** — Specialist AI workers. Each one gets a narrow, well-defined task with a specific persona (`swift-pro`, `code-reviewer`, `debugger`). They work independently and write structured reports.

**Verification** — Before any finding becomes a fix, it goes through adversarial checking. An extraction agent deduplicates findings, then severity-routed agents try to falsify each one against the actual source code. Only findings that survive become fixes. This is what prevents hallucinated bugs from being "fixed."

**Dynamic workflow** — No fixed pipeline. The planner classifies your task on 5 axes (size, domain breadth, ambiguity, severity, change type) and assembles a custom stage plan. A cosmetic text change skips discovery and uses a single agent. A critical security fix gets full adversarial verification across multiple parallel review pairs.

## Requirements

- [OpenCode CLI](https://opencode.ai)
- At least one LLM provider configured in `~/.config/opencode/opencode.json`
- `uv` (auto-installed if missing — handles Python dependencies for tools)

## License

MIT
