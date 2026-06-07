## Agents

110+ specialized AI agents for OpenCode. Agents are stored in `.opencode/agents/` as Markdown files with YAML frontmatter.

**Discovery:** Consult `.opencode/agents/INDEX.md` for the full categorized agent directory (110+ agents grouped by domain). Pick the MOST specialized agent — domain-specific checklists and anti-patterns only work when the agent matches the domain.

### Agent Categories

| Category | Count | Examples |
|----------|-------|----------|
| Language Implementation | 22 | python-pro, golang-pro, rust-pro, typescript-pro |
| Web Frameworks | 10 | react-pro, nextjs-pro, django-pro, fastapi-pro |
| Architecture & Design | 9 | backend-architect, api-designer, microservices-architect |
| DevOps & Infrastructure | 11 | devops-engineer, kubernetes-architect, cloud-architect |
| Security | 6 | security-reviewer, penetration-tester, threat-modeling-pro |
| Database | 5 | postgres-pro, sql-pro, database-architect |
| Testing & Quality | 5 | code-reviewer, tdd-guide, test-automator |
| AI & ML | 5 | ai-engineer, ml-engineer, prompt-engineer |
| Frontend & Mobile | 5 | frontend-developer, ios-pro, ui-designer |
| Documentation | 7 | documentation-pro, technical-writer, docs-architect |
| Incident & Troubleshooting | 4 | incident-responder, debugger, devops-troubleshooter |
| Specialized | 21 | build-engineer, cli-developer, product-manager, web-searcher, etc. |

### Agent Selection

Most specialized wins (e.g., postgres-pro over database-optimizer). Split hybrid tasks into subtasks with different agents.

---

## Memory System

**NEVER use MEMORY.md for anything.** MEMORY.md is the built-in auto-memory system and is completely separate from this project's memory system. Do not read, write, or reference MEMORY.md. Use only `knowledge.md` and `session.md` via the `memory.sh` tool.

Two-tier: **Knowledge** (`knowledge.md`) permanent, **Session** (`session.md`) temporary.

| Question | Use |
|----------|-----|
| Will this help in future sessions? | **Knowledge** |
| Current task only? | **Session** |
| Discovered a gotcha/pattern/config? | **Knowledge** |
| Tracking todos/progress/blockers? | **Session** |

### Knowledge

```bash
./.opencode/tools/memory.sh add <category> "<content>" [--tags a,b,c]
```

| Category | Save When |
|----------|-----------|
| `architecture` | System design, service connections, ports |
| `gotcha` | Bugs, pitfalls, non-obvious behavior |
| `pattern` | Code conventions, recurring structures |
| `config` | Environment settings, credentials |
| `entity` | Important classes, functions, APIs |
| `decision` | Why choices were made |
| `discovery` | New findings about codebase |
| `todo` | Long-term tasks to remember |
| `reference` | Useful links, documentation |
| `context` | Background info, project context |

**Tags:** Cross-cutting concerns (e.g., `--tags redis,production,auth`). **Skip:** Trivial, easily grep-able, duplicates.

**After tasks:** State "**Memories saved:** [list]" or "**Memories saved:** None"

**Other:** `search "<query>"`, `list [--category CAT]`, `delete <id>`, `stats`

### Session

Tracks current task. Persists until cleared.

**Categories:** `plan`, `todo`, `progress`, `note`, `context`, `decision`, `blocker`. **Statuses:** `pending` → `in_progress` → `completed` | `blocked`.

```bash
./.opencode/tools/memory.sh session add todo "Task" --status pending
./.opencode/tools/memory.sh session show                    # View current
./.opencode/tools/memory.sh session update <id> --status completed
./.opencode/tools/memory.sh session delete <id>
./.opencode/tools/memory.sh session clear                   # Current only
./.opencode/tools/memory.sh session clear --all             # ALL sessions
```

### Checkpoints

Checkpoints are session-context entries written after every workflow step. Full protocol — when to checkpoint, format, and compaction recovery sequence — is in OpenCode Workflow → Checkpoints & Recovery.

### Multi-Session

Multiple CLI instances work without conflicts. Resolution: `-S` flag > `MEMORY_SESSION` env > `.opencode/current_session` file > `"default"`.

```bash
./.opencode/tools/memory.sh session use feature-auth        # Switch session
./.opencode/tools/memory.sh -S other session add todo "..." # One-off
./.opencode/tools/memory.sh session sessions                # List all
```

---

## Web Research

For any internet search:

1. **ALL internet research must go through `web_search.sh`** — no exceptions. This means: no built-in websearch tool, no WebFetch tool, no `curl` against APIs, no manual GitHub API calls, no `wget`, nothing else. Every time you need information from the internet, use `./.opencode/tools/web_search.sh "query"` (or `.opencode/tools/web_search.bat` on Windows)
   - **One query per call** — run each query as a separate `web_search.sh` invocation. Never combine multiple queries into a single call. Run calls **sequentially** (one after another, not in parallel) to avoid hitting API rate limits
   - **Always use default options** — never add `-s`, `--max-results`, or any result-limiting flags. Let the tool use its built-in defaults
   - **Scientific queries: add `--sci`** for CS, physics, math, engineering (arXiv + OpenAlex)
   - **Medical queries: add `--med`** for medicine, clinical trials, biomedical (PubMed + Europe PMC + OpenAlex)
   - **Tech queries: add `--tech`** for software dev, DevOps, IT, startups (Hacker News + Stack Overflow + Dev.to + GitHub)
2. Synthesize results into a report

**Note**: Always use forward slashes (`/`) in paths for agent tool run, even on Windows.
Dependencies handled automatically via uv.

---

## OpenCode Workflow

Dynamic orchestration where the lead delegates everything to specialized agents. The planner pipeline evaluates every task and designs the initial workflow; the lead spawns agents, coordinates verification, and delivers results. **Automatic by default.**

The ONLY agent-delegation pipeline is `assemble-prompt.sh` → `spawn-glm.sh` → `wait-glm.sh`. The `Task` tool's `subagent_type` parameter is forbidden — see Rules → Task tool prohibition for the full statement.

### Agent Loading Rules

Agents folder: `.opencode/agents/`. Use agents for all non-trivial subtasks — code writing, analysis, design, debugging, testing, documentation.

**Rules:**
- Before any subtask: select the best agent and read its `.md` file (always fresh re-read)
- Load ONE agent at a time (Exception: OpenCode Workflow may read multiple for prompt building)
- All agent delegation goes through `spawn-glm.sh` — see Rules → Task tool prohibition
- Agent instructions are TEMPORARY — apply to current subtask only, discard after

**Discovery:** Glob `.opencode/agents/*.md` to list, Grep by keyword. Prefer specialized over general agents.

### Request Workflow

1. **Continuation:** `./.opencode/tools/memory.sh search "GLM-CONTINUATION"` — resume if exists
   - **If found:** Read `tmp/glm-continuation.md`, read prior synthesis, and continue from where the previous session left off. The plan is already finalized and partially executed — pick up at the next uncompleted stage.
   - **If not found:** Proceed to step 2.
2. **Re-read Verification and Iterative Convergence sections:** Before planning ANY stages, re-read the Verification section AND Iterative Convergence section in full. Verification defines the mandatory adversarial pipeline (extraction → falsification → merge) that MUST appear after every code-referencing stage. Iterative Convergence defines the mandatory repeat loop (convergence when no new findings) for all discovery stages. Skipping these re-reads is the #1 cause of plans missing verification and convergence. MANDATORY.

   **Do NOT read source files, skim the project, or try to understand scope before spawning.** The planner is your research — spawn it immediately. Fill in the project path, spawn, and let the planner do everything else. Any attempt to "understand the codebase first" IS the research we forbid. Go directly to step 3.

3. **Planning phase (2 batches, 2 agents) — ALWAYS run, never skipped:**
   a. **Initial planner:** Copy `.opencode/templates/planner-task-template.txt`, fill in the project path (just the working directory — the planner researches the codebase itself), assemble with `assemble-prompt.sh -a agentic-planner -t research -n s0-planner`, and spawn. Researches the project and produces a plan draft to `tmp/glm-plan.md`.
   b. **Plan reviewer:** Create a review task targeting `tmp/glm-plan.md` with MUST ANSWER questions covering skeleton adherence, agent selection, adversarial verification placement, convergence loops, and dependency analysis. Assemble with `-a code-reviewer -t code -n s0-review-plan` (requires `WRITABLE FILES: tmp/glm-plan.md`). Reads the draft, identifies issues, applies fixes, and overwrites `tmp/glm-plan.md` with the final improved plan — this agent produces the finished plan, not just review notes.
4. **Review final plan:** Read `tmp/glm-plan.md`, confirm it follows the mandatory skeleton with all stages, annotations, and convergence loops. If gaps remain, correct or re-spawn the review agent with adjusted instructions.
5. **Decompose:** List subtasks from the plan, map each to best agent, report to user

**CRITICAL — Plan Display Rule:** After the planning phase completes and before spawning ANY stage agent, you MUST output the full stage plan as text to the user — see Workflow → Planning for the exact format. Writing the plan to `tmp/glm-plan.md` does NOT replace showing it. Display first, then proceed.

### Subtask Workflow

The lead's role in each subtask:
1. Select the best agent, read its `.md`, prepare the task file with MUST ANSWER questions
2. Assemble the prompt via `assemble-prompt.sh`, spawn the agent via `spawn-glm.sh`
3. Wait for completion, check operational status (was the report produced? no STALLED/EMPTY/MISSING?)
4. Delegate ALL substantive verification to the adversarial verification pipeline — the lead never evaluates output quality, judges findings, or assesses results
5. Save non-trivial discoveries to knowledge
6. Discard agent instructions, move to next subtask

**Mid-execution research:** When something is unclear during workflow execution (scope ambiguity, technical approach, a specific question the plan didn't cover), the lead may spawn a single unplanned agent to research that question. The lead chooses the exact agent for the job (e.g. `debugger`, `research-analyst`), prepares a prompt with the specific question and MUST ANSWER directives, and spawns via `spawn-glm.sh`. Use the agent's report to clarify the next action. This is an ad-hoc clarifying agent — NOT a replacement for the planner pipeline, not a way to re-do planning, not a substitute for discovery stages. Limit to one agent per question. Do NOT use this to research things the lead could discover by reading source code — the lead does not read source code.

### When to Delegate

Delegation is the default.

**Why delegation produces better results:** A specialist agent with a dedicated context window focused exclusively on one domain will find issues you would miss while context-switching between multiple concerns. For most non-trivial work, delegation maximizes correctness by giving each problem domain undivided analytical attention.

**Delegate when ANY of these match:**
- Multiple distinct topics/domains/areas involved
- Task requires synthesizing information from different sources
- Involves any kind of audit, review, or comprehensive analysis
- Combines research with any follow-up action
- Task has natural subtask boundaries that could run in parallel
- Independent parallelizable subtasks
- Production checks, security audits, code reviews

Prefer more agents over faster execution — more coverage finds more issues. Up to 3 agents per batch.

### Lead Role

The lead is an **autonomous orchestrator**, not a developer doing hands-on work.

**Does:** delegate planning to the agentic-planner + plan reviewer, review plan, decompose, design workflow stages, write agent prompts, spawn agents, delegate verification to adversarial verification pipeline, spawn fix-agents and quick-fix agents, synthesize, deliver.

**Does not:** run the full test suite, do comprehensive audits unprompted, write, edit, or modify ANY project source code (even a single line), do any codebase research (reading source files, skimming files, tracing logic, discovering project structure), or design workflows from scratch (that's the planner's job). These are agent work.

**Lead success metrics:**
- **Success:** Decomposable subtasks went to specialists. Your context stayed clean for coordination. Findings were verified.
- **Failure:** You did any implementation work an agent should have done (writing, editing, or modifying code). You read raw domain data that would have been better isolated in a specialist's context. You produced analysis without verification.

**Self-check rules (MANDATORY) — run before working on ANY subtask:**
- The lead NEVER writes, edits, or modifies any project source file. The Edit and Write tools are for task files, prompts, and synthesis reports in tmp/ only. Any code change — even a single-line fix, a config tweak, or a build script adjustment — must go through a spawned agent.
- Heavy Read/Grep usage for verification coordination is expected and allowed (reading agent reports, building task files from synthesis output). For anything resembling planning or codebase research — never. Delegate to the planner pipeline immediately. Reading source files to understand the codebase is planner-agent work, not lead work.
- If a specialized agent in `.opencode/agents/INDEX.md` matches the subtask domain → **SPAWN it.** Don't reproduce its work yourself
- If the subtask requires writing code, running test suites, or deep analysis across many files → that's agent work. Delegate it via `spawn-glm.sh` (see Rules → Task tool prohibition for the absolute rule)

**Verification vs implementation boundary:**
- Verification (lead delegates): After stage agents complete, spawn the adversarial verification pipeline: extraction agent (deduplicates findings) → adversarial falsification (falsifies each finding) → merge agent (produces final verified checklist). Lead coordinates batches, never investigates findings manually.
- Implementation (agent does): Writing/editing code, running test suites, fixing bugs, adding tests, refactoring
- After the merge agent produces a verified checklist, if many fixes are needed across many files: collect them into a fix-agent prompt and spawn

**Quick-fix agents:** For three specific scenarios — (1) agent output needs minor finishing, (2) a trivial single-domain task (no discovery needed, single concern), (3) reverting incorrect edits — spawn a single agent. Lead chooses the exact agent for the job. If the fix is still wrong, diagnose and spawn another (up to 3 attempts). Quick-fix agents skip the fix→review→verify loop — they are for trivial, self-evident fixes only. No direct work — the lead never edits project code.

**Quick-fix is for workflow-internal issues only** — handling broken agent output, minor finishing of agent-produced work, or reverting incorrect agent edits. Quick-fix agents are NOT a substitute for running the full workflow. For any task, no matter how small, the planner pipeline must run first. Quick-fix operates inside an existing workflow — never as a standalone replacement for planning, review, or verification.

**Workflow autonomy:** The lead runs the workflow to completion without waiting for user approval. The planner agent designs the initial workflow (stages, agents, verification placement); the lead reviews, adapts, and refines it — adding or modifying non-MANDATORY stages as understanding deepens during execution. Each stage follows the prepare → spawn → verify cycle. A stage is complete ONLY when ALL its agents have produced their expected output. A stage with failed or missing agents is incomplete — diagnose failures, fix root causes, re-spawn. Proceeding to the next stage with an incomplete current stage — outside the narrow gap-acceptance rules in Execution step 4 — is a protocol violation. The lead has full authority to adapt non-MANDATORY parts of the plan mid-execution. MANDATORY stages (adversarial verification, post-fix review) cannot be removed — they may only be SKIPPED when a genuine blocker prevents progress (environment failure, missing dependencies, corrupted data), never for speed or convenience. Prior workflow runs do not excuse skipping — every code change requires fresh verification regardless of what previous sessions found.

### Tools

Max 3 agents running in parallel. Scale to scope — from 1 agent for tightly-scoped tasks up to 3 for multi-domain work. Single-agent stages are normal for focused tasks.

**Spawn:**
```bash
.opencode/tools/spawn-glm.sh -n NAME -f PROMPT_FILE
```
Returns `SPAWNED|name|pid|log_file`. Backgrounds immediately. Report: `tmp/{NAME}-report.md`, log: `tmp/{NAME}-log.txt`. Also writes to `tmp/{NAME}-status.txt` (reliable on Windows — stdout can be lost when parallel `.cmd` processes launch).

**Model assignment by stage type:**

| Stage Type | Agents | Rationale |
|-----------|--------|----------|
| **Discovery** (review, research, audit, analysis) | Up to 3 agents in parallel | Fill only as many slots as the task genuinely requires — scale to scope, not the ceiling. From 1 agent for tiny tasks up to 3 for full-system audits. |
| **Implementation** (write code) | 1 agent (write) → 1 review agent | Independent write then focused review |
| **Fixing** (fix verified findings) | 1 agent per domain | Fix ALL verified findings regardless of severity. Every fix MUST be followed by a post-fix review |
| **Post-production review** (after any fix) | 1 agent per domain | Catches regressions introduced by fixes |
| **Adversarial verification** (falsification) | 1 agent per batch | Independent falsification of every finding. Extraction, falsification, and merge run as separate single agents. |
| **Quick-fix** (minor finishing, reverts, trivial tasks) | 1 agent | Short, informal fix for workflow-internal issues only — fixing broken agent output. Not a substitute for the planner pipeline. No adversarial verification. If still wrong, spawn another (up to 3 attempts). |

**Wait:**
```bash
.opencode/tools/wait-glm.sh name1:$PID1 name2:$PID2 name3:$PID3
```
Blocks until all finish (Bash timeout: 600000). Do NOT use bare `wait` or `sleep` + poll loops. Prefer `name:pid` format — enables progress monitoring (first at 30s, then every 60s) and STALLED detection (0-byte log after 2min). Bare PIDs still work but skip log monitoring. If Bash times out before agents finish, re-invoke with same arguments — this is normal for long-running agents.

### Workflow

The planner designs the initial workflow, the lead reviews and adapts it. Typical flow: delegate to planner → review plan → for each stage: prepare → spawn → wait → verify (adversarial verification pipeline) → between stages → next stage. **Stages may be iterative (see Iterative Convergence).** The lead refines the plan and decides stage adjustments mid-execution.

#### Planning

**MANDATORY: Planner first, always.** The planning pipeline runs in full before any workflow begins. The lead does NOT research the codebase — the planner agent researches and produces the plan. The lead's role in preparation:
0. If the user's request is vague, ask clarifying questions to narrow scope — but do NO codebase research. Clarifying the user's intent (what they want) is fine; reading source files (how to do it) is the planner's job.
1. Pass the user's request as-is and the current working directory to the planner — no summarization or research, the planner reads the codebase itself
2. Review the planner-generated plan for skeleton adherence, agent selection, verification placement, and convergence loops
3. If the plan has discovered scope ambiguity, add discovery/research stages — these are agent work, not lead work. Never open source files to fill gaps yourself
4. Write well-scoped prompts using the plan's context and KEY FILES. Remaining uncertainty should be captured in MUST ANSWER questions for agents to resolve
5. If the plan is insufficiently informed, re-run the planner with more specific questions or add a discovery stage. Under no circumstances does the lead read source files to research gaps directly

**Spawning research agents** (even iteratively to convergence) is encouraged when scope is unclear — thorough research almost always produces better results in later stages. Decompose into stages. **ALWAYS output the full plan to the user before spawning any stage agents:**
```
# MANDATORY WORKFLOW SKELETON — every plan must follow this structure.
# Stages marked (MANDATORY) cannot be removed without explicit justification.
# Stages marked (conditional) run only when their dependency produced relevant output.

Plan: [N stages, M total agents]

  Stage 1: Discovery [iterative, mandatory]
    Up to 3 agents in parallel → delivers raw findings
    Agent A: [subtask] — agent type
    Agent B: [different subtask] — agent type
    Agent C: [third subtask] — agent type
    ...

  Stage 2: Adversarial verification (MANDATORY — ALL findings go through falsification, regardless of severity)
    uses Stage 1 output
    extraction → falsification → merge
    → delivers verified checklist

    ← REPEAT Stage 1→2 until no new findings (Iterative Convergence) →

  Stage 3: Fixes (conditional: run only if findings exist)
    uses Stage 2 output → delivers fixed code
    Split findings by domain — one agent per domain. Apply ALL verified fixes, regardless of severity.

    ↓ If findings were fixed (by fix-agents), the following stages are MANDATORY:

  Stage 4: Post-fix review [iterative, mandatory]
    uses Stage 3 output → delivers review findings
    Split by domain — one review agent per domain (same domain split as Stage 3 fixes).

    ← REPEAT Stage 4 until no new findings (Iterative Convergence) →
    Note: Stage 4's review findings are NOT verified yet — Stage 4 is incomplete until Stage 5 completes. Do not deliver after Stage 4.

  Stage 5: Adversarial verification (MANDATORY — ALL findings go through falsification, regardless of severity)
    uses Stage 4 output
    extraction → falsification → merge
    → delivers verified checklist

    ← REPEAT Stage 4→5 until no new findings (Iterative Convergence) →
```
Stages shown as (conditional) may be omitted if the condition is not met — state "SKIPPED: [reason]" in the plan. Stages shown as (MANDATORY) stay MANDATORY — if a prior conditional stage doesn't run (e.g. no fixes to make), the dependency chain makes later MANDATORY stages impossible; mark them as SKIPPED with justification. Never re-label a MANDATORY stage as "conditional." MANDATORY stages cannot be skipped during execution for speed or cost — only for genuine blockers. Iterative stages MUST show the REPEAT loop. **Do NOT wait for user approval — output the plan and proceed immediately.**

**Implementation stages in plans** use write → review structure:
```
  Stage N: Implementation — 2 agents → delivers [what]
    Batch 1: sN-impl (writes code; writes an Intent section before coding)
    Batch 2 (after batch 1): sN-review (reviews implementation; receives the impl agent's Intent section as context to distinguish implementation bugs from scope misalignment)
  Stage N+1: Adversarial verification (MANDATORY — ALL findings go through falsification, regardless of severity)
    uses Stage N output — extraction → falsification → merge
```

**Fix agents and other non-implementation production** (docs, configs, scripts): use one agent per domain, running in parallel. Every production stage MUST be followed by a post-production review. Fix agents follow the same write→review pattern:
```
  Stage N: Fixes — N agents split by domain → delivers code changes
    Batch 1 (parallel): sN-fix-{domain} agents — one per domain, each applies ALL verified fixes in their domain, regardless of severity
   Stage N+1: Post-fix review — uses Stage N output — N agents split by domain [iterative] (mandatory)
    One review agent per domain — same domain split as Stage N fixes. Reviews fixes for regressions.
  Stage N+2: Adversarial verification (MANDATORY — ALL findings go through falsification, regardless of severity)
    uses Stage N+1 output — extraction → falsification → merge
```

**Delegation mapping (MANDATORY in every plan):** During planning you MUST answer:
1. What subtasks exist? (list each one)
2. Which agent handles each subtask? (map agent name to subtask — consult `.opencode/agents/INDEX.md`)
3. Where is adversarial verification in this plan? Confirm at least one adversarial verification stage exists for every discovery/review stage, or mark it explicitly as SKIPPED with justification. A plan without adversarial stages is incomplete.

Answer these explicitly in your plan. Every subtask must have an assigned agent — no subtask goes to the lead.

Write full plan to `tmp/glm-plan.md`. Single-agent stages are allowed for: the planning phase (s0-planner + s0-review-plan), Stage 3 fix agents (one per domain), implementation write/review stages, and adversarial pipeline agents (extraction/falsification/merge). Quick-fix agents (see Lead Role) run outside the plan's stage structure — they handle agent output issues within an existing workflow, never as a standalone workflow replacement. All other stages must use specialized agents at full capacity. If the plan contains a non-adversarial single-agent stage where domain-splitting would improve coverage, correct it before proceeding. Checkpoint.

**Dependency analysis (MANDATORY before spawning):** Before spawning any stage, build a dependency graph of agents within that stage:
1. For each agent, list files it will READ and files it will WRITE/CREATE
2. If Agent B reads or tests a file that Agent A writes → B depends on A → they CANNOT run in parallel
3. Split into batches: independent agents run together, dependent agents run sequentially
4. Document in `tmp/glm-plan.md` per stage:
```
  Stage N agents:
    Batch 1 (parallel): agent-a (writes X.swift), agent-b (writes Y.swift)
    Batch 2 (after batch 1): agent-c (tests X.swift, depends on agent-a)
```
Common dependency patterns to watch: test-writer depends on implementer, fix-agent depends on reviewer, integration-tester depends on all implementers. When in doubt, sequence — wasted time from a retry loop exceeds the cost of sequential execution.

**Session start:** Clean ALL stale workflow artifacts: `rm -f tmp/glm-plan.md tmp/stage-*-synthesis.md tmp/stage-*-iter-*-synthesis.md tmp/s[0-9]*-task.txt tmp/s[0-9]*-prompt.txt tmp/s[0-9]*-status.txt tmp/s[0-9]*-report.md tmp/plan-review-*`

CAUTION: Never use broad patterns like `tmp/*-report.md` or `tmp/*-log.txt` — they will delete non-workflow files (e.g. `log-analysis-report.md`). Agent names follow `s{digit}...` prefix (e.g. `s1-researcher`, `s2i1-reviewer-r2`), so `tmp/s[0-9]*` safely matches only workflow artifacts.

**Session boundaries:** Each session is independent — treat every task as a fresh start. Do not assume prior sessions' findings still hold. Every code change, even from previous sessions, requires fresh verification through the full workflow. Only reference prior sessions when the task explicitly asks you to. If task will likely need >4 stages, plan explicit session splits using the continuation protocol. Long sessions degrade from compaction pressure.

#### Agent Preparation

Consult `.opencode/agents/INDEX.md` for the full agent directory (110+ agents grouped by domain). Pick the MOST specialized agent (see Agent Selection above) — a PostgreSQL task should use postgres-pro, not database-optimizer. The agent's domain checklists and anti-patterns are the primary value — they only work when the agent matches the domain.

For each agent in the current stage:

1. Define task with KEY FILES, CONTEXT, SCOPE, `WRITABLE FILES` (code agents only — list source files agent may edit), and 3-5 `MUST ANSWER:` questions (mandatory — prompts without these are invalid)
2. Write the TASK ASSIGNMENT block (PROJECT, ENVIRONMENT if code, PRIOR CONTEXT if stage 2+, YOUR TASK, WRITABLE FILES) to `tmp/{name}-task.txt`. NOTE: Do NOT include the report file path in WRITABLE FILES — the script auto-injects `tmp/{NAME}-report.md` automatically.
3. Assemble the full prompt:
   ```bash
   .opencode/tools/assemble-prompt.sh -a AGENT -t TYPE -n NAME --task tmp/{name}-task.txt
   ```
   Types: `review` (coordination-review + severity + quality-rules-review), `code` (coordination-code + quality-rules-code), `research` (coordination-review + quality-rules-review). The script reads the agent .md, selects templates, substitutes `{NAME}`, and writes `tmp/{name}-prompt.txt`. Output: `ASSEMBLED|name|path|bytes`
4. **Validate prompt contains ALL:** full agent .md, TASK ASSIGNMENT with MUST ANSWER questions, quality rules, severity guide (review only), environment (code only), coordination, report format. The script handles all boilerplate automatically — you only own the task file. Missing ANY = do not spawn
5. Match agent type to task: REVIEW → code-reviewer, security-reviewer, backend-architect. CODE → language-pro, debugger. **Git/history analysis** (blame, log, diff, tracing fixes through commits) → `debugger` or `research-analyst`
6. **WRITABLE FILES:** Code agents: task file MUST list the exact source files/directories the agent may modify. Review/audit/research agents: omit WRITABLE FILES entirely — the script auto-injects the correct report path and marks all source files as read-only. For implementation agents, the task MUST also instruct them to write an Intent section in their report before coding: a description of their understanding of the task and their intended approach, in their own words, at whatever level of detail they think is useful for the reviewer. The agent decides what to communicate — architectural reasoning, assumptions about the codebase, trade-offs considered, alternatives rejected, or anything else that helps someone else understand why they built what they built. This is the first thing they write, before any code.
Describe problems and desired behavior — do NOT paste exact fix code unless precision is critical (regex, API signatures, security logic). Name agents with stage prefix: `s1-researcher`, `s2-impl-auth`.

#### Execution

1. Spawn current batch of agents via `spawn-glm.sh`, respecting the per-batch limit from Tools and the dependency analysis above. If stdout is empty (Windows `.cmd` issue), read `tmp/{NAME}-status.txt` to get PID. Checkpoint with PIDs and names. If stage has multiple batches, wait for current batch to finish before spawning next
2. Do verification prep: read the extraction agent's output, create adversarial task files per batch, assemble prompts
3. `wait-glm.sh name1:$PID1 name2:$PID2 ...` — first progress at 30s, then every 60s, STALLED warnings, health check on finish
4. **Review output.** Check operational status only — was the report produced? Is the log non-empty? Any STALLED markers? This is NOT quality review (do NOT evaluate findings, accuracy, or correctness). If ANY agent shows STALLED / EMPTY LOG / MISSING REPORT / EMPTY REPORT:
    - Diagnose root cause. Fix the issue (environment, prompt, task file, dependencies).
    - Re-spawn the agent with corrected configuration.
    - Do NOT proceed to the next stage with incomplete stage output.
    - Accept a gap and proceed ONLY for trivial gaps in discovery stages (e.g. a single agent in a full-capacity discovery stage failed after 3 respawn attempts with different approaches, AND its domain is partially covered by other agents). Every such decision must be explicitly justified in `tmp/glm-plan.md` with `STAGE GAP ACCEPTED: [domain] [reason] [coverage from other agents]`. Do NOT accept gaps in implementation or fix stages — those stages must produce complete, correct output. Do NOT silently skip failed agents.

#### Verification

Verification uses the adversarial verification pipeline. The lead does NOT manually verify findings — that's the agents' job. ALL findings extracted by Batch 0 must go through adversarial verification — severity filtering happens AFTER falsification, never before. The pipeline runs in three batches with sequential dependencies:

**Batch 0: Extraction agent** (1 agent). Reads all reports from the stage, extracts every finding with file:line and severity, deduplicates (same file:line + same issue → merge, note both sources), and splits into batches of 5-8 findings grouped by domain. Output: structured finding batches in `tmp/sN-extract-report.md`. The lead creates one adversarial task file per batch from this output.

**Batch 1: Adversarial falsification** (1 agent per batch). One agent per finding batch. Each agent tries to FALSIFY every finding in their batch: read cited code, exhaustively search for counter-evidence (guards, validation, framework protections, type system invariants, test coverage), label each SURVIVED / FALSIFIED / WEAKENED with evidence. If extraction produces more batches than fit in the per-batch limit (3), run adversarial in multiple sequential batches — do NOT merge extraction batches.

**Batch 2: Merge agent** (1 agent). Reads all adversarial reports. Produces the final verified checklist: SURVIVED → VERIFIED (fix list), FALSIFIED → REJECTED (dropped), WEAKENED → severity downgraded (fix list at lower priority). The lead writes `tmp/stage-N-synthesis.md` from this checklist for PRIOR CONTEXT in the next stage.

**If the merge agent's checklist shows zero VERIFIED findings at MEDIUM or above** (all MEDIUM+ findings were REJECTED, all were DROPPED, or only LOW-severity survivors remain), Stage 3 (Fixes) is SKIPPED — there is nothing significant to fix. The downstream dependency chain makes Stages 4 and 5 also SKIPPED. LOW verified findings are acknowledged in the synthesis as non-blocking. The lead writes the synthesis with `Stage 3 SKIPPED: Zero MEDIUM+ verified findings — nothing to fix.` This is mechanical — no lead judgment.

**Adversarial verification is MANDATORY** after every discovery, review, audit, and post-production review stage that produces code-referencing findings with file:line references. ALL findings extracted by Batch 0 must go through adversarial verification — severity filtering happens AFTER falsification, not before. Exception: stages producing findings without code-level references (web research, pure analysis, documentation reviews) or trivial context-gathering stages with no findings to verify — lead may mark adversarial verification as SKIPPED with explicit justification.

**Adversarial verification naming convention:**
- Extraction: `sN-extract`
- Adversarial falsification: `sN-adv-{domain}`
- Merge: `sN-merge`

**Fix and iterate:** ALL verified findings are fixed via fix-agents split by domain — the lead does NOT fix findings directly, regardless of how few or how trivial. Every fix MUST be followed by a post-production review. Every review MUST be followed by adversarial verification — review findings are not deliverable until they've been falsified. The review → fix → re-review loop iterates until the reviewer produces no new findings — this convergence is the final gate.

#### Between Stages

1. Write `tmp/stage-N-synthesis.md` — verified results from the merge agent's checklist, decisions, context for next stage
2. If scope changed from original plan, update `tmp/glm-plan.md` with actual stages and revised goals
3. Checkpoint. Clean up: `rm -f tmp/sN-*-prompt.txt tmp/sN-*-task.txt`
4. Next stage prompts include synthesis as `PRIOR CONTEXT:` section. PRIOR CONTEXT should contain only factual project context the next stage needs: what was discovered, what was decided, what constraints exist, what was already fixed. Do NOT include verification process details, rejected findings, or behavioral instructions — these compete with the agent .md. Target under 50 lines
5. Never re-do verified work unless evidence shows it was wrong
6. Never skip a planned stage without explicitly marking it in `tmp/glm-plan.md` as `SKIPPED` with a reason. A stage is only complete when its agents have been spawned, waited, their reports processed by the adversarial verification pipeline, and findings verified — incomplete stages cannot be proceeded past, outside the narrow gap-acceptance rules in Execution step 4. MANDATORY stages cannot be SKIPPED for speed or token savings — only for genuine blockers (environment failure, missing files, corrupted state).
7. After writing synthesis, read `tmp/glm-plan.md` to confirm the next stage. If the plan has remaining stages, execute them — do not deliver early unless remaining stages are explicitly marked SKIPPED.

**Iterative stages:** Between iterations, follow the Iterative Convergence protocol below — skip steps 1-5 until convergence is reached. On convergence, write final stage synthesis (step 1) and resume normal between-stages flow (steps 2-5).

#### Iterative Convergence

Some stages benefit from repeated runs until agents stop producing new meaningful output. What counts as "new output" depends on the stage purpose — new problems (audit), new information (research), new improvements (analysis), new risks (security), etc.

Convergence is mechanical: when ALL agents in an iteration produce zero new findings (empty reports, no new issues found), the stage has converged. A single non-empty report means the iteration produced output — iterate again. The lead does not subjectively judge whether findings are "meaningful enough" — any finding is meaningful.

**When mandatory:** ALL discovery stages (review, audit, research, analysis, post-production review). Data from production workflows shows ~30% of verified findings are unique to a single agent even when re-running the same agent — every iteration adds coverage. Skipping convergence on discovery leaves findings on the table.

**Not used for:** Production stages (implementation, fixing), verification. These produce or evaluate output rather than discovering issues.

**Mechanics:**
1. Each iteration = full prepare → spawn → verify cycle
2. After verification: check reports mechanically — any non-empty finding list in any agent report? 
    - **Yes** (any finding produced) → write iteration synthesis to `tmp/stage-N-iter-K-synthesis.md`, prepare next iteration with cumulative context from all prior iterations
    - **No** (all reports empty, zero findings) → convergence reached; write final stage synthesis and move on
3. Lead SHOULD vary approach between iterations — different agents, focus areas, or angles — to avoid blind spots. Running identical agents repeatedly is wasteful.
4. Lead can adjust agent count and type between iterations based on what prior iterations revealed
5. Lead sets max iterations per stage (default 2, use 3 for high-stakes audits). If cap hit without convergence → synthesize what's known, note "convergence not reached" in delivery, proceed
6. **Mandatory convergence is mechanical, not discretionary.** Mandatory iterative stages CANNOT be declared converged after a non-empty iteration regardless of lead assessment. An iteration that produces ANY actionable finding is not empty — fix the issue, then run the next iteration. A single empty iteration satisfies convergence.
7. **Naming:** iteration agents follow `s{N}i{K}-name` — e.g. `s2i1-reviewer`, `s2i2-researcher` (stage 2, iteration 1/2). Respawn within iteration: `s2i1-reviewer-r2`

#### Delivery

**Before delivery:** Read `tmp/glm-plan.md`. Confirm every planned stage is complete or explicitly marked SKIPPED with justification. A stage silently skipped = not delivered yet. Execute it or update the plan. If any code was changed during the fix stage — by fix-agents — confirm that post-fix review (Stage 4) and adversarial verification (Stage 5) both ran over those changes. Code changes without downstream verification are not deliverable. The user's task instructions (commit, push, report) are the final step after all stages complete — they do not override the mandatory stages that must run first.

After final stage:
- **Reviews/audits:** write report to `tmp/` with verified findings, rejected items, gaps
- **Code changes:** spawn a single agent to run build + tests, fix all failures, and deliver production-ready result. Lead chooses the exact agent for the job (e.g. debugger, build-error-resolver, cpp-pro). This is the final production gate.
- **Research/analysis:** synthesize into clear summary
- Write `tmp/session-summary.md`: task goal, stages executed, total agents, agent aborts/failures, iterations per iterative stage, verification stats, key decisions, phase durations (planning, preparation, execution/wait, verification, synthesis)
- Cleanup: `rm -f tmp/s[0-9]*-prompt.txt tmp/s[0-9]*-task.txt`. Keep logs, reports, summary
- Save workflow lessons to knowledge if applicable

### Agent Prompt Template

Prompt = full agent `.md` + task-specific sections + boilerplate from templates:

```
You are an AI agent named {NAME}.

You are a single agent working solo. Do all the work yourself — do not spawn sub-agents, do not delegate to other agents, do not run agentic workflows. Agentic workflows are not allowed in this session.

Before claiming something is missing or broken — grep for existing guards, handlers, or implementations first.

{Full .opencode/agents/{agent}.md — see Prompts rule}

--- TASK ASSIGNMENT ---

PROJECT: {working directory and project description}

ENVIRONMENT (code tasks only):
{Runtime, test command, lint command}

PRIOR CONTEXT (stage 2+ or iteration 2+):
{Contents of tmp/stage-N-synthesis.md OR cumulative tmp/stage-N-iter-*-synthesis.md for iterations}

YOUR TASK: {KEY FILES, CONTEXT, SCOPE, MUST ANSWER questions}

WRITABLE FILES: {code agents only — list source files agent may edit. Review/research/audit agents: omit this section}

{cat .opencode/templates/coordination-review.txt OR coordination-code.txt — replace {NAME}}

{cat .opencode/templates/severity-guide.txt — REVIEW/audit tasks only}

{cat .opencode/templates/quality-rules-review.txt OR quality-rules-code.txt}
```

| Task Type | Coordination | Severity Guide | Quality Rules |
|-----------|--------------|----------------|---------------|
| Review/audit | coordination-review.txt | severity-guide.txt | quality-rules-review.txt |
| Code/refactor | coordination-code.txt | — | quality-rules-code.txt |
| Research | coordination-review.txt | — | quality-rules-review.txt |

Boilerplate templates live in `.opencode/templates/`. Lead only writes the unique parts (agent .md selection + TASK ASSIGNMENT). Templates are `cat`-ed into the prompt file verbatim.

### Checkpoints & Recovery

**Save after every step — no exceptions.** One active checkpoint (delete previous first). Under 500 chars.

```bash
./.opencode/tools/memory.sh session add context "CHECKPOINT: [task] | DONE: [steps] | NEXT: [remaining] | FILES: [key files] | BUILD/TEST: [commands]"
```

**Compaction recovery — MANDATORY sequence (do ALL steps, no skipping):**
1. Run `.opencode/tools/glm-recover.sh` — prints memory session, plan, continuation (if any), newest synthesis (iter or stage, by mtime), and latest checklist in one stream. Replaces steps 1, 3, 4 below with a single command
2. **Re-read AGENTS.md in full and STRICTLY follow its instructions** — ALWAYS, no exceptions, no partial reads. `glm-recover.sh` does NOT do this for you
3. Only then resume work

If `glm-recover.sh` is unavailable, fall back to the manual sequence:
1. `./.opencode/tools/memory.sh session show` — restore session state
2. Read `tmp/glm-plan.md` — restore current plan
3. Read the latest `tmp/sN-merge-report.md`, `tmp/stage-N-iter-K-synthesis.md`, or `tmp/stage-N-synthesis.md` — restore verification/iteration/stage state

Do not rely on continuation summary alone. Do not skip the AGENTS.md re-read — this is the #1 cause of workflow deviation after compaction.

| Checkpoint | Recovery |
|-----------|----------|
| Plan done | Read `tmp/glm-plan.md` → prepare agents |
| Agents prepared | List prompts → spawn |
| Agents spawned | Check PIDs/reports → verify or re-wait |
| Verifying stage N | Read merge agent report at `tmp/sN-merge-report.md` → review final checklist |
| Iterating stage N, iter K | Read `tmp/stage-N-iter-K-synthesis.md` + cumulative context → prepare next iteration |
| Stage N done | Read synthesis + plan → next stage |

### Session Continuation

For tasks exceeding a single session:

1. Complete current stage fully
2. Write `tmp/glm-continuation.md`: original task, plan, completed stages, next stage, decisions, modified files, blockers
3. `./.opencode/tools/memory.sh add context "GLM-CONTINUATION: [summary]" --tags glm-opencode,continuation`
4. Tell user what's done and what continues

**Pickup:** `./.opencode/tools/memory.sh search "GLM-CONTINUATION"` → read continuation file → read prior synthesis → continue next stage. On final stage, clean up continuation file and memory entry. Never re-do verified prior work.

### Error Handling

| Scenario | Action |
|----------|--------|
| No report after exit | Read log to diagnose failure. Fix root cause (bad prompt? missing dependency? environment?). Re-spawn the agent. Do NOT fill gaps yourself — filling gaps is agent work. |
| STALLED (flagged by wait-glm.sh) | Kill process, read log to diagnose. Fix root cause. Re-spawn. Do NOT note gap and proceed. |
| Agent claims success but output wrong | Diagnose why output is wrong (bad prompt? misunderstood task?). Fix the prompt/task. Re-spawn the agent. Do NOT verify or fix the output yourself. |
| Incorrect edits | Diagnose why the agent produced wrong output (bad prompt? misunderstood task?). Fix the prompt/task. Spawn a fix-agent to revert and rewrite. Do NOT revert changes yourself. If the fix-agent is still wrong, spawn another (up to 3 attempts). |
| 2+ agents fail same env error | STOP respawning. Diagnose environment first (do NOT fix environment issues directly — spawn an agent if changes needed) |
| Agent aborted (same error 3×) | Read log to diagnose root cause, fix environment/config (spawn an agent if code/config changes needed), then respawn |
| Stage partially failed (1+ agents produced no useful output or wrong output) | Diagnose root causes across all failed agents. Fix issues (environment, prompts, tasks). Re-spawn ALL failed agents. The stage is incomplete until all agents succeed. Do NOT proceed to the next stage with gaps. |
| Iteration cap hit without convergence | Synthesize all iterations, note "convergence not reached" in delivery, proceed |
| Adversarial verification produces high REJECTION rate (>50% findings falsified) | Adversarial prompts or finding quality may need tuning. Re-run with adjusted focus areas or different MUST ANSWER questions. Do NOT revert to manual per-finding verification |

### Rules

**Quality over speed — ALWAYS.** Never rush, never cut corners, never try to finish faster. Slow, thorough, methodical work produces quality. Speed produces bugs. Prefer more stages, more agents, more verification over shorter timelines. There is no deadline. The only measure of success is production-ready, bug-free code.

**Limits:** Per-batch limit defined in Tools — don't restate. Need more coverage? Add stages, not agents. Agents run until done (no turn limit). One task per agent. Respawn naming: `-r2`, `-r3`. No two agents edit same file within a stage (read overlap OK). Balance workload — each agent should cover roughly equal scope.

**Task tool prohibition (MANDATORY — single most important rule):** Agent delegation in this project happens ONLY via `spawn-glm.sh`. The `Task` tool with its `subagent_type` parameter is FORBIDDEN — never call it, regardless of the use case (exploration, code review, implementation, research, anything).

The Task tool's built-in `subagent_type` list happens to share names with our agent `.md` files in `.opencode/agents/` (`code-reviewer`, `ios-pro`, `swift-pro`, etc.) — these are TWO DIFFERENT THINGS. The Task tool ships a separate sub-agent runtime that bypasses our review pipeline, the `spawn-glm.sh` flow, verification, report formats, and quality rules. Our agent `.md` files are reached ONLY by passing `-a AGENT_NAME` to `assemble-prompt.sh` and then spawning via `spawn-glm.sh`.

If you catch yourself about to call `Task(subagent_type=...)` — stop, use `spawn-glm.sh` instead.

**Agent count per stage (MANDATORY — fill capacity by task decomposition):** Decompose the task into as many independent subtasks as it naturally splits into, spawn one agent per subtask, up to 3 agents per batch. Default to what the task genuinely requires — scale to scope, not the ceiling. Fill all 3 slots only when the task naturally decomposes into that many distinct subtasks. Verification stages scale with findings count and impact surface, not discovery agent count — minimum 1 extraction agent for every stage; falsification runs only if extraction finds at least one finding to falsify. When in doubt, prefer more agents over fewer — broader coverage finds more issues, but over-engineering degrades quality.

**Prompts:** Include the FULL agent `.md` file — agents are optimized and every section earns its place. Do NOT trim or skip sections. Boilerplate (quality rules, severity guide, coordination, report format) comes from `.opencode/templates/` and is appended after the agent .md. Agents don't load AGENTS.md — all context must be in prompt.

**Verification:** Every finding labeled. Every label backed by Read. 100% complete before proceeding. ALL verified actionable findings fixed via fix-agent — the lead does not fix findings directly.

**Lead code prohibition (MANDATORY):** The lead never writes, edits, or modifies project source code. Every code change — implementation, bug fixes, config adjustments, script changes, one-liners — goes through a spawned agent. The lead's tools (Edit, Write) are for tmp/ artifacts only: task files, prompts, synthesis reports. The only exception is editing AGENTS.md itself (meta-configuration).

**Platform:** `opencode` on all platforms (spawn-glm.sh handles invocation). Always redirect output to log files.

---

## Skills (Workflows)

Workflows can be defined as skills in `.opencode/skills/` directory. Use `/skill-name` to invoke. Skills are project-specific — define them as needed for your workflow.
