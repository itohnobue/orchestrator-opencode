# Orchestration Workflow

A parallel AI agent orchestrator for [OpenCode](https://opencode.ai). Instead of doing work itself, the lead decomposes your task, spawns agents to do the actual work in parallel, verifies their output through an adversarial pipeline, and delivers production-ready results — all automatically. Works with any LLM provider.

## Why use it

A single agent working alone has one analytical lens. This workflow gives every problem multiple independent perspectives:

- **Parallel execution** — Up to 10 agents work simultaneously on different parts of your task. Scales to what the task needs: no wasted agents, no under-staffed stages
- **Adversarial verification** — Before any finding becomes a fix, adversarial agents try to **falsify** it. They read full source context and search exhaustively at every level — function guards, caller validation, framework protections, type system invariants, test coverage. Only findings that survive become actionable fixes. This catches false positives a single agent would have "fixed" into a regression
- **Iterative convergence** — The planner sets an iteration ceiling per stage (ONCE default, LOOP for highly ambiguous or production-critical work); whether an iteration actually fires is decided mechanically by the prior VERIFY synthesis grid (≥1 CONFIRMED HIGH/CRITICAL finding). Iterations use genuinely different FOCUS standpoints — no angle repeats, no role-swapping tricks. Each iteration gets its own full verify cycle
- **Smart scoping** — A three-agent planning pipeline researches the project, classifies the task on 5 axes (size, domains, ambiguity, severity, change type), then builds a custom workflow from available bricks. A cosmetic fix gets a handful of agents; a critical multi-domain refactor gets full adversarial verification with second opinions and cross-domain intersection audits
- **Comprehensive research stage** — A separate RESEARCH stage gathers external facts (standards, formats, versions, ecosystems, advisories) before execution. Reports are routed with precision: each agent receives exactly the research covering its scope — nothing unrelated
- **Research-defined specialist identity** — No static personas. Specialist standpoint comes from the research stage's FOCUS angles. The generic executor (`executor`) handles every execution role; research agents (web-searcher, research-analyst, data-researcher) produce the knowledge. At MEDIUM+ severity, every discovery and post-implementation review stage gets a research-backed second opinion with a complementary FOCUS (post-fix review is primary-only by measurement)

## The one general rule

> **Every agent should have research data.** If the data is already gathered and covers everything the agent needs, run PLAIN and pass the already-present data with the task. Research is injected only when the task depends on facts the file does not carry.

## Quick Start

```bash
git clone https://github.com/itohnobue/orchestrator-opencode
cd orchestrator-opencode
./install.sh /path/to/your/project   # macOS/Linux
# or: .\install.ps1 C:\path\to\project   (Windows)
```

The installer copies `.opencode/` (agents, tools, templates) into your project and creates `AGENTS.md` with workflow instructions. If `.opencode/` already exists, it merges new files without overwriting existing ones. Open your project with OpenCode — the workflow activates automatically when you give it a non-trivial task.

## How it works

```
You ask: "Add dark mode" or "Fix the payment race condition"
         │
         ▼
    Planning     Three-agent pipeline: agentic-planner researches
    Pipeline     the codebase and builds a custom workflow manifest
         │       (Research Coverage Map + Routing Table + per-agent
         │       tiers); volume-splitter resolves file scopes to
         │       exact paths with line counts; agent-organizer
         │       reviews structural compliance and routing precision
         ▼
    Research     Comprehensive external-fact research (standards,
         │       formats, versions, ecosystems, advisories) per the
         │       coverage map. Reports carry Report Scope + FOCUS
         │       angle + confidence tiers + Discovery Questions
         ▼
    Discovery    Executor agents audit existing code (PLAIN —
         │       planner context is the research). At MEDIUM+
         │       severity, a research-backed second opinion runs in
         │       parallel with a complementary FOCUS. Intersection
         │       agents trace cross-boundary flows with boundary-
         │       integrity research
         ▼
   Verification  Extraction deduplicates findings, tags confidence
         │       signals (both-found, boundary-found), and routes
         │       investigated-and-rejected items for re-examination.
         │       Adversarial agents (1:1 for CRITICAL, 1 per 3 for
         │       HIGH, 1 per 8 for MEDIUM) try to falsify every
         │       finding — reading full source context, searching
         │       for guards, types, tests. Only survivors become
         │       actionable fixes
         ▼
   [Converge?]   Fires only when the prior VERIFY grid contains
         │       ≥1 CONFIRMED HIGH/CRITICAL finding (mechanical).
         │       Iterations use genuinely different FOCUS angles
         │       (fresh research generated when the map runs out);
         │       converged when the grid shows no CONFIRMED HIGH+
         ▼
  Implementation Executor agents write the code. Reviewed by
         │       executor + research-backed second opinion at
         │       MEDIUM+. Cross-domain reviewers check integration
         │       points
         ▼
      Fixes      All confirmed findings applied mechanically by
         │       executor agents, verified by a build-gate,
         │       then independently reviewed (primary-only). If
         │       reviews find MEDIUM+ issues →
         │       fix again until clean
         ▼
      Test       Build + test suite + runtime smoke gate. Failures
         │       fixed. 100% working code verified.
         ▼
   Deliverable   Clean commits, passing tests, verified code
```

Everything runs autonomously — the lead coordinates, agents do the work, verification catches mistakes.

## Key concepts

**Lead** — The orchestrator. It doesn't write code. It researches your task, picks the right agents, writes their prompts, spawns them, and routes their findings through verification. The lead never edits project source code.

**Planning pipeline** — Before any stage agents run, a three-agent pipeline (agentic-planner + volume-splitter + agent-organizer) researches the codebase, classifies the task on 5 axes, selects workflow bricks, splits domains by language/framework and volume, builds the Research Coverage Map + Routing Table, and produces a verified plan with exact file paths, per-agent tiers, and FOCUS angles. No bad plan reaches the execution phase.

**Agents** — 10 agents: 9 workflow-internal roles (planning, verification, research, single-session prep) + the generic executor. No static specialist personas — specialist identity comes from the research stage's FOCUS angles. The executor handles every execution role with maximum reasoning effort (default); research agents produce the knowledge; verification agents gate the findings. At MEDIUM+ severity, every discovery and post-implementation review stage gets a research-backed second opinion with a complementary FOCUS. Post-fix review is primary-only by measurement.

**RESEARCH brick** — Gathers EXTERNAL facts beyond what the codebase provides: web search, documentation, standards, community knowledge, datasets. Internal codebase facts are executor work — executors read code themselves. The planner's Research Coverage Map ensures every area any executor may need is covered; the Routing Table gives each agent exactly the reports covering its scope (precision rule — unrelated data degrades results). Reports carry Report Scope (routing key), FOCUS angle, findings with confidence tiers (CONFIRMED/LIKELY/TENTATIVE/SPECULATIVE), provisional traps, and Discovery Questions. VERIFY is skipped for purely informational findings; runs when findings include code-level references.

**Tiers** — PLAIN (the task file already carries the research — planner context, contracts, specs; pass it through), POINTER (report path + Discovery Questions for external-fact primaries), INJECT (full report as RESEARCH DATA for s2, intersections, thin-context primaries).

**Verification** — Before any finding becomes a fix, it goes through adversarial checking. An extraction agent deduplicates findings, tags them with confidence signals (both-found, boundary-found), and routes each report's investigated-and-rejected items into the adversarial batches for re-examination. Severity-routed adversarial agents then try to falsify each one: 1:1 for CRITICAL findings, 1 per batch of 3 for HIGH findings, 1 per batch of 8 for MEDIUM findings. Each agent reads full source context (minimum 30 lines) and exhaustively searches for counter-evidence at every level — function guards, caller validation, framework protections, type system invariants, test coverage. Only findings that survive become fixes.

**Convergence** — The planner sets an iteration ceiling per stage (ONCE: at most one extra iteration, the default; LOOP: up to 3 for highly ambiguous or production-critical work). Firing is mechanical, never a lead judgment call: an iteration fires only when the prior VERIFY synthesis grid contains at least one CONFIRMED HIGH/CRITICAL finding (adversarially verified). REJECTED or WEAKENED findings never trigger. Each pass uses genuinely different FOCUS angles — no angle repeats, no role-swapping. When the pre-baked research map runs out, fresh research is generated per angle (bounded by the ceiling). Each iteration gets its own full verify stage before the next iteration spawns. A stage with zero CONFIRMED HIGH+ in its grid is converged after one pass.

**Dynamic workflow** — No fixed pipeline. The planner classifies your task on 5 axes (size, domain breadth, ambiguity, severity, change type) and assembles a custom stage plan from a brick catalog (RESEARCH/DISCOVER/IMPLEMENT/REVIEW/VERIFY/CONVERGE/FIX/TEST). A cosmetic text change skips discovery and research. A critical security fix gets full adversarial verification with research on CVE context and multiple discovery passes.

**Temporary files** — All agent reports, logs, and task prompts go to the orchestrator's `tmp/` directory using absolute paths. The tool script (`assemble-task.sh`) computes the repository root at startup and injects absolute paths into every agent's task prompt — agents always write to the correct directory regardless of which project they're inspecting. Agent `.md` files are loaded natively by opencode as subagent system prompts, and task content uses plain `tmp/` references that are auto-converted to absolute at assembly time.

## Requirements

- [OpenCode CLI](https://opencode.ai)
- At least one LLM provider configured in `~/.config/opencode/opencode.json`
- `uv` (auto-installed if missing — handles Python dependencies for tools)

## Single-session mode (on-demand switch)

The repo ships a `single-session-workflow` skill that switches the model out of orchestrator mode on demand: invoking it makes the model stop acting as the lead and follow the single-session protocol instead (main session = primary worker, direct work in dialog with the user, tiered delegation only, no planner pipeline).

**Usage:** in any session, ask the model to invoke the skill (or invoke it via the skill tool): "switch to single-session mode".

**Where it lives:** the skill content is tracked at `skills/single-session-workflow/SKILL.md` — the single-session-opencode `AGENTS.md` protocol verbatim, prefixed with a mandatory mode-switch preamble. Because `.opencode/skills/` is gitignored in this repo (machine-local by design), the tracked copy is symlinked into place on each machine:

```bash
ln -s ../../skills/single-session-workflow .opencode/skills/single-session-workflow
```

See `skills/README.md` for details.

**Known limitations:** none — the single-session suite's pieces are fully installed in this repo (`prepare-agent`, the `executor` agent shared with the orchestrator pipeline, `inject-research.sh`, and the `-t prepare` task type in `assemble-task.sh`), so the researched-delegation path (T2/T3) is available alongside the orchestrator pipeline.

## Automatic tasks execution

Run multiple tasks sequentially without manual intervention. Write tasks in `loop-tasks.txt`, one per line with a `[ ]` marker. The script picks the first pending task, sends it to opencode for automatic processing, marks it `[x]` when done, commits the progress, and moves to the next.

Compatible with **Windows** (Git Bash), **Linux**, and **macOS**.

### Usage

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
   MODEL=""          # uses configured default model
   # MODEL="-m zai/glm-5.2"  # or override with a specific model
   ```

3. Run it:
   ```bash
   ./loop-tasks-run.sh
   ```

   Stop at any time with `Ctrl+C`. The current task will be interrupted but already-completed tasks stay marked `[x]` — restarting picks up the next pending one.

### Output

Logs go to `tmp/loop-runs/`. Each task gets its own timestamped log file. Progress (marked `[x]`) is committed and pushed automatically so you can run this on a dedicated machine and monitor completion from anywhere.

## License

MIT
