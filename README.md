# Orchestration Workflow

A parallel AI agent orchestrator for [OpenCode](https://opencode.ai). Instead of doing work itself, the lead decomposes your task, spawns specialist agents to do the actual work in parallel, verifies their output through an adversarial pipeline, and delivers production-ready results — all automatically. Works with any LLM provider.

## Why use it

OpenCode is great at single-file edits, but complex tasks overwhelm a single context window. This workflow solves that:

- **Parallel execution** — Up to 3 specialist agents work simultaneously on different parts of your task
- **Built-in verification** — Every finding is adversarially checked against source code before it becomes a fix. False positives are caught and dropped automatically
- **Smart scoping** — The planner researches your project first, classifies the task on 5 axes (size, domain breadth, ambiguity, severity, change type), then builds a custom workflow selecting only the stages the task actually needs. A cosmetic fix uses a handful of agents; a critical multi-file refactor gets full adversarial verification
- **Domain experts** — 110+ specialized agents (from `python-pro` to `security-reviewer` to `ios-pro`), each with domain-specific checklists and anti-patterns

## Agent Quality — Real-Project Tested

All 111 agents have been tested and optimized through a rigorous methodology:

**Method:** Each agent was tested in a 3-way comparison (original / polished / smart-applied) on real production codebases — not synthetic tasks. Test projects included C++ geostatistics libraries (hpgl-reborn), Python data parsers (pylasdev), Swift email clients (arcaios), Python/Qt desktop apps (pe_mac), and C# Outlook add-ins (peoutlook).

**Result:** The winning variant for each agent was selected based on objective criteria: finding accuracy, evidence quality, cross-file tracing depth, and zero false positives. Agents were compared head-to-head against Claude Code's own native subagents — **our agents won every comparison.**

**Cognitive Mode Tags:** Each agent in INDEX.md carries a Mode tag (TRACE / SWEEP / KNOW) derived from these tests, indicating which cognitive approach it's best at. This helps match the right agent to the task type.

- **TRACE** — best at following data/logic/flow through code (bug hunting, pipeline analysis)
- **SWEEP** — best at systematic checklist verification (security audits, idiom reviews)
- **KNOW** — best at applying deep domain/framework expertise (.NET, Spring, Django)

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
     Specialist    Up to 3 agents run in parallel — each gets a
      Agents       focused prompt with specific files, a domain
          │        persona, and questions they must answer
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

**Dynamic workflow** — No fixed pipeline. The planner classifies your task on 5 axes (size, domain breadth, ambiguity, severity, change type) and assembles a custom stage plan. A cosmetic text change skips discovery and uses a single agent. A critical security fix gets full adversarial verification with multiple verification passes.

## Requirements

- [OpenCode CLI](https://opencode.ai)
- At least one LLM provider configured in `~/.config/opencode/opencode.json`
- `uv` (auto-installed if missing — handles Python dependencies for tools)

## Automatic tasks execution

Run multiple tasks sequentially without manual intervention. Write tasks in `loop-tasks.txt`, one per line with a `[ ]` marker. The script picks the first pending task, sends it to opencode for automatic processing, marks it `[x]` when done, commits the progress, and moves to the next.

Compatible with **Windows** (Git Bash), **Linux**, and **macOS**.

### Quick Start

1. Add tasks to `loop-tasks.txt`:
   ```
   # How to use task loop file
   # =========================
   # [ ] Task to do (full description in one line)
   # [x] Finished task (marked by lead)

   [ ] Add dark mode support with automatic system theme detection
   [x] Fix race condition in payment confirmation handler
   [ ] Refactor database layer to use connection pooling
   ```

   - `[ ]` — pending task (will be processed)
   - `[x]` — completed task (skipped automatically)
   - `#` — comment (ignored)

2. Configure the command and model at the top of `loop-tasks-run.sh`:
   ```bash
   OPENCODE_CMD="opencode"
   MODEL="-m zai/glm-5.2"    # set to empty string to use default model
   ```

3. Run it:
   ```bash
   ./loop-tasks-run.sh
   ```

   Stop at any time with `Ctrl+C`. The current task will be interrupted but already-completed tasks stay marked `[x]` — restarting picks up the next pending one.

### Output

Logs go to `tmp/loop-runs/`. Each task gets its own timestamped log file.

## License

MIT
