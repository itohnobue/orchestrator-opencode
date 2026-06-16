## Temporary Files

You can use the `tmp/` subfolder in the current project folder to save any temporary files if needed.
This is useful for storing intermediate results, reports, or data during multi-step workflows.

---

## Agents

110+ specialized AI agents for OpenCode. Agents are stored in `.opencode/agents/` as Markdown files with YAML frontmatter.

**Discovery:** Do FULL read of `.opencode/agents/INDEX.md` for the full categorized agent directory (110+ agents grouped by domain). Pick the MOST specialized agent — domain-specific checklists and anti-patterns only work when the agent matches the domain.

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
| Specialized | 22 | build-engineer, cli-developer, product-manager, web-searcher, etc. |

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

Checkpoints are session-context entries written after every workflow step. Full protocol — when to checkpoint, format, and compaction recovery sequence — is in Orchestration Workflow → Checkpoints & Recovery.

### Multi-Session

Multiple CLI instances work without conflicts. Resolution: `-S` flag > `MEMORY_SESSION` env > `.opencode/current_session` file > `"default"`.

```bash
./.opencode/tools/memory.sh session use feature-auth        # Switch session
./.opencode/tools/memory.sh -S other session add todo "..." # One-off
./.opencode/tools/memory.sh session sessions                # List all
```

---

## Web Research

For any internet search or web content retrieval:

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

## Orchestration Workflow

Dynamic orchestration where the lead delegates everything to specialized agents. The planner researches the project, classifies the task, and dynamically assembles a custom workflow from available bricks — selecting only the stages the task actually needs. The lead spawns agents according to the manifest, coordinates verification, and delivers results. **Automatic by default.**

The ONLY agent-delegation pipeline is `assemble-prompt.sh` → `spawn-glm.sh` → `wait-glm.sh`. The `Task` tool's `subagent_type` parameter is forbidden — see Rules → Task tool prohibition for the full statement.

### Agent Loading Rules

Agents folder: `.opencode/agents/`. Use agents for all non-trivial subtasks — code writing, analysis, design, debugging, testing, documentation.

**Rules:**
- Before any subtask: select the best agent and read its `.md` file (always fresh re-read)
- Load ONE agent at a time (Exception: Orchestration Workflow may read multiple for prompt building)
- All agent delegation goes through `spawn-glm.sh` — see Rules → Task tool prohibition
- Agent instructions are TEMPORARY — apply to current subtask only, discard after

**Discovery:** Glob `.opencode/agents/*.md` to list, Grep by keyword. Prefer specialized over general agents.

**How the lead uses agents:** The lead selects agents by name from the INDEX, writes task files with KEY FILES and MUST ANSWER questions, and uses `assemble-prompt.sh` to inject the agent's `.md` into the spawned agent's prompt. The lead does NOT load agent `.md` content into its own working context and never applies agent instructions itself. The agent `.md` is read for agent selection (which specialist?), not for the lead to execute. Agent `.md` files reach agents exclusively through `assemble-prompt.sh` → `spawn-glm.sh`.

### Request Workflow

1. **Continuation:** `./.opencode/tools/memory.sh search "GLM-CONTINUATION"` — resume if exists
   - **If found:** Read `tmp/glm-continuation.md`, read prior synthesis, and continue from where the previous session left off. The plan is already finalized and partially executed — pick up at the next uncompleted stage.
   - **If not found:** Proceed to step 2.
2. **Re-read Verification and Iterative Convergence sections:** Before spawning ANY stage agents, re-read the Verification section AND Iterative Convergence section in full. Verification defines the severity-routed pipeline (extraction → route findings by severity → synthesis). Iterative Convergence defines planner-decided repeat logic (NONE/ONCE/LOOP). Skipping these re-reads is the #1 cause of plans missing appropriate verification and convergence. MANDATORY.

   **Do NOT read source files, skim the project, or try to understand scope before spawning.** The planner is your research — spawn it immediately. Fill in the project path, spawn, and let the planner do everything else. Any attempt to "understand the codebase first" IS the research we forbid. Go directly to step 3.

3. **Planning phase (2 batches, 2 agents) — ALWAYS run, never skipped:**
   a. **Initial planner:** Copy `.opencode/templates/planner-task-template.txt`, fill in the project path (just the working directory — the planner researches the codebase itself), assemble with `assemble-prompt.sh -a agentic-planner -t research -n s0-planner`, spawn (no `-m`, uses default model). Researches the project, classifies the task on 5 axes (size, domains, ambiguity, severity, type), selects bricks from the palette, and produces a custom workflow manifest to `tmp/glm-plan.md`.
   b. **Mandatory plan review (ALL plans):** Create a review task targeting `tmp/glm-plan.md` with MUST ANSWER questions covering brick selection, severity classification, agent assignment, verification placement, convergence decisions, volume splitting, and dependency analysis. Include `WRITABLE FILES: tmp/glm-plan.md` in the task file. Assemble with `assemble-prompt.sh -a agent-organizer -t review -n s0-organize`, spawn (no `-m`, default model). The agent-organizer reviews the plan using its dual analytical framework:

      *Workflow quality (native anti-patterns):* Check for over-staffing, wrong agent assignments, redundant agents, vague delegations, ignored dependencies, and stale agent references. Its anti-patterns list is a ready-made plan review checklist.

      *Structural validation (embedded rules in task):* Verify every DISCOVER/REVIEW stage has a corresponding VERIFY. Verify IMPLEMENT stages have a corresponding REVIEW. Verify MEDIUM+ severity tasks have second opinions in ALL DISCOVER and REVIEW stages, including CONVERGE iterations. Verify FIX stages include post-fix REVIEW. Verify cross-domain integration review only runs when genuinely different specialists are at integration boundaries. Verify domain breadth counts specialists, not packages. Verify volume splitting: check the planner's stated file/LOC counts per domain — if any domain exceeds ~50 files / 15K LOC, the plan must have agents split into sub-groups. Flag miscounts or over-large single-agent scopes.

      After review, the organizer applies all fixes directly to `tmp/glm-plan.md`. Its report documents what was changed and why. The organizer's output IS the final plan — no separate merge agent is needed. This runs on EVERY plan — a bad plan poisons everything downstream regardless of severity.
4. **Review final plan:** Read `tmp/glm-plan.md`, confirm classification, brick selection, and stage structure are sound. If gaps remain, spawn a quick-fix agent to correct the plan.
5. **Decompose:** List subtasks from the plan, map each to best agent, report to user

**CRITICAL — Plan Display Rule:** After the planning phase completes and before spawning ANY stage agent, you MUST output the full stage plan as text to the user — see Workflow → Planning for the format. Writing the plan to `tmp/glm-plan.md` does NOT replace showing it. Display first, then proceed.

### Subtask Workflow

The lead's role in each subtask:
1. Select the best agent, read its `.md`, prepare the task file using the planner's KEY FILES and MUST ANSWER questions from the manifest
2. Assemble the prompt via `assemble-prompt.sh`, spawn the agent via `spawn-glm.sh`
3. Wait for completion, check operational status (was the report produced? no STALLED/EMPTY/MISSING?)
4. Delegate ALL substantive verification to the verification pipeline — the lead never evaluates output quality, judges findings, or assesses results
5. Save non-trivial discoveries to knowledge
6. Discard agent instructions, move to next subtask

**Mid-execution research:** When something is unclear during workflow execution (scope ambiguity, technical approach, a specific question the plan didn't cover), the lead may spawn a single unplanned agent using the default model to research that question. The lead chooses the exact agent for the job (e.g. `debugger`, `research-analyst`), prepares a prompt with the specific question and MUST ANSWER directives, and spawns via `spawn-glm.sh`. Use the agent's report to clarify the next action. This is an ad-hoc clarifying agent — NOT a replacement for the planner pipeline, not a way to re-do planning, not a substitute for discovery stages. Limit to one agent per question. Do NOT use this to research things the lead could discover by reading source code — the lead does not read source code.

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

When a task has multiple independent angles (multi-file refactor, audit + test review, etc.), spawn as many agents as the task naturally decomposes into — spawn only what the work requires — all in parallel within a SINGLE stage. Sequential stages are ONLY correct when the next stage actually consumes the previous stage's verified output. **Default: fan out within a stage; sequence only when there's a real dependency.** More coverage finds more issues — fan-out (parallel agents) and convergence iterations are both ways to add coverage.

### Lead Role

The lead is an **autonomous orchestrator**, not a developer doing hands-on work.

**Does:** delegate planning to the agentic-planner pipeline, review manifest, decompose, execute workflow stages from the manifest, write agent prompts, spawn agents, delegate verification according to manifest (adversarial verification for CRITICAL/HIGH, single-agent review for MEDIUM), spawn fix-agents and quick-fix agents, synthesize, deliver.

**Does not:** run the full test suite, do comprehensive audits unprompted, write, edit, or modify ANY project source code (even a single line), do any codebase research (reading source files, skimming files, tracing logic, discovering project structure), or design workflows from scratch (that's the planner's job). These are agent work.

**Lead success metrics:**
- **Success:** Decomposable subtasks went to specialists. Your context stayed clean for coordination. Findings were verified.
- **Failure:** You did any implementation work an agent should have done (writing, editing, or modifying code). You read raw domain data that would have been better isolated in a specialist's context. You produced analysis without verification.

**Self-check rules (MANDATORY) — run before working on ANY subtask:**
- The lead NEVER writes, edits, or modifies any project source file. The Edit and Write tools are for task files, prompts, and synthesis reports in tmp/ only. Any code change — even a single-line fix, a config tweak, or a build script adjustment — must go through a spawned agent.
- Heavy Read/Grep usage for verification coordination is expected and allowed (reading agent reports, building task files from synthesis output). For anything resembling planning or codebase research — never. Delegate to the planner pipeline immediately. Reading source files to understand the codebase is planner-agent work, not lead work.
- If a specialized agent in `.opencode/agents/INDEX.md` matches the subtask domain → **SPAWN it.** Don't reproduce its work yourself
- If the subtask requires writing code, running test suites, or deep analysis across many files → that's agent work. Delegate it via `spawn-glm.sh` (see Rules → Task tool prohibition for the absolute rule)

**Rule compliance — the lead NEVER:**
- Reclassifies or downgrades an agent's severity finding to avoid running a mandatory verification stage. The reviewer's filed severity is authoritative.
- Substitutes judgment for a mechanical trigger. "When X, do Y" means exactly that — the lead does not override with "X is true but Y seems unnecessary."
- Resolves ambiguity in workflow rules by choosing the interpretation that avoids work. When a term has multiple readings, the lead applies the reading that preserves verification and quality gates, not the one that saves agents.

**Verification vs implementation boundary:**
- Verification (lead delegates): After stage agents complete, spawn the verification pipeline:

1. **Extraction agent** (single, default model): Reads all reports from the stage, deduplicates findings (same file:line + same issue → merge, note source), classifies each finding by severity, splits into batches grouped by domain and severity. When the originating stage (DISCOVERY or REVIEW) used a second opinion agent, tag each finding as "both-found" (both agents reported independently) or "single-found" (one agent only). Both-found carries higher initial confidence — surface this in synthesis. Findings from documentation specialist agents (documentation-pro) are domain-verified — route them directly to synthesis at the agent's rated severity, skipping adversarial/review verification. If extraction finds 0 findings, VERIFY early-exits — nothing to verify, skip all subsequent batches.

    **Mechanical trigger — MANDATORY:** If extraction finds any finding at MEDIUM severity or above, the lead MUST spawn the full verification pipeline (adversarial/review agents → synthesis agent). The lead does NOT pre-judge findings, skip verification steps, or decide which findings "don't matter." Only the synthesis grid determines FIX=SKIPPED. The synthesis agent is part of the pipeline — it MUST run after all routing agents complete, even if every routed finding was REJECTED or WEAKENED. The lead does NOT evaluate routing agent outputs to decide whether synthesis is needed. Proceeding to the next stage without completing all verification steps is a protocol violation.

2. **Findings routed by severity** (single-source routing):

   - **CRITICAL/HIGH findings** → Adversarial agent (single agent per batch of 5-8 findings, default model; use `adversarial-reviewer` agent `.md`). The adversarial agent tries to FALSIFY every finding in its batch: reads cited code with full surrounding context (minimum 30 lines), exhaustively searches for counter-evidence at every level (same function guards, caller-level validation, framework-level protections — middleware, decorators, interceptors, global error handlers, type system invariants, test coverage), and labels each finding with evidence:

     * **CONFIRMED** — exhaustive search found NO counter-evidence. Describe what patterns were searched, which grep commands were run, why nothing was found.
     * **REJECTED** — found CLEAR counter-evidence that disproves the claim. Paste exact code with file:line.
     * **WEAKENED** — partial counter-evidence reduces severity or scope but doesn't fully disprove. State the correct severity.

     The adversarial agent assumes the claimed issue is a misunderstanding and searches exhaustively before confirming. For "missing X" findings, searching for X and finding it in no reachable code path IS valid evidence — document all searched locations. Every CONFIRMED label must be hard-won — superficial grep is not exhaustive. Surviving findings become ADVERSARIALLY VERIFIED.

- **CRITICAL/HIGH findings from cross-domain integration review** → Adversarial cross-domain agent (single agent per batch, default model). Same exhaustive falsification but verifies from BOTH sides of the integration boundary (Domain A producer + Domain B consumer + bridge between them). Finding only survives if no counter-evidence on either side or in the bridge.

   - **MEDIUM findings** → Review agent (single agent per batch of 8-12 findings, default model; use `code-reviewer` agent `.md`). Reads cited code, assesses validity of each finding against the same severity standards, labels each CONFIRMED / REJECTED / WEAKENED. Still requires evidence for every label — grep for guards before claiming something is missing, verify assertions against actual code. Mandatory: every finding MUST include file:line, code snippet, and grep evidence.

   - **LOW findings** → NOTED. Recorded in the report. No further agent spend.

3. **Synthesis agent** (single, default model): Reads all adjudication verdicts. Builds a unified verification grid:

   | CONFIRMED | REJECTED | WEAKENED |
   |-----------|----------|----------|
   | → fix list | → dropped | severity downgraded → fix list at lower priority |

   Surfaces "both-found" confidence signals from extraction — findings reported by both primary and second opinion agents carry higher initial confidence.

   If the synthesis grid shows zero CONFIRMED findings at MEDIUM or above (all MEDIUM+ findings were REJECTED, or only LOW-severity survivors remain), FIX is SKIPPED — there is nothing significant to fix. LOW verified findings are acknowledged in the synthesis as non-blocking. The lead writes the synthesis with `FIX SKIPPED: Zero MEDIUM+ verified findings — nothing to fix.` This is mechanical — no lead judgment.

Lead coordinates batches, never investigates findings manually, and writes the final synthesis from the synthesis agent's grid.
- Implementation (agent does): Writing/editing code, running test suites, fixing bugs, adding tests, refactoring
- After the verified checklist is produced, if many fixes are needed across many files: collect them into a fix-agent prompt and spawn

**Quick-fix agents:** For two specific scenarios — (1) agent output needs minor finishing, (2) reverting incorrect edits — spawn a single quick-fix agent using the default model. Lead chooses the exact agent for the job. No verification pipeline — this is a quick, informal fix. If the fix is wrong, escalate immediately to a full IMPLEMENT → REVIEW → VERIFY cycle for that component. No direct work — the lead never edits project code. Quick-fix agents are the only exception to "every review must be verified."

**Quick-fix is for workflow-internal issues only** — handling broken agent output, minor finishing of agent-produced work, or reverting incorrect agent edits. Quick-fix agents are NOT a substitute for running the full workflow. For any task, no matter how small, the planner pipeline must run first. Quick-fix operates inside an existing workflow — never as a standalone replacement for planning, review, or verification.

**Workflow autonomy:** The lead runs the workflow to completion without waiting for user approval. The planner agent designs the initial workflow (stages, agents, verification placement); the lead reviews, adapts, and refines it — adding or modifying non-PLAN stages as understanding deepens during execution. Each stage follows the prepare → spawn → verify cycle. A stage is complete ONLY when ALL its agents have produced their expected output. A stage with failed or missing agents is incomplete — diagnose failures, fix root causes, re-spawn. Proceeding to the next stage with an incomplete current stage — outside the narrow gap-acceptance rules in Execution step 4 — is a protocol violation. The lead has full authority to adapt non-PLAN parts of the plan mid-execution. PLAN stages (2-agent planning pipeline) cannot be removed. DISCOVER, IMPLEMENT, REVIEW, FIX, and TEST stages may be SKIPPED only when the planner's manifest explicitly marks them as NONE for the given task severity — never for speed or convenience. VERIFY is skipped when extraction finds 0 findings or when the lead may mark it as SKIPPED for non-code-level findings. Prior workflow runs do not excuse skipping — every code change requires fresh verification regardless of what previous sessions found.

### Tools

**Maximum 10 agents per parallel batch within a stage.** A stage that has independent subtasks SHOULD use as many parallel agents as the task naturally decomposes into — spawn only what the work requires. Scale to scope: over-engineering with unnecessary agents degrades quality. When a stage genuinely needs more than 10 independent subtasks, split into sequential sub-batches within the stage. Single-agent stages are normal for tightly-scoped work and are only "the exception" when a task genuinely splits into more subtasks. Each agent is an independent unit; a stage is a parallel-batch boundary that may contain multiple agents. Implementation stages: a single agent writes code directly to original files, followed by a single review agent that reviews the result (see Agent Spawning). For multi-domain changes, one agent per domain writes in parallel.

**Spawn:**
```bash
.opencode/tools/spawn-glm.sh -n NAME -f PROMPT_FILE [-m MODEL]
```
`-m` is optional — when omitted, the agent uses opencode's configured default model. Use `-m MODEL` to override with a specific model. Returns `SPAWNED|name|pid|log_file`. Backgrounds immediately. Report: `tmp/{NAME}-report.md`, log: `tmp/{NAME}-log.txt`. Also writes to `tmp/{NAME}-status.txt` (reliable on Windows — stdout can be lost when parallel `.cmd` processes launch).

**Stage types and model usage** — all agents use the opencode default model unless overridden with `-m`. The `-m` flag is available for any stage type when a specific model is needed.

| Stage Type | Description |
|-----------|-------------|
| **Plan** (always runs) | Planner researches and produces the plan. Organizer (agent-organizer) reviews the plan, applies fixes, produces final plan. All use default model. |
| **Discovery** (review, research, audit, analysis) | Specialist agent with dedicated context focused on one domain. When a stage has independent subtasks (different files, modules, concerns), spawn one agent per subtask — as many as the task naturally decomposes into, maximum 10 in parallel. At MEDIUM+ severity: second opinion agent runs in parallel with complementary specialist `.md`. |
| **Implementation** (write code) | Single agent writes code directly to original files. For multi-domain changes, one agent per domain writes to respective files in parallel. |
| **Review** (after implementation or fix) | Reviews implementation or fix for bugs, quality, correctness. Every implementation and every fix MUST be followed by a review agent. At MEDIUM+ severity: second opinion agent runs in parallel with language specialist `.md`. |
| **Fixing** (fix verified findings) | Applies known fixes mechanically. Fix ALL confirmed findings from the synthesis grid. Every fix MUST be followed by a post-fix review agent. |
| **Adversarial verification** (falsification) | For CRITICAL/HIGH findings — exhaustive falsification: read cited code, search for counter-evidence at every level (same function, caller, framework, type system, tests). Label CONFIRMED / REJECTED / WEAKENED with evidence. Extraction and synthesis agents also default model. |
| **Review verification** (judgment) | For MEDIUM findings — reads cited code, assesses validity, labels CONFIRMED / REJECTED / WEAKENED. Same thoroughness standards but confirms/rejects without exhaustive falsification. |
| **Test** (build + test suite) | Runs build and test commands, fixes compilation/test failures, reports results. |
| **Quick-fix** (minor finishing, reverts) | Short, informal fix for workflow-internal issues — fixing broken agent output or reverting incorrect edits. Not a substitute for the planning pipeline. No verification. If wrong, escalate to full IMPLEMENT → REVIEW → VERIFY. |

**Wait:**
```bash
.opencode/tools/wait-glm.sh name1:$PID1 name2:$PID2 name3:$PID3
```
Blocks until all finish (Bash timeout: 600000). Do NOT use bare `wait` or `sleep` + poll loops. Prefer `name:pid` format — enables progress monitoring (first at 30s, then every 60s) and STALLED detection (0-byte log after 2min). Bare PIDs still work but skip log monitoring. If Bash times out before agents finish, re-invoke with same arguments — this is normal for long-running agents.

### Workflow

The planner designs the initial workflow, the lead reviews and adapts it. Typical flow: delegate to planner → review plan → for each stage in the manifest: prepare → spawn → wait → verify (severity-routed pipeline) → between stages → next stage. **Stages may be iterative (see Iterative Convergence).** The lead refines the plan and decides stage adjustments mid-execution.

#### Planning

**MANDATORY: Planner first, always.** The planning pipeline runs in full before any workflow begins. The lead does NOT research the codebase — the planner agent researches and produces the plan.

**Plan Display Rule:** After the planning phase completes and before spawning ANY stage agent, you MUST output the full stage plan as text to the user. Writing to `tmp/glm-plan.md` does NOT replace showing it. Display first, then proceed.

The lead's role in preparation:
0. If the user's request is vague, ask clarifying questions to narrow scope — but do NO codebase research. Clarifying the user's intent (what they want) is fine; reading source files (how to do it) is the planner's job.
1. Pass the user's request as-is and the current working directory to the planner — no summarization or research, the planner reads the codebase itself
2. Review the planner-generated manifest for classification accuracy, brick selection, severity justification, and agent assignments
3. If the manifest has discovered scope ambiguity, add discovery/research stages — these are agent work, not lead work. Never open source files to fill gaps yourself
4. Write well-scoped prompts using the manifest's context, KEY FILES, and MUST ANSWER questions (provided by the planner per stage). The lead may add 1-2 supplementary questions about workflow concerns (e.g., "Was the linter run?") but does not write code-level technical questions.
5. If the plan is insufficiently informed, re-run the planner with more specific questions or add a discovery stage. Under no circumstances does the lead read source files to research gaps directly

**Spawning research agents** (even iteratively to convergence) is encouraged when scope is unclear — thorough research almost always produces better results in later stages. Decompose into stages. **ALWAYS output the full plan to the user before spawning any agents:**

```
# DYNAMIC BRICK MANIFEST — planner selects bricks per task.
# No fixed skeleton. Each task gets a custom workflow.

Plan: [N stages, M total agents]

  Stage 0: Plan — 2 agents (planner + organizer)
    Classification: size=[], domains=[], ambiguity=[], severity=[], type=[]

  Stage 1: [Brick name] — [Variant] — N agents
    Justification: [why this brick, why this variant]
    Agent: [specialist name]
    Second Opinion: [agent name if MEDIUM+; "N/A (severity < MEDIUM)" otherwise]
    KEY FILES: [list]
    MUST ANSWER:
      1. [technical question from planner's codebase research]
      2. [...]
    ...

  Total agents: M
```

The planner selects from the following bricks. Skipped bricks are noted as `SKIPPED: [reason]`. **Do NOT wait for user approval — output the plan and proceed immediately.**

##### Brick Catalog

The planner assembles a custom workflow by selecting from these bricks. Each has variants. Not all bricks are needed for every task.

```
PLAN            Always FULL (2 agents: planner + organizer, both default model).
                No variants. Never skipped. Bad plan poisons everything downstream.
                Planner (agentic-planner) researches and produces the plan. Organizer (agent-organizer) reviews and fixes in-place — the organizer's output IS the final plan.

DISCOVER        Pre-change analysis — review/audit existing code before making changes.
├── NONE        Required for size=tiny — nothing to discover on changes this small.
│               Required for size=small when the planner traced the complete code
│               path and identified the exact fix location with file:line citations
│               — no open questions remain. Justify with specific research findings.
│               If the planner cannot state "Root cause at [file:line], fix is
│               [approach]" with concrete evidence, the NONE bar is not met.
├── SINGLE      1 agent per domain. Use for medium+ tasks, or small tasks
│               where open questions remain after planning research.
│               At MEDIUM+ severity: +1 second opinion agent per domain (parallel).
│               Default pair: domain specialist (primary) + code-reviewer (second opinion) — planner may override based on task context.
└── MULTI       N agents, one per domain. Split by specialist → volume.
                At MEDIUM+: each domain gets a second opinion agent.

IMPLEMENT       Write or modify code.
├── NONE        No code change (analysis-only, cosmetic-only).
├── SINGLE      1 agent per domain. Writes code directly to original files.
│               Standard for all code changes.
└── MULTI       N agents, one per domain. Split by specialist → volume.

                SINGLE for narrow single-domain changes; MULTI for changes
                spanning multiple specialists. Line count is not the measure —
                split by domain diversity, not file count.

REVIEW          Review code changes.
├── NONE        Skip: change type=cosmetic AND severity=none.
│               Or: IMPLEMENT=NONE.
├── SINGLE      1 agent per domain. Standard.
│               At MEDIUM+ severity: +1 second opinion agent per domain (parallel).
│               Default pair: code-reviewer (primary) + language specialist (second opinion) — planner may override based on task context.
│               When the task spans 2+ domains using DIFFERENT specialists,
│               the planner adds a cross-domain integration reviewer to the
│               REVIEW batch. This agent focuses ONLY on integration points:
│               API contracts, shared types, data flow between domains.
│               Do NOT re-review domain-internal logic — the domain reviewers
│               already cover that. Findings from cross-domain integration
│               review are routed through adversarial cross-verification.
└── MULTI       N agents, one per domain.

VERIFY          Verify findings from DISCOVER, REVIEW, or post-fix review.
                Always includes extraction (1 agent, default model). Tags findings
                "both-found"/"single-found" when originating stage had second opinion.
                Routes findings by severity:
                
                CRITICAL/HIGH → ADVERSARIAL AGENT (1 agent per batch of 5-8 findings)
                  Adversarial agent tries to FALSIFY every finding: reads cited code
                  with full surrounding context (minimum 30 lines), exhaustively
                  searches for counter-evidence at every level (same function guards,
                  caller-level validation, framework-level protections — middleware,
                  decorators, interceptors, global error handlers — type system
                  invariants, test coverage). Labels each CONFIRMED / REJECTED /
                  WEAKENED with evidence. For CONFIRMED: describe what patterns
                  were searched, which grep commands were run, why nothing was found.
                  For REJECTED: paste exact counter-evidence code with file:line.
                  For WEAKENED: paste partial counter-evidence AND explain what
                  portion of the original claim still stands.
                  Default position: assume the claimed issue is a misunderstanding and search exhaustively before confirming. For "missing X" findings, searching for X and finding it in no reachable code path IS valid evidence — document all searched locations. Findings that survive
                  exhaustive falsification become ADVERSARIALLY VERIFIED.
                
                CRITICAL/HIGH from cross-domain integration review → ADVERSARIAL CROSS AGENT
                  (1 agent per batch). Same exhaustive falsification but verifies
                  from BOTH sides of the integration boundary (Domain A producer +
                  Domain B consumer + bridge between them). Finding only survives
                  if no counter-evidence on either side or in the bridge.
                
                MEDIUM → REVIEW AGENT (1 agent per batch of 8-12 findings)
                  Reads cited code, assesses validity of each finding against
                  the same severity standards, labels CONFIRMED / REJECTED /
                  WEAKENED. Still requires evidence for every label — grep for
                  guards before claiming something is missing, verify assertions
                  against actual code. Mandatory: every finding MUST include
                  file:line, code snippet, and grep evidence.
                
                LOW → NOTED. Recorded in report. No further agent spend.
                
                After routing: SYNTHESIS (1 agent, default model) compiles all
                verdicts into unified grid. Surfaces "both-found" confidence signals.
                Unified vocabulary: CONFIRMED / REJECTED / WEAKENED.
                Also sanity-checks severity assignments against the severity
                classification criteria — if a finding's severity appears mismatched
                (e.g., "SQL injection" labeled MEDIUM), flag it as CHALLENGED.
                Challenged findings are re-routed through adversarial verification.
                Exception: documentation-domain challenged findings skip
                adversarial — documentation severity is inherently subjective
                (is "10 missing API docs" HIGH or MEDIUM?) and adversarial
                review of severity ratings adds no meaningful verification.
                Documentation-domain challenged findings stay at their
                challenged severity; the lead accepts the downgrade directly.
                Early-exit: 0 findings after extraction → skip synthesis.
                Always runs when DISCOVER, REVIEW, or post-fix review produced findings with code-level references.
                When CONFIRMED findings exist at MEDIUM+, FIX=DOMAINS must follow.

CONVERGE        Repeat DISCOVER or REVIEW for additional passes. Planner decides variant.
                Factors: ambiguity, codebase complexity, finding volume, production impact,
                change type, time sensitivity.
                NONE: One pass. For well-understood, narrow work. Also appropriate
                      for codebases with comprehensive test coverage (>80%) and
                      clean module boundaries — first pass is unlikely to miss
                      meaningful issues.
                ONCE: One extra iteration if first pass found anything. Use when
                      the planner's Phase 1 research reveals interconnected modules,
                      dense coupling, non-uniform code patterns, or >15K LOC per
                      domain — characteristics suggesting a first pass may miss
                      issues. Also used when severity is HIGH/CRITICAL regardless
                      of codebase quality (missed findings are expensive). ONCE is
                      NOT the universal default — well-tested, cleanly-structured
                      codebases should use NONE.
                LOOP: Up to 3 iterations, stop on empty report. For highly ambiguous
                      or production-critical work where missed findings would be
                      unacceptable.
                Iterations inherit ALL mandatory rules from the parent stage type
                (second opinions at MEDIUM+, DISCOVER/REVIEW → VERIFY pipeline, etc.).
                The planner must list all agents per iteration — the lead spawns
                whatever the plan lists.

FIX             Apply verified findings. Always 2-3 sequential stages — includes post-fix review.
                When DOMAINS: 1 fix agent per domain → post-fix REVIEW
                (same variant/domain split as the REVIEW stage), then VERIFY
                if any post-fix review report contains at least one finding at
                MEDIUM severity or above. A finding is any numbered item with a
                severity label and code reference (file:line, function, or block)
                in a reviewer's report. The lead does NOT re-classify, downgrade,
                or exclude findings — the reviewer's filed severity is authoritative.
                VERIFY is skipped ONLY when ALL post-fix review reports contain
                zero MEDIUM+ findings. Mechanical trigger, no judgment.
├── NONE        No verified findings.
└── DOMAINS     1 fix agent per domain → post-fix REVIEW → conditional VERIFY.

TEST            Run build + test suite. Always single agent, default model (mechanical).
├── NONE        IMPLEMENT=NONE. Or planner skips with justification (no test infra).
└── FULL        1 agent. Runs build + tests, fixes failures.
```

##### Severity Classification

The planner assesses severity from code context — NOT keyword matching:

| Level | Criteria |
|-------|----------|
| **None** | No functional impact. Comment, formatting, variable rename. |
| **Low** | Minor, immediately reversible. Dev tooling, internal logging, tests. |
| **Medium** | User-facing, visible but contained. UI component, new endpoint, feature. |
| **High** | Core product function, data mutation, could break key flows. Payment, auth, database writes, primary user flows, data model changes. |
| **Critical** | Product outage, data loss, severe production bugs, irreversible damage. Secret exposure, SQL injection, data deletion, auth bypass, production crash, corrupt state. |

The planner reads the actual code, traces what it touches, and assigns severity based on *actual product impact*. No keyword auto-detection. A function named `validatePassword` that handles UI password strength is LOW, not HIGH. A log statement in a payment module is LOW unless the logging itself can break payments.

##### Domain Splitting

When a task spans multiple domains, split in two steps. **Domain breadth is measured by distinct specialist agents needed, not package count.** A task touching 5 Swift packages that all use `swift-pro` is single-domain. A task touching Python + TypeScript files is few-domain.

1. **Split by specialist** — map each file/concern to the best specialist agent from `.opencode/agents/INDEX.md`
2. **Split by volume** — if work for one specialist exceeds a single agent's context window, split into N sub-groups by module or concern

##### Size Classification

The planner assesses scope along with severity. Size gates DISCOVER=NONE decisions.

| Size | Criteria |
|------|----------|
| **tiny** | Single file, single change, under 10 lines. Trivial fix, no structural impact. |
| **small** | Single module, few files. Well-scoped change with clear boundaries. |
| **medium** | Multiple modules, cross-file changes. Moderate scope, may touch different concerns. |
| **large** | Multi-domain changes, significant refactors. Spans different specialist areas. |

DISCOVER=NONE requires `size=tiny` (nothing to discover) OR `size=small` with planner-identified root cause at file:line. For `medium` and `large`, DISCOVER is mandatory.

##### Mid-Execution Amendment

After VERIFY produces confirmed findings at MEDIUM severity or above: if the manifest does not include IMPLEMENT, the lead auto-adds IMPLEMENT followed by FIX (which includes internal post-fix REVIEW + conditional VERIFY). This is unconditional — all confirmed MEDIUM+ findings are fixed regardless of task intent. LOW findings are reported but not auto-fixed.

**Implementation stages** use write → review structure:
```
  Stage N: Implementation — 1 agent per domain
    Agent writes code directly to original files.
  Stage N+1: Review — 1 agent per domain
    Reviews the implementation for bugs, quality, correctness.
  Stage N+2: Verification — severity-routed (extraction → adversarial [CRITICAL/HIGH] + review [MEDIUM] → synthesis)
```

**Fix agents** (docs, configs, scripts): use default model agents for code. Split fixes by domain — one agent per domain. Every fix stage MUST be followed by a post-fix review:
```
  Stage N: Fixes — N agents split by domain
  Stage N+1: Post-fix review — N agents (1 per domain)
  Stage N+2: Verification — severity-routed (only if fix review found MEDIUM+ findings)
```

**Delegation mapping (MANDATORY in every plan):** During planning you MUST answer:
1. What subtasks exist? (list each one)
2. Which agent handles each subtask? (map agent name to subtask — consult `.opencode/agents/INDEX.md`)
3. Where is verification in this plan? Confirm verification runs after every DISCOVER and REVIEW stage that produces findings, or mark it explicitly as SKIPPED with justification.

Answer these explicitly in your plan. Every subtask must have an assigned agent — no subtask goes to the lead.

**Stage decomposition rule (MANDATORY):** If stage N+1 does NOT consume stage N's verified output — they're independent — MERGE them into a single stage with parallel agents. Sequential stages are only correct when the next stage actually needs the previous stage's verified findings as `PRIOR CONTEXT:`.

Write full plan to `tmp/glm-plan.md`. All agents use the opencode default model. The `-m` flag on `spawn-glm.sh` is available to override when a specific model is needed. Quick-fix agents (see Lead Role) are always single-model but run outside the plan's stage structure — they handle agent output issues within an existing workflow, never as a standalone workflow replacement. Checkpoint.

**Dependency analysis (MANDATORY — lead's responsibility, before spawning):** Before spawning any stage, the lead builds a dependency graph of agents within that stage:
1. For each agent, list files it will READ and files it will WRITE/CREATE
2. If Agent B reads or tests a file that Agent A writes → B depends on A → they CANNOT run in parallel
3. Split into batches: independent agents run together, dependent agents run sequentially
4. Document in `tmp/glm-plan.md` per stage:
```
  Stage N agents:
    Batch 1 (parallel): agent-a (writes X.swift), agent-b (writes Y.swift)
    Batch 2 (after batch 1): agent-c (tests X.swift, depends on agent-a)
```
Common dependency patterns to watch: test-writer depends on implementer, fix-agent depends on reviewer, integration-tester depends on all implementers, plan organizer depends on the planner's output. When in doubt, sequence — wasted time from a retry loop exceeds the cost of sequential execution.

**Session start:** Clean ALL stale workflow artifacts: `rm -f tmp/glm-plan.md tmp/stage-*-synthesis.md tmp/stage-*-iter-*-synthesis.md tmp/s[0-9]*-task.txt tmp/s[0-9]*-prompt.txt tmp/s[0-9]*-status.txt tmp/s[0-9]*-report.md tmp/plan-review-*`

Also clear stale session checkpoints: `echo "# Session Memory" > session.md`
CAUTION: Never use broad patterns like `tmp/*-report.md` or `tmp/*-log.txt` — they will delete non-workflow files (e.g. `log-analysis-report.md`). Agent names follow `s{digit}...` prefix (e.g. `s1-researcher`, `s2i1-reviewer-r2`), so `tmp/s[0-9]*` safely matches only workflow artifacts.

**Session boundaries:** Each session is independent — treat every task as a fresh start. Do not assume prior sessions' findings still hold. Every code change, even from previous sessions, requires fresh verification through the full workflow. Only reference prior sessions when the task explicitly asks you to. If task will likely need >4 stages, plan explicit session splits using the continuation protocol. Long sessions degrade from compaction pressure.

#### Agent Preparation

Consult `.opencode/agents/INDEX.md` for the full agent directory (110+ agents grouped by domain). Pick the MOST specialized agent (see Agent Selection above) — a PostgreSQL task should use postgres-pro, not database-optimizer. The agent's domain checklists and anti-patterns are the primary value — they only work when the agent matches the domain.

For each agent in the current stage:

1. Define task with KEY FILES, CONTEXT, SCOPE, `WRITABLE FILES` (code agents only — list source files agent may edit), and `MUST ANSWER:` questions (provided by the planner in the manifest — mandatory, prompts without these are invalid). The lead may add 1-2 supplementary workflow-level questions (e.g., "Was the linter run?") but does not write code-level technical questions.
2. Write the TASK ASSIGNMENT block (PROJECT, ENVIRONMENT if code, PRIOR CONTEXT if stage 2+, YOUR TASK, WRITABLE FILES) to `tmp/{name}-task.txt`. NOTE: Do NOT include the report file path in WRITABLE FILES — the script auto-injects `tmp/{NAME}-report.md` automatically.
3. Assemble the full prompt:
   ```bash
   .opencode/tools/assemble-prompt.sh -a AGENT -t TYPE -n NAME --task tmp/{name}-task.txt
   ```
    Types: `review` (coordination-review + severity + quality-rules-review), `code` (coordination-code + quality-rules-code), `research` (coordination-review + quality-rules-review). The script reads the agent .md, selects templates, substitutes `{NAME}` in the task file content, and writes `tmp/{name}-prompt.txt`. Output: `ASSEMBLED|name|path|bytes`
4. **Validate prompt contains ALL:** full agent .md, TASK ASSIGNMENT with MUST ANSWER questions, quality rules, severity guide (review only), environment (code only), coordination, report format. The script handles all boilerplate automatically — you only own the task file. Missing ANY = do not spawn
5. Match agent type to task: REVIEW → code-reviewer, security-reviewer, backend-architect. CODE → language-pro, debugger. **Git/history analysis** (blame, log, diff, tracing fixes through commits) → `debugger` or `research-analyst`
6. **WRITABLE FILES:** Code agents: task file MUST list the exact source files/directories the agent may modify. Review/audit/research agents: omit WRITABLE FILES entirely — the script auto-injects the correct report path and marks all source files as read-only.
   - **Implementation agents:** WRITABLE FILES must list the exact source files the agent may modify directly. The task must instruct them to produce their implementation and run any available lint/test commands to verify correctness. The task MUST also instruct them to write an Intent section in their report before coding: a description of their understanding of the task and their intended approach, in their own words, at whatever level of detail they think is useful for the reviewer. The agent decides what to communicate — architectural reasoning, assumptions about the codebase, trade-offs considered, alternatives rejected, or anything else that helps someone else understand why they built what they built. This is the first thing they write, before any code.
   - **Review/audit/research agents:** omit WRITABLE FILES entirely — the script auto-injects the correct report path and marks all source files as read-only.
Describe problems and desired behavior — do NOT paste exact fix code unless precision is critical (regex, API signatures, security logic). Name agents with stage prefix: `s1-researcher`, `s2-impl-auth`.

#### Agent Spawning

All agents use the opencode default model. The `-m` flag is available to override when a specific model is needed but is never required.

**How it works for review/research/audit stages:**
1. A single agent gets the agent `.md` and the task assignment — it works independently
2. When a stage has independent subtasks (different files, modules, concerns), spawn one agent per subtask in parallel — as many as the task naturally decomposes into, maximum 10 agents
3. Each agent's report feeds into the verification pipeline (see Verification section)
4. **Naming convention:** `sN-name`, e.g. `s1-reviewer`, `s2i1-researcher` (stage 2, iteration 1)

**How it works for implementation stages:**
1. **Write step:** A single agent writes the implementation directly to the original files. The agent reads the full task, understands the requirements, and produces a complete implementation.
2. **Review step:** A single review agent reviews the implementation — same task description, independent assessment.
3. **Fix and iterate:** The review report is processed by the verification pipeline to produce a verified checklist. ALL verified findings are fixed via fix-agents split by domain. The lead does NOT fix findings directly, regardless of how few or how trivial. Every fix MUST be followed by a post-fix review agent. Every review MUST be followed by verification — review findings are not deliverable until they've been verified. The review → fix → re-review loop iterates until the review agent produces no new findings (empty report) — this convergence is the final gate.

**Spawn:**
```bash
# Single agent (uses default model)
.opencode/tools/spawn-glm.sh -n s1-reviewer -f tmp/s1-reviewer-prompt.txt
# Override model
.opencode/tools/spawn-glm.sh -n s1-reviewer -f tmp/s1-reviewer-prompt.txt -m zai/glm-5.1
```

**Prompt assembly:** Assemble ONE prompt per agent via `assemble-prompt.sh`:
```bash
.opencode/tools/assemble-prompt.sh -a AGENT -t TYPE -n NAME --task tmp/task.txt
```
Types: `review` (coordination-review + severity + quality-rules-review), `code` (coordination-code + quality-rules-code), `research` (coordination-review + quality-rules-review).

**Implementation spawn pattern:**
```bash
# Write step
.opencode/tools/spawn-glm.sh -n sN-impl  -f tmp/sN-impl-prompt.txt
# Review step (spawn AFTER write completes)
.opencode/tools/spawn-glm.sh -n sN-review -f tmp/sN-review-prompt.txt
```

**Naming convention overview:**
- Plan: `s0-planner`, `s0-organize`
- Discovery: `sN-discover-{domain}`, `sN-discover-2-{domain}` (second opinion)
- Implementation: `sN-impl-{domain}`, `sN-review-{domain}`, `sN-review-2-{domain}` (second opinion)
- Verification: `sN-extract`, `sN-adv-{domain}` (adversarial), `sN-adv-cross` (cross-domain adversarial), `sN-drev-{domain}` (review), `sN-synth`
- Fix: `sN-fix-{domain}`
- Test: `sN-test`
- Iterations: `s{N}i{K}-name` (e.g., `s2i1-researcher`, `s2i2-researcher`)
- Respawns: add `-r2`, `-r3` suffix when re-spawning a failed agent with corrected configuration (e.g., `s2i1-reviewer-r2` = stage 2 iteration 1 reviewer, respawn attempt 2). Maximum 3 respawn attempts per agent.

#### Second Opinion Guidelines

For DISCOVERY and REVIEW stages at MEDIUM+ severity, spawn a second opinion agent using a different agent `.md` from the INDEX. The two agents review the same code but through different analytical frameworks, producing complementary findings (proven: 87% complementarity across 5 language domains across 3 languages; 4-agent audit confirmed each additional agent type finds structurally distinct issues). PLAN always has an agent-organizer review (mandatory, all tasks) — see Planning phase step 3b. Agent selection is task-driven — the tables below show recommended defaults; the planner selects the best agents for the specific task based on codebase context.

**No domain exception:** The documentation-domain exceptions (skipping adversarial/review verification, accepting challenged downgrades directly) apply ONLY to the verification pipeline — how findings are routed and verified. They do NOT excuse documentation-domain DISCOVERY or REVIEW stages from the second-opinion requirement. MEDIUM+ severity → second opinion is unconditional across all domains. If a task is MEDIUM+ and includes documentation as a domain, the discovery and review stages for that domain MUST include a second opinion agent.

#### DISCOVER pairings (defaults — planner may override)

For DISCOVER, the primary agent is typically the domain specialist who audits existing code. The second opinion is typically a code-reviewer providing a general quality lens. The planner may select different agents when the task warrants it — the table shows recommended defaults, not hard assignments.

| Context | Primary | Second Opinion |
|---------|---------|----------------|
| General code | domain specialist (`python-pro`, `swift-pro`, etc.) | `code-reviewer` |
| Auth/crypto | `security-reviewer` | `code-reviewer` |
| Infrastructure/config | `devops-engineer` | `code-reviewer` |
| Trivial / single-domain-small | skip | — |

#### REVIEW pairings (defaults — planner may override)

For REVIEW, the primary agent is typically a code-reviewer assessing implementation quality. The second opinion varies by context to provide a complementary lens. The planner may select different agents when the task warrants it — the table shows recommended defaults, not hard assignments.

| Context | Primary | Second Opinion |
|---------|---------|----------------|
| General code | `code-reviewer` | language specialist (`python-pro`, `swift-pro`, etc.) |
| Auth/crypto | `code-reviewer` | `security-reviewer` |
| Infrastructure/config | `code-reviewer` | `devops-engineer` |
| System design / architecture | `code-reviewer` | `backend-architect` |
| Multi-language | `code-reviewer` | `backend-architect` (prefer splitting into per-language reviews with individual second opinions) |
| Trivial / single-domain-small | skip | — |

**Same-agent prohibition:** The second opinion agent MUST use a different `.md` file from the primary. Using the same agent `.md` twice — even with "different task scoping" — does not create a different analytical framework. Same checklists, same anti-patterns, same blind spots. The 87% complementarity effect depends on genuinely different agent expertise. If no different specialist can be found for a second opinion, split the review into smaller per-domain reviews where each can get a truly different second opinion.

**Task-framing guideline:** The task file for the second opinion agent uses the same KEY FILES as the primary but may add a domain-specific emphasis directive in the YOUR TASK section. Example: for `python-pro` reviewing OAuth code, add "Pay special attention to Python error handling patterns around I/O, binary data decoding, and data class validation." This costs zero tokens and amplifies the complementarity effect.

**Both-found confidence signal:** When a DISCOVERY or REVIEW stage used a second opinion, the subsequent extraction agent tags each finding as "both-found" (both agents reported independently) or "single-found" (only one agent reported). Both-found findings carry higher confidence — surface this in the synthesis grid.

#### Execution

1. Spawn current batch of agents via `spawn-glm.sh`, respecting the per-batch limit from Tools and the dependency analysis above. If stdout is empty (Windows `.cmd` issue), read `tmp/{NAME}-status.txt` to get PID. Checkpoint with PIDs and names. If stage has multiple batches, wait for current batch to finish before spawning next
2. `wait-glm.sh name1:$PID1 name2:$PID2 ...` — first progress at 30s, then every 60s, STALLED warnings, health check on finish
3. Do verification prep (for VERIFY stages): read the extraction agent's output, create verification task files per batch, assemble prompts
4. **Review output.** Check operational status only — was the report produced? Is the log non-empty? Any STALLED markers? This is NOT quality review (do NOT evaluate findings, accuracy, or correctness). If ANY agent shows STALLED / EMPTY LOG / MISSING REPORT / EMPTY REPORT:
    - Diagnose root cause. Fix the issue (environment, prompt, task file, dependencies).
    - Re-spawn the agent with corrected configuration.
    - Do NOT proceed to the next stage with incomplete stage output.
    - Accept a gap and proceed ONLY for trivial gaps in discovery stages (e.g. a single agent in a 10-agent discovery stage failed after 3 respawn attempts with different approaches, AND its domain is partially covered by other agents). Every such decision must be explicitly justified in `tmp/glm-plan.md` with `STAGE GAP ACCEPTED: [domain] [reason] [coverage from other agents]`. Do NOT accept gaps in implementation or fix stages — those stages must produce complete, correct output. Do NOT silently skip failed agents.

#### Verification

Verification uses the severity-routed verification pipeline. The lead does NOT manually verify findings — that's the agents' job. The pipeline runs in batches with sequential dependencies:

**Batch 0: Extraction agent** (single, default model; use `code-reviewer` agent `.md`). Reads all reports from the stage, extracts every finding with file:line and severity, deduplicates (same file:line + same issue → merge, note both sources), classifies each finding by severity, and splits into batches grouped by domain. When the originating stage (DISCOVERY or REVIEW) used a second opinion agent, tag each finding as "both-found" (both agents reported independently) or "single-found" (one agent only). Both-found carries higher initial confidence — surface this in synthesis. Findings from documentation specialist agents (documentation-pro) are domain-verified — route them directly to synthesis at the agent's rated severity, skipping adversarial/review verification.

**Mechanical trigger — MANDATORY:** If extraction finds any finding at MEDIUM severity or above, the lead MUST spawn the full verification pipeline (adversarial/review agents → synthesis agent). The synthesis agent runs after all routing agents complete — even if every routed finding was REJECTED or WEAKENED. The lead does NOT evaluate routing agent outputs to decide whether synthesis is needed. The synthesis grid — not the lead's judgment — determines which findings are fixed. Skipping verification for MEDIUM+ findings is a protocol violation.

**Batch 1: Findings routed by severity.** All findings extracted by Batch 0 are routed:

- **CRITICAL/HIGH findings** → Adversarial agent (single agent per batch of 5-8 findings, default model). Tries to FALSIFY every finding: reads cited code with full surrounding context, exhaustively searches for counter-evidence (guards, validation, framework protections, type system invariants, test coverage), labels each CONFIRMED / REJECTED / WEAKENED with evidence. Adversarial methodology: assume the claimed issue is a misunderstanding and search exhaustively before confirming. Every CONFIRMED label must be hard-won with grep evidence.

- **CRITICAL/HIGH findings from cross-domain integration review** → Adversarial cross-domain agent (single agent per batch, default model). Same exhaustive falsification but verifies from BOTH sides of the integration boundary (Domain A producer + Domain B consumer + bridge between them). Finding only survives if no counter-evidence on either side or in the bridge.

- **MEDIUM findings** → Review agent (single agent per batch of 8-12 findings, default model). Reads cited code, assesses validity, labels each CONFIRMED / REJECTED / WEAKENED. Same thoroughness standards — grep for guards before claiming something is missing, verify assertions against actual code.

- **LOW findings** → NOTED. Recorded in the report. No further agent spend.

**Batch 2: Synthesis agent** (single, default model; use `code-reviewer` agent `.md`). Reads all verdicts. Builds a cross-reference grid per finding using unified vocabulary:

| CONFIRMED | REJECTED | WEAKENED |
|---------------|--------------|---------------|
| → fix list | → dropped | severity downgraded → fix list at lower priority |

Surfaces "both-found" confidence signals from extraction — findings reported by both primary and second opinion agents carry higher initial confidence.

Also sanity-checks severity assignments against the severity classification criteria — if a finding's severity appears mismatched (e.g., "SQL injection" labeled MEDIUM), flag it as CHALLENGED. Challenged findings are re-routed through adversarial verification. Exception: documentation-domain challenged findings skip adversarial — documentation severity is inherently subjective (is "10 missing API docs" HIGH or MEDIUM?) and adversarial review of severity ratings adds no meaningful verification. Documentation-domain challenged findings stay at their challenged severity; the lead accepts the downgrade directly.

**If the synthesis grid shows zero CONFIRMED findings at MEDIUM or above** (all MEDIUM+ findings were REJECTED, all were DROPPED, or only LOW-severity survivors remain), FIX is SKIPPED — there is nothing significant to fix. LOW verified findings are acknowledged in the synthesis as non-blocking. The lead writes the synthesis with `FIX SKIPPED: Zero MEDIUM+ verified findings — nothing to fix.` This is mechanical — no lead judgment.

**Verification is MANDATORY** after every discovery, review (including cross-domain integration review), and post-fix review stage that produces code-referencing findings with file:line references. Exception: stages producing findings without code-level references (web research, pure analysis, documentation reviews) — lead may mark verification as SKIPPED with explicit justification.

**Verification completion checklist — MANDATORY before marking a stage as done:**
  1. Extraction agent spawned and report produced
  2. If extraction found 0 findings → stage complete (early-exit)
  3. If extraction found MEDIUM+ findings:
     a. Adversarial agents spawned for CRITICAL/HIGH (batches of 5-8)
     b. Review agents spawned for MEDIUM (batches of 8-12)
     c. Synthesis agent spawned — compiles grid, sanity-checks severity
     d. Synthesis grid determines FIX=SKIPPED or FIX follows
  Skipping any step when MEDIUM+ findings exist is a protocol violation.

**Verification naming convention:**
- Extraction: `sN-extract`
- Adversarial pairs: `sN-adv-{domain}` (single agent per batch)
- Adversarial cross: `sN-adv-cross` (single agent per batch)
- Review verification: `sN-drev-{domain}` (single agent per batch)
- Synthesis: `sN-synth`

#### Between Stages

1. Write `tmp/stage-N-synthesis.md` — verified results from the synthesis grid, decisions, context for next stage
2. **Mid-execution amendment:** If VERIFY produces confirmed findings at MEDIUM severity or above and IMPLEMENT is NOT in the manifest, the lead auto-adds IMPLEMENT followed by FIX (always 2-3 sequential stages: fix + post-fix review + conditional VERIFY). This is unconditional — all confirmed MEDIUM+ findings are fixed regardless of task intent. LOW findings are reported but not auto-fixed. This is mechanical — verify the condition, add the stages.
3. If scope changed from original plan, update `tmp/glm-plan.md` with actual stages and revised goals
4. Checkpoint. Clean up: `rm -f tmp/sN-*-prompt.txt tmp/sN-*-task.txt`
5. Next stage prompts include synthesis as `PRIOR CONTEXT:` section. PRIOR CONTEXT should contain only factual project context the next stage needs: what was discovered, what was decided, what constraints exist, what was already fixed. Do NOT include verification process details, rejected findings, or behavioral instructions — these compete with the agent .md. Target under 50 lines
6. Never re-do verified work unless evidence shows it was wrong
7. Never skip a planned stage without explicitly marking it in `tmp/glm-plan.md` as `SKIPPED` with a reason. A stage is only complete when its agents have been spawned, waited, their reports processed by the verification pipeline, and findings verified — incomplete stages cannot be proceeded past, outside the narrow gap-acceptance rules in Execution step 4. PLAN stages cannot be SKIPPED for speed or token savings — only for genuine blockers (environment failure, missing files, corrupted state).
8. After writing synthesis, read `tmp/glm-plan.md` to confirm the next stage. If the plan has remaining stages, execute them — do not deliver early unless remaining stages are explicitly marked SKIPPED.

**Iterative stages:** Between iterations, follow the Iterative Convergence protocol below — skip steps 1-5 until convergence is reached. On convergence, write final stage synthesis (step 1) and resume normal between-stages flow (steps 2-5).

#### Iterative Convergence

Some stages benefit from repeated runs until agents stop producing new meaningful output. What counts as "new output" depends on the stage purpose — new problems (audit), new information (research), new improvements (analysis), new risks (security), etc.

Convergence is mechanical: when ALL agents in an iteration produce zero new findings (empty reports, no new issues found), the stage has converged. A single non-empty report means the iteration produced output — iterate again. The lead does not subjectively judge whether findings are "meaningful enough" — any finding is meaningful.

**Planner-decided, not mandatory.** The planner selects NONE / ONCE / LOOP per stage based on task characteristics:

- **NONE**: One pass. For well-understood, narrow work. Also appropriate for codebases with comprehensive test coverage (>80%) and clean module boundaries — first pass is unlikely to miss meaningful issues.
- **ONCE**: One extra iteration if first pass found anything. Use when the planner's Phase 1 research reveals interconnected modules, dense coupling, non-uniform code patterns, or >15K LOC per domain — characteristics suggesting a first pass may miss issues. Also used when severity is HIGH/CRITICAL regardless of codebase quality (missed findings are expensive). ONCE is NOT the universal default — well-tested, cleanly-structured codebases should use NONE.
- **LOOP**: Up to 3 iterations, stop on empty report. For highly ambiguous or production-critical work where missed findings would be unacceptable.

Factors the planner considers: ambiguity, codebase complexity, finding volume from first pass, production impact of missed findings, change type (exploratory vs. mechanical), time sensitivity.

**Not used for:** Production stages (implementation and fixing) and verification stages. These produce or evaluate output rather than discovering issues.

**Mandatory rules apply:** CONVERGE iterations of DISCOVERY or REVIEW stages inherit ALL mandatory rules from the parent stage type — including second-opinion requirements at MEDIUM+ severity (see Second Opinion Guidelines). When the original DISCOVER/REVIEW required a second opinion agent, every CONVERGE iteration must also include a second opinion. The planner's decision table must list all agents to spawn per iteration — the lead spawns exactly what the plan lists.

**Execution is mechanical — the lead does NOT re-evaluate the CONVERGE decision.** If the plan says ONCE and verified findings exist, the lead spawns the iteration agents unconditionally. If the plan says NONE, the lead skips unconditionally. The planner's assessment of codebase characteristics (test coverage, coupling, module density, severity) was already baked into the plan during Phase 1 research. The lead does NOT substitute judgment based on what findings happened to be confirmed — whether findings appear "isolated" or "specific" is the planner's call at plan time, not the lead's call at execution time. The planner sees the full codebase structure during research; the lead only sees post-hoc finding counts.

**Mechanics:**
1. Each iteration = full prepare → spawn → verify cycle
2. After verification: check reports mechanically — any non-empty finding list in any agent report? 
    - **Yes** (any finding produced) → write iteration synthesis to `tmp/stage-N-iter-K-synthesis.md`, prepare next iteration with cumulative context from all prior iterations
    - **No** (all reports empty, zero findings) → convergence reached; write final stage synthesis and move on
3. Lead SHOULD vary approach between iterations — different agents, focus areas, or angles — to avoid blind spots. Running identical agents repeatedly is wasteful.
4. Lead can adjust agent count and type between iterations based on what prior iterations revealed
5. If iteration cap hit without convergence → synthesize what's known, note "convergence not reached" in delivery, proceed
6. **Naming:** iteration agents follow `s{N}i{K}-name` — e.g. `s2i1-reviewer`, `s2i2-researcher` (stage 2, iteration 1/2). Respawn within iteration: `s2i1-reviewer-r2`.

#### Delivery

**Before delivery:** Read `tmp/glm-plan.md`. Confirm every planned stage is complete or explicitly marked SKIPPED with justification. A stage silently skipped = not delivered yet. Execute it or update the plan. If any code was changed during the fix stage — by fix-agents — confirm that post-fix review and verification both ran (verification runs only if review found new findings). Code changes without downstream verification are not deliverable. The user's task instructions (commit, push, report) are the final step after all stages complete — they do not override the mandatory stages that must run first.

Before delivery, mechanically verify all mid-execution decisions:
- If any conditional VERIFY was skipped: read the stage's review reports.
  If any report contains a MEDIUM+ finding with a code reference, the VERIFY
  stage must be run now.
- If any finding was marked as dropped or noted by the lead without routing
  through the verification pipeline: the finding must be routed through the
  verification pipeline now.

After final stage:
- **Reviews/audits:** write report to `tmp/` with verified findings, rejected items, gaps
- **Code changes:** spawn a single agent (default model) to run build + tests, fix all failures, and deliver production-ready result. Lead chooses the exact agent for the job (e.g. debugger, build-error-resolver, cpp-pro). This is the final production gate.
- **Research/analysis:** synthesize into clear summary
- Write `tmp/session-summary.md`: task goal, stages executed, total agents, agent aborts/failures, iterations per iterative stage, verification stats, key decisions, phase durations (planning, preparation, execution/wait, verification, synthesis)
- Cleanup: `rm -f tmp/s[0-9]*-prompt.txt tmp/s[0-9]*-task.txt`. Keep logs, reports, summary
- Save workflow lessons to knowledge if applicable

### Agent Prompt Template

Prompts are assembled with cache-aware ordering: stable shared content first (cached across calls), volatile per-instance content last. The assembly order:

```
You are a single agent working solo. Do all the work yourself — do not spawn sub-agents, do not delegate to other agents, do not run agentic workflows. Agentic workflows are not allowed in this session.

Before claiming something is missing or broken — grep for existing guards, handlers, or implementations first.

{cat .opencode/templates/coordination-review.txt OR coordination-code.txt — replace {NAME}}

{cat .opencode/templates/severity-guide.txt — REVIEW/audit tasks only}

{cat .opencode/templates/quality-rules-review.txt OR quality-rules-code.txt}

{Full .opencode/agents/{agent}.md — see Rules → Prompts}

You are an AI agent named {NAME}.

--- TASK ASSIGNMENT ---

PROJECT: {working directory and project description}

ENVIRONMENT (code tasks only):
{Runtime, test command, lint command}

PRIOR CONTEXT (stage 2+ or iteration 2+):
{Contents of tmp/stage-N-synthesis.md OR cumulative tmp/stage-N-iter-*-synthesis.md for iterations}

YOUR TASK: {KEY FILES, CONTEXT, SCOPE, MUST ANSWER questions}

WRITABLE FILES: {code agents only — list source files agent may edit. Review/research/audit agents: omit this section}
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
./.opencode/tools/memory.sh session add context "CHECKPOINT: [task] | DONE: [steps] | NEXT: [remaining] | SKIP: [do not redo — completed agents, failed approaches, skipped stages, pending approvals] | FILES: [key files] | BUILD/TEST: [commands]"
```

The `SKIP:` field prevents rework after compaction/crash recovery. Record:
- Already-completed agents whose reports exist (e.g. `s2-reviewer done`)
- Failed approaches tried 3× (do not retry same thing)
- Stages explicitly skipped with reason (e.g. `verify skipped — 0 findings`)
- Pending approval decisions (`awaiting user approval for push`)

**Compaction recovery — MANDATORY sequence (do ALL steps, no skipping):**
1. Run `.opencode/tools/glm-recover.sh` — prints memory session, plan, continuation (if any), newest synthesis (iter or stage, by mtime), and latest checklist in one stream. Replaces steps 1, 2, 3 below with a single command
2. **Re-read AGENTS.md in full and STRICTLY follow its instructions** — ALWAYS, no exceptions, no partial reads. `glm-recover.sh` does NOT do this for you
3. Only then resume work

If `glm-recover.sh` is unavailable, fall back to the manual sequence:
1. `./.opencode/tools/memory.sh session show` — restore session state
2. Read `tmp/glm-plan.md` — restore current plan
3. Read the latest `tmp/sN-synth-report.md`, `tmp/stage-N-iter-K-synthesis.md`, or `tmp/stage-N-synthesis.md` — restore verification/iteration/stage state

Do not rely on continuation summary alone. Do not skip the AGENTS.md re-read — this is the #1 cause of workflow deviation after compaction.

| Checkpoint | Recovery |
|-----------|----------|
| Plan done | Read `tmp/glm-plan.md` → prepare agents |
| Agents prepared | List prompts → spawn |
| Agents spawned | Check PIDs/reports → verify or re-wait |
| Verifying stage N | Read `tmp/stage-N-synthesis.md` — the lead's synthesis from the synthesis agent's grid |
| Iterating stage N, iter K | Read `tmp/stage-N-iter-K-synthesis.md` + cumulative context → prepare next iteration |
| Stage N done | Read synthesis + plan → next stage |

**Compaction handoff format —** for long-running stages, include this block in stage synthesis to preserve active process state:

```markdown
## Compaction Handoff
- **Current objective:** [what this stage is doing]
- **User constraints:** [explicit instructions that must survive compaction]
- **Active plan / workflow:** [reference to plan artifact or current step]
- **Approval state:** [what's approved, what's pending, what was denied]
- **Key facts and decisions:** [exact values, resolved ambiguities, why choices were made]
- **Actions already taken:** [agents spawned, commands run, files changed]
- **Errors, blockers, attempted fixes:** [what failed and what was tried — do not retry same approach]
- **Pending tasks:** [remaining subtasks in this stage]
- **Next recommended step:** [single concrete action to resume with]
- **Do not redo:** [completed agents, failed approaches, skipped steps]
```

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
| Incorrect edits | Diagnose why the agent produced wrong output (bad prompt? misunderstood task?). Fix the prompt/task. Spawn a quick-fix agent to revert and rewrite. Do NOT revert changes yourself. If the quick-fix agent is still wrong, escalate to full IMPLEMENT → REVIEW → VERIFY. |
| 2+ agents fail same env error | STOP respawning. Diagnose environment first (do NOT fix environment issues directly — spawn an agent if changes needed) |
| Agent aborted (same error 3×) | Read log to diagnose root cause, fix environment/config (spawn an agent if code/config changes needed), then respawn |
| Stage partially failed (1+ agents produced no useful output or wrong output) | Diagnose root causes across all failed agents. Fix issues (environment, prompts, tasks). Re-spawn ALL failed agents. The stage is incomplete until all agents succeed. Do NOT proceed to the next stage with gaps. |
| Iteration cap hit without convergence | Synthesize all iterations, note "convergence not reached" in delivery, proceed |
| Adversarial verification produces suspicious results (CONFIRMED on obviously-wrong findings or REJECTED with weak evidence) | Diagnose prompt/task quality — adversarial agent may have misunderstood its role. Adjust MUST ANSWER questions or adversarial instructions and respawn. |

### Rules

**Quality over speed — ALWAYS.** Never rush, never cut corners, never try to finish faster. Slow, thorough, methodical work produces quality. Speed produces bugs. Prefer more stages, more agents, more verification over shorter timelines. There is no deadline. The only measure of success is production-ready, bug-free code.

**Limits:** Per-batch limit and agent parallelism rules are defined in Tools and Agent Spawning — don't restate. Need more coverage than the 10-agent per-batch cap allows? Add stages, not more agents per batch. Agents run until done (no turn limit). One task per agent. Respawn naming: `-r2`, `-r3`. No two agents edit same file within a stage (read overlap OK). Balance workload — each agent should cover roughly equal scope.

**Task tool prohibition (MANDATORY — single most important rule):** Agent delegation in this project happens ONLY via `spawn-glm.sh`. The `Task` tool with its `subagent_type` parameter is FORBIDDEN — never call it, regardless of the use case (exploration, code review, implementation, research, anything).

The Task tool's built-in `subagent_type` list happens to share names with our agent `.md` files in `.opencode/agents/` (`code-reviewer`, `ios-pro`, `swift-pro`, etc.) — these are TWO DIFFERENT THINGS. The Task tool ships a separate sub-agent runtime that bypasses our agent delegation system, the `spawn-glm.sh` pipeline, verification, report formats, and quality rules. Our agent `.md` files are reached ONLY by passing `-a AGENT_NAME` to `assemble-prompt.sh` and then spawning via `spawn-glm.sh`.

If you catch yourself about to call `Task(subagent_type=...)` — stop, use `spawn-glm.sh` instead.

**Agent count per stage (MANDATORY — fill capacity by task decomposition):** Decompose the task into as many independent subtasks as it naturally splits into, spawn one agent per subtask, maximum 10 agents per batch. Default to what the task genuinely requires — scale to scope. Over-engineering with unnecessary agents adds coordination overhead that degrades quality (proven across 260+ configurations). Fill the maximum only when the task truly spans that many distinct domains. Verification stages scale with findings count and impact surface, not discovery agent count — minimum 1 extraction agent for every stage; adversarial agents run only if extraction finds at least one finding to falsify. When in doubt, decompose into more parallel agents — broader coverage finds more issues. **Never run sequential single-agent stages when those stages could be a single stage with parallel agents (see Workflow → Planning → Stage decomposition rule).**

**Prompts:** Include the FULL agent `.md` file — agents are optimized and every section earns its place. Do NOT trim or skip sections. Boilerplate (quality rules, severity guide, coordination, report format) comes from `.opencode/templates/` and is prepended before the agent .md for prompt-cache stability (stable shared content cached first, volatile content last). Agents don't load AGENTS.md — all context must be in prompt.

**Verification:** Every finding labeled. Every label backed by Read. 100% complete before proceeding. ALL verified actionable findings fixed via fix-agent — the lead does not fix findings directly.

**Lead code prohibition (MANDATORY):** The lead never writes, edits, or modifies project source code. Every code change — implementation, bug fixes, config adjustments, script changes, one-liners — goes through a spawned agent. The lead's tools (Edit, Write) are for tmp/ artifacts only: task files, prompts, synthesis reports. The only exception is editing AGENTS.md itself (meta-configuration).

**Platform:** `opencode` on all platforms (spawn-glm.sh handles invocation). Always redirect output to log files.

---


---

## Skills (Workflows)

Workflows are available as skills in `.opencode/skills/` directory. Use `/skill-name` to invoke. Skills are orthogonal to the agentic workflow — they are utility operations invoked directly by the lead as needed. Skill output is not routed through the verification pipeline.
