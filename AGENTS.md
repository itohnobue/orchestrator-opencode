# Project-Specific — orchestrator-opencode

## Skills (Workflows)

Workflows are available as skills in `.opencode/skills/` directory. Use `/skill-name` to invoke. Skills are orthogonal to the agentic workflow — they are utility operations invoked directly by the lead as needed. Skill output is not routed through the verification pipeline.

---




## Shared Workflow Infrastructure

The sections below are identical across all repositories that use this workflow system. When propagating to other repos, copy from here to end of file.

---

## Temporary Files

You can use the `tmp/` subfolder in the current project folder to save any temporary files if needed.
This is useful for storing intermediate results, reports, or data during multi-step workflows.

**Path resolution:** All `tmp/` paths in workflow instructions resolve to `$REPO_ROOT/tmp/` where `$REPO_ROOT` is the absolute path to the repository root (the directory where `opencode` was launched). The tool scripts (`assemble-prompt.sh`, `spawn-glm.sh`, `wait-glm.sh`, `glm-recover.sh`) compute `REPO_ROOT` and use absolute `${REPO_ROOT}/tmp/` paths so that agent reports, logs, and artifacts are always written to the correct location regardless of each agent's working directory or the project under inspection. When writing task files or instructions for agents, always reference `tmp/` paths relative to `$REPO_ROOT`.

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

3. **Planning phase (3 batches, 3 agents) — ALWAYS run, never skipped:**
   a. **Initial planner:** Copy `.opencode/templates/planner-task-template.txt`, fill in the project path (just the working directory — the planner researches the codebase itself), assemble with `assemble-prompt.sh -a agentic-planner -t research -n s0-planner`, spawn (no `-m`, uses default model). Researches the project, classifies the task on 5 axes (size, domains, ambiguity, severity, type), selects bricks from the palette, and produces a custom workflow manifest with FILE SCOPES to `tmp/glm-plan.md`.
   b. **Volume splitter (ALL plans):** Create a task targeting `tmp/glm-plan.md` with MUST ANSWER questions covering splits, merge-backs, and path verification. Include `WRITABLE FILES: tmp/glm-plan.md` in the task file. Assemble with `assemble-prompt.sh -a volume-splitter -t code -n s0-volume`, spawn (no `-m`, default model). The volume-splitter resolves FILE SCOPES to exact KEY FILES with `wc -l` counts, applies mechanical split/merge rules, builds the volume audit table, rewrites the plan in-place, and writes `tmp/s0-volume-report.md`.
   c. **Mandatory plan review (ALL plans):** Create a review task targeting `tmp/glm-plan.md` with MUST ANSWER questions covering brick selection, severity classification, agent assignment, verification placement, convergence decisions, and dependency analysis. Include `WRITABLE FILES: tmp/glm-plan.md` in the task file. Assemble with `assemble-prompt.sh -a agent-organizer -t review -n s0-organize`, spawn (no `-m`, default model). The agent-organizer reviews the plan using its structural analytical framework (the volume-splitter has already resolved KEY FILES and applied mechanical splits):

       *MUST ANSWER redistribution:* When the volume-splitter created sub-agents, the original MUST ANSWER questions were copied verbatim. The organizer redistributes them — assigning each question to the sub-agent whose scope covers the relevant code, writing new scoped questions when needed.

       *Workflow quality (native anti-patterns):* Check for stale agent references, ignored dependencies, missing intersection agents, exclusion-list violations, and missing second opinions. The organizer FIXES mechanical violations directly in the plan — its anti-patterns list defines the Fix/Flag split (see agent-organizer.md).

       *Structural validation (embedded rules in task):* Verify every DISCOVER/REVIEW stage has a corresponding VERIFY. Verify IMPLEMENT stages have a corresponding REVIEW. Verify MEDIUM+ severity tasks have second opinions in ALL DISCOVER and REVIEW stages, including CONVERGE iterations. Verify FIX stages include post-fix REVIEW. Verify no agent is reused across CONVERGE iterations (different iterations deploy genuinely different specialists). If the plan specifies an exclusion list, mechanically cross-check EVERY iter 2 agent against it — do NOT trust the plan's claim without verifying each slot. When the task spans 2+ domains: verify the Boundary Analysis section exists, each boundary is triaged (ALWAYS/DEFAULT/SKIP), ALWAYS/DEFAULT boundaries have intersection agents in DISCOVER and cross-domain reviewers in REVIEW, and SKIP boundaries have one-line justification with exact call-site count. Verify domain breadth counts specialists, not packages. Volume splitting is handled by the volume-splitter before structural validation — do NOT duplicate here; spot-check for obvious errors and flag. Verify sequential stages are genuinely dependent — if stage N+1 does not consume stage N's verified output, flag for merge into a single parallel stage. Flag miscounts or over-large single-agent scopes.

       After review, the organizer applies all structural fixes directly to `tmp/glm-plan.md`. For judgment-level findings (see agent-organizer.md Fix/Flag split), the organizer flags them in its report but does not modify them — the lead reviews and decides during Step 4. The organizer's output IS the final plan — no separate merge agent is needed. This runs on EVERY plan — a bad plan poisons everything downstream regardless of severity.
4. **Review final plan:** Read `tmp/glm-plan.md`, confirm classification, brick selection, and stage structure are sound. Review the volume-splitter's audit report (`tmp/s0-volume-report.md`) for split correctness, merge-back decisions, and close-call justifications. Review the organizer's flag report — for each flagged judgment call: accept the flag and adjust the plan (spawn a quick-fix agent if needed), reject the flag with documented justification, or if uncertain revert to the planner's original decision (conservative default). Verify CONVERGE variant matches both task type AND codebase characteristics from the planner's own Phase 1 research. Production checks, audits, and security reviews require CONVERGE >= ONCE — if the planner assigned CONVERGE=NONE to an audit task, flag for correction regardless of codebase cleanliness. For non-audit tasks: if research shows >80% coverage and clean boundaries but CONVERGE=ONCE, flag for correction (ONCE is for interconnected modules, dense coupling, non-uniform code patterns, 12+ agents deployed, or HIGH+ severity, not a default). If gaps remain, spawn a quick-fix agent to correct the plan.
5. **Decompose:** List subtasks from the plan, map each to best agent, report to user

**CRITICAL — Plan Display Rule:** After the planning phase completes and before spawning ANY stage agent, you MUST output the full stage plan as text to the user — see Workflow → Planning for the format. Writing the plan to `tmp/glm-plan.md` does NOT replace showing it. Display first, then proceed.

### Subtask Workflow

The lead's role in each subtask:
1. Select the best agent, read its `.md`, prepare the task file using the planner's KEY FILES and MUST ANSWER questions from the manifest. For DISCOVER agents that follow a RESEARCH stage: copy the research report's `## Discovery Questions` section verbatim into the YOUR TASK section — the research agent wrote them, the lead transports them untouched.
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

**Does:** delegate planning to the agentic-planner pipeline, review manifest, decompose, execute workflow stages from the manifest, write agent prompts, spawn agents, delegate verification according to manifest (adversarial verification: 1:1 for CRITICAL/HIGH, 1 per 5 for MEDIUM), spawn fix-agents and quick-fix agents, synthesize, deliver.

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

1. **Extraction agent** (single, default model): Reads all reports from the stage, deduplicates findings (same file:line + same issue → merge, note source), classifies each finding by severity, splits into batches grouped by domain and severity. When the originating stage (DISCOVERY or REVIEW) used a second opinion agent, tag each finding as "both-found" (both agents reported independently) or "single-found" (one agent only). When intersection agents were present, also tag findings as "boundary-found" (reported by an intersection agent auditing a domain boundary — inherently invisible to within-domain specialists) or "domain-only" (reported only by domain primaries/second opinions). Both-found and boundary-found carry elevated confidence for different reasons: both-found signals cross-agent agreement within a domain; boundary-found signals issues spanning domains that no within-domain specialist could have detected. A finding that is both "both-found" AND "boundary-found" carries the highest confidence. Surface all tags in synthesis.

When the codebase is a git repository with prior production check commits: for each finding, check whether the cited file:line was introduced or modified in a prior production check commit (`git log --all --format="%h %s" | grep -i "production\|check\|fix\|audit"`). Tag findings that fall on previously-fixed lines as `PRIOR_FIX_ATTEMPT: <commit-hash>`. A file with ≥3 PRIOR_FIX_ATTEMPT findings signals a repeat-regression hotspot — surface this count in the extraction report for synthesis routing. A function with ≥3 PRIOR_FIX_ATTEMPT findings clustered within ~40 lines (same logical block) signals a function-level regression hotspot — surface both file-level and function-level counts.

Findings from documentation specialist agents (documentation-pro) are domain-verified — route them directly to synthesis at the agent's rated severity, skipping adversarial verification. If extraction finds 0 findings, VERIFY early-exits — nothing to verify, skip all subsequent batches.

    **Mechanical trigger — MANDATORY:** If extraction finds any finding at MEDIUM severity or above, the lead MUST spawn ALL verification batches the extraction report prescribes — every adversarial batch, at the exact finding IDs listed in the extraction's batch assignment table. Spawning an adversarial agent against different findings than prescribed does NOT satisfy this trigger. The lead does NOT pre-judge findings, skip verification steps, substitute finding targets, or decide which findings "don't matter." Only the synthesis grid determines FIX=SKIPPED. The synthesis agent is part of the pipeline — it MUST run after all routing agents complete, even if every routed finding was REJECTED or WEAKENED. The lead does NOT evaluate routing agent outputs to decide whether synthesis is needed. Proceeding to the next stage without completing all verification steps is a protocol violation.

2. **Findings routed by severity** (single-source routing):

   - **CRITICAL/HIGH findings** → Adversarial agent (single agent per finding (1:1), default model; use `adversarial-reviewer` agent `.md`). The adversarial agent tries to FALSIFY every finding in its batch: reads cited code with full surrounding context (minimum 30 lines), exhaustively searches for counter-evidence at every level (same function guards, caller-level validation, framework-level protections — middleware, decorators, interceptors, global error handlers, type system invariants, test coverage), and labels each finding with evidence:

     * **CONFIRMED** — exhaustive search found NO counter-evidence. Describe what patterns were searched, which grep commands were run, why nothing was found.
     * **REJECTED** — found CLEAR counter-evidence that disproves the claim. Paste exact code with file:line.
     * **WEAKENED** — partial counter-evidence reduces severity or scope but doesn't fully disprove. State the correct severity.

      The adversarial agent assumes the claimed issue is a misunderstanding and searches exhaustively before confirming. For "missing X" findings, searching for X and finding it in no reachable code path IS valid evidence — document all searched locations. Every CONFIRMED label must be hard-won — superficial grep is not exhaustive. Surviving findings become ADVERSARIALLY VERIFIED.

- **CRITICAL/HIGH findings from intersection or cross-domain integration review** (any finding spanning domain boundaries, from DISCOVER or REVIEW) → Adversarial cross-domain agent (single agent per finding (1:1), default model). Same exhaustive falsification but verifies from BOTH sides of the integration boundary (Domain A producer + Domain B consumer + bridge between them). Finding only survives if no counter-evidence on either side or in the bridge.

   - **MEDIUM findings** → Adversarial agent (single agent per batch of 5 findings, default model; use `adversarial-reviewer` agent `.md`). Same exhaustive falsification methodology as CRITICAL/HIGH findings — reads cited code with full surrounding context (minimum 30 lines), exhaustively searches for counter-evidence at every level (same function guards, caller-level validation, framework-level protections — middleware, decorators, interceptors, global error handlers, type system invariants, test coverage), and labels each CONFIRMED / REJECTED / WEAKENED with evidence. Default position: assume the claimed issue is a misunderstanding and search exhaustively before confirming. Every CONFIRMED label must be hard-won — superficial grep is not exhaustive. For "missing X" findings, searching for X and finding it in no reachable code path IS valid evidence — document all searched locations.

   - **LOW findings** → NOTED. Recorded in the report. No further agent spend.

3. **Synthesis agent** (single, default model): Reads all adjudication verdicts. Builds a unified verification grid:

   | CONFIRMED | REJECTED | WEAKENED |
   |-----------|----------|----------|
   | → fix list | → dropped | severity downgraded → fix list at lower priority |

   Surfaces "both-found" confidence signals from extraction — findings reported by both primary and second opinion agents carry higher initial confidence.

   Surfaces PRIOR_FIX_ATTEMPT regression signals from extraction. When a file has ≥3 PRIOR_FIX_ATTEMPT findings, flag it in the synthesis grid as a repeat-regression hotspot. When ≥3 findings cluster within the same function (~40 lines), flag that function as a regressing function requiring a localized pre-fix audit. Fix agents for hotspot files and regressing functions receive an automatic second-opinion reviewer regardless of finding severity — these locations have a demonstrated pattern of incomplete fixes.

   If the synthesis grid shows zero CONFIRMED findings at MEDIUM or above (all MEDIUM+ findings were REJECTED, or only LOW-severity survivors remain), FIX is SKIPPED — there is nothing significant to fix. LOW verified findings are acknowledged in the synthesis as non-blocking. The lead writes the synthesis with `FIX SKIPPED: Zero MEDIUM+ verified findings — nothing to fix.` This is mechanical — no lead judgment.

Lead coordinates batches, never investigates findings manually, and writes the final synthesis from the synthesis agent's grid.
- Implementation (agent does): Writing/editing code, running test suites, fixing bugs, adding tests, refactoring
- After the verified checklist is produced, if many fixes are needed across many files: collect them into a fix-agent prompt and spawn

**Quick-fix agents:** For two specific scenarios — (1) agent output needs minor finishing, (2) reverting incorrect edits — spawn a single quick-fix agent using the default model. Lead chooses the exact agent for the job. No verification pipeline — this is a quick, informal fix. If the fix is wrong, diagnose the issue (bad prompt? wrong specialist?) and retry once with corrections. If the retry also fails: for HIGH/CRITICAL-adjacent changes, escalate to full IMPLEMENT → REVIEW → VERIFY; otherwise (LOW/MEDIUM or workflow-internal clutter), spawn a quick-fix agent to revert the change entirely — better to ship clean than to ship a broken fix. No direct work — the lead never edits project code. Quick-fix agents are the only exception to "every review must be verified."

**Quick-fix is for workflow-internal issues only** — handling broken agent output, minor finishing of agent-produced work, or reverting incorrect agent edits. Quick-fix agents are NOT a substitute for running the full workflow. For any task, no matter how small, the planner pipeline must run first. Quick-fix operates inside an existing workflow — never as a standalone replacement for planning, review, or verification.

**Workflow autonomy:** The lead runs the workflow to completion without waiting for user approval. The planner agent designs the initial workflow (stages, agents, verification placement); the lead reviews, adapts, and refines it — adding or modifying non-PLAN stages as understanding deepens during execution. Each stage follows the prepare → spawn → verify cycle. A stage is complete ONLY when ALL its agents have produced their expected output. A stage with failed or missing agents is incomplete — diagnose failures, fix root causes, re-spawn. Proceeding to the next stage with an incomplete current stage — outside the narrow gap-acceptance rules in Execution step 4 — is a protocol violation. The lead has full authority to adapt non-PLAN parts of the plan mid-execution. PLAN stages (3-agent planning pipeline) cannot be removed. DISCOVER, RESEARCH, IMPLEMENT, REVIEW, FIX, and TEST stages may be SKIPPED only when the planner's manifest explicitly marks them as NONE for the given task severity — never for speed or convenience. VERIFY is skipped when extraction finds 0 findings or when the lead may mark it as SKIPPED for non-code-level findings. Prior workflow runs do not excuse skipping — every code change requires fresh verification regardless of what previous sessions found.

### Tools

**Maximum 10 agents per parallel batch within a stage.** A stage that has independent subtasks SHOULD use as many parallel agents as the task naturally decomposes into — spawn only what the work requires. Under-splitting discovery agents (cramming too much code into one context) degrades quality by creating a detection ceiling — the agent can read everything but cannot deeply analyze cross-file contracts, producing fewer findings. Default to splitting discovery agents at the volume caps below; only merge sub-agents back when the post-split re-evaluation confirms the scope is truly trivial. When a stage genuinely needs more than 10 independent subtasks, split into sequential sub-batches within the stage. The 10-agent-per-batch limit is a coordination constraint, not a quality limit. Single-agent stages are normal for tightly-scoped implementation work; single-agent discovery stages are correct only for very small domains (<1,200 LOC). Each agent is an independent unit; a stage is a parallel-batch boundary that may contain multiple agents. Implementation stages: a single agent writes code directly to original files, followed by a single review agent that reviews the result (see Agent Spawning). For multi-domain changes, one agent per domain writes in parallel.

**Spawn:**
```bash
.opencode/tools/spawn-glm.sh -n NAME -f PROMPT_FILE [-m MODEL]
```
`-m` is optional — when omitted, the agent uses opencode's configured default model. Use `-m MODEL` to override with a specific model. Returns `SPAWNED|name|pid|log_file`. Backgrounds immediately. Report: `tmp/{NAME}-report.md`, log: `tmp/{NAME}-log.txt`. Also writes to `tmp/{NAME}-status.txt` (reliable on Windows — stdout can be lost when parallel `.cmd` processes launch).

**Stage types and model usage** — all agents use the opencode default model unless overridden with `-m`. The `-m` flag is available for any stage type when a specific model is needed.

| Stage Type | Description |
|-----------|-------------|
| **Plan** (always runs) | Planner researches and produces the plan draft with FILE SCOPES. Volume-splitter (volume-splitter) resolves to exact KEY FILES, applies split/merge rules. Organizer (agent-organizer) reviews structural compliance, redistributes MUST ANSWER questions, produces final plan. All use default model. |
| **Research** (gather external information) | Gathers information beyond what the codebase provides — web search, documentation, standards, community knowledge, dataset analysis, or deep internal codebase exploration. Placed before DISCOVER when findings inform what to look for in code. Can run standalone for pure research tasks. Uses web-searcher, research-analyst, data-researcher, or domain specialists as appropriate. Scales by topic specialization, not second opinions. VERIFY skipped for purely informational findings (no code-level refs). CONVERGE available for ambiguous/critical questions. |
| **Discovery** (review, audit, analysis of existing code) | Specialist agent with dedicated context focused on one domain. When a stage has independent subtasks (different files, modules, concerns), spawn one agent per subtask — as many as the task naturally decomposes into, maximum 10 in parallel. At MEDIUM+ severity: second opinion agent runs in parallel with complementary specialist `.md`. |
| **Implementation** (write code) | Single agent writes code directly to original files. For multi-domain changes, one agent per domain writes to respective files in parallel. |
| **Review** (after implementation or fix) | Reviews implementation or fix for bugs, quality, correctness. Every implementation and every fix MUST be followed by a review agent. At MEDIUM+ severity: second opinion agent runs in parallel with language specialist `.md`. |
| **Fixing** (fix verified findings) | Applies known fixes mechanically. Fix ALL confirmed findings from the synthesis grid. Every fix MUST be followed by a post-fix review agent. |
| **Adversarial verification** (falsification) | For CRITICAL/HIGH findings — 1 agent per finding (1:1). For MEDIUM findings — 1 agent per batch of 5 findings. Both use exhaustive falsification: read cited code, search for counter-evidence at every level (same function, caller, framework, type system, tests). Label CONFIRMED / REJECTED / WEAKENED with evidence. Extraction and synthesis agents also default model. |
| **Test** (build + test suite) | Runs build and test commands, fixes compilation/test failures, reports results. |
| **Quick-fix** (minor finishing, reverts) | Short, informal fix for workflow-internal issues — fixing broken agent output or reverting incorrect edits. Not a substitute for the planning pipeline. No verification. If wrong, diagnose and retry once. If retry also fails: escalate to full IMPLEMENT → REVIEW → VERIFY for HIGH/CRITICAL changes; revert for everything else. |

**Wait:**
```bash
.opencode/tools/wait-glm.sh name1:$PID1 name2:$PID2 name3:$PID3
```
Blocks until all finish (Bash timeout: 600000). Do NOT use bare `wait` or `sleep` + poll loops. Prefer `name:pid` format — enables progress monitoring (first at 30s, then every 60s) and STALLED detection (0-byte log after 2min). Bare PIDs still work but skip log monitoring. If Bash times out before agents finish, re-invoke with same arguments — this is normal for long-running agents. **Planner, volume-splitter, and organizer agents read many files in a single tool call, producing bursts of log growth separated by long pauses where the agent is thinking, not stuck. A Stage 0 agent showing STALLED after 2 minutes of no log growth but with healthy early activity (file reads, grep, wc -l) is not stalled — wait for the full Bash timeout. Only kill and re-spawn if the log is empty from the start or grows zero bytes for 10+ minutes.**

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

  Stage 0: Plan — 3 agents (planner + volume-splitter + organizer)
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
PLAN            Always FULL (3 agents: planner + volume-splitter + organizer, all default model).
                No variants. Never skipped. Bad plan poisons everything downstream.
                Planner (agentic-planner) researches and produces the plan draft with FILE SCOPES.
                Volume-splitter (volume-splitter) resolves FILE SCOPES to exact KEY FILES with
                wc -l counts, applies mechanical split/merge rules, rewrites the plan in-place,
                and writes the volume audit report. Organizer (agent-organizer) reviews structural
                compliance, redistributes MUST ANSWER questions across split domains, cross-checks
                exclusion lists, and flags judgment calls. The organizer's output IS the final plan.

RESEARCH        Gather information beyond what the codebase provides.
                External (web, docs, standards, community knowledge) or
                internal (git history, deep codebase exploration).
                The planner MUST add RESEARCH for every external reference
                the codebase depends on. A reference exists when the code:
                (a) calls a named API from an external standard or library,
                (b) uses a named standard's directives or pragmas,
                (c) reads/writes a named file format or protocol,
                (d) cites a named book or paper as an algorithmic source,
                or (e) selects behavior based on which named implementation
                is available. A formal spec URL is NOT required. The test:
                would verifying this code require knowledge of external
                documentation? If yes — reference. Count mechanically
                from systematic codebase grep during Phase 1 — not from
                what you happen to notice in ad-hoc file reads. One agent
                per distinct named reference — every row in the
                External Reference Inventory gets a research agent. The
                inventory is authoritative: no row is dismissed as
                "infrastructure," "already tested," or "no spec needed."
                Research is cheap; missed external requirements are
                expensive. RESEARCH builds the reference library that
                DISCOVER agents consult. Skip only when the inventory
                is empty (systematic grep found zero references).
                RESEARCH typically precedes DISCOVER
                (research findings become PRIOR CONTEXT for discovery
                agents who check code against external information) but
                the planner places it wherever the task structure demands.

                Every research report MUST include a `## Discovery Questions`
                section at the end. This section contains 2-5 MUST ANSWER
                questions for the downstream DISCOVER agents, each with the
                relevant spec text or reference quoted inline so the
                discovery agent can verify against the actual specification
                without reading the full research report. Format:

                ```
                ## Discovery Questions

                The [SPEC NAME] specification (Section X) states:
                "[quoted spec text]"

                > 1. Verify that [module/file] satisfies [requirement].
                >    Check files: [file:line, file:line].
                >    [specific edge cases to examine].
                >
                > 2. Verify that [another module] correctly handles [contract].
                >    Check files: [file:line].
                ```

                The research agent is the domain expert on the specification —
                it writes the questions with inline spec quotes. The lead
                copies them verbatim into discovery agent task files. Zero
                lead interpretation; zero summarization; zero claim extraction.
                The instruction to include this section must be in the task
                file (see Agent Preparation) — the lead owns this handoff.

                Research findings are informational, not authoritative.
                The ground truth is the project code and the task at
                hand — research fills gaps and provides context. When
                research and code conflict, code wins. Always preserve
                the research agent's confidence tier (CONFIRMED/LIKELY/
                TENTATIVE/SPECULATIVE) when passing research into PRIOR
                CONTEXT or delivery. Exception: tasks with no codebase
                to check against (pure research questions, technology
                selection) — there, confidence tiers are the best signal
                available.

                The planner selects agents from the INDEX based on
                the research type needed — web-searcher (internet),
                research-analyst (structured analysis), data-researcher
                (datasets), or a domain specialist (internal codebase
                exploration). Follows the same conventions as other
                discovery-oriented bricks: CONVERGE for ambiguous/
                critical questions, agent exclusion lists across
                iterations. No second opinions — research agents
                scale by topic specialization, not analytical
                complementarity.

                Findings that map to code references go through the
                normal VERIFY pipeline. Purely informational findings
                (no file:line references to falsify) carry the research
                agent's confidence tiers (CONFIRMED/LIKELY/TENTATIVE/
                SPECULATIVE) and VERIFY is SKIPPED with explicit
                justification.

├── NONE        Purely internal tasks. Mechanical fixes, well-
│               understood patterns, nothing to verify against
│               external sources. The task draws entirely from
│               codebase knowledge.
├── SINGLE      1 research agent on one topic.
└── MULTI       N agents, one per distinct research question.
                Split by question diversity, not code domains.

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
└── MULTI       N agents, one per domain. Split by specialist → volume
                (≤1,200 LOC/10f per agent — see Domain Splitting caps).
                At MEDIUM+: each domain gets a second opinion agent.

                When the task spans 2+ domains with non-trivial coupling (see
                Boundary Selection Criteria below), the planner adds intersection
                discovery agents to the DISCOVER batch. An intersection agent
                audits the integration boundary between two adjacent domains —
                tracing the full data/error/call flow across the divide,
                verifying contracts hold at the boundary, and identifying
                mismatches in data format, error semantics, or transactional
                consistency. This is distinct from second opinions: second
                opinions apply a different analytical lens to the SAME domain;
                intersection agents trace the boundary BETWEEN different domains
                where coupling creates defect-prone blind spots invisible to
                either domain specialist alone. Intersection findings are tagged
                "boundary-found" in extraction — signaling issues no within-domain
                specialist could have detected. CRITICAL/HIGH findings from
                intersection discovery are routed through cross-domain adversarial
                verification (1:1 per finding, verifying from both sides of the
                boundary). Intersection agents MUST be placed in the first DISCOVER
                stage — never deferred to CONVERGE iterations. CONVERGE inherits
                the intersection requirement but adds ADDITIONAL agents with
                different specialists, not replacements for the first-stage ones.
                Intersection agents run in parallel with domain primaries and
                second opinions within the same stage. At MEDIUM+ severity: each
                intersection agent gets its own second opinion (a different
                specialist from the INDEX, not the same type as the intersection
                agent). Intersection agents audit gaps between domains — second
                opinions audit the intersection audit itself for missed concerns.

                The planner selects the best agent for each boundary based on
                domain context. Suggested defaults (planner's selection is
                authoritative — these are starting points, not mandates):
                `backend-architect` for data flow and contract tracing;
                `security-reviewer` for crypto/auth boundaries. The planner
                may choose any agent from the INDEX that fits the boundary.

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
│               When the task spans 2+ domains OR has same-specialist
│               ALWAYS-tier boundaries (see Boundary Selection Criteria),
│               the planner adds cross-domain integration reviewers to the
│               REVIEW batch (same ALWAYS/DEFAULT/SKIP tiers apply). These agents focus
│               ONLY on integration points: API contracts, shared types,
│               data flow between domains, and regressions at boundaries from
│               implementation changes. Do NOT re-review domain-internal logic.
│               Post-implementation intersection review is critical: domain
│               reviewers see new methods as correct within their context;
│               only tracing the full boundary reveals regressions where error
│               contracts, data formats, or transactional ordering differ from
│               what the caller expects. Findings from cross-domain integration
│               review are routed through adversarial cross-verification (1:1
│               per CRITICAL/HIGH finding, verifying from both sides).
└── MULTI       N agents, one per domain.

VERIFY          Verify findings from DISCOVER, REVIEW, RESEARCH (code-ref findings), or post-fix review.
                Always includes extraction (1 agent, default model). Tags findings
                "both-found"/"single-found" when originating stage had second opinion,
                and "boundary-found"/"domain-only" when intersection agents were present.
                Tags findings "PRIOR_FIX_ATTEMPT" when the cited file:line was
                modified in a prior production check commit (git log analysis).
                Routes findings by severity:
                
                CRITICAL/HIGH → ADVERSARIAL AGENT (1 agent per finding — 1:1)
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
                
                CRITICAL/HIGH from intersection or cross-domain integration review
                  (any finding spanning domain boundaries, regardless of whether
                  it originated in DISCOVER or REVIEW) → ADVERSARIAL CROSS AGENT
                  (1 agent per finding — 1:1). Same exhaustive falsification but verifies
                  from BOTH sides of the integration boundary (Domain A producer +
                  Domain B consumer + bridge between them). Finding only survives
                  if no counter-evidence on either side or in the bridge.
                
                MEDIUM → ADVERSARIAL AGENT (1 agent per batch of 5 findings)
                  Same exhaustive falsification methodology as CRITICAL/HIGH —
                  reads cited code with full surrounding context (minimum 30
                  lines), exhaustively searches for counter-evidence at every
                  level (same function guards, caller-level validation,
                  framework-level protections, type system invariants, test
                  coverage). Labels each CONFIRMED / REJECTED / WEAKENED with
                  evidence. Default position: assume the claimed issue is a
                  misunderstanding and search exhaustively before confirming.
                  Every CONFIRMED label must be hard-won with grep evidence.
                
                LOW → NOTED. Recorded in report. No further agent spend.
                
                After routing: SYNTHESIS (1 agent, default model) compiles all
                verdicts into unified grid. Surfaces "both-found" confidence signals.
                Surfaces PRIOR_FIX_ATTEMPT regression signals — file-level
                and function-level hotspot counts from extraction.
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
                Always runs when DISCOVER, REVIEW, RESEARCH, or post-fix review produced findings with code-level references.
                When CONFIRMED findings exist at MEDIUM+, FIX=DOMAINS must follow.

CONVERGE        Repeat DISCOVER, REVIEW, or RESEARCH for additional passes. Planner decides variant.
                Factors: ambiguity, codebase complexity, finding volume, production impact,
                change type, time sensitivity.
                 NONE: One pass. For well-understood, narrow work. Also appropriate
                       for codebases with comprehensive test coverage (>80%) and
                       clean module boundaries — first pass is unlikely to miss
                       meaningful issues. NONE is inappropriate for production
                       checks, audits, and security reviews — tasks whose purpose
                       IS comprehensive discovery require at minimum ONCE regardless
                       of test coverage or boundary cleanliness. The codebase
                       characteristics that favor NONE (clean boundaries, good
                       coverage) do not outweigh the task's fundamental purpose:
                       when the task itself is an audit, a single-pass specialist
                       will miss what an orthogonal specialist rotation would find.
                       NONE is also inappropriate for tasks touching a codebase
                       that has accumulated ≥5 prior production check runs — the
                       long tail of deep correctness issues in post-audit codebases
                       requires orthogonal specialist rotation to surface.
                 ONCE: One extra iteration if first pass found anything ("found
                       anything" means any iter 1 agent reported at least one
                       finding — regardless of whether it survived adversarial
                       verification; the point is different iter 2 specialists
                        re-examine what iter 1 noticed). Use when
                        the planner's Phase 1 research reveals interconnected modules,
                        dense coupling, non-uniform code patterns, or the stage deploys
                        12+ agents — characteristics suggesting a first pass may miss
                        issues. Also used when severity is HIGH/CRITICAL AND one
                       of: (a) total source LOC > 10K, (b) dense cross-module
                       coupling (5+ shared headers/interfaces across 3+ modules),
                       (c) non-uniform code patterns (mixed language paradigms,
                       FFI boundaries, legacy + modern code), (d) 4+ specialist
                       domains. Severity alone does not force ONCE — a 300-line
                       HIGH-severity bugfix on a small, clean codebase should use
                       NONE. ONCE is NOT the universal default — well-tested,
                       cleanly-structured codebases should use NONE.
                 LOOP: Up to 3 iterations, stop on empty report. For highly ambiguous
                       or production-critical work where missed findings would be
                       unacceptable.
                 
                 **CONVERGE for RESEARCH:** The spawn trigger for research
                 iterations differs from DISCOVER/REVIEW (which use "any
                 finding = spawn"). For RESEARCH, spawn iter 2 when any
                 research finding is rated LIKELY or lower (i.e., not
                 CONFIRMED) on a question that is critical to downstream
                 stages. Each iteration narrows scope: iter 1 asks "What
                 does [SPEC] require?" at broad scope; iter 2 asks
                 "What does [SPEC], Section X, Subsection Y specifically
                 require?" on the area where iter 1 was uncertain.
                 Research iterations inherit the same agent exclusion rules
                 (no agent .md reused across iterations).
                 
                 Iterations inherit ALL mandatory rules from the parent stage type
                (second opinions at MEDIUM+, intersection agents at triaged boundaries,
                DISCOVER/REVIEW → VERIFY pipeline, etc.). Intersection agents inherited
                by CONVERGE are ADDITIONAL agents, not replacements — the first DISCOVER
                stage must have its own intersection agents for ALWAYS/DEFAULT boundaries;
                CONVERGE iter 2 adds fresh intersection agents with different specialists.
                
                Each iteration gets its own VERIFY stage. Iter 1's VERIFY runs BEFORE
                iter 2 spawns — the synthesis grid from iter 1's VERIFY determines
                whether iter 2 spawns (any finding = spawn) AND provides PRIOR CONTEXT
                for iter 2 agents. Do NOT merge both iterations' verification into a
                single stage after both iterations complete. The plan structure must be:
                  Stage N:   DISCOVER iter 1
                  Stage N+1: VERIFY iter 1
                  Stage N+2: DISCOVER iter 2 (conditional, PRIOR CONTEXT from N+1)
                  Stage N+3: VERIFY iter 2
                
                The planner must list all agents per iteration with different
                specialists from the previous iteration — the lead spawns
                whatever the plan lists. Before writing iter 2, the planner MUST
                list every agent `.md` file used in iter 1 and exclude them all
                from iter 2 — no agent may appear in any role in both iterations.
                Swapping primary and second opinion roles between iterations does
                NOT count as different specialists. Using the same pair of agent
                `.md` files in opposite roles is still the same analytical
                framework. The exclusion list must be explicit in the plan.

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

                CONVERGENCE: If post-fix VERIFY produces CONFIRMED MEDIUM+
                findings in the synthesis grid, the fix is incomplete. Spawn a new
                fix pass (fix agents → post-fix review → conditional verify) for
                the confirmed findings. This repeats until post-fix review
                produces zero MEDIUM+ findings and VERIFY is skipped. The FIX
                brick is a convergence loop — one pass is never final when
                MEDIUM+ findings survive verification. When convergence is
                reached (post-fix review is clean), proceed to Delivery —
                convergence does not end the workflow.
├── NONE        No verified findings.
└── DOMAINS     1 fix agent per domain → post-fix REVIEW → conditional VERIFY.

TEST            Run build + test suite. Always single agent, default model (mechanical).
├── NONE        IMPLEMENT=NONE. Or planner skips with justification (no test infra).
└── FULL        1 agent. Runs build + tests, fixes failures.
```

##### Severity Assessment

The planner assesses severity by answering 5 specific YES/NO questions, each backed by one concrete code reference. The label is computed mechanically from the score — do NOT override.

| Level | Criteria |
|-------|----------|
| **None** | Score 0. No functional impact. Comment, formatting, variable rename. |
| **Low** | Score 1. Minor, immediately reversible. Dev tooling, internal logging, tests. |
| **Medium** | Score 2-3. User-facing, visible but contained. |
| **High** | Score 4. Core product function, data mutation, wide blast radius. |
| **Critical** | Score 5 (Q5=YES). Permanent harm possible — destruction of pre-existing assets, data loss that cannot be recovered from remaining inputs, secret exposure, auth bypass. |

Score 3 tiebreak: Q5=NO → MEDIUM. Q5=YES → HIGH (irreversible harm outweighs contained blast radius). Score 4 is always HIGH regardless of Q5 answer — the tiebreak does not apply to score 4.

See agentic-planner.md Phase 2 for the 5-question checklist. Base answers on code understanding, NOT keyword matching. A function named `validatePassword` that handles UI password strength scores 0-1 (Q2=NO, Q3=NO). A log statement in a payment module scores 0-1 unless the logging itself writes to persistent state.

##### Domain Splitting

When a task spans multiple domains, split in two steps. **Domain breadth is measured by distinct source-code specialists (languages, frameworks), not package count and not audit roles.** A task touching 5 Swift packages that all use `swift-pro` is single-domain. A task touching Python + TypeScript files is few-domain. Test-automator, documentation-pro, and security-reviewer are audit lenses on the same source code — they do not increase domain breadth.

1. **Split by specialist** — map each file/concern to the best specialist agent from `.opencode/agents/INDEX.md`
2. **Split by volume** — keep each discovery agent within these mechanical limits:
   - LOC ≤ 1,200 AND files ≤ 10 → **do not split.**
   - LOC > 1,500 OR files > 15 → **must split** (no exceptions — "cohesive code" does not override exceeding the caps).
   - 1,201 ≤ LOC ≤ 1,500 OR 11 ≤ files ≤ 15 → **split UNLESS:** (a) all files form a single cohesive module, AND (b) no individual file exceeds 200 LOC. If both conditions hold, do not split (with one-line justification). Otherwise, split.
   Discovery agents must read every file — a 20-line header costs the same context as a 200-line implementation file because the agent must understand the API and cross-reference every caller. These caps are calibrated from empirical data: agents at ~1,000 LOC find 3–4× more findings than agents at 5,000 LOC because they can hold cross-file contracts in active analytical memory. After splitting, re-count each resulting sub-group to verify none still exceeds the limits.

   **Post-split re-evaluation.** After mandatory splits, verify the resulting agents
   are not fragmented. If any sub-agent has fewer than 5 files AND fewer than 500 LOC,
   the split produced an under-utilized agent — standalone agents this small add
   coordination overhead without proportional audit depth. Merge sub-agents back into
   the parent domain and accept the parent as within the narrow cap instead.
   A 10f/800-LOC agent is better than two 5f/400-LOC agents that have almost nothing to
   audit. When file count exceeds the 15f cap but total LOC is under 500, the files
   are likely thin stubs — prefer accepting as within the narrow cap over splitting
   into fragments.

   **Scope overlap at integration boundaries.** When volume-splitting a large
   single-specialist domain, do NOT cut cleanly between architectural layers — that
   creates blind spots where no sub-agent reads the interface between them. Instead,
   design scopes that intentionally overlap: each sub-agent reads its core scope PLUS
   the integration-layer files that bridge to adjacent scopes. For a 200K LOC Python
   app with GPG, DB, Mail, and UI areas, the GPG sub-agent includes the GPG↔DB
   interface layer, the DB sub-agent overlaps to read the DB↔GPG storage layer and
   the DB↔Mail bridge. Each sub-agent traces BOTH sides of its adjacent integration
   points as part of its natural audit. The overlap files count toward both sub-agents'
   volume caps — factor this in when sizing scopes. Intersection agents in DISCOVER
   are required for boundaries between genuinely different specialists (Python↔C++,
   Rust↔TypeScript) where neither specialist can fully assess the other side's
   conventions, AND for same-specialist boundaries meeting ALWAYS-tier criteria
   (see Boundary Selection below).

   The planner provides FILE SCOPES (module-level descriptions, e.g. "GPG core:
   core/GPGHandler.py, core/gpg_utils/*.py") with exact LOC counts from Phase
   1 research (`wc -l`). The volume-splitter resolves every scope to exact individual file paths
   (using glob + find + test -f), runs wc -l for exact counts, produces a
   systematic volume audit table comparing each domain against the 1.2K/10f
   baseline and the 1.5K/15f narrow cap, applies the split rules mechanically,
   and writes the resolved KEY FILES + exact LOC counts into the plan file,
   preserving the planner's MUST ANSWER questions, domain descriptions, and
   agent assignments for each domain. The organizer then redistributes MUST ANSWER
   questions across split domains and validates structural compliance.

3. **Split implementation agents by edit density** — different from discovery volume splitting. Sequential edits on the same file accumulate context pressure linearly (agent re-reads, re-edits, re-tests the same code) causing edit amnesia: the agent forgets it already applied a change and tries to re-apply it. Two mechanical caps, counted from the synthesis grid's confirmed MEDIUM+ findings:
   - **Per-file cap:** no single file may carry more than 8 confirmed MEDIUM+ findings to one implementation agent. If a file exceeds 8, split that file's fixes across 2 agents by finding index.
   - **Per-agent cap:** no implementation agent may receive more than 12 confirmed MEDIUM+ findings across all files. If a domain exceeds 12 total, split into 2 agents by file/module.

##### Boundary Selection for Intersection Agents

The planner identifies domain adjacencies during Phase 1 research. **Domains are defined by specialist diversity**, not architectural layering. If all files in two groups map to the same specialist, they are ONE domain — split it by volume with overlapping scopes at integration boundaries (see step 2 split rules). Intersection agents in DISCOVER are mandatory for boundaries between DIFFERENT specialist domains (e.g., Python↔C++, Go↔Rust) where neither specialist can fully assess the other side's conventions, AND for same-specialist boundaries meeting the ALWAYS tier criteria below (5+ cross-boundary call sites in 3+ distinct modules; OR data format/encoding transformation at boundary; OR two distinct persistence mechanisms). At same-specialist ALWAYS boundaries, use a contract-tracing specialist (``backend-architect`` or ``code-reviewer`` — a **different** agent ``.md`` than the domain primary) to read both sides of the boundary plus one hop into each module. DEFAULT-tier same-specialist boundaries get intersection agents only when the project has 3+ domains in total.

Count cross-boundary references mechanically (grep imports/includes/FFI/API calls — exact counts, not estimates). Classify each boundary:

| Tier | Criteria | Action |
|------|----------|--------|
| **ALWAYS** | 5+ cross-boundary call sites in 3+ distinct modules; OR data format/encoding transformation at boundary; OR two distinct persistence mechanisms at boundary | Add intersection agent to DISCOVER and REVIEW |
| **DEFAULT** | 3-4 cross-boundary call sites in 2+ modules; OR error contract differs between producer and consumer at boundary | Add intersection agent to DISCOVER and REVIEW |
| **SKIP** | 1-2 cross-boundary call sites AND boundary bridged through a single well-understood mediator (e.g., standard library protocol layer, established framework convention) | Skip — domain primaries + second opinions sufficient |

SKIP boundaries require a one-line justification with the exact count
(e.g., "SKIP: Crypto×Network — 2 call sites, bridged by MailCore2 TLS").
Do not use "multiple" or "moderate" — always report exact call-site counts.

**Test consumption of source APIs is always SKIP.** Tests import and exercise source code through standard test frameworks (pytest, JUnit, MSTest). The test quality specialist already reads source code as part of assessing tests — a one-way consumer relationship, not a shared integration boundary. Do NOT add intersection agents for Source×Test; test-automator + code-reviewer already cover this seam.

**Rationale (from Run 4 empirical data):**

Intersection agents at high-coupling boundaries produce unique MEDIUM+ findings at
~1.4 agents per unique finding. At thin boundaries bridged by a single mediator
class, intersection agents add near-zero unique value (<20% precision, 0 unique
findings in Run 4). Triaging prevents wasteful agent spend at boundaries where
domain primaries and second opinions already provide sufficient coverage.

**Academic support:** Koru et al. (2007) established that highly coupled modules are
more defect-prone. Zhou et al. (2020) confirmed package coupling metrics predict
defect-proneness. An empirical study of interaction bugs in ROS-based software
(2025) found failures "often manifest at the boundaries between components."

##### Size Classification

The planner assesses scope along with severity. Size gates DISCOVER=NONE decisions.

| Size | Criteria |
|------|----------|
| **tiny** | Single file, single change, under 10 lines. Trivial fix, no structural impact. |
| **small** | Single module, few files. Well-scoped change with clear boundaries. Under ~10 source files and ~1.2K source LOC. |
| **medium** | Multiple modules, cross-file changes. Moderate scope, may touch different concerns. Under ~15 source files and ~1.5K source LOC. |
| **large** | Exceeds ~15 source files OR ~1.5K source LOC in any domain, OR spans multiple specialist domains (different languages/frameworks). Requires volume splitting. |

DISCOVER=NONE requires `size=tiny` (nothing to discover) OR `size=small` with planner-identified root cause at file:line. For `medium` and `large`, DISCOVER is mandatory.

##### Mid-Execution Amendment

After VERIFY produces confirmed findings at MEDIUM severity or above: if the manifest does not include IMPLEMENT, the lead auto-adds IMPLEMENT followed by FIX (which includes internal post-fix REVIEW + conditional VERIFY). This is unconditional — all confirmed MEDIUM+ findings are fixed regardless of task intent. LOW findings are reported but not auto-fixed.

When auto-adding IMPLEMENT or planning implementation stages from the synthesis grid, count confirmed MEDIUM+ findings per file. Apply the edit-density split (Domain Splitting step 3): if any single file carries more than 8 findings or any domain carries more than 12 total findings, split that domain's implementation into 2 agents.

After a FIX stage's post-fix VERIFY produces CONFIRMED MEDIUM+ findings in the synthesis grid: auto-add another FIX pass (fix agents → post-fix review → conditional verify). This repeats until post-fix review produces zero MEDIUM+ findings and VERIFY is skipped. This is mechanical — the FIX brick is a convergence loop, and surviving MEDIUM+ findings mean the fix was incomplete. IMPLEMENT already being in the manifest does not block this — FIX convergence re-entry is independent of the IMPLEMENT amendment.

**Implementation stages** use write → review structure:
```
  Stage N: Implementation — 1 agent per domain
    Agent writes code directly to original files.
  Stage N+1: Review — 1 agent per domain
    Reviews the implementation for bugs, quality, correctness.
  Stage N+2: Verification — severity-routed (extraction → adversarial [CRITICAL/HIGH 1:1, MEDIUM 1 per 5] → synthesis)
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
3. Where is verification in this plan? Confirm verification runs after every DISCOVER, REVIEW, and RESEARCH (code-ref findings) stage that produces findings, or mark it explicitly as SKIPPED with justification.

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
Common dependency patterns to watch: test-writer depends on implementer, fix-agent depends on reviewer, integration-tester depends on all implementers. In PLAN: volume-splitter depends on the planner's output, organizer depends on the volume-splitter's output. When in doubt, sequence — wasted time from a retry loop exceeds the cost of sequential execution.

**Session start:** Clean ALL stale workflow artifacts. Use two steps — explicit files first (shell-safe), then wildcard patterns via `find` (avoids zsh glob errors when no files match a pattern):

1. `rm -f tmp/glm-plan.md`
2. `find tmp/ -maxdepth 1 \( -name 'stage-*-synthesis.md' -o -name 'stage-*-iter-*-synthesis.md' -o -name 's[0-9]*-task.txt' -o -name 's[0-9]*-prompt.txt' -o -name 's[0-9]*-status.txt' -o -name 's[0-9]*-report.md' -o -name 'plan-review-*' \) -delete`
3. **Verify:** `ls tmp/` — confirm no stale workflow artifacts remain. If any survived, remove them manually before proceeding.

Also clear stale session checkpoints: `echo "# Session Memory" > session.md`

CAUTION: Never use broad patterns like `tmp/*-report.md` or `tmp/*-log.txt` — they will delete non-workflow files (e.g. `log-analysis-report.md`). Never delete `tmp/loop-runs/` — this directory contains permanent loop run logs and must be preserved across sessions. Agent names follow `s{digit}...` prefix (e.g. `s1-researcher`, `s2i1-reviewer-r2`), so `tmp/s[0-9]*` safely matches only workflow artifacts.

**Session boundaries:** Each session is independent — treat every task as a fresh start. Do not assume prior sessions' findings still hold. Every code change, even from previous sessions, requires fresh verification through the full workflow. Only reference prior sessions when the task explicitly asks you to. If task will likely need >4 stages, plan explicit session splits using the continuation protocol. Long sessions degrade from compaction pressure.

#### Agent Preparation

Consult `.opencode/agents/INDEX.md` for the full agent directory (112 agents grouped by domain). Pick the MOST specialized agent (see Agent Selection above) — a PostgreSQL task should use postgres-pro, not database-optimizer. The agent's domain checklists and anti-patterns are the primary value — they only work when the agent matches the domain.

For each agent in the current stage:

1. Define task with KEY FILES, CONTEXT, SCOPE, `WRITABLE FILES` (code agents only — list source files agent may edit), and `MUST ANSWER:` questions (mandatory — prompts without these are invalid). MUST ANSWER questions come from two sources: (a) the planner's manifest per-stage technical questions from Phase 1 codebase research, (b) for DISCOVER agents following a RESEARCH stage, the research report's `## Discovery Questions` section, copied verbatim. The lead may add 1-2 supplementary workflow-level questions (e.g., "Was the linter run?") but does not write code-level or spec-level technical questions. For RESEARCH agents: the YOUR TASK section MUST instruct the agent to include a `## Discovery Questions` section at the end of their report with 2-5 MUST ANSWER questions for downstream DISCOVER agents, each with inline spec quotes (see RESEARCH brick catalog for the format template). This instruction is the lead's responsibility — research agents only know their domain; they don't know the downstream handoff protocol unless the task file tells them.
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
   - **Implementation and Fix agents — mandatory pre-work reading:** The YOUR TASK section MUST instruct the agent to read the verification pipeline's synthesis grid report (full confirmed findings with adversarial evidence: grep results, call-chain traces, cross-file context) BEFORE writing any code. Include the exact file paths in the task (e.g., `tmp/sN-synth-report.md`). When the task involves specific finding IDs (e.g., "Fix finding F-03"), the agent MUST read that finding's full entry in the synthesis report — the lead's one-line PRIOR CONTEXT summary is navigational, not authoritative. The synthesis report is the authoritative source of finding details, evidence context, and original discovery analysis. For FIX convergence passes (re-fixes of surviving findings), also include the path to the prior-pass synthesis report so the agent can see what was already attempted and why it failed.
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
- Plan: `s0-planner`, `s0-volume`, `s0-organize`
- Research: `sN-research-{topic}`
- Discovery: `sN-discover-{domain}`, `sN-discover-2-{domain}` (second opinion),
  `sN-discover-{domainA}-{domainB}` (intersection, e.g., `s1-discover-crypto-services`)
- Implementation: `sN-impl-{domain}`, `sN-review-{domain}`, `sN-review-2-{domain}` (second opinion),
  `sN-review-{domainA}-{domainB}` (intersection, e.g., `s6-review-crypto-services`)
- Verification: `sN-extract`, `sN-adv-{domain}` (adversarial — 1:1 for CRITICAL/HIGH, 1 per 5 for MEDIUM), `sN-adv-cross` (cross-domain adversarial), `sN-synth`
- Fix: `sN-fix-{domain}`
- Test: `sN-test`
- Iterations: `s{N}i{K}-name` (e.g., `s2i1-researcher`, `s2i2-researcher`)
- Respawns: add `-r2`, `-r3` suffix when re-spawning a failed agent with corrected configuration (e.g., `s2i1-reviewer-r2` = stage 2 iteration 1 reviewer, respawn attempt 2). Maximum 3 respawn attempts per agent.

#### Second Opinion Guidelines

For DISCOVERY and REVIEW stages at MEDIUM+ severity, spawn a second opinion agent using a different agent `.md` from the INDEX. The two agents review the same code but through different analytical frameworks, producing complementary findings (proven: 87% complementarity across 5 language domains across 3 languages; 4-agent audit confirmed each additional agent type finds structurally distinct issues). PLAN always has an agent-organizer review (mandatory, all tasks) — see Planning phase step 3c. Agent selection is task-driven — the tables below show recommended defaults; the planner selects the best agents for the specific task based on codebase context.

**No domain exception:** The documentation-domain exceptions (skipping adversarial verification, accepting challenged downgrades directly) apply ONLY to the verification pipeline — how findings are routed and verified. They do NOT excuse documentation-domain DISCOVERY or REVIEW stages from the second-opinion requirement. MEDIUM+ severity → second opinion is unconditional across all domains.

#### DISCOVER pairings (defaults — planner may override)

For DISCOVER, the primary agent is typically the domain specialist who audits existing code. The second opinion is typically a code-reviewer providing a general quality lens. The planner may select different agents when the task warrants it — the table shows recommended defaults, not hard assignments.

| Context | Primary | Second Opinion |
|---------|---------|----------------|
| General code | domain specialist (`python-pro`, `swift-pro`, etc.) | `code-reviewer` |
| Auth/crypto | `security-reviewer` | `code-reviewer` |
| Infrastructure/config | `devops-engineer` | `code-reviewer` |
| Trivial / single-domain-small | skip | — (only when overall task severity < MEDIUM; the MEDIUM+ severity rule — "second opinion mandatory in all DISCOVER stages" — overrides this row) |

#### REVIEW pairings (defaults — planner may override)

For REVIEW, the primary agent is typically a code-reviewer assessing implementation quality. The second opinion varies by context to provide a complementary lens. The planner may select different agents when the task warrants it — the table shows recommended defaults, not hard assignments.

| Context | Primary | Second Opinion |
|---------|---------|----------------|
| General code | `code-reviewer` | language specialist (`python-pro`, `swift-pro`, etc.) |
| Auth/crypto | `code-reviewer` | `security-reviewer` |
| Infrastructure/config | `code-reviewer` | `devops-engineer` |
| System design / architecture | `code-reviewer` | `backend-architect` |
| Multi-language | `code-reviewer` | `backend-architect` (prefer splitting into per-language reviews with individual second opinions) |
| Trivial / single-domain-small | skip | — (only when overall task severity < MEDIUM; the MEDIUM+ severity rule — "second opinion mandatory in all REVIEW stages" — overrides this row) |

**Same-agent prohibition:** The second opinion agent MUST use a different `.md` file from the primary. Using the same agent `.md` twice — even with "different task scoping" — does not create a different analytical framework. Same checklists, same anti-patterns, same blind spots. The 87% complementarity effect depends on genuinely different agent expertise. If no different specialist can be found for a second opinion, split the review into smaller per-domain reviews where each can get a truly different second opinion.

**Task-framing guideline:** The task file for the second opinion agent uses the same KEY FILES as the primary but may add a domain-specific emphasis directive in the YOUR TASK section. Example: for `python-pro` reviewing OAuth code, add "Pay special attention to Python error handling patterns around I/O, binary data decoding, and data class validation." This costs zero tokens and amplifies the complementarity effect.

**Both-found confidence signal:** When a DISCOVERY or REVIEW stage used a second opinion, the subsequent extraction agent tags each finding as "both-found" (both agents reported independently) or "single-found" (only one agent reported). Both-found findings carry higher confidence — surface this in the synthesis grid.

#### Execution

1. Spawn current batch of agents via `spawn-glm.sh`, respecting the per-batch limit from Tools and the dependency analysis above. If stdout is empty (Windows `.cmd` issue), read `tmp/{NAME}-status.txt` to get PID. Checkpoint with PIDs and names. If stage has multiple batches, wait for current batch to finish before spawning next
2. `wait-glm.sh name1:$PID1 name2:$PID2 ...` — first progress at 30s, then every 60s, STALLED warnings, health check on finish
3. Do verification prep (for VERIFY stages): read the extraction agent's output, create verification task files per batch, assemble prompts. **Batch cross-check (MANDATORY):** Before spawning, verify that every batch the extraction report prescribes has a corresponding task file, and each task file targets the exact finding IDs from the extraction's batch assignment table (e.g., ADV-1 → B1-B4). A task file for different findings than prescribed does not satisfy the batch assignment. The extraction report is authoritative — the lead does NOT substitute finding targets.
4. **Review output.** Check operational status only — was the report produced? Is the log non-empty? Any STALLED markers? This is NOT quality review (do NOT evaluate findings, accuracy, or correctness). If ANY agent shows STALLED / EMPTY LOG / MISSING REPORT / EMPTY REPORT:
    - Diagnose root cause. Fix the issue (environment, prompt, task file, dependencies).
    - Re-spawn the agent with corrected configuration.
    - Do NOT proceed to the next stage with incomplete stage output.
    - Accept a gap and proceed ONLY for trivial gaps in discovery stages (e.g. a single agent in a 10-agent discovery stage failed after 3 respawn attempts with different approaches, AND its domain is partially covered by other agents). Every such decision must be explicitly justified in `tmp/glm-plan.md` with `STAGE GAP ACCEPTED: [domain] [reason] [coverage from other agents]`. Do NOT accept gaps in implementation or fix stages — those stages must produce complete, correct output. Do NOT silently skip failed agents.

#### Verification

Verification uses the severity-routed verification pipeline. The lead does NOT manually verify findings — that's the agents' job. The pipeline runs in batches with sequential dependencies:

**Batch 0: Extraction agent** (single, default model; use `research-analyst` agent `.md`). Reads all reports from the stage, extracts every finding with file:line and severity, deduplicates (same file:line + same issue → merge, note both sources), classifies each finding by severity, and splits into batches grouped by domain. When the originating stage (DISCOVERY or REVIEW) used a second opinion agent, tag each finding as "both-found" (both agents reported independently) or "single-found" (one agent only). When intersection agents were present, also tag findings as "boundary-found" (reported by an intersection agent auditing a domain boundary — inherently invisible to within-domain specialists) or "domain-only" (reported only by domain primaries/second opinions). Both-found and boundary-found carry elevated confidence for different reasons: both-found signals cross-agent agreement within a domain; boundary-found signals issues spanning domains that no within-domain specialist could have detected. A finding that is both "both-found" AND "boundary-found" carries the highest confidence. Surface all tags in synthesis.

When the codebase is a git repository with prior production check commits: for each finding, check whether the cited file:line was introduced or modified in a prior production check commit (`git log --all --format="%h %s" | grep -i "production\|check\|fix\|audit"`). Tag findings that fall on previously-fixed lines as `PRIOR_FIX_ATTEMPT: <commit-hash>`. A file with ≥3 PRIOR_FIX_ATTEMPT findings signals a repeat-regression hotspot — surface this count in the extraction report for synthesis routing. A function with ≥3 PRIOR_FIX_ATTEMPT findings clustered within ~40 lines (same logical block) signals a function-level regression hotspot — surface both file-level and function-level counts.

Findings from documentation specialist agents (documentation-pro) are domain-verified — route them directly to synthesis at the agent's rated severity, skipping adversarial verification.

**Mechanical trigger — MANDATORY:** If extraction finds any finding at MEDIUM severity or above, the lead MUST spawn ALL verification batches the extraction report prescribes — every adversarial batch, at the exact finding IDs listed in the extraction's batch assignment table. Spawning an adversarial agent against different findings than prescribed does NOT satisfy this trigger. The synthesis agent runs after all routing agents complete — even if every routed finding was REJECTED or WEAKENED. The lead does NOT evaluate routing agent outputs to decide whether synthesis is needed. The synthesis grid — not the lead's judgment — determines which findings are fixed. Skipping verification for MEDIUM+ findings is a protocol violation.

**Batch 1: Findings routed by severity.** All findings extracted by Batch 0 are routed:

- **CRITICAL/HIGH findings** → Adversarial agent (single agent per finding (1:1), default model). Tries to FALSIFY every finding: reads cited code with full surrounding context, exhaustively searches for counter-evidence (guards, validation, framework protections, type system invariants, test coverage), labels each CONFIRMED / REJECTED / WEAKENED with evidence. Adversarial methodology: assume the claimed issue is a misunderstanding and search exhaustively before confirming. Every CONFIRMED label must be hard-won with grep evidence.

- **CRITICAL/HIGH findings from intersection or cross-domain integration review** (any finding spanning domain boundaries, from DISCOVER or REVIEW) → Adversarial cross-domain agent (single agent per finding (1:1), default model). Same exhaustive falsification but verifies from BOTH sides of the integration boundary (Domain A producer + Domain B consumer + bridge between them). Finding only survives if no counter-evidence on either side or in the bridge.

- **MEDIUM findings** → Adversarial agent (single agent per batch of 5 findings, default model). Same exhaustive falsification methodology as CRITICAL/HIGH — reads cited code with full surrounding context, exhaustively searches for counter-evidence (guards, validation, framework protections, type system invariants, test coverage), labels each CONFIRMED / REJECTED / WEAKENED with evidence. Adversarial methodology: assume the claimed issue is a misunderstanding and search exhaustively before confirming. Every CONFIRMED label must be hard-won with grep evidence.

- **LOW findings** → NOTED. Recorded in the report. No further agent spend.

**Batch 2: Synthesis agent** (single, default model; use `research-analyst` agent `.md`). Reads all verdicts. Builds a cross-reference grid per finding using unified vocabulary:

| CONFIRMED | REJECTED | WEAKENED |
|---------------|--------------|---------------|
| → fix list | → dropped | severity downgraded → fix list at lower priority |

Surfaces "both-found" confidence signals from extraction — findings reported by both primary and second opinion agents carry higher initial confidence.

Surfaces PRIOR_FIX_ATTEMPT regression signals from extraction. When a file has ≥3 PRIOR_FIX_ATTEMPT findings, flag it in the synthesis grid as a repeat-regression hotspot. When ≥3 findings cluster within the same function (~40 lines), flag that function as a regressing function requiring a localized pre-fix audit. Fix agents for hotspot files and regressing functions receive an automatic second-opinion reviewer regardless of finding severity — these locations have a demonstrated pattern of incomplete fixes.

Also sanity-checks severity assignments against the severity classification criteria — if a finding's severity appears mismatched (e.g., "SQL injection" labeled MEDIUM), flag it as CHALLENGED. Challenged findings are re-routed through adversarial verification. Exception: documentation-domain challenged findings skip adversarial — documentation severity is inherently subjective (is "10 missing API docs" HIGH or MEDIUM?) and adversarial review of severity ratings adds no meaningful verification. Documentation-domain challenged findings stay at their challenged severity; the lead accepts the downgrade directly.

**If the synthesis grid shows zero CONFIRMED findings at MEDIUM or above** (all MEDIUM+ findings were REJECTED, all were DROPPED, or only LOW-severity survivors remain), FIX is SKIPPED — there is nothing significant to fix. LOW verified findings are acknowledged in the synthesis as non-blocking. The lead writes the synthesis with `FIX SKIPPED: Zero MEDIUM+ verified findings — nothing to fix.` This is mechanical — no lead judgment.

**Verification is MANDATORY** after every discovery, review (including cross-domain integration review), post-fix review, and RESEARCH stage whose findings include code-level references. Exception: stages producing findings without code-level references (web research, pure analysis, documentation reviews) — lead may mark verification as SKIPPED with explicit justification.

**Verification completion checklist — MANDATORY before marking a stage as done:**
  1. Extraction agent spawned and report produced
  2. If extraction found 0 findings → stage complete (early-exit)
  3. If extraction found MEDIUM+ findings:
     a. ALL adversarial batches from extraction's batch assignment table spawned — cross-check each ADV task file's finding IDs against the prescribed batch:finding mapping
     b. Synthesis agent spawned — compiles grid, sanity-checks severity
     c. Synthesis grid determines FIX=SKIPPED or FIX follows
  Skipping any step when MEDIUM+ findings exist is a protocol violation.

**Verification naming convention:**
- Extraction: `sN-extract`
- Adversarial pairs: `sN-adv-{domain}` (single agent per finding for CRITICAL/HIGH — 1:1; single agent per batch of 5 for MEDIUM)
- Adversarial cross: `sN-adv-cross` (single agent per finding — 1:1)
- Synthesis: `sN-synth`

#### Between Stages

1. Write `tmp/stage-N-synthesis.md` — verified results from the synthesis grid, decisions, context for next stage
2. **Mid-execution amendment (new findings):** If VERIFY produces confirmed findings at MEDIUM severity or above and IMPLEMENT is NOT in the manifest, the lead auto-adds IMPLEMENT followed by FIX (always 2-3 sequential stages: fix + post-fix review + conditional VERIFY). This is unconditional — all confirmed MEDIUM+ findings are fixed regardless of task intent. LOW findings are reported but not auto-fixed. This is mechanical — verify the condition, add the stages.
   **FIX convergence (incomplete fixes):** After a FIX stage's post-fix VERIFY produces CONFIRMED MEDIUM+ findings in the synthesis grid, auto-add another FIX pass regardless of whether IMPLEMENT is already in the manifest. IMPLEMENT presence does not block FIX convergence — surviving MEDIUM+ findings mean the fix was incomplete. Repeat until post-fix review produces zero MEDIUM+ findings and VERIFY is skipped. When convergence is reached, proceed to Delivery — convergence does not end the workflow.
   **Regression-aware fix scrutiny:** When the synthesis grid flags any file as a repeat-regression hotspot (≥3 PRIOR_FIX_ATTEMPT findings on the same file), that file's fix agent MUST receive a second-opinion reviewer — regardless of finding severity on that file. Files with a demonstrated pattern of incomplete fixes from prior production check runs require elevated review to break the fix-regress cycle.

   When the synthesis grid flags a regressing function (≥3 PRIOR_FIX_ATTEMPT findings clustered within ~40 lines of the same function), the lead spawns a single pre-fix audit agent BEFORE the fix stage. The audit agent:
   - Reads only the flagged function and its immediate context (the function body plus its callers in the same file — not the full module)
   - Reads the git history of prior failed fix attempts for that function
   - Produces a localized structural recommendation: extract a helper, consolidate duplicate guards, hoist a validation check — a change strictly within that function's own file, touching no public APIs or cross-file interfaces
   - The recommendation is advisory — the lead reviews it and decides "accept" or "skip"

   If accepted, the recommendation is included as additional input in the fix agent's task ("Apply this structural change, then fix the confirmed findings"). If rejected, or if the recommendation spans beyond the function's file, the fix proceeds with the second-opinion reviewer only — no structural change. The audit agent writes no code; the fix agent owns implementation. Recommendation-only, function-scoped, no cross-file interface changes.
3. If scope changed from original plan, update `tmp/glm-plan.md` with actual stages and revised goals
4. Checkpoint. Clean up: `rm -f tmp/sN-*-prompt.txt tmp/sN-*-task.txt`
5. Next stage prompts include synthesis as `PRIOR CONTEXT:` section. PRIOR CONTEXT is a navigation aid that guides the agent to complete source artifacts — it is NOT a replacement for reading agent reports. Structure it as: (a) file paths to agent reports the downstream agent MUST read before beginning work (synthesis grid with adversarial evidence, discovery reports with cross-file analysis, Intent sections from prior implementation), (b) one-line item counts for orientation (e.g., "3 MEDIUM confirmed findings, 2 LOW noted"), (c) lead-level decisions and constraints (what scope was decided, what was explicitly excluded). Do NOT flatten cross-file analysis, call-chain traces, adversarial grep evidence, or architectural reasoning from agent reports into PRIOR CONTEXT — point to the source report and trust the agent to read it. When a downstream agent receives a finding ID (e.g., "F-03: null dereference at auth.py:42"), the agent MUST read the synthesis grid report for the full finding with adversarial evidence and the original discovery report for cross-file context. Target under 50 lines total (navigation pointers + item counts + decisions). When PRIOR CONTEXT includes research findings, include their confidence tier and instruct downstream agents to check claims against code, not trust them blindly. **When passing research findings into discovery agents:** the lead copies the research report's `## Discovery Questions` section verbatim into the discovery agent's YOUR TASK as MUST ANSWER questions — zero lead interpretation, zero summarization, zero claim extraction. The research agent is the domain expert on the specification; it writes the questions with spec text quoted inline. The lead's only responsibility is to transport them untouched from the research report to the task file. Include the research report file path in PRIOR CONTEXT for reference.
6. Never re-do verified work unless evidence shows it was wrong
7. Never skip a planned stage without explicitly marking it in `tmp/glm-plan.md` as `SKIPPED` with a reason. A stage is only complete when its agents have been spawned, waited, their reports processed by the verification pipeline, and findings verified — incomplete stages cannot be proceeded past, outside the narrow gap-acceptance rules in Execution step 4. PLAN stages cannot be SKIPPED for speed or token savings — only for genuine blockers (environment failure, missing files, corrupted state).
8. After writing synthesis, read `tmp/glm-plan.md` to confirm the next stage. If the plan has remaining stages, execute them — do not deliver early unless remaining stages are explicitly marked SKIPPED.

**Iterative stages:** Between iterations, follow the Iterative Convergence protocol below — skip steps 1-5 until convergence is reached. On convergence, write final stage synthesis (step 1) and resume normal between-stages flow (steps 2-5).

#### Iterative Convergence

Some stages benefit from repeated runs until agents stop producing new meaningful output. What counts as "new output" depends on the stage purpose — new problems (audit), new information (research), new improvements (analysis), new risks (security), etc.

Convergence is mechanical: when ALL agents in an iteration produce zero new findings (empty reports, no new issues found), the stage has converged. A single non-empty report means the iteration produced output — iterate again. The lead does not subjectively judge whether findings are "meaningful enough" — any finding is meaningful.

**Planner-decided, not mandatory.** The planner selects NONE / ONCE / LOOP per stage based on task characteristics:

- **NONE**: One pass. For well-understood, narrow work. Also appropriate for codebases with comprehensive test coverage (>80%) and clean module boundaries — first pass is unlikely to miss meaningful issues.
- **ONCE**: One extra iteration if first pass found anything ("found anything" means any iter 1 agent reported at least one finding — regardless of whether it survived adversarial verification; the point is different iter 2 specialists re-examine what iter 1 noticed). Use when the planner's Phase 1 research reveals interconnected modules, dense coupling, non-uniform code patterns, or the stage deploys 12+ agents — characteristics suggesting a first pass may miss issues. Also used when severity is HIGH/CRITICAL AND one of: (a) total source LOC > 10K, (b) dense cross-module coupling (5+ shared headers/interfaces across 3+ modules), (c) non-uniform code patterns (mixed language paradigms, FFI boundaries, legacy + modern code), (d) 4+ specialist domains. Severity alone does not force ONCE — a 300-line HIGH-severity bugfix on a small, clean codebase should use NONE. ONCE is NOT the universal default — well-tested, cleanly-structured codebases should use NONE.
- **LOOP**: Up to 3 iterations, stop on empty report. For highly ambiguous or production-critical work where missed findings would be unacceptable.

Factors the planner considers: ambiguity, codebase complexity, finding volume from first pass, production impact of missed findings, change type (exploratory vs. mechanical), time sensitivity.

**Not used for:** Production stages (implementation and fixing) and verification stages. These produce or evaluate output rather than discovering issues. RESEARCH stages may use CONVERGE — the planner decides based on ambiguity and criticality of the research question.

**Mandatory rules apply:** CONVERGE iterations of DISCOVERY, REVIEW, or RESEARCH stages inherit ALL mandatory rules from the parent stage type — including second-opinion requirements at MEDIUM+ severity for DISCOVERY/REVIEW iterations. When the original DISCOVER/REVIEW required a second opinion agent, every CONVERGE iteration must also include a second opinion. The planner's decision table must list all agents to spawn per iteration — the lead spawns exactly what the plan lists.

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

**VERIFY between iterations (MANDATORY):** The plan must include a VERIFY stage
between every pair of CONVERGE iterations. The structure is:
  Stage N:   DISCOVER iter 1
  Stage N+1: VERIFY iter 1  (extraction → adversarial → synthesis)
  Stage N+2: DISCOVER iter 2 (conditional on N+1 synthesis, PRIOR CONTEXT from N+1)
  Stage N+3: VERIFY iter 2
Iter 1's VERIFY produces the synthesis grid that (a) determines whether iter 2
spawns (any finding = spawn) and (b) provides PRIOR CONTEXT for iter 2 agents.
Merging both iterations' verification into one stage after both complete is a
protocol violation — there is no way to know whether iter 2 should spawn, and no
PRIOR CONTEXT for iter 2 without iter 1's synthesis first.

#### Delivery

**Before delivery:** Read `tmp/glm-plan.md`. Confirm every planned stage is complete or explicitly marked SKIPPED with justification. A stage silently skipped = not delivered yet. Execute it or update the plan. If any code was changed during the fix stage — by fix-agents — confirm that post-fix review and verification both ran (verification runs only if review found new findings). Code changes without downstream verification are not deliverable. If any synthesis grid contains CONFIRMED findings, confirm knowledge harvesting ran and the report (`tmp/knowledge-harvest-report.md`) was produced. The user's task instructions (commit, push, report) are the final step after all stages complete — they do not override the mandatory stages that must run first.

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
- **Research/analysis:** synthesize into clear summary, preserving the research agent's confidence tier for each key finding. Do not present research findings as established facts unless they are CONFIRMED (≥2 independent sources); for LIKELY, TENTATIVE, or SPECULATIVE findings, state the tier explicitly in the delivery.
- Write `tmp/session-summary.md`: task goal, stages executed, total agents, agent aborts/failures, iterations per iterative stage, verification stats, key decisions, phase durations (planning, preparation, execution/wait, verification, synthesis)
- **Knowledge harvesting:** If any synthesis grid contains CONFIRMED findings, spawn a single `research-analyst` agent (default model). It reads all synthesis grids and discovery reports, classifies each CONFIRMED finding as PATTERN (the lesson generalizes beyond this fix) or INCIDENT (one-off specific fix), deduplicates against existing `knowledge.md` entries via `memory.sh search`, and for each PATTERN writes a `memory.sh add` entry (category: `gotcha` or `pattern`, tagged by domain — `numerical`, `concurrency`, `memory`, `ffi`, `io`). For each existing knowledge entry found by search, evaluate whether the current run's fix supersedes it: if yes, update or delete via `memory.sh`; if the entry references code not addressed by current findings, leave it untouched. Conservative: prefer silence over noise; never delete without clear evidence. The agent's report is written to `tmp/knowledge-harvest-report.md`. After the harvester completes, commit and push `knowledge.md` from the orchestrator's root (where `.opencode/` lives — the same `$REPO_ROOT` that `tmp/` paths resolve to) so harvested patterns survive the session. Skip the commit if `knowledge.md` is unchanged (all findings were INCIDENT with no knowledge updates).
- Cleanup: `rm -f tmp/s[0-9]*-prompt.txt tmp/s[0-9]*-task.txt`. Keep logs, reports, summary, knowledge-harvest-report

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
{Navigation aid per Between Stages step 5 — file paths to source reports the agent MUST read (synthesis grid, discovery reports, prior Intent sections), one-line item counts, lead decisions and constraints. NOT a replacement for reading agent reports. Target under 50 lines.}

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
| STALLED (flagged by wait-glm.sh) — planner, volume-splitter, or organizer | Do NOT kill. Read the log: if early activity exists (file reads, grep, wc -l), the agent is reading files in bursts — wait for the full Bash timeout. Stage 0 agents on large projects legitimately spend 5-10 minutes between visible tool calls. Only kill if zero bytes for 10+ minutes. |
| STALLED (flagged by wait-glm.sh) — other agent types | Kill process, read log to diagnose. Fix root cause. Re-spawn. Do NOT note gap and proceed. |
| Agent claims success but output wrong | Diagnose why output is wrong (bad prompt? misunderstood task?). Fix the prompt/task. Re-spawn the agent. Do NOT verify or fix the output yourself. |
| Incorrect edits | Diagnose why the agent produced wrong output (bad prompt? misunderstood task?). Fix the prompt/task. Spawn a quick-fix agent to revert and rewrite. Do NOT revert changes yourself. If the quick-fix agent is still wrong, diagnose the issue and retry once with corrected configuration. If the retry also fails: for HIGH/CRITICAL-adjacent changes, escalate to full IMPLEMENT → REVIEW → VERIFY; otherwise (LOW/MEDIUM or workflow-internal clutter), spawn a quick-fix agent to revert the change entirely — better to ship clean than to ship a broken fix. No direct work — the lead never edits project code. Quick-fix agents are the only exception to "every review must be verified." |
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

**Agent count per stage (MANDATORY — fill capacity by task decomposition):** Decompose the task into as many independent subtasks as it naturally splits into, spawn one agent per subtask, maximum 10 agents per batch. Default to what the task genuinely requires — scale to scope. Under-splitting agents creates a detection ceiling where agents can read but not deeply analyze cross-file contracts, producing fewer findings (empirically: agents at ~1K LOC find 3-4× more findings than agents at 5K LOC). The 10-agent-per-batch limit is a coordination constraint, not a quality limit. Verification stages scale with findings count and impact surface, not discovery agent count — minimum 1 extraction agent for every stage; adversarial agents run only if extraction finds at least one finding to falsify. When in doubt, decompose into more parallel agents — broader coverage finds more issues. **Never run sequential single-agent stages when those stages could be a single stage with parallel agents (see Workflow → Planning → Stage decomposition rule).**

**Prompts:** Include the FULL agent `.md` file — agents are optimized and every section earns its place. Do NOT trim or skip sections. Boilerplate (quality rules, severity guide, coordination, report format) comes from `.opencode/templates/` and is prepended before the agent .md for prompt-cache stability (stable shared content cached first, volatile content last). Agents don't load AGENTS.md — all context must be in prompt.

**Verification:** Every finding labeled. Every label backed by Read. 100% complete before proceeding. ALL verified actionable findings fixed via fix-agent — the lead does not fix findings directly.

**Lead code prohibition (MANDATORY):** The lead never writes, edits, or modifies project source code. Every code change — implementation, bug fixes, config adjustments, script changes, one-liners — goes through a spawned agent. The lead's tools (Edit, Write) are for tmp/ artifacts only: task files, prompts, synthesis reports. The only exception is editing AGENTS.md itself (meta-configuration).

**Platform:** `opencode` on all platforms (spawn-glm.sh handles invocation). Always redirect output to log files.
