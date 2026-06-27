# Orchestration Workflow

A parallel AI agent orchestrator for [OpenCode](https://opencode.ai). Instead of doing work itself, the lead decomposes your task, spawns specialist agents to do the actual work in parallel, verifies their output through an adversarial pipeline, and delivers production-ready results — all automatically. Works with any LLM provider.

## Why use it

A single agent working alone has one analytical lens. Two different specialists checking the same code find **structurally different issues** — our testing across 5 language domains and 260+ agent configurations shows 87% complementarity between specialist pairs. This workflow gives every problem multiple independent perspectives:

- **Parallel execution** — Up to 10 specialist agents work simultaneously on different parts of your task. Count scales to what the task needs: no wasted agents, no under-staffed stages
- **Adversarial verification** — Before any finding becomes a fix, adversarial agents try to **falsify** it. They read full source context and search exhaustively at every level — function guards, caller validation, framework protections, type system invariants, test coverage. Only findings that survive become actionable fixes. This catches false positives a single agent would have "fixed" into a regression
- **Iterative convergence** — For complex or critical work, the planner schedules a second pass with genuinely different specialists. No agent reappears, no role-swapping tricks. Each iteration gets its own full verify cycle. Agents stop when they find nothing new — no guessing, no "that looks good enough"
- **Smart scoping** — A two-agent planning pipeline (planner + organizer) researches the project, classifies the task on 5 axes, splits domains by specialist and volume, then builds a custom workflow. A cosmetic fix gets a handful of agents; a critical multi-domain refactor gets full adversarial verification with second opinions and cross-domain intersection audits
- **Domain experts** — 110+ specialized agents, each with domain-specific checklists and anti-patterns. At MEDIUM+ severity, every discovery and review stage gets a second opinion from a **different** specialist — two independent analytical frameworks on the same code

## Agent Quality — Real-Project Tested

All 111 agents have been tested and optimized through a rigorous methodology:

**Method:** Each agent was tested in a 3-way comparison (original / polished / smart-applied) on real production codebases — not synthetic tasks. Tested on real production codebases.

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
    Planning     Two-agent pipeline: agentic-planner researches your
    Pipeline     codebase and builds a custom workflow manifest;
         │       agent-organizer reviews it, resolves file scopes
         │       to exact paths, verifies volume limits, and fixes
         │       any gaps — all before stage agents spawn
         ▼
    Discovery    Specialist agents audit existing code. At MEDIUM+
        │        severity, a second opinion runs in parallel with
        │        a different specialist. For multi-domain tasks,
        │        intersection agents trace cross-boundary flows
        │        for gaps neither domain specialist would catch
        ▼
   Verification  Extraction deduplicates findings. Adversarial
        │        agents (1:1 for CRITICAL/HIGH, 1 per 5 for
        │        MEDIUM) try to falsify every finding — reading
        │        full source context, searching for guards, types,
        │        tests. Only survivors become actionable fixes
        ▼
   [Converge?]   For complex/critical work: spawn a second pass
        │        with genuinely different specialists. Repeat
        │        until no new findings — then proceed to fix
        ▼
  Implementation Domain specialists write the code. Reviewed by
        │        code-reviewer + second opinion at MEDIUM+.
        │        Cross-domain reviewers check integration points
        ▼
      Fixes      All confirmed findings applied mechanically
        │        by domain specialists, then independently
        │        reviewed. If reviews find MEDIUM+ issues →
        │        fix again until clean
        ▼
      Test       Build + test suite. Failures fixed. Working
        │        code verified.
        ▼
   Deliverable   Clean commits, passing tests, verified code
```

Everything runs autonomously — the lead coordinates, agents do the work, verification catches mistakes.

## Key concepts

**Lead** — The orchestrator. It doesn't write code. It researches your task, picks the right agents, writes their prompts, spawns them, and routes their findings through verification. The lead never edits project source code.

**Planning pipeline** — Before any stage agents run, a two-agent pipeline (agentic-planner + agent-organizer) researches the codebase, classifies the task, selects workflow bricks, splits domains by specialist and volume, and produces a verified plan with exact file paths and agent assignments. No bad plan reaches the execution phase.

**Agents** — Specialist AI workers. Each one gets a narrow, well-defined task with a specific persona (`swift-pro`, `code-reviewer`, `security-reviewer`). They work independently and write structured reports. At MEDIUM+ severity, every discovery and review stage gets a second opinion — a different specialist checking the same code through a different analytical framework (proven 87% complementarity).

**Verification** — Before any finding becomes a fix, it goes through adversarial checking. An extraction agent deduplicates findings and tags them with confidence signals (both-found, boundary-found). Severity-routed adversarial agents then try to falsify each one: 1:1 for CRITICAL/HIGH findings, 1 per batch of 5 for MEDIUM findings. Each agent reads full source context (minimum 30 lines) and exhaustively searches for counter-evidence at every level — function guards, caller validation, framework protections, type system invariants, test coverage. Only findings that survive become fixes.

**Convergence** — For interconnected modules, dense coupling, or HIGH+ severity tasks, the planner can schedule iterative passes (ONCE: one extra iteration; LOOP: up to 3). Each pass uses genuinely different specialists — no agent reappears, no role-swapping. Each iteration gets its own full verify stage before the next iteration spawns. Convergence happens when agents stop finding new issues.

**Dynamic workflow** — No fixed pipeline. The planner classifies your task on 5 axes (size, domain breadth, ambiguity, severity, change type) and assembles a custom stage plan from a brick catalog (DISCOVER/IMPLEMENT/REVIEW/VERIFY/CONVERGE/FIX/TEST). A cosmetic text change skips discovery. A critical security fix gets full adversarial verification with multiple discovery passes.

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
