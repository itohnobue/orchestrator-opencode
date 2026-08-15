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

**Path resolution:** All `tmp/` paths in workflow instructions resolve to `$REPO_ROOT/tmp/` where `$REPO_ROOT` is the absolute path to the repository root (the directory where `opencode` was launched). The tool scripts (`assemble-task.sh`, `glm-recover.sh`) compute `REPO_ROOT` and use absolute `${REPO_ROOT}/tmp/` paths so that agent reports, logs, and artifacts are always written to the correct location regardless of each agent's working directory or the project under inspection. When writing task files or instructions for agents, always reference `tmp/` paths relative to `$REPO_ROOT`.

---

## Agents

11 agents for OpenCode. Agents are stored in `.opencode/agents/` as Markdown files with YAML frontmatter. There are no static specialist personas — specialist identity comes from the research stage's FOCUS angles, not from agent files. `prepare-agent` is a single-session-suite agent, provided for the single-session-workflow skill — the orchestrator pipeline does not use it. `executor` is the universal executor used by both pipelines.

**Discovery:** Read `.opencode/agents/INDEX.md` for the full agent directory (11 agents). All execution uses the generic executor; workflow-internal agents run the pipeline (planning, verification, research).

| Agent | Role |
|-------|------|
| `agentic-planner` | Planning: classification, Research Coverage Map + Routing Table, per-agent tiers (PLAIN/POINTER/INJECT), FOCUS angles |
| `volume-splitter` | Mechanical KEY FILES resolution, split/merge (3K/3.5K caps) |
| `agent-organizer` | Structural plan review: tiers, routing precision, FOCUS complementarity, exclusion lists |
| `verification-analyst` | Extraction + synthesis + knowledge harvesting |
| `adversarial-reviewer-max` | Falsification gate for CRITICAL (1:1) and HIGH (1:3) finding batches (MAX effort); Findings-Review Mode |
| `adversarial-reviewer-high` | Falsification gate for MEDIUM (1:8) finding batches (HIGH effort); Findings-Review Mode |
| `web-searcher` | RESEARCH brick — internet research |
| `research-analyst` | RESEARCH brick — structured analysis; mid-execution research |
| `data-researcher` | RESEARCH brick — dataset research |
| `executor` | The ONE generic executor: DISCOVER, IMPLEMENT, REVIEW, FIX, TEST, TEST-UPDATE, quick-fix, build-gate, final gate, single-session tasks. High reasoning effort (max reserved for planner/adversarial). PLAIN or research-baked (routed report injected). No web research of its own. |
| `prepare-agent` | (single-session-workflow skill) Research generation for T2/T3 tasks: per-technology queries, one ≤15KB research-data file. FOCUS parameter defines the specialist identity. |

### Agent Selection

All execution → `executor`. Tier per the ONE general rule (PLAIN / POINTER / INJECT — see Tier rule). Research → web-searcher / research-analyst / data-researcher. Split hybrid tasks into subtasks with different FOCUS angles.

### The Tier rule (THE ONE general rule)

> **Every agent should have research data.** If the data is already gathered and covers everything the agent needs, we do NOT add a research stage — we run plain and pass the already-present data with the task. Research is injected only when the task depends on facts the file does not carry.

Operational meaning:
- **PLAIN** = pass-through mode: the task file ALREADY carries the research (planner-baked context, contracts, specs, expected behaviors, external facts). No injection needed — the data travels with the task. Never "no research".
- **INJECT / POINTER** = the file lacks needed facts; the research stage's report supplies them (injected into the prompt as `## RESEARCH DATA`, or pointed to via path + Discovery Questions).
- **Baseline:** researched. PLAIN is the optimization when the work is already done — not the default state of ignorance.

**Assemble-time tier verification (MANDATORY, lead — smart, surgical):** when assembling any PLAIN task file, check the rule's condition against the actual file, precisely:
1. Identify the SPECIFIC gap areas — which facts the executor needs are NOT carried by the task file. Not "the file is thin" — *which facts are missing*.
2. Check the routing table / research coverage map first — does an existing report cover the gap? Covered → route it (POINTER for supplementary areas, INJECT when the approach depends on it). Not covered → do NOT auto-generate research (no on-the-go research; the sole exception is the CONVERGE research extension): if the missing facts are internal to the codebase, proceed PLAIN with a "verify from code" note; if genuinely external AND critical, the mid-execution research rule applies (single ad-hoc agent, documented exception).
3. Never upgrade the whole tier for a partial gap — route/inject only what covers that area.
4. Never add research where the file already has the facts.

**Precision routing (MANDATORY):** each agent receives ONLY the research data it really needs — nothing unrelated (unrelated data degrades results). Applies to INJECT/POINTER reports AND to PLAIN task files (planner-baked context scoped to the agent's domain, never a global blob). One report per injection; supplementary areas ride as POINTER paths.

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

1. **ALL internet research must go through `web_search.sh`** — no exceptions. This means: no built-in websearch tool, no WebFetch tool, no `curl` against APIs, no manual GitHub API calls, no `wget` for search. Fetching a specific known URL goes through `web_search.sh --url <url>` (direct fetch mode, up to 50k chars) — the sanctioned way to get a named page when a search would be wasteful. Every time you need information from the internet, use `./.opencode/tools/web_search.sh "query"` (or `.opencode/tools/web_search.bat` on Windows)
   - **One query per call** — run each query as a separate `web_search.sh` invocation. Never combine multiple queries into a single call. Run calls **sequentially** (one after another, not in parallel) to avoid hitting API rate limits
   - **Fixed tuned defaults** — the tool has no count or format flags: search always fetches 30 results, fetches up to 20 pages, and outputs plain text only. The only flags are the source flags `--sci`/`--med`/`--tech` and `--url` direct fetch — never add count/result-limiting or output-format flags (they do not exist). Let the tool use its built-in defaults
   - **DIGEST + FULL REPORT FILE** — search mode prints a compact digest (stats line, FULL REPORT path, per-page previews) and writes the full filtered text to `tmp/webresearch/<run-id>.txt`. The report file IS the product — read or grep the file at the given path for the content you need (grep by URL or term). Never trim the digest with `tail`/`head`/`grep -m` or any other trimming — it is small and carries the FULL REPORT path: trimmed, you lose the link to the reference database. For a specific page's fresh content, fetch it directly with `--url`. The stats line also carries dropped-page counters (farm/stub/rerank/stale/dedup-dropped) when quality filters removed pages.
   - **Direct URL fetch: `--url`** — when you need a specific known page (URL from a search result, docs page, paper), use `web_search.sh --url <url>` instead of WebFetch/curl/wget (no query needed — the query is optional in this mode). Up to 50k chars per page, plain text. One URL per call.
   - **Scientific queries: add `--sci`** for CS, physics, math, engineering (arXiv + OpenAlex)
   - **Medical queries: add `--med`** for medicine, clinical trials, biomedical (PubMed + Europe PMC + OpenAlex)
   - **Tech queries: add `--tech`** for software dev, DevOps, IT, startups (Hacker News + Stack Overflow + Dev.to + GitHub)
   - **Empty results & timeouts are not tool failures** — a non-zero exit with a "No results: …" message on stderr means the query legitimately produced nothing usable (quality filters dropped every page, or all fetches failed) — retry with a different query angle. Each run is self-bounded by a 300s wall-clock timeout (env-overridable via `WEB_RESEARCH_TIMEOUT_SECONDS`); on timeout it exits non-zero with a "wall-clock timeout" message.
2. Synthesize results into a report

**Note**: Always use forward slashes (`/`) in paths for agent tool run, even on Windows.
Dependencies handled automatically via uv.

---

## Autonomy

The workflow is fully automatic and autonomous. The lead and every agent run the task to 100% completion without stops, questions, or continuations. Asking the operator for decisions is NOT part of this workflow.

**MANDATORY — applies to the lead AND every agent:**
- NEVER ask the operator questions, request approval or confirmation, or ask "should I continue?" — this includes the `question` tool. The operator is not part of the execution loop.
- NEVER pause waiting for a decision. Every decision is made on sight with best judgment; the decision and its reasoning are documented in the report (or in `tmp/` artifacts for the lead). Noting a decision for the operator is fine — asking them to make it is not.
- Ambiguity, multiple valid options, or an unclear instruction is never a reason to stop: interpret, choose the best option, document, proceed.
- Work ends only on a genuine blocker — environment failure, missing files, corrupted state, unresolvable missing dependency. Report the blocker and what remains.
- Any rule elsewhere (AGENTS.md, agent `.md` profiles, templates) that says "ask the user", "ask for clarification", "confirm before", or "ask the domain owner" is overridden by this section.

The same rule is baked into every agent prompt via the coordination templates (`.opencode/templates/coordination-*.txt`), so it reaches the lead and all subagents alike.

---

## Orchestration Workflow

Dynamic orchestration where the lead delegates everything to agents. The planner researches the project, classifies the task, and dynamically assembles a custom workflow from available bricks — selecting only the stages the task actually needs. The lead spawns agents according to the manifest, coordinates verification, and delivers results. **Automatic by default.**

The ONLY agent-delegation mechanism is the opencode `task` tool. The lead assembles a task prompt with `assemble-task.sh`, then calls the `task` tool with `subagent_type` set to the agent name from `.opencode/agents/`. The 11 agents are native opencode subagents, auto-loaded from `.opencode/agents/*.md`. Agents run as in-process child sessions with full permissions inherited from the project config.

### Agent Loading Rules

Agents folder: `.opencode/agents/`. Use agents for all non-trivial subtasks — code writing, analysis, design, debugging, testing, documentation.

**Rules:**
- Before any subtask: select the agent (executor for execution; research agents for research rows) and read its `.md` file (always fresh re-read)
- Load ONE agent at a time (Exception: Orchestration Workflow may read multiple for prompt building)
- All agent delegation goes through the `task` tool — see Tools → Agent Spawning
- Agent instructions are TEMPORARY — apply to current subtask only, discard after

**Discovery:** Glob `.opencode/agents/*.md` to list, Grep by keyword. All execution uses executor — the FOCUS angles and routed research define the specialist standpoint.

**How the lead uses agents:** The lead selects the agent by role from the INDEX (executor for execution; web-searcher/research-analyst/data-researcher for research rows), writes task files with KEY FILES, tier, and MUST ANSWER questions, and uses `assemble-task.sh` to build the task prompt (the agent's `.md` is auto-loaded by opencode as the subagent's system prompt). The lead does NOT load agent `.md` content into its own working context and never applies agent instructions itself. Agent `.md` files reach agents natively — opencode loads them for the `task` tool's `subagent_type`.

### Request Workflow

1. **Continuation:** `./.opencode/tools/memory.sh search "GLM-CONTINUATION"` — resume if exists
   - **If found:** Read `tmp/glm-continuation.md`, read prior synthesis, and continue from where the previous session left off. The plan is already finalized and partially executed — pick up at the next uncompleted stage.
   - **If not found:** Proceed to step 2.
2. **Re-read Verification and Iterative Convergence sections:** Before spawning ANY stage agents, re-read the Verification section AND Iterative Convergence section in full. Verification defines the severity-routed pipeline (extraction → route findings by severity → synthesis). Iterative Convergence defines the planner-set iteration ceiling (ONCE default / LOOP rare) and the mechanical synthesis-grid trigger (≥1 CONFIRMED HIGH/CRITICAL). Skipping these re-reads is the #1 cause of plans missing appropriate verification and convergence. MANDATORY.

   **Do NOT read source files, skim the project, or try to understand scope before spawning.** The planner is your research — spawn it immediately. Fill in the project path, spawn, and let the planner do everything else. Any attempt to "understand the codebase first" IS the research we forbid. Go directly to step 3.

3. **Planning phase (3 batches, 3 agents) — ALWAYS run, never skipped:**
   a. **Initial planner:** Copy `.opencode/templates/planner-task-template.txt`, fill in the project path (just the working directory — the planner researches the codebase itself), assemble with `assemble-task.sh -a agentic-planner -t research -n s0-planner`, then delegate via the `task` tool (subagent_type `agentic-planner`, prompt = read-and-execute instruction + path to the assembled file — see **Spawn** below). Researches the project, classifies the task on 5 axes (size, domains, ambiguity, severity, type), selects bricks from the palette, and produces a custom workflow manifest with FILE SCOPES to `tmp/glm-plan.md`.
   b. **Volume splitter (ALL plans):** Create a task targeting `tmp/glm-plan.md` with MUST ANSWER questions covering splits, merge-backs, and path verification. Include `WRITABLE FILES: tmp/glm-plan.md` in the task file. Assemble with `assemble-task.sh -a volume-splitter -t code -n s0-volume`, then delegate via the `task` tool (subagent_type `volume-splitter`). The volume-splitter resolves FILE SCOPES to exact KEY FILES with `wc -l` counts, applies mechanical split/merge rules, builds the volume audit table, rewrites the plan in-place, and writes `tmp/s0-volume-report.md`.
   c. **Mandatory plan review (ALL plans):** Create a review task targeting `tmp/glm-plan.md` with MUST ANSWER questions covering brick selection, severity classification, agent assignment, verification placement, convergence decisions, and dependency analysis. Include `WRITABLE FILES: tmp/glm-plan.md` in the task file. Assemble with `assemble-task.sh -a agent-organizer -t review -n s0-organize`, then delegate via the `task` tool (subagent_type `agent-organizer`). The agent-organizer reviews the plan using its structural analytical framework (the volume-splitter has already resolved KEY FILES and applied mechanical splits):

       *MUST ANSWER redistribution:* When the volume-splitter created sub-agents, the original MUST ANSWER questions were copied verbatim. The organizer redistributes them — assigning each question to the sub-agent whose scope covers the relevant code, writing new scoped questions when needed.

       *Workflow quality (native anti-patterns):* Check for stale agent references, ignored dependencies, missing intersection agents, FOCUS/exclusion-list violations, missing second opinions, and missing/incomplete tier assignments. The organizer FIXES mechanical violations directly in the plan — its anti-patterns list defines the Fix/Flag split (see agent-organizer.md).

       *Structural validation (embedded rules in task):* Verify every DISCOVER/REVIEW stage has a corresponding VERIFY. Verify IMPLEMENT stages have a corresponding REVIEW. Verify MEDIUM+ severity tasks have second opinions in ALL DISCOVER and post-implementation REVIEW stages, including CONVERGE iterations (post-fix REVIEW inside FIX is primary-only — do NOT require seconds there). Verify every s2 declares a complementary-FOCUS angle and has a routed in-scope research report. Verify FIX stages include the BUILD-GATE and post-fix REVIEW. Verify no FOCUS angle is reused across CONVERGE iterations (different iterations deploy genuinely different standpoints). If the plan specifies an exclusion list, mechanically cross-check EVERY iter 2 FOCUS angle against it — do NOT trust the plan's claim without verifying each slot. Verify the Routing Table is precise: every research-baked agent's routed reports are in-scope; no out-of-scope report is routed; PLAIN agents have no routed reports. When the task spans 2+ domains: verify the Boundary Analysis section exists, each boundary is triaged (ALWAYS/DEFAULT/SKIP), ALWAYS/DEFAULT boundaries have intersection agents in DISCOVER and cross-domain reviewers in REVIEW, and SKIP boundaries have one-line justification with exact call-site count. Verify domain breadth counts languages/frameworks, not packages. Volume splitting is handled by the volume-splitter before structural validation — do NOT duplicate here; spot-check for obvious errors and flag. Verify sequential stages are genuinely dependent — if stage N+1 does not consume stage N's verified output, flag for merge into a single parallel stage. Flag miscounts or over-large single-agent scopes.

       After review, the organizer applies all structural fixes directly to `tmp/glm-plan.md`. For judgment-level findings (see agent-organizer.md Fix/Flag split), the organizer flags them in its report but does not modify them — the lead reviews and decides during Step 4. The organizer's output IS the final plan — no separate merge agent is needed. This runs on EVERY plan — a bad plan poisons everything downstream regardless of severity.
4. **Review final plan:** Read `tmp/glm-plan.md`, confirm classification, brick selection, and stage structure are sound. Review the volume-splitter's audit report (`tmp/s0-volume-report.md`) for split correctness, merge-back decisions, and close-call justifications. Review the organizer's flag report — for each flagged judgment call: accept the flag and adjust the plan (spawn a quick-fix agent if needed), reject the flag with documented justification, or if uncertain revert to the planner's original decision (conservative default). Verify each stage's CONVERGE ceiling is sound (ONCE default; LOOP only with justification for highly ambiguous or production-critical work). Firing is mechanical — iterations spawn only when the prior VERIFY synthesis grid contains at least one CONFIRMED HIGH/CRITICAL finding. Do NOT require or forbid iterations based on task type (audit/production check) or codebase cleanliness — a clean first pass converges after one pass regardless, and a CONFIRMED HIGH+ finding triggers a rotation even on a "clean" codebase. If gaps remain, spawn a quick-fix agent to correct the plan.
5. **Decompose:** List subtasks from the plan, map each to best agent, report to user

**CRITICAL — Plan Display Rule:** After the planning phase completes and before spawning ANY stage agent, you MUST output the full stage plan as text to the user — see Workflow → Planning for the format. Writing the plan to `tmp/glm-plan.md` does NOT replace showing it. Display first, then proceed.

### Subtask Workflow

The lead's role in each subtask:
1. Select the best agent, read its `.md`, prepare the task file using the planner's KEY FILES and MUST ANSWER questions from the manifest. For DISCOVER agents that follow a RESEARCH stage: copy the research report's `## Discovery Questions` section verbatim into the YOUR TASK section — the research agent wrote them, the lead transports them untouched.
2. Assemble the task prompt via `assemble-task.sh`, delegate via the `task` tool (subagent_type = agent name)
3. Wait for the task tool result, check operational status (was the report produced? no EMPTY/MISSING?)
4. Delegate ALL substantive verification to the verification pipeline — the lead never evaluates output quality, judges findings, or assesses results
5. Save non-trivial discoveries to knowledge
6. Discard agent instructions, move to next subtask

**Mid-execution research:** When something is unclear during workflow execution (scope ambiguity, technical approach, a specific question the plan didn't cover), the lead may spawn a single unplanned agent using the default model to research that question. The lead chooses the exact agent for the job (e.g. `research-analyst`, `web-searcher`), prepares a prompt with the specific question and MUST ANSWER directives, and delegates via the `task` tool. Use the agent's report to clarify the next action. This is an ad-hoc clarifying agent — NOT a replacement for the planner pipeline, not a way to re-do planning, not a substitute for discovery stages. Limit to one agent per question. Do NOT use this to research things the lead could discover by reading source code — the lead does not read source code.

### When to Delegate

Delegation is the default.

**Why delegation produces better results:** A dedicated-context agent focused exclusively on one scope will find issues you would miss while context-switching between multiple concerns. For most non-trivial work, delegation maximizes correctness by giving each problem domain undivided analytical attention.

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

**Does:** delegate planning to the agentic-planner pipeline, review manifest, decompose, execute workflow stages from the manifest, write agent prompts, spawn agents, delegate verification according to manifest (adversarial verification: 1:1 for CRITICAL and cross-domain, 1 per 3 for HIGH, 1 per 8 for MEDIUM), spawn fix-agents and quick-fix agents, synthesize, deliver.

**Does not:** run the full test suite, do comprehensive audits unprompted, write, edit, or modify ANY project source code (even a single line), do any codebase research (reading source files, skimming files, tracing logic, discovering project structure), or design workflows from scratch (that's the planner's job). These are agent work.

**Lead success metrics:**
- **Success:** Decomposable subtasks went to agents. Findings were verified. The full mandated workflow ran to completion.
- **Failure:** You did any implementation work an agent should have done (writing, editing, or modifying code). You read raw domain data that would have been better isolated in an agent's context. You produced analysis without verification. You skipped, shortened, or altered mandated work.

**Context is not the lead's concern (MANDATORY — read this before everything):**
- Your context window is a platform resource managed by opencode (auto-compaction). It is not your problem to budget, conserve, or worry about. You never manage context.
- The workflow is designed so the platform's compaction safely compresses your context mid-run, and the checkpoint + continuation protocol restores full state — you (or a replacement lead) resume exactly where you left off. Running low on context is impossible to lose work over.
- Therefore, context pressure NEVER justifies deviation. There is no circumstance under which you skip, shorten, reduce, merge, or hand-construct work because of context. Not to save tokens, not to "finish faster," not to avoid overflow. If context runs low, the platform compacts and you continue — you do nothing special, and you never change the work.
- Any reasoning that includes "to save context", "context budget", "context-efficient", "to avoid reading X", or "this is too many agents" is a deviation trigger — you must NOT act on it. The correct action is exactly what the workflow says, unchanged.
- The only legitimate context-related action is following the normal checkpoint protocol (save after every step) — which you do anyway, as part of the workflow, not as a response to pressure.

**Self-check rules (MANDATORY) — run before working on ANY subtask:**
- The lead NEVER writes, edits, or modifies any project source file. The Edit and Write tools are for task files, prompts, and synthesis reports in tmp/ only. Any code change — even a single-line fix, a config tweak, or a build script adjustment — must go through a spawned agent.
- Heavy Read/Grep usage for verification coordination is expected and allowed (reading agent reports, building task files from synthesis output). For anything resembling planning or codebase research — never. Delegate to the planner pipeline immediately. Reading source files to understand the codebase is planner-agent work, not lead work.
- If the subtask is execution work → **DELEGATE it** to executor via the `task` tool (see Tools → Agent Spawning). Don't reproduce its work yourself

**Rule compliance — the lead NEVER:**
- Reclassifies or downgrades an agent's severity finding to avoid running a mandatory verification stage. The reviewer's filed severity is authoritative.
- Substitutes judgment for a mechanical trigger. "When X, do Y" means exactly that — the lead does not override with "X is true but Y seems unnecessary."
- Resolves ambiguity in workflow rules by choosing the interpretation that avoids work. When a term has multiple readings, the lead applies the reading that preserves verification and quality gates, not the one that saves agents.
- Deviates from any mandated rule, stage, trigger, or quality gate to save context, tokens, agents, or time. Context pressure, task size, finding volume, and "pragmatism" are NEVER reasons to reduce work. The full workflow runs exactly as specified, always (see Context is not the lead's concern above).

**Verification vs implementation boundary:**
- Verification (lead delegates): After stage agents complete, spawn the verification pipeline:

1. **Extraction agent** (single, default model): Reads all reports from the stage, deduplicates findings (same file:line + same issue → merge, note source), classifies each finding by severity, splits into batches grouped by domain and severity. When the originating stage (DISCOVERY or REVIEW) used a second opinion agent, tag each finding as "both-found" (both agents reported independently) or "single-found" (one agent only). When intersection agents were present, also tag findings as "boundary-found" (reported by an intersection agent auditing a domain boundary — inherently invisible to within-domain executors) or "domain-only" (reported only by domain primaries/second opinions). Both-found and boundary-found carry elevated confidence for different reasons: both-found signals cross-agent agreement within a domain; boundary-found signals issues spanning domains that no within-domain executor could have detected. A finding that is both "both-found" AND "boundary-found" carries the highest confidence. Surface all tags in synthesis.

When the codebase is a git repository with prior production check commits: for each finding, check whether the cited file:line was introduced or modified in a prior production check commit (`git log --all --format="%h %s" | grep -i "production\|check\|fix\|audit"`). Tag findings that fall on previously-fixed lines as `PRIOR_FIX_ATTEMPT: <commit-hash>`. A file with ≥3 PRIOR_FIX_ATTEMPT findings signals a repeat-regression hotspot — surface this count in the extraction report for synthesis routing. A function with ≥3 PRIOR_FIX_ATTEMPT findings clustered within ~40 lines (same logical block) signals a function-level regression hotspot — surface both file-level and function-level counts.

Findings from documentation work-type tasks (docs task type) are domain-verified — route them directly to synthesis at the agent's rated severity, skipping adversarial verification. If extraction finds 0 findings, VERIFY early-exits — nothing to verify, skip all subsequent batches.

    **Mechanical trigger — MANDATORY:** If extraction finds any finding at MEDIUM severity or above, the lead MUST spawn ALL verification batches the extraction report prescribes — every adversarial batch, at the exact finding IDs listed in the extraction's batch assignment table. Spawning an adversarial agent against different findings than prescribed does NOT satisfy this trigger. The lead does NOT pre-judge findings, skip verification steps, substitute finding targets, or decide which findings "don't matter." Only the synthesis grid determines FIX=SKIPPED. The synthesis agent is part of the pipeline — it MUST run after all routing agents complete, even if every routed finding was REJECTED or WEAKENED. The lead does NOT evaluate routing agent outputs to decide whether synthesis is needed. Proceeding to the next stage without completing all verification steps is a protocol violation.

2. **Findings routed by severity** (single-source routing):

   - **CRITICAL findings** → Adversarial agent (single agent per finding (1:1), default model; use `adversarial-reviewer-max` agent `.md`). The adversarial agent tries to FALSIFY every finding in its batch: reads cited code with full surrounding context (minimum 30 lines), exhaustively searches for counter-evidence at every level (same function guards, caller-level validation, framework-level protections — middleware, decorators, interceptors, global error handlers, type system invariants, test coverage), and labels each finding with evidence:

     * **CONFIRMED** — exhaustive search found NO counter-evidence. Describe what patterns were searched, which grep commands were run, why nothing was found.
     * **REJECTED** — found CLEAR counter-evidence that disproves the claim. Paste exact code with file:line.
     * **WEAKENED** — partial counter-evidence reduces severity or scope but doesn't fully disprove. State the correct severity.

      The adversarial agent assumes the claimed issue is a misunderstanding and searches exhaustively before confirming. For "missing X" findings, searching for X and finding it in no reachable code path IS valid evidence — document all searched locations. Every CONFIRMED label must be hard-won — superficial grep is not exhaustive. Surviving findings become ADVERSARIALLY VERIFIED.

   - **HIGH findings** → Adversarial agent (single agent per batch of 3 findings, default model; use `adversarial-reviewer-max` agent `.md`). Same exhaustive falsification methodology as CRITICAL findings — reads cited code with full surrounding context (minimum 30 lines), exhaustively searches for counter-evidence at every level (same function guards, caller-level validation, framework-level protections — middleware, decorators, interceptors, global error handlers, type system invariants, test coverage), and labels each CONFIRMED / REJECTED / WEAKENED with evidence. Default position: assume the claimed issue is a misunderstanding and search exhaustively before confirming. Every CONFIRMED label must be hard-won — superficial grep is not exhaustive. For "missing X" findings, searching for X and finding it in no reachable code path IS valid evidence — document all searched locations.

- **CRITICAL/HIGH findings from intersection or cross-domain integration review** (any finding spanning domain boundaries, from DISCOVER or REVIEW) → Adversarial cross-domain agent (single agent per finding (1:1), default model). Same exhaustive falsification but verifies from BOTH sides of the integration boundary (Domain A producer + Domain B consumer + bridge between them). Finding only survives if no counter-evidence on either side or in the bridge.

   - **MEDIUM findings** → Adversarial agent (single agent per batch of 8 findings, default model; use `adversarial-reviewer-high` agent `.md`). Same exhaustive falsification methodology as CRITICAL findings — reads cited code with full surrounding context (minimum 30 lines), exhaustively searches for counter-evidence at every level (same function guards, caller-level validation, framework-level protections — middleware, decorators, interceptors, global error handlers, type system invariants, test coverage), and labels each CONFIRMED / REJECTED / WEAKENED with evidence. Default position: assume the claimed issue is a misunderstanding and search exhaustively before confirming. Every CONFIRMED label must be hard-won — superficial grep is not exhaustive. For "missing X" findings, searching for X and finding it in no reachable code path IS valid evidence — document all searched locations.

   - **LOW findings** → NOTED. Recorded in the report. No further agent spend.

3. **Synthesis agent** (single, default model): Reads all adjudication verdicts. Builds a unified verification grid:

   | CONFIRMED | REJECTED | WEAKENED |
   |-----------|----------|----------|
   | → fix list | → dropped | severity downgraded → fix list at lower priority |

   Surfaces "both-found" confidence signals from extraction — findings reported by both primary and second opinion agents carry higher initial confidence.

   Surfaces PRIOR_FIX_ATTEMPT regression signals from extraction. When a file has ≥3 PRIOR_FIX_ATTEMPT findings, flag it in the synthesis grid as a repeat-regression hotspot. When ≥3 findings cluster within the same function (~40 lines), flag that function as a regressing function requiring a localized pre-fix audit (see Between Stages — the audit is advisory and lead-spawned; post-fix REVIEW is primary-only, no second-opinion reviewer). Hotspot flags are informational for the lead — these locations have a demonstrated pattern of incomplete fixes.

   If the synthesis grid shows zero CONFIRMED findings at MEDIUM or above (all MEDIUM+ findings were REJECTED, or only LOW-severity survivors remain), FIX is SKIPPED — there is nothing significant to fix. LOW verified findings are acknowledged in the synthesis as non-blocking. The lead writes the synthesis with `FIX SKIPPED: Zero MEDIUM+ verified findings — nothing to fix.` This is mechanical — no lead judgment.

Lead coordinates batches, never investigates findings manually, and writes the final synthesis from the synthesis agent's grid.
- Implementation (agent does): Writing/editing code, running test suites, fixing bugs, adding tests, refactoring
- After the verified checklist is produced, if many fixes are needed across many files: collect them into a fix-agent prompt and spawn

**Quick-fix agents:** For two specific scenarios — (1) agent output needs minor finishing, (2) reverting incorrect edits — spawn a single quick-fix agent (executor, PLAIN) using the default model. No verification pipeline — this is a quick, informal fix. If the fix is wrong, diagnose the issue (bad prompt? wrong tier?) and retry once with corrections. If the retry also fails: for HIGH/CRITICAL-adjacent changes, escalate to full IMPLEMENT → REVIEW → VERIFY; otherwise (LOW/MEDIUM or workflow-internal clutter), spawn a quick-fix agent to revert the change entirely — better to ship clean than to ship a broken fix. No direct work — the lead never edits project code. Quick-fix agents are the only exception to "every review must be verified."

**Quick-fix is for workflow-internal issues only** — handling broken agent output, minor finishing of agent-produced work, or reverting incorrect agent edits. Quick-fix agents are NOT a substitute for running the full workflow. For any task, no matter how small, the planner pipeline must run first. Quick-fix operates inside an existing workflow — never as a standalone replacement for planning, review, or verification.

**Workflow autonomy:** The lead runs the workflow to completion without waiting for user approval. The planner agent designs the initial workflow (stages, agents, verification placement); the lead reviews, adapts, and refines it — adding or modifying non-PLAN stages as understanding deepens during execution. Each stage follows the prepare → spawn → verify cycle. A stage is complete ONLY when ALL its agents have produced their expected output. A stage with failed or missing agents is incomplete — diagnose failures, fix root causes, re-spawn. Proceeding to the next stage with an incomplete current stage — outside the narrow gap-acceptance rules in Execution step 4 — is a protocol violation. The lead has full authority to adapt non-PLAN parts of the plan mid-execution. PLAN stages (3-agent planning pipeline) cannot be removed. DISCOVER, RESEARCH, IMPLEMENT, REVIEW, FIX, and TEST stages may be SKIPPED only when the planner's manifest explicitly marks them as NONE for the given task severity — never for speed or convenience. VERIFY is skipped when extraction finds 0 findings or when the lead may mark it as SKIPPED for non-code-level findings. Prior workflow runs do not excuse skipping — every code change requires fresh verification regardless of what previous sessions found.

### Tools

**Maximum 10 agents per parallel batch within a stage.** A stage that has independent subtasks SHOULD use as many parallel agents as the task naturally decomposes into — spawn only what the work requires. Under-splitting discovery agents (cramming too much code into one context) degrades quality by creating a detection ceiling — the agent can read everything but cannot deeply analyze cross-file contracts, producing fewer findings. Default to splitting discovery agents at the volume caps below; only merge sub-agents back when the post-split re-evaluation confirms the scope is truly trivial. When a stage genuinely needs more than 10 independent subtasks, split into sequential sub-batches within the stage. The 10-agent-per-batch limit is a coordination constraint, not a quality limit. Single-agent stages are normal for tightly-scoped implementation work; single-agent discovery stages are correct only for small domains (<3,000 LOC). Each agent is an independent unit; a stage is a parallel-batch boundary that may contain multiple agents. Implementation stages: a single agent writes code directly to original files, followed by a single review agent that reviews the result (see Agent Spawning). For multi-domain changes, one agent per domain writes in parallel.

**Spawn:**
```bash
.opencode/tools/assemble-task.sh -a executor -t TYPE -n NAME --task tmp/{NAME}-task.txt [--research-file tmp/research/R-xx.md]
```
Produces `tmp/{NAME}-task-prompt.txt` (templates + optional RESEARCH DATA injection + TASK ASSIGNMENT + WRITABLE FILES directive; the agent `.md` is auto-loaded by opencode). The `--research-file` flag injects a routed research report as the `## RESEARCH DATA` section (research-baked runs: s2, intersections, thin-context primaries). PLAIN runs omit it — the task file's context is the briefing. Then delegate via the `task` tool — pass the **file path** with a read-and-execute instruction, NOT the full content:
```bash
task(description="<3-5 words>", prompt="Read this file. Strictly follow instructions there and execute the described task: tmp/{NAME}-task-prompt.txt", subagent_type="executor")
```
The `task` tool runs the agent as a native opencode subagent (isolated child session, full project permissions). It blocks until the subagent completes and returns only its final summary to the lead. Report: `tmp/{NAME}-report.md` (the subagent writes it). Agents use the opencode default model unless the agent `.md` sets `model:`.

**Stage types and model usage** — all agents use the opencode default model unless their `.md` sets `model:`. To pin a subagent to a different model than the lead, add `model: provider/model-id` to the agent `.md` frontmatter (e.g. `model: deepseek/deepseek-v4-flash`); without it, the subagent inherits the invoking lead's model.

| Stage Type | Description |
|-----------|-------------|
| **Plan** (always runs) | Planner researches and produces the plan draft with FILE SCOPES. Volume-splitter (volume-splitter) resolves to exact KEY FILES, applies split/merge rules. Organizer (agent-organizer) reviews structural compliance, redistributes MUST ANSWER questions, produces final plan. All use default model. |
| **Research** (gather external information) | Gathers EXTERNAL facts beyond what the codebase provides — web search, documentation, standards, community knowledge, dataset analysis. Placed before DISCOVER when findings inform what to look for in code. Can run standalone for pure research tasks. Uses web-searcher, research-analyst, data-researcher (research producers — never receive research data themselves). Internal codebase facts are executor work, not research rows. Scales by topic specialization, not second opinions. VERIFY skipped for purely informational findings (no code-level refs). CONVERGE available for ambiguous/critical questions. |
| **Discovery** (review, audit, analysis of existing code) | Executor with dedicated context focused on one domain. When a stage has independent subtasks (different files, modules, concerns), spawn one agent per subtask — as many as the task naturally decomposes into, maximum 10 in parallel. At MEDIUM+ severity: research-backed s2 runs in parallel (executor, complementary-FOCUS report injected). |
| **Implementation** (write code) | Single agent writes code directly to original files. For multi-domain changes, one agent per domain writes to respective files in parallel. |
| **Review** (after implementation) | Reviews implementation for bugs, quality, correctness. Every implementation MUST be followed by a review agent. At MEDIUM+ severity: research-backed second opinion agent runs in parallel (executor, complementary-FOCUS report injected). (Post-fix review inside FIX is primary-only — no second opinions; see FIX brick.) |
| **Fixing** (fix verified findings) | Applies known fixes mechanically. Fix ALL confirmed findings from the synthesis grid. Every fix MUST be followed by a build-gate and a post-fix review agent; stale tests and missing regression tests route to a test-update agent after convergence. |
| **Adversarial verification** (falsification) | For CRITICAL findings — 1 agent per finding (1:1). For HIGH findings — 1 agent per batch of 3 findings. For MEDIUM findings — 1 agent per batch of 8 findings. All use exhaustive falsification: read cited code, search for counter-evidence at every level (same function, caller, framework, type system, tests). Label CONFIRMED / REJECTED / WEAKENED with evidence. Extraction and synthesis agents also default model. |
| **Test** (build + test suite) | Runs build and test commands, fixes compilation/test failures, reports results. |
| **Quick-fix** (minor finishing, reverts) | Short, informal fix for workflow-internal issues — fixing broken agent output or reverting incorrect edits. Not a substitute for the planning pipeline. No verification. If wrong, diagnose and retry once. If retry also fails: escalate to full IMPLEMENT → REVIEW → VERIFY for HIGH/CRITICAL changes; revert for everything else. |

**Wait:**
The `task` tool blocks until the subagent completes — no separate wait step. For parallel batches, issue multiple `task` calls in ONE message; all run concurrently and the lead receives all results together.

### Workflow

The planner designs the initial workflow, the lead reviews and adapts it. Typical flow: delegate to planner → review plan → for each stage in the manifest: prepare → spawn → wait → verify (severity-routed pipeline) → between stages → next stage. **Stages may be iterative (see Iterative Convergence).** The lead refines the plan and decides stage adjustments mid-execution.

#### Planning

**MANDATORY: Planner first, always.** The planning pipeline runs in full before any workflow begins. The lead does NOT research the codebase — the planner agent researches and produces the plan.

**Plan Display Rule:** After the planning phase completes and before spawning ANY stage agent, you MUST output the full stage plan as text to the user. Writing to `tmp/glm-plan.md` does NOT replace showing it. Display first, then proceed.

The lead's role in preparation:
0. If the user's request is vague, interpret it autonomously with best judgment — do NOT ask clarifying questions and do NO codebase research. State your interpretation and any assumptions in the plan so the planner can resolve scope. Clarifying the user's intent is a judgment call the lead makes on sight (per the Autonomy section above); reading source files (how to do it) is the planner's job.
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
    Agent: [executor — tier (PLAIN/POINTER/INJECT) + routed report IDs + FOCUS angles]
    Second Opinion: [s2 FOCUS angles if MEDIUM+; "N/A (severity < MEDIUM)" otherwise]
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

RESEARCH        Gather EXTERNAL information beyond what the codebase provides.
                (web, docs, standards, community knowledge). Internal
                codebase exploration is executor work — executors read code
                themselves; it is NOT a research row.
                The planner MUST add RESEARCH for every external reference
                that passes the precision criterion. A reference exists when
                the code:
                (a) calls a named API from an external standard or library,
                (b) uses a named standard's directives or pragmas,
                (c) reads/writes a named file format or protocol,
                (d) cites a named book or paper as an algorithmic source,
                or (e) selects behavior based on which named implementation
                is available. A formal spec URL is NOT required. The test:
                would verifying this code require knowledge of external
                documentation? If yes — candidate reference. Count mechanically
                from systematic codebase grep during Phase 1 — not from
                what you happen to notice in ad-hoc file reads.

                PRECISION CRITERION (applied per candidate, documented per
                decision): a candidate gets a research agent ONLY when
                verification requires external documentation the executor
                does not already possess. Two-part test:
                  1. NECESSITY: does verifying this code require external
                     documentation the executor lacks? (NO → no agent)
                  2. POSSESSED-KNOWLEDGE: would a research agent produce
                     anything beyond what the executor already possesses
                     (training + planner context)? (NO → no agent)
                Standard usage of a generic, well-documented library (e.g.
                numpy array ops, chardet.detect, stdlib) does NOT get a
                research agent — the executor possesses this; a
                research agent would only restate public docs and its
                Discovery Questions would add noise to discovery prompts.
                Named formats/protocols/standards (LAS, DEV, TLS, SQLite...)
                and named algorithms/papers DO get agents — byte-level
                compliance and external semantics are not in the executor's
                head. Each named version (e.g., "LAS 1.2" and "LAS 3.0")
                gets ITS OWN ROW — never consolidate distinct references or
                versions into one row. Every SKIP must be documented in the
                plan with a one-line reason (e.g., "numpy — standard usage,
                executor possesses"). The RESEARCH agent count is the
                number of rows that PASS the precision criterion.
                Research is cheap; missed external requirements are
                expensive. RESEARCH builds the reference library that
                DISCOVER agents consult. RESEARCH may be NONE when no
                reference passes the precision criterion (e.g. purely
                internal tasks drawing entirely from codebase knowledge).
                RESEARCH typically precedes DISCOVER
                (research findings become PRIOR CONTEXT for discovery
                agents who check code against external information) but
                the planner places it wherever the task structure demands.

                RESEARCH COVERAGE MAP + ROUTING: the planner's research
                manifest is the Research Coverage Map — every area any
                executor may need researched (External Reference Inventory
                PASS rows, codebase ecosystem, thin-context domains, planned
                s2 standpoints, planned intersection boundaries). Each row:
                `R-xx | topic | scope | agent | FOCUS angle`. The Routing
                Table maps agents → report IDs + tier (POINTER vs INJECT):
                every research-baked agent gets EXACTLY the reports covering
                its scope — nothing more (precision rule: unrelated data
                degrades results). PLAIN agents have no routed reports.

                Every research report MUST include a `## Discovery Questions`
                section at the end. This section contains 2-5 MUST ANSWER
                questions for the downstream DISCOVER agents, each with the
                relevant spec text or reference quoted inline so the
                discovery agent can verify against the actual specification
                without reading the full research report. Format:

                ```
                # Research Report: <R-xx slug>
                ## Report Scope: <domains/techs/references/files covered>   ← routing key
                ## FOCUS angle: <angle(s) this report was prepared from>
                ## Findings: facts, versions, best practices, pitfalls — confidence tiers, dated
                ## Provisional traps: known-good patterns as hypotheses to verify, never hard exclusions
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

                The planner selects research agents based on
                the research type needed — web-searcher (internet),
                research-analyst (structured analysis), data-researcher
                (datasets). Research agents are PRODUCERS — they never
                receive research data beforehand. Follows the same
                conventions as other discovery-oriented bricks: CONVERGE for
                ambiguous/critical questions, FOCUS/report exclusion across
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
│               Both are executor; the second opinion is research-baked
│               (INJECT) with a complementary-FOCUS report from the research stage.
└── MULTI       N agents, one per domain. Split by domain → volume
                (≤3,000 LOC/10f per agent — see Domain Splitting caps).
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
                either domain executor alone. Intersection findings are tagged
                "boundary-found" in extraction — signaling issues no within-domain
                executor could have detected. CRITICAL/HIGH findings from
                intersection discovery are routed through cross-domain adversarial
                verification (1:1 per finding, verifying from both sides of the
                boundary). Intersection agents MUST be placed in the first DISCOVER
                stage — never deferred to CONVERGE iterations. CONVERGE inherits
                the intersection requirement but adds ADDITIONAL agents with
                different FOCUS angles, not replacements for the first-stage ones.
                Intersection agents run in parallel with domain primaries and
                second opinions within the same stage. At MEDIUM+ severity: each
                intersection agent gets its own second opinion (a different
                FOCUS angle, not the same as the intersection's). Intersection
                agents audit gaps between domains — second opinions audit the
                intersection audit itself for missed concerns.

                Each intersection agent is executor, research-baked (INJECT)
                with a boundary-integrity FOCUS report covering both sides'
                conventions + bridge semantics. The planner specifies the boundary
                FOCUS per boundary (data-flow/contract tracing, crypto/auth
                boundaries, format integrity, etc.) — the research row's angle
                follows the boundary's nature.

IMPLEMENT       Write or modify code.
├── NONE        No code change (analysis-only, cosmetic-only).
├── SINGLE      1 agent per domain. Writes code directly to original files.
│               Standard for all code changes.
└── MULTI       N agents, one per domain. Split by domain → volume.

                SINGLE for narrow single-domain changes; MULTI for changes
                spanning multiple domains. Line count is not the measure —
                split by domain diversity, not file count.

REVIEW          Review code changes.
├── NONE        Skip: change type=cosmetic AND severity=none.
│               Or: IMPLEMENT=NONE.
├── SINGLE      1 agent per domain. Standard.
│               At MEDIUM+ severity: +1 second opinion agent per domain (parallel).
│               Both are executor; the second opinion is research-baked
│               (INJECT) with a complementary-FOCUS report (subject to the
│               2-run measurement gate — see Second Opinion Guidelines).
│               When the task spans 2+ domains OR has same-domain
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
                
                CRITICAL → ADVERSARIAL AGENT (1 agent per finding — 1:1)
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

                HIGH → ADVERSARIAL AGENT (1 agent per batch of 3 findings)
                  Same exhaustive falsification methodology as CRITICAL — reads cited
                  code with full surrounding context (minimum 30 lines), exhaustively
                  searches for counter-evidence at every level, labels each finding
                  CONFIRMED / REJECTED / WEAKENED with evidence. Default position:
                  assume the claimed issue is a misunderstanding and search
                  exhaustively before confirming. Findings that survive become
                  ADVERSARIALLY VERIFIED.

                CRITICAL/HIGH from intersection or cross-domain integration review
                  (any finding spanning domain boundaries, regardless of whether
                  it originated in DISCOVER or REVIEW) → ADVERSARIAL CROSS AGENT
                  (1 agent per finding — 1:1). Same exhaustive falsification but verifies
                  from BOTH sides of the integration boundary (Domain A producer +
                  Domain B consumer + bridge between them). Finding only survives
                  if no counter-evidence on either side or in the bridge.
                
                MEDIUM → ADVERSARIAL AGENT (1 agent per batch of 8 findings)
                  Same exhaustive falsification methodology as CRITICAL —
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
                (The documentation-domain exception is keyed to the DOCS WORK-TYPE —
                task type = docs — not to any agent.)
                Early-exit: 0 findings after extraction → skip synthesis.
                Always runs when DISCOVER, REVIEW, RESEARCH, or post-fix review produced findings with code-level references.
                When CONFIRMED findings exist at MEDIUM+, FIX=DOMAINS must follow.
                POST-FIX GRIDS: classify each CONFIRMED finding as CODE-FIX
                (code defect — re-triggers the fix pass) or TEST-UPDATE (test
                asserting pre-fix behavior — does NOT re-trigger the code-fix
                pass; routes to the TEST-UPDATE sub-stage after convergence).
                In convergence passes, compare against the prior pass's grid:
                a CONFIRMED CODE-FIX finding on the same function region
                (~40 lines) as a finding that already failed verification
                flags an in-run regressing function (N attempts).
                POST-FIX GRIDS also classify each CONFIRMED finding as
                fix-introduced vs new-mechanism (PRIOR_FIX_ATTEMPT lines)
                and report the ratio — the program's fix-quality metric.
                SYNTHESIS also categorizes every CONFIRMED finding by MECHANISM
                (validation gap, state-machine ordering, dispatch gap,
                cross-module divergence, error swallowing, etc.) — see
                Between Stages for the recurrence escalation rule.

CONVERGE        Repeat DISCOVER, REVIEW, or RESEARCH for additional passes. The planner
                sets the iteration CEILING; whether an iteration actually runs is decided
                MECHANICALLY by the prior VERIFY synthesis grid — never by planner choice
                and never by lead judgment. There is no CONVERGE=NONE: every DISCOVER and
                REVIEW stage is convergence-eligible, and a stage converges by failing the
                trigger, not by being opted out.
                Ceiling factors: ambiguity, codebase complexity, finding volume,
                production impact, change type, time sensitivity.
                CEILING — ONCE (default): at most 1 additional iteration.
                       Applies to every DISCOVER/REVIEW stage unless the planner
                       justifies a higher ceiling.
                CEILING — LOOP (rare): up to 3 additional iterations, each gated by the
                       same trigger. For highly ambiguous or production-critical work
                       where missed findings would be unacceptable.
                TRIGGER (mechanical — the ONLY way an iteration fires): the immediately
                       preceding VERIFY synthesis grid contains at least one CONFIRMED
                       finding at HIGH or CRITICAL severity (adversarially verified).
                       - REJECTED findings never trigger.
                       - WEAKENED findings trigger only when the corrected severity
                         remains HIGH+.
                       - Documentation-domain findings (which skip adversarial
                         verification) are EXCLUDED from the trigger — they cannot
                         cause an iteration to fire. (Keyed to the docs work-type.)
                       - A stage with zero CONFIRMED HIGH+ in its VERIFY grid is
                         CONVERGED after one pass, regardless of task type, codebase
                         cleanliness, or prior production-check history.
                 This replaces the old "any finding = spawn" trigger. The old rules that
                 forced CONVERGE>=ONCE on audits/production checks and on codebases with
                 >=5 prior production check runs are REMOVED: firing is purely a function
                 of the verified synthesis grid.
                 
                 **CONVERGE for RESEARCH:** The spawn trigger for research
                 iterations differs from DISCOVER/REVIEW (which use "any
                 CONFIRMED HIGH+ = spawn"). For RESEARCH, spawn iter 2 when any
                 research finding is rated LIKELY or lower (i.e., not
                 CONFIRMED) on a question that is critical to downstream
                 stages. Each iteration narrows scope: iter 1 asks "What
                 does [SPEC] require?" at broad scope; iter 2 asks
                 "What does [SPEC], Section X, Subsection Y specifically
                 require?" on the area where iter 1 was uncertain.
                 Research iterations inherit the same FOCUS/report exclusion rules
                 (no research report or FOCUS angle reused across iterations).
                 
                 Iterations inherit ALL mandatory rules from the parent stage type
                (second opinions at MEDIUM+, intersection agents at triaged boundaries,
                DISCOVER/REVIEW → VERIFY pipeline, etc.). Intersection agents inherited
                by CONVERGE are ADDITIONAL agents, not replacements — the first DISCOVER
                stage must have its own intersection agents for ALWAYS/DEFAULT boundaries;
                CONVERGE iter 2 adds fresh intersection agents with different FOCUS angles.
                
                Each iteration gets its own VERIFY stage. Iter 1's VERIFY runs BEFORE
                iter 2 spawns — the synthesis grid from iter 1's VERIFY determines
                whether iter 2 spawns (any CONFIRMED HIGH+ in the grid = spawn) AND
                provides PRIOR CONTEXT for iter 2 agents. Do NOT merge both iterations' verification into a
                single stage after both iterations complete. The plan structure must be:
                  Stage N:   DISCOVER iter 1
                  Stage N+1: VERIFY iter 1
                  Stage N+2: DISCOVER iter 2 (conditional, PRIOR CONTEXT from N+1)
                  Stage N+3: VERIFY iter 2
                
                The planner must list all FOCUS angles per iteration with different
                angles from the previous iteration — the lead spawns
                whatever the plan lists. Before writing iter 2, the planner MUST
                list every FOCUS angle/research report used in iter 1 and exclude
                them all from iter 2 — no angle may appear in any role in both
                iterations. Swapping primary and second opinion angles between
                iterations does NOT count as different standpoints. Using the
                same pair of FOCUS angles in opposite roles is still the same
                analytical framework. The exclusion list must be explicit in
                the plan.
                
                **RESEARCH EXTENSION on iterations:** when an iteration fires
                beyond the pre-baked coverage map (no unused FOCUS rows for its
                scope), the lead spawns ONE research agent per needed angle —
                fresh research on the spot, same research-producer rules, same
                report format, new FOCUS angle complementary to ALL prior
                iterations' angles. The fresh research then feeds the iteration
                per the tier rules. Bounded by the iteration CEILING — the
                ceiling remains the only stop; iteration depth is never
                research-blocked.

FIX             Apply verified findings. Always 3-4 sequential stages — includes build-gate and post-fix review.
                When DOMAINS: 1 fix agent per domain → BUILD-GATE
                (1 mechanical agent, default model: compiles the tree and runs
                the tests covering the changed files plus grep-derived test files
                importing changed modules; reports GATE PASS/FAIL with file:line
                attribution via `git diff`; modifies NOTHING — report-only
                tripwire; the sole exception to the per-agent parallel-safety
                rule — it runs the full suite solo, after the parallel batch
                completes) → post-fix REVIEW (primary-only per domain — NO
                second opinions, per Second Opinion Guidelines; cross-domain
                integration reviewers for triaged boundaries still apply),
                then VERIFY if any post-fix review report contains
                at least one finding at MEDIUM severity or above. Fix agents MUST
                self-verify their own changes before reporting (parallel-safe
                verification per quality-rules-code.txt: compile/syntax checks of
                changed files or targeted tests — never the full suite, which is
                the build-gate's job). A finding is any
                numbered item with a severity label and code reference (file:line,
                function, or block) in a reviewer's report. The lead does NOT
                re-classify, downgrade, or exclude findings — the reviewer's filed
                severity is authoritative. VERIFY is skipped ONLY when ALL post-fix
                review reports contain zero MEDIUM+ findings. Mechanical trigger,
                no judgment.

                GATE FAIL ROUTING: the lead attributes each failure to the
                responsible fix agent via the gate report's file:line mapping.
                Trivial compile errors (missing import, typo, unbalanced brace)
                go to a single quick-fix agent; logic/test failures route back to
                the responsible fix agent with the gate report as PRIOR CONTEXT.
                The gate then re-runs. ONE re-run is allowed; a second consecutive
                gate FAIL escalates to a full fix pass (synthesis-grid + prior-
                attempt context, standard post-fix protocol). The gate MUST PASS
                before post-fix REVIEW starts.

                GATE REPORT USE: the gate report is a workflow-internal artifact,
                not a finding source — no severity classification, no adversarial
                routing. Post-fix REVIEW agents receive a one-line gate status +
                report path in PRIOR CONTEXT (informational — the diff remains
                the review object).

                GATE SKIP RULES: no fix stage → no gate. No build/test infra
                (TEST=NONE justification) → gate skipped with the same
                justification. Machine-constrained repos (operator no-execution
                constraint): the gate runs bounded verification (changed targets
                only, `-j1`, memory caps) or reports `GATE NOT RUN: constraint`
                and the workflow falls back to the pre-gate protocol.

                CONVERGENCE: If post-fix VERIFY produces CONFIRMED CODE-FIX
                findings in the synthesis grid, the fix is incomplete. Spawn a new
                fix pass (fix agents → build-gate → post-fix review → conditional
                verify) for the confirmed CODE-FIX findings. This repeats until
                post-fix review produces zero CONFIRMED CODE-FIX findings and
                VERIFY is skipped. TEST-UPDATE findings (tests asserting pre-fix
                behavior) do NOT re-trigger the code-fix pass — they accumulate in
                the grid and route to the TEST-UPDATE sub-stage (below). The FIX
                brick is a convergence loop — one pass is never final when
                CODE-FIX findings survive verification. When convergence is
                reached (post-fix review is clean), proceed to TEST-UPDATE —
                convergence does not end the workflow.

                TEST-UPDATE (post-convergence sub-stage, execution-triggered):
                when the post-fix VERIFY grid contains TEST-UPDATE findings or
                CONFIRMED fixes lack regression tests, ONE agent (executor)
                updates the stale tests and
                writes regression tests pinning the CONFIRMED fixes. PRIOR
                CONTEXT = the full synthesis grid; WRITABLE FILES = the named
                test files; does NOT touch production code. Followed by a
                build-gate re-run and 1 review agent (no weakened pins, no scope
                creep; no adversarial pipeline for test-only changes). The final
                TEST brick remains the acceptance gate.
├── NONE        No verified findings.
└── DOMAINS     1 fix agent per domain → BUILD-GATE → post-fix REVIEW → conditional VERIFY → TEST-UPDATE (conditional).

                REGRESSION-AWARE FIX SCRUTINY (regressing regions): when the
                synthesis grid flags a regressing function (≥3 PRIOR_FIX_ATTEMPT
                findings clustered ~40 lines, OR in-run ≥2 consecutive failed fix
                attempts), the lead spawns a single pre-fix audit agent
                (executor, PLAIN) BEFORE the fix stage. The audit agent
                reads only the flagged function + its immediate context + the
                git history of prior failed attempts, and produces a localized
                structural recommendation (extract a helper, hoist a guard,
                consolidate a duplicate). MANDATORY: the fix agent MUST apply
                the recommendation or explicitly justify rejecting it in its
                report. Confirmed findings landing in a known regressing region
                are delivered as SINGLE-FINDING fixes with their own review —
                never batched with other findings in the same file.

TEST            Run build + test suite. Always single agent, default model (mechanical).
├── NONE        IMPLEMENT=NONE. Or planner skips with justification (no test infra).
└── FULL        1 agent. Runs build + tests, fixes failures.
                RUNTIME SMOKE GATE (production-check tasks where launch is
                feasible): after tests pass, build → install → launch the product;
                require it to reach a usable state and stay alive ≥2 minutes;
                check console for fatal signatures + crash-report directory
                before/after. Library equivalent: package imports cleanly + the
                primary API/CLI entry points execute one real round-trip against
                real fixture data. Project policy conflicts (e.g. "never launch
                the product") are documented as the explicit exception — the
                smoke gate is the one scoped override.
                TEST-OPTIMIZATION (optional phase for mature stabilization
                programs): audit the suite for vacuous/unreachable-body/
                fixed-sleep/non-discriminating/trivial-state-default tests and
                skipif-overuse; apply the PRECISE/VALUABLE/NOT-OVERGROWN bar;
                never delete revert-sensitive pins; mandatory final review/
                adversarial/fix over accumulated production findings.
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

When a task spans multiple domains, split in two steps. **Domain breadth is measured by distinct source-code specialists (languages, frameworks), not package count and not audit roles.** A task touching 5 Swift packages that all use the same language/framework is single-domain. A task touching Python + TypeScript files is few-domain. Audit lenses (test quality, security, documentation, performance) apply to the same source code — they do not increase domain breadth.

1. **Split by domain** — identify each file/concern's domain (language/framework/concern area). ALL execution uses executor; specialist identity comes from the research stage's FOCUS angles. Per-domain tiers (PLAIN/POINTER/INJECT) are assigned per the ONE general rule; research-baked domains get rows in the Research Coverage Map.
2. **Split by volume** — keep each discovery agent within these mechanical limits:
   - LOC ≤ 3,000 AND files ≤ 10 → **do not split.**
   - LOC > 3,500 OR files > 15 → **must split** (no exceptions — "cohesive code" does not override exceeding the caps).
   - 3,001 ≤ LOC ≤ 3,500 OR 11 ≤ files ≤ 15 → **split UNLESS:** (a) all files form a single cohesive module, AND (b) no individual file exceeds 200 LOC. If both conditions hold, do not split (with one-line justification). Otherwise, split.
   Discovery agents must read every file — a 20-line header costs the same context as a 200-line implementation file because the agent must understand the API and cross-reference every caller. After splitting, re-count each resulting sub-group to verify none still exceeds the limits.

   **Post-split re-evaluation.** After mandatory splits, verify the resulting agents
   are not fragmented. If any sub-agent has fewer than 5 files AND fewer than 1,200 LOC,
   the split produced an under-utilized agent — standalone agents this small add
   coordination overhead without proportional audit depth. Merge sub-agents back into
   the parent domain and accept the parent as within the narrow cap instead.
   A 10f/2,000-LOC agent is better than two 5f/1,000-LOC agents that have almost nothing to
   audit. When file count exceeds the 15f cap but total LOC is under 1,000, the files
   are likely thin stubs — prefer accepting as within the narrow cap over splitting
   into fragments.

   **Scope overlap at integration boundaries.** When volume-splitting a large
   single-domain scope, do NOT cut cleanly between architectural layers — that
   creates blind spots where no sub-agent reads the interface between them. Instead,
   design scopes that intentionally overlap: each sub-agent reads its core scope PLUS
   the integration-layer files that bridge to adjacent scopes. For a 200K LOC Python
   app with GPG, DB, Mail, and UI areas, the GPG sub-agent includes the GPG↔DB
   interface layer, the DB sub-agent overlaps to read the DB↔GPG storage layer and
   the DB↔Mail bridge. Each sub-agent traces BOTH sides of its adjacent integration
   points as part of its natural audit. The overlap files count toward both sub-agents'
   volume caps — factor this in when sizing scopes. Intersection agents in DISCOVER
   are required for boundaries between genuinely different languages/frameworks
   (Python↔C++, Rust↔TypeScript) where neither domain can fully assess the other
   side's conventions, AND for same-language boundaries meeting ALWAYS-tier criteria
   (see Boundary Selection below). Scope boundaries from volume splits are
   boundaries — apply the tier table mechanically. Format transformation between
   scopes (writer↔parser, encoder↔decoder) is ALWAYS tier.

   **Per-layer-then-sweep sequencing (large audit/production-check tasks):** for
   large codebases, prefer per-layer deep checks first (architectural layers:
   presentation, business logic, data access, models, infrastructure) to identify
   recurrence classes (patterns repeating across 5-25+ files), apply structural
   fixes for those classes, then run a full-codebase sweep for the algorithm-specific
   long tail. Never full-sweep first on an un-structuralized codebase — the sweep
   becomes dominated by recurrence-class instances that surgical fixes cannot close.

   The planner provides FILE SCOPES (module-level descriptions, e.g. "GPG core:
   core/GPGHandler.py, core/gpg_utils/*.py") with exact LOC counts from Phase
   1 research (`wc -l`). The volume-splitter resolves every scope to exact individual file paths
   (using glob + find + test -f), runs wc -l for exact counts, produces a
   systematic volume audit table comparing each domain against the 3K/10f
   baseline and the 3.5K/15f narrow cap, applies the split rules mechanically,
   and writes the resolved KEY FILES + exact LOC counts into the plan file,
   preserving the planner's MUST ANSWER questions, domain descriptions, and
   agent assignments for each domain. The organizer then redistributes MUST ANSWER
   questions across split domains and validates structural compliance.

3. **Split implementation agents by edit density** — different from discovery volume splitting. Sequential edits on the same file accumulate context pressure linearly (agent re-reads, re-edits, re-tests the same code) causing edit amnesia: the agent forgets it already applied a change and tries to re-apply it. Two mechanical caps, counted from the synthesis grid's confirmed MEDIUM+ findings:
   - **Per-file cap:** no single file may carry more than 8 confirmed MEDIUM+ findings to one implementation agent. If a file exceeds 8, split that file's fixes across 2 agents by finding index.
   - **Per-agent cap:** no implementation agent may receive more than 12 confirmed MEDIUM+ findings across all files. If a domain exceeds 12 total, split into 2 agents by file/module.

##### Boundary Selection for Intersection Agents

The planner identifies domain adjacencies during Phase 1 research. **Domains are defined by specialist diversity**, not architectural layering. If all files in two groups share the same language/framework, they are ONE domain — split it by volume with overlapping scopes at integration boundaries (see step 2 split rules). Intersection agents in DISCOVER are mandatory for boundaries between DIFFERENT language/framework domains (e.g., Python↔C++, Go↔Rust) where neither domain can fully assess the other side's conventions, AND for same-language boundaries meeting the ALWAYS tier criteria below (5+ cross-boundary call sites in 3+ distinct modules; OR data format/encoding transformation at boundary; OR two distinct persistence mechanisms). At same-language ALWAYS boundaries, use a contract-tracing executor (executor with a boundary-integrity FOCUS report — a different FOCUS angle than the domain primary) to read both sides of the boundary plus one hop into each module. DEFAULT-tier same-language boundaries get intersection agents only when the project has 3+ domains in total.

Count cross-boundary references mechanically (grep imports/includes/FFI/API calls — exact counts, not estimates). Classify each boundary:

| Tier | Criteria | Action |
|------|----------|--------|
| **ALWAYS** | 5+ cross-boundary call sites in 3+ distinct modules; OR data format/encoding transformation at boundary; OR two distinct persistence mechanisms at boundary | Add intersection agent to DISCOVER and REVIEW |
| **DEFAULT** | 3-4 cross-boundary call sites in 2+ modules; OR error contract differs between producer and consumer at boundary | Add intersection agent to DISCOVER and REVIEW |
| **SKIP** | 1-2 cross-boundary call sites AND boundary bridged through a single well-understood mediator (e.g., standard library protocol layer, established framework convention) | Skip — domain primaries + second opinions sufficient |

SKIP boundaries require a one-line justification with the exact count
(e.g., "SKIP: Crypto×Network — 2 call sites, bridged by MailCore2 TLS").
Do not use "multiple" or "moderate" — always report exact call-site counts.

**Test consumption of source APIs is always SKIP.** Tests import and exercise source code through standard test frameworks (pytest, JUnit, MSTest). The test scope executor already reads source code as part of assessing tests — a one-way consumer relationship, not a shared integration boundary. Do NOT add intersection agents for Source×Test; the executor covering the test scope already covers this seam.

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
| **small** | Single module, few files. Well-scoped change with clear boundaries. Under ~10 source files and ~3K source LOC. |
| **medium** | Multiple modules, cross-file changes. Moderate scope, may touch different concerns. Under ~15 source files and ~3.5K source LOC. |
| **large** | Exceeds ~15 source files OR ~3.5K source LOC in any domain, OR spans multiple domains (different languages/frameworks). Requires volume splitting. |

DISCOVER=NONE requires `size=tiny` (nothing to discover) OR `size=small` with planner-identified root cause at file:line. For `medium` and `large`, DISCOVER is mandatory.

##### Mid-Execution Amendment

After VERIFY produces confirmed findings at MEDIUM severity or above: if the manifest does not include IMPLEMENT, the lead auto-adds IMPLEMENT followed by FIX (which includes internal BUILD-GATE + post-fix REVIEW + conditional VERIFY + conditional TEST-UPDATE). This is unconditional — all confirmed MEDIUM+ findings are fixed regardless of task intent. LOW findings are reported but not auto-fixed.

When auto-adding IMPLEMENT or planning implementation stages from the synthesis grid, count confirmed MEDIUM+ findings per file. Apply the edit-density split (Domain Splitting step 3): if any single file carries more than 8 findings or any domain carries more than 12 total findings, split that domain's implementation into 2 agents.

After a FIX stage's post-fix VERIFY produces CONFIRMED CODE-FIX findings in the synthesis grid: auto-add another FIX pass (fix agents → build-gate → post-fix review → conditional verify). This repeats until post-fix review produces zero CONFIRMED CODE-FIX findings and VERIFY is skipped. This is mechanical — the FIX brick is a convergence loop, and surviving CODE-FIX findings mean the fix was incomplete. TEST-UPDATE findings (tests asserting pre-fix behavior) do NOT re-trigger the code-fix pass; they route to the TEST-UPDATE sub-stage after convergence. IMPLEMENT already being in the manifest does not block this — FIX convergence re-entry is independent of the IMPLEMENT amendment.

**Implementation stages** use write → review structure:
```
  Stage N: Implementation — 1 agent per domain
    Agent writes code directly to original files.
  Stage N+1: Review — 1 agent per domain
    Reviews the implementation for bugs, quality, correctness.
  Stage N+2: Verification — severity-routed (extraction → adversarial [CRITICAL 1:1, HIGH 1 per 3, MEDIUM 1 per 8] → synthesis)
```

**Fix agents** (docs, configs, scripts): use default model agents for code. Split fixes by domain — one agent per domain. Fix agents MUST self-verify their changes before reporting (parallel-safe verification per quality-rules-code.txt: compile/syntax of changed files or targeted tests — never the full suite; the build-gate runs it). Every fix stage MUST be followed by a build-gate and a post-fix review:
```
  Stage N: Fixes — N agents split by domain
  Stage N+1: Build-gate — 1 mechanical agent (compiles + runs tests covering changed files, report-only, GATE PASS/FAIL)
  Stage N+2: Post-fix review — N agents (1 per domain)
  Stage N+3: Verification — severity-routed (only if fix review found MEDIUM+ findings)
  Stage N+4: Test-update — 1 agent (only if TEST-UPDATE findings or missing regression tests; updates stale tests + writes regression tests for fixes; gate re-run + 1 reviewer follows)
```

**Delegation mapping (MANDATORY in every plan):** During planning you MUST answer:
1. What subtasks exist? (list each one)
2. Which agent handles each subtask? (map agent name to subtask — all execution → executor with the tier (PLAIN/POINTER/INJECT) + routed report IDs + FOCUS angles from the manifest)
3. Where is verification in this plan? Confirm verification runs after every DISCOVER, REVIEW, and RESEARCH (code-ref findings) stage that produces findings, or mark it explicitly as SKIPPED with justification.

Answer these explicitly in your plan. Every subtask must have an assigned agent — no subtask goes to the lead.

**Stage decomposition rule (MANDATORY):** If stage N+1 does NOT consume stage N's verified output — they're independent — MERGE them into a single stage with parallel agents. Sequential stages are only correct when the next stage actually needs the previous stage's verified findings as `PRIOR CONTEXT:`.

Write full plan to `tmp/glm-plan.md`. All agents use the opencode default model (or their `.md` `model:` override). Quick-fix agents (see Lead Role) are always single-model but run outside the plan's stage structure — they handle agent output issues within an existing workflow, never as a standalone workflow replacement. Checkpoint.

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
2. `find tmp/ -maxdepth 1 \( -name 'stage-*-synthesis.md' -o -name 'stage-*-iter-*-synthesis.md' -o -name 's[0-9]*-task.txt' -o -name 's[0-9]*-task-prompt.txt' -o -name 's[0-9]*-report.md' -o -name 'plan-review-*' \) -delete`
3. **Verify:** `ls tmp/` — confirm no stale workflow artifacts remain. If any survived, remove them manually before proceeding.

Also clear stale session checkpoints: `echo "# Session Memory" > session.md`

CAUTION: Never use broad patterns like `tmp/*-report.md` or `tmp/*-log.txt` — they will delete non-workflow files (e.g. `log-analysis-report.md`). Never delete `tmp/loop-runs/` — this directory contains permanent loop run logs and must be preserved across sessions. Agent names follow `s{digit}...` prefix (e.g. `s1-researcher`, `s2i1-reviewer-r2`), so `tmp/s[0-9]*` safely matches only workflow artifacts.

**Session boundaries:** Each session is independent — treat every task as a fresh start. Do not assume prior sessions' findings still hold. Every code change, even from previous sessions, requires fresh verification through the full workflow. Only reference prior sessions when the task explicitly asks you to. If task will likely need >4 stages, plan explicit session splits using the continuation protocol. Long sessions degrade from compaction pressure.

#### Agent Preparation

Consult `.opencode/agents/INDEX.md` for the full agent directory (11 agents). All execution uses `executor` — specialist identity comes from the research stage's FOCUS angles and the routed research reports, not from agent personas.

For each agent in the current stage:

1. Define task with KEY FILES, CONTEXT, SCOPE, tier (PLAIN/POINTER/INJECT per the ONE general rule), `WRITABLE FILES` (code agents only — list source files agent may edit), and `MUST ANSWER:` questions (mandatory — prompts without these are invalid). MUST ANSWER questions come from two sources: (a) the planner's manifest per-stage technical questions from Phase 1 codebase research, (b) for DISCOVER agents following a RESEARCH stage, the research report's `## Discovery Questions` section, copied verbatim. The lead may add 1-2 supplementary workflow-level questions (e.g., "Was the linter run?") but does not write code-level or spec-level technical questions. For RESEARCH agents: the YOUR TASK section MUST instruct the agent to include a `## Discovery Questions` section at the end of their report with 2-5 MUST ANSWER questions for downstream DISCOVER agents, each with inline spec quotes (see RESEARCH brick catalog for the format template). This instruction is the lead's responsibility — research agents only know their domain; they don't know the downstream handoff protocol unless the task file tells them.
2. Write the TASK ASSIGNMENT block (PROJECT, ENVIRONMENT if code, PRIOR CONTEXT if stage 2+, YOUR TASK, WRITABLE FILES) to `tmp/{name}-task.txt`. NOTE: Do NOT include the report file path in WRITABLE FILES — the script auto-injects `tmp/{NAME}-report.md` automatically.
3. Assemble the task prompt:
   ```bash
   .opencode/tools/assemble-task.sh -a executor -t TYPE -n NAME --task tmp/{name}-task.txt [--research-file tmp/research/R-xx.md]
   ```
    Types: `review` (coordination-review + severity + quality-rules-review), `code` (coordination-code + quality-rules-code), `research` (coordination-review + quality-rules-review). The `--research-file` flag injects the routed research report as the `## RESEARCH DATA` section (INJECT runs: s2, intersections, thin-context primaries). POINTER runs assemble plain — the report path rides in PRIOR CONTEXT. The script selects templates, substitutes `{NAME}` in the task file content, and writes `tmp/{name}-task-prompt.txt`. Output: `ASSEMBLED|name|path|bytes`. The agent `.md` is NOT embedded — opencode loads it natively as the subagent's system prompt.
4. **Validate task prompt contains ALL:** TASK ASSIGNMENT with MUST ANSWER questions, quality rules, severity guide (review only), environment (code only), coordination, report format. The script handles all boilerplate automatically — you only own the task file. The agent `.md` is auto-loaded by opencode. Missing ANY = do not spawn
5. Match agent type to task: all execution → executor. **Git/history analysis** (blame, log, diff, tracing fixes through commits) → `research-analyst` or executor
6. **WRITABLE FILES:** Code agents: task file MUST list the exact source files/directories the agent may modify. Review/audit/research agents: omit WRITABLE FILES entirely — the script auto-injects the correct report path and marks all source files as read-only.
   - **Implementation agents:** WRITABLE FILES must list the exact source files the agent may modify directly. The task must instruct them to produce their implementation and run the mandatory parallel-safe verification (per quality-rules-code.txt: compile/syntax check of changed files or targeted tests — NEVER the full suite; the build-gate/TEST stage runs it). The task MUST also instruct them to write an Intent section in their report before coding: a description of their understanding of the task and their intended approach, in their own words, at whatever level of detail they think is useful for the reviewer. The agent decides what to communicate — architectural reasoning, assumptions about the codebase, trade-offs considered, alternatives rejected, or anything else that helps someone else understand why they built what they built. This is the first thing they write, before any code.
   - **Implementation and Fix agents — mandatory pre-work reading:** The YOUR TASK section MUST instruct the agent to read the verification pipeline's synthesis grid report (full confirmed findings with adversarial evidence: grep results, call-chain traces, cross-file context) BEFORE writing any code. Include the exact file paths in the task (e.g., `tmp/sN-synth-report.md`). When the task involves specific finding IDs (e.g., "Fix finding F-03"), the agent MUST read that finding's full entry in the synthesis report — the lead's one-line PRIOR CONTEXT summary is navigational, not authoritative. The synthesis report is the authoritative source of finding details, evidence context, and original discovery analysis. For FIX convergence passes (re-fixes of surviving findings), also include the path to the prior-pass synthesis report so the agent can see what was already attempted and why it failed.
   - **Review/audit/research agents:** omit WRITABLE FILES entirely — the script auto-injects the correct report path and marks all source files as read-only.
Describe problems and desired behavior — do NOT paste exact fix code unless precision is critical (regex, API signatures, security logic). Name agents with stage prefix: `s1-researcher`, `s2-impl-auth`.

#### Agent Spawning

All agents use the opencode default model. The `-m` flag is not used — to pin a subagent to a different model than the lead, add `model: provider/model-id` to the agent `.md` frontmatter; without it, the subagent inherits the invoking lead's model.

**How it works for review/research/audit stages:**
1. A single agent gets the agent `.md` (auto-loaded) and the task assignment — it works independently
2. When a stage has independent subtasks (different files, modules, concerns), spawn one agent per subtask in parallel — as many as the task naturally decomposes into, maximum 10 agents
3. Each agent's report feeds into the verification pipeline (see Verification section)
4. **Naming convention:** `sN-name`, e.g. `s1-reviewer`, `s2i1-researcher` (stage 2, iteration 1)

**How it works for implementation stages:**
1. **Write step:** A single agent writes the implementation directly to the original files. The agent reads the full task, understands the requirements, and produces a complete implementation.
2. **Review step:** A single review agent reviews the implementation — same task description, independent assessment.
3. **Fix and iterate:** The review report is processed by the verification pipeline to produce a verified checklist. ALL verified findings are fixed via fix-agents split by domain. The lead does NOT fix findings directly, regardless of how few or how trivial. Every fix MUST be followed by a build-gate and a post-fix review agent. Every review MUST be followed by verification — review findings are not deliverable until they've been verified. The review → fix → re-review loop iterates until the post-fix review produces zero CONFIRMED CODE-FIX findings — this FIX-brick convergence is the final gate; TEST-UPDATE findings route to the test-update agent after convergence.

**Spawn:**
```bash
# Assemble task prompt (agent .md is auto-loaded by opencode)
.opencode/tools/assemble-task.sh -a executor -t TYPE -n NAME --task tmp/{NAME}-task.txt [--research-file tmp/research/R-xx.md]
# Delegate via the task tool — pass the file path with a read-and-execute instruction
task(description="<3-5 words>", prompt="Read this file. Strictly follow instructions there and execute the described task: tmp/{NAME}-task-prompt.txt", subagent_type="executor")
```

**Prompt assembly:** Assemble ONE task prompt per agent via `assemble-task.sh`:
```bash
.opencode/tools/assemble-task.sh -a executor -t TYPE -n NAME --task tmp/task.txt [--research-file tmp/research/R-xx.md]
```
Types: `review` (coordination-review + severity + quality-rules-review), `code` (coordination-code + quality-rules-code), `research` (coordination-review + quality-rules-review). The agent `.md` is auto-loaded by opencode.

**Implementation spawn pattern:**
```bash
# Write step
.opencode/tools/assemble-task.sh -a executor -t code -n sN-impl --task tmp/sN-impl-task.txt
# Delegate via task tool (subagent_type executor)
# Review step (delegate AFTER write completes)
.opencode/tools/assemble-task.sh -a executor -t review -n sN-review --task tmp/sN-review-task.txt
```

**Naming convention overview:**
- Plan: `s0-planner`, `s0-volume`, `s0-organize`
- Research: `sN-research-{topic}`
- Discovery: `sN-discover-{domain}`, `sN-discover-2-{domain}` (second opinion),
  `sN-discover-{domainA}-{domainB}` (intersection, e.g., `s1-discover-crypto-services`)
- Implementation: `sN-impl-{domain}`, `sN-review-{domain}`, `sN-review-2-{domain}` (second opinion),
  `sN-review-{domainA}-{domainB}` (intersection, e.g., `s6-review-crypto-services`)
- Verification: `sN-extract`, `sN-adv-{domain}` (adversarial — 1:1 for CRITICAL, 1 per 3 for HIGH, 1 per 8 for MEDIUM), `sN-adv-cross` (cross-domain adversarial), `sN-synth`
- Fix: `sN-fix-{domain}`
- Build-gate: `sN-gate` (e.g., `s7-gate` — report-only build/test tripwire between fix agents and post-fix review)
- Test-update: `sN-test-update` (e.g., `s8-test-update` — updates stale tests + writes regression tests after fix convergence)
- Test: `sN-test`
- Iterations: `s{N}i{K}-name` (e.g., `s2i1-researcher`, `s2i2-researcher`)
- Respawns: re-issue the `task` call with corrected configuration. Add `-r2`, `-r3` suffix to the name when re-delegating a failed agent (e.g., `s2i1-reviewer-r2` = stage 2 iteration 1 reviewer, respawn attempt 2). Maximum 3 respawn attempts per agent.

#### Second Opinion Guidelines

For DISCOVERY and post-implementation REVIEW stages at MEDIUM+ severity, spawn a second opinion agent — executor with a complementary-FOCUS research report injected (research-backed s2). The primary and the s2 review the same code but through different analytical standpoints, producing complementary findings. The s2's standpoint IS its injected report's FOCUS angle — never the same FOCUS twice. PLAN always has an agent-organizer review (mandatory, all tasks) — see Planning phase step 3c. The planner specifies the s2's complementary FOCUS per stage (the tables below show recommended default pairings; the planner selects based on task context).

**Post-fix REVIEW (inside the FIX brick) is PRIMARY-ONLY — no second opinions.** The both-found confidence signal is lost for fix-stage findings — adversarial verification remains the quality floor.

**No domain exception:** The documentation-domain exceptions (skipping adversarial verification, accepting challenged downgrades directly) apply ONLY to the verification pipeline — how findings are routed and verified. They do NOT excuse documentation-domain DISCOVERY or post-implementation REVIEW stages from the second-opinion requirement. MEDIUM+ severity → second opinion is unconditional across all domains for DISCOVER and post-implementation REVIEW stages.

#### DISCOVER FOCUS pairings (defaults — planner may override)

For DISCOVER, the primary is executor (PLAIN — planner context is the research). The second opinion is research-backed with a complementary FOCUS. The planner may override the angles when the task warrants it — the table shows recommended defaults, not hard assignments.

| Context | Primary FOCUS | Second Opinion FOCUS |
|---------|---------|----------------|
| General code | correctness, completeness | robustness, maintainability |
| Auth/crypto | security, correctness | memory-safety, robustness |
| Infrastructure/config | correctness, completeness | security, hardening |
| Trivial / single-domain-small | skip | — (only when overall task severity < MEDIUM; the MEDIUM+ severity rule — "second opinion mandatory in all DISCOVER stages" — overrides this row) |

#### REVIEW FOCUS pairings (defaults — planner may override)

For REVIEW (post-implementation review of the IMPLEMENT brick), the primary is executor (PLAIN — code + stated specs carry the facts). The second opinion is research-backed with a complementary FOCUS. **These pairings apply to post-implementation REVIEW only — post-fix REVIEW (inside FIX) is primary-only (see above).**

| Context | Primary FOCUS | Second Opinion FOCUS |
|---------|---------|----------------|
| General code | correctness, completeness | performance, maintainability |
| Auth/crypto | correctness, completeness | security, memory-safety |
| Infrastructure/config | correctness, completeness | security, hardening |
| System design / architecture | correctness, completeness | maintainability, scalability |
| Multi-language | correctness, completeness | boundary-integrity (prefer splitting into per-language reviews with individual second opinions) |
| Trivial / single-domain-small | skip | — (only when overall task severity < MEDIUM; the MEDIUM+ severity rule — "second opinion mandatory in all post-implementation REVIEW stages" — overrides this row) |

**REVIEW-seconds measurement gate:** post-implementation REVIEW seconds are subject to a 2-run measurement experiment — extraction tags review-second findings (source) for 2 runs; if the unique confirmed yield is <10%, restrict REVIEW seconds to hotspot files thereafter. DISCOVER seconds stay mandatory. Decision point after 2 runs.

**Same-FOCUS prohibition:** The second opinion MUST use a complementary FOCUS angle — never the primary's. Using the same FOCUS twice — even with "different task scoping" — does not create a different analytical framework. The complementarity effect depends on genuinely different standpoints. If no complementary angle fits, split the review into smaller per-domain reviews where each can get a truly different second opinion.

**Task-framing guideline:** The task file for the second opinion agent uses the same KEY FILES as the primary; its standpoint comes from the injected complementary-FOCUS report. The s2 report MUST state which findings are unique to its standpoint vs also found by the primary (uniqueness reporting — improves extraction both-found/single-found fidelity).

**Both-found confidence signal:** When a DISCOVERY or REVIEW stage used a second opinion, the subsequent extraction agent tags each finding as "both-found" (both agents reported independently) or "single-found" (only one agent reported). Both-found findings carry higher confidence — surface this in the synthesis grid.

#### Execution

1. Spawn current batch of agents via the `task` tool, respecting the per-batch limit from Tools and the dependency analysis above. Issue multiple `task` calls in ONE message for parallel batches (all run concurrently). Checkpoint with agent names and task descriptions. If stage has multiple batches, wait for current batch to finish before spawning next
2. The `task` tool blocks until each subagent completes — results return together for parallel batches
3. Do verification prep (for VERIFY stages): read the extraction agent's output, create verification task files per batch, assemble prompts. **Batch cross-check (MANDATORY):** Before spawning, verify that every batch the extraction report prescribes has a corresponding task file, and each task file targets the exact finding IDs from the extraction's batch assignment table (e.g., ADV-1 → B1-B4). A task file for different findings than prescribed does not satisfy the batch assignment. The extraction report is authoritative — the lead does NOT substitute finding targets.
4. **Review output.** Check operational status only — was the report produced? Is it non-empty? Any EMPTY/MISSING? This is NOT quality review (do NOT evaluate findings, accuracy, or correctness). If ANY agent produced EMPTY REPORT / MISSING REPORT / FAILED TASK:
    - Diagnose root cause. Fix the issue (environment, prompt, task file, dependencies).
    - Re-issue the task call with corrected configuration.
    - Do NOT proceed to the next stage with incomplete stage output.
    - Accept a gap and proceed ONLY for trivial gaps in discovery stages (e.g. a single agent in a 10-agent discovery stage failed after 3 respawn attempts with different approaches, AND its domain is partially covered by other agents). Every such decision must be explicitly justified in `tmp/glm-plan.md` with `STAGE GAP ACCEPTED: [domain] [reason] [coverage from other agents]`. Do NOT accept gaps in implementation or fix stages — those stages must produce complete, correct output. Do NOT silently skip failed agents.

#### Verification

Verification uses the severity-routed verification pipeline. The lead does NOT manually verify findings — that's the agents' job. The pipeline runs in batches with sequential dependencies:

**Batch 0: Extraction agent** (single, default model; use `verification-analyst` agent `.md`). Reads all reports from the stage, extracts every finding with file:line and severity, deduplicates (same file:line + same issue → merge, note both sources), classifies each finding by severity, and splits into batches grouped by domain. When the originating stage (DISCOVERY or REVIEW) used a second opinion agent, tag each finding as "both-found" (both agents reported independently) or "single-found" (one agent only). When intersection agents were present, also tag findings as "boundary-found" (reported by an intersection agent auditing a domain boundary — inherently invisible to within-domain executors) or "domain-only" (reported only by domain primaries/second opinions). Both-found and boundary-found carry elevated confidence for different reasons: both-found signals cross-agent agreement within a domain; boundary-found signals issues spanning domains that no within-domain executor could have detected. A finding that is both "both-found" AND "boundary-found" carries the highest confidence. Surface all tags in synthesis.

**Investigated-and-rejected routing (MANDATORY):** extraction additionally collects each report's `### Investigated-and-Rejected` section (dismissed items with reasoning + file:line) and routes them into the adversarial batches as RE-EXAMINE items (label CONFIRMED / WEAKENED / REJECTED like findings). Dismissals at HIGH/CRITICAL claim severity are always re-examined; MEDIUM/LOW dismissals batched with findings. Dismissals are not trusted — executors have dismissed real bugs.

When the codebase is a git repository with prior production check commits: for each finding, check whether the cited file:line was introduced or modified in a prior production check commit (`git log --all --format="%h %s" | grep -i "production\|check\|fix\|audit"`). Tag findings that fall on previously-fixed lines as `PRIOR_FIX_ATTEMPT: <commit-hash>`. A file with ≥3 PRIOR_FIX_ATTEMPT findings signals a repeat-regression hotspot — surface this count in the extraction report for synthesis routing. A function with ≥3 PRIOR_FIX_ATTEMPT findings clustered within ~40 lines (same logical block) signals a function-level regression hotspot — surface both file-level and function-level counts.

Findings from documentation work-type tasks (docs task type) are domain-verified — route them directly to synthesis at the agent's rated severity, skipping adversarial verification.

**Mechanical trigger — MANDATORY:** If extraction finds any finding at MEDIUM severity or above, the lead MUST spawn ALL verification batches the extraction report prescribes — every adversarial batch, at the exact finding IDs listed in the extraction's batch assignment table. Spawning an adversarial agent against different findings than prescribed does NOT satisfy this trigger. The synthesis agent runs after all routing agents complete — even if every routed finding was REJECTED or WEAKENED. The lead does NOT evaluate routing agent outputs to decide whether synthesis is needed. The synthesis grid — not the lead's judgment — determines which findings are fixed. Skipping verification for MEDIUM+ findings is a protocol violation.

**Batch 1: Findings routed by severity.** All findings extracted by Batch 0 are routed:

- **CRITICAL findings** → Adversarial agent (single agent per finding (1:1), default model). Tries to FALSIFY every finding: reads cited code with full surrounding context, exhaustively searches for counter-evidence (guards, validation, framework protections, type system invariants, test coverage), labels each CONFIRMED / REJECTED / WEAKENED with evidence. Adversarial methodology: assume the claimed issue is a misunderstanding and search exhaustively before confirming. Every CONFIRMED label must be hard-won with grep evidence.

- **HIGH findings** → Adversarial agent (single agent per batch of 3 findings, default model). Same exhaustive falsification methodology as CRITICAL — reads cited code with full surrounding context, exhaustively searches for counter-evidence (guards, validation, framework protections, type system invariants, test coverage), labels each CONFIRMED / REJECTED / WEAKENED with evidence. Adversarial methodology: assume the claimed issue is a misunderstanding and search exhaustively before confirming. Every CONFIRMED label must be hard-won with grep evidence.

- **CRITICAL/HIGH findings from intersection or cross-domain integration review** (any finding spanning domain boundaries, from DISCOVER or REVIEW) → Adversarial cross-domain agent (single agent per finding (1:1), default model). Same exhaustive falsification but verifies from BOTH sides of the integration boundary (Domain A producer + Domain B consumer + bridge between them). Finding only survives if no counter-evidence on either side or in the bridge.

- **MEDIUM findings** → Adversarial agent (single agent per batch of 8 findings, default model). Same exhaustive falsification methodology as CRITICAL — reads cited code with full surrounding context, exhaustively searches for counter-evidence (guards, validation, framework protections, type system invariants, test coverage), labels each CONFIRMED / REJECTED / WEAKENED with evidence. Adversarial methodology: assume the claimed issue is a misunderstanding and search exhaustively before confirming. Every CONFIRMED label must be hard-won with grep evidence.

- **LOW findings** → NOTED. Recorded in the report. No further agent spend.

**Batch 2: Synthesis agent** (single, default model; use `verification-analyst` agent `.md`). Reads all verdicts. Builds a cross-reference grid per finding using unified vocabulary:

| CONFIRMED | REJECTED | WEAKENED |
|---------------|--------------|---------------|
| → fix list | → dropped | severity downgraded → fix list at lower priority |

Surfaces "both-found" confidence signals from extraction — findings reported by both primary and second opinion agents carry higher initial confidence.

Surfaces PRIOR_FIX_ATTEMPT regression signals from extraction. When a file has ≥3 PRIOR_FIX_ATTEMPT findings, flag it in the synthesis grid as a repeat-regression hotspot. When ≥3 findings cluster within the same function (~40 lines), flag that function as a regressing function requiring a localized pre-fix audit. Regressing functions trigger the pre-fix audit protocol (see Between Stages) — these locations have a demonstrated pattern of incomplete fixes. Hotspot flags are informational for the lead; post-fix REVIEW is primary-only (no second-opinion reviewer).

Also sanity-checks severity assignments against the severity classification criteria — if a finding's severity appears mismatched (e.g., "SQL injection" labeled MEDIUM), flag it as CHALLENGED. Challenged findings are re-routed through adversarial verification. Exception: documentation-domain challenged findings skip adversarial — documentation severity is inherently subjective (is "10 missing API docs" HIGH or MEDIUM?) and adversarial review of severity ratings adds no meaningful verification. Documentation-domain challenged findings stay at their challenged severity; the lead accepts the downgrade directly.

For POST-FIX grids, the synthesis agent additionally classifies each CONFIRMED finding as **CODE-FIX** (code defect — re-triggers the fix pass) or **TEST-UPDATE** (test asserting pre-fix behavior — does NOT re-trigger the code-fix pass; routes to the TEST-UPDATE sub-stage after convergence). For post-fix grids in convergence passes, also compare CONFIRMED CODE-FIX findings against the prior pass's grid: a finding mapping to the same function region (~40 lines) as a finding that already failed verification in a previous pass flags that region as an **in-run regressing function (N attempts)** — surface the flag for the lead's pre-fix audit trigger.

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
- Adversarial pairs: `sN-adv-{domain}` (single agent per finding for CRITICAL — 1:1; single agent per batch of 3 for HIGH; single agent per batch of 8 for MEDIUM)
- Adversarial cross: `sN-adv-cross` (single agent per finding — 1:1)
- Synthesis: `sN-synth`

#### Between Stages

1. Write `tmp/stage-N-synthesis.md` — verified results from the synthesis grid, decisions, context for next stage
2. **Mid-execution amendment (new findings):** If VERIFY produces confirmed findings at MEDIUM severity or above and IMPLEMENT is NOT in the manifest, the lead auto-adds IMPLEMENT followed by FIX (always 3-4 sequential stages: fix + build-gate + post-fix review + conditional VERIFY, plus conditional TEST-UPDATE). This is unconditional — all confirmed MEDIUM+ findings are fixed regardless of task intent. LOW findings are reported but not auto-fixed. This is mechanical — verify the condition, add the stages.
   **FIX convergence (incomplete fixes):** After a FIX stage's post-fix VERIFY produces CONFIRMED CODE-FIX findings in the synthesis grid, auto-add another FIX pass regardless of whether IMPLEMENT is already in the manifest. IMPLEMENT presence does not block FIX convergence — surviving CODE-FIX findings mean the fix was incomplete. Repeat until post-fix review produces zero CONFIRMED CODE-FIX findings and VERIFY is skipped. Each convergence pass re-runs the build-gate before its post-fix review. TEST-UPDATE findings (tests asserting pre-fix behavior) do NOT re-trigger the code-fix pass. After convergence, if the grid contains TEST-UPDATE findings or CONFIRMED fixes lack regression tests, auto-add a TEST-UPDATE stage (1 agent: executor — updates stale tests + writes regression tests pinning the fixes; PRIOR CONTEXT = the synthesis grid; WRITABLE FILES = the named test files; does NOT touch production code), followed by a build-gate re-run and 1 review agent (no weakened pins, no scope creep; no adversarial pipeline for test-only changes). When convergence is reached, proceed to Delivery — convergence does not end the workflow.
   **Regression-aware fix scrutiny:** When the synthesis grid flags any file as a repeat-regression hotspot (≥3 PRIOR_FIX_ATTEMPT findings on the same file) or a regressing function (≥3 PFA clustered ~40 lines, OR in-run ≥2 consecutive failed fix attempts), the lead notes the flag for fix-agent assignment awareness — these locations have a demonstrated pattern of incomplete fixes. Post-fix REVIEW is primary-only (no second-opinion reviewer per Second Opinion Guidelines); the elevated-review mechanism for regressing functions is the pre-fix audit below.

   When the synthesis grid flags a regressing function (≥3 PRIOR_FIX_ATTEMPT findings clustered within ~40 lines of the same function, OR an in-run regressing function flagged by the synthesis agent — ≥2 consecutive failed fix attempts on the same function region within this run), the lead spawns a single pre-fix audit agent BEFORE the fix stage. The audit agent:
   - Reads only the flagged function and its immediate context (the function body plus its callers in the same file — not the full module)
   - Reads the git history of prior failed fix attempts for that function
   - Produces a localized structural recommendation: extract a helper, consolidate duplicate guards, hoist a validation check — a change strictly within that function's own file, touching no public APIs or cross-file interfaces
   - The recommendation is MANDATORY INPUT for the fix agent — the fix agent MUST apply it or explicitly justify rejecting it in its report. If the recommendation spans beyond the function's file, the lead rejects it and the fix proceeds without the structural change (standard primary-only post-fix review). The audit agent writes no code; the fix agent owns implementation. Function-scoped, no cross-file interface changes.

   Confirmed findings landing in a known regressing region are delivered as SINGLE-FINDING fixes with their own review — never batched with other findings in the same file.

   **Recurrence-class escalation:** synthesis categorizes every CONFIRMED finding by MECHANISM (validation gap, state-machine ordering, dispatch gap, cross-module divergence, error swallowing, etc.). Between stages, the lead checks category recurrence across consecutive checks: ≥2 findings in the same category as a prior check → stop surgical fixing of that category, escalate to a structural fix (centralize validation, extract shared logic, enforce ordering at the type level). Oscillating finding counts across ≥3 consecutive checks → stop the audit loop, structural refactor before more audits.
3. If scope changed from original plan, update `tmp/glm-plan.md` with actual stages and revised goals
4. Checkpoint. Clean up: `rm -f tmp/sN-*-task-prompt.txt tmp/sN-*-task.txt`
5. Next stage prompts include synthesis as `PRIOR CONTEXT:` section. PRIOR CONTEXT is a navigation aid that guides the agent to complete source artifacts — it is NOT a replacement for reading agent reports. Structure it as: (a) file paths to agent reports the downstream agent MUST read before beginning work (synthesis grid with adversarial evidence, discovery reports with cross-file analysis, Intent sections from prior implementation), (b) one-line item counts for orientation (e.g., "3 MEDIUM confirmed findings, 2 LOW noted"), (c) lead-level decisions and constraints (what scope was decided, what was explicitly excluded). Do NOT flatten cross-file analysis, call-chain traces, adversarial grep evidence, or architectural reasoning from agent reports into PRIOR CONTEXT — point to the source report and trust the agent to read it. When a downstream agent receives a finding ID (e.g., "F-03: null dereference at auth.py:42"), the agent MUST read the synthesis grid report for the full finding with adversarial evidence and the original discovery report for cross-file context. Target under 50 lines total (navigation pointers + item counts + decisions). When PRIOR CONTEXT includes research findings, include their confidence tier and instruct downstream agents to check claims against code, not trust them blindly. **When passing research findings into discovery agents:** the lead copies the research report's `## Discovery Questions` section verbatim into the discovery agent's YOUR TASK as MUST ANSWER questions — zero lead interpretation, zero summarization, zero claim extraction. The research agent is the domain expert on the specification; it writes the questions with spec text quoted inline. The lead's only responsibility is to transport them untouched from the research report to the task file. Include the research report file path in PRIOR CONTEXT for reference.
6. Never re-do verified work unless evidence shows it was wrong
7. Never skip a planned stage without explicitly marking it in `tmp/glm-plan.md` as `SKIPPED` with a reason. A stage is only complete when its agents have been spawned, waited, their reports processed by the verification pipeline, and findings verified — incomplete stages cannot be proceeded past, outside the narrow gap-acceptance rules in Execution step 4. PLAN stages cannot be SKIPPED for speed or token savings — only for genuine blockers (environment failure, missing files, corrupted state).
8. After writing synthesis, read `tmp/glm-plan.md` to confirm the next stage. If the plan has remaining stages, execute them — do not deliver early unless remaining stages are explicitly marked SKIPPED.

**Iterative stages:** Between iterations, follow the Iterative Convergence protocol below — skip steps 1-5 until convergence is reached. On convergence, write final stage synthesis (step 1) and resume normal between-stages flow (steps 2-5).

#### Iterative Convergence

Some stages benefit from repeated runs until agents stop producing new meaningful output. What counts as "new output" depends on the stage purpose — new problems (audit), new information (research), new improvements (analysis), new risks (security), etc.

Convergence is mechanical: a stage converges when the VERIFY synthesis grid of its last iteration contains zero CONFIRMED HIGH/CRITICAL findings. The lead does not subjectively judge whether findings are "meaningful enough" — the trigger is read directly off the verified grid.

**Ceiling-set, trigger-mechanical.** The planner sets the iteration CEILING; whether an
iteration actually runs is decided MECHANICALLY by the prior VERIFY synthesis grid — never
by planner choice and never by lead judgment. There is no CONVERGE=NONE: every DISCOVER
and REVIEW stage is convergence-eligible, and a stage converges by failing the trigger,
not by being opted out.

- **CEILING — ONCE (default):** at most 1 additional iteration. Applies to every
  DISCOVER/REVIEW stage unless the planner justifies a higher ceiling.
- **CEILING — LOOP (rare):** up to 3 additional iterations, each gated by the same
  trigger. For highly ambiguous or production-critical work where missed findings would
  be unacceptable.

**TRIGGER (mechanical — the ONLY way an iteration fires):** the immediately preceding
VERIFY synthesis grid contains at least one CONFIRMED finding at HIGH or CRITICAL severity
(adversarially verified).
- REJECTED findings never trigger.
- WEAKENED findings trigger only when the corrected severity remains HIGH+.
- Documentation-domain findings (which skip adversarial verification) are EXCLUDED from
  the trigger — they cannot cause an iteration to fire.
- A stage with zero CONFIRMED HIGH+ in its VERIFY grid is CONVERGED after one pass,
  regardless of task type, codebase cleanliness, or prior production-check history.

Note on run variance: a MEDIUM-only converged grid means "no verified HIGH/CRITICAL
in THIS pass" — it is NOT proof the code has no HIGH-severity bugs. Discovery runs
are variance-exposed: two identical-scope runs of the same code can diverge on HIGH
discovery. MEDIUM findings are a permanent noise floor on mature codebases and are
NOT a reliable trigger reference. Treat convergence as "clean this pass, subject to
run variance" — the multi-check trajectory (0 HIGH/CRITICAL across checks), not any
single pass, is the convergence proof.

This replaces the old "any finding = spawn" trigger. The old rules that forced
CONVERGE>=ONCE on audits/production checks and on codebases with >=5 prior production
check runs are REMOVED: firing is purely a function of the verified synthesis grid.

Factors the planner considers when setting the ceiling: ambiguity, codebase complexity,
finding volume, production impact of missed findings, change type (exploratory vs.
mechanical), time sensitivity.

**Not used for:** Production stages (implementation and fixing) and verification stages. These produce or evaluate output rather than discovering issues. RESEARCH stages use the confidence-tier trigger (spawn iter 2 when any research finding critical to downstream stages is rated LIKELY or lower) — also conditional-by-default, with the ceiling model applied.

**Mandatory rules apply:** CONVERGE iterations of DISCOVERY, REVIEW, or RESEARCH stages inherit ALL mandatory rules from the parent stage type — including second-opinion requirements at MEDIUM+ severity for DISCOVERY/REVIEW iterations. When the original DISCOVER/REVIEW required a second opinion agent, every CONVERGE iteration must also include a second opinion. The planner's decision table must list all agents to spawn per iteration — the lead spawns exactly what the plan lists.

**Execution is mechanical — the lead does NOT re-evaluate the CONVERGE decision.** If the plan sets a ceiling (ONCE/LOOP) and the prior VERIFY grid contains ≥1 CONFIRMED HIGH+ finding, the lead spawns the iteration agents unconditionally (up to the ceiling). If the grid contains no CONFIRMED HIGH+ finding, the stage is converged — the lead skips unconditionally. The planner's ceiling assessment was already baked into the plan during Phase 1 research. The lead does NOT substitute judgment based on finding volume, "isolated"-vs-"specific" appearance, or task type — whether the trigger fired is read directly off the synthesis grid.

**Mechanics:**
1. Each iteration = full prepare → spawn → verify cycle
2. After verification: check the synthesis grid mechanically — does it contain any CONFIRMED HIGH/CRITICAL finding?
    - **Yes** → write iteration synthesis to `tmp/stage-N-iter-K-synthesis.md`, prepare next iteration. Each iteration's synthesis file is the cumulative state — the lead does not accumulate iterations in its own context; the files hold the history (see Context is not the lead's concern above).
    - **No** → convergence reached; write final stage synthesis and move on
3. Lead SHOULD vary approach between iterations — different agents, focus areas, or angles — to avoid blind spots. Running identical agents repeatedly is wasteful.
4. Lead can adjust agent count and type between iterations based on what prior iterations revealed
5. If iteration cap hit without convergence → synthesize what's known, note "convergence not reached" in delivery, proceed
6. **Naming:** iteration agents follow `s{N}i{K}-name` — e.g. `s2i1-reviewer`, `s2i2-researcher` (stage 2, iteration 1/2). Respawn within iteration: re-issue the task call with `s2i1-reviewer-r2`.

**VERIFY between iterations (MANDATORY):** The plan must include a VERIFY stage
between every pair of CONVERGE iterations. The structure is:
  Stage N:   DISCOVER iter 1
  Stage N+1: VERIFY iter 1  (extraction → adversarial → synthesis)
  Stage N+2: DISCOVER iter 2 (conditional on N+1 synthesis, PRIOR CONTEXT from N+1)
  Stage N+3: VERIFY iter 2
Iter 1's VERIFY produces the synthesis grid that (a) determines whether iter 2
spawns (any CONFIRMED HIGH+ in the grid = spawn) and (b) provides PRIOR CONTEXT
for iter 2 agents.
Merging both iterations' verification into one stage after both complete is a
protocol violation — there is no way to know whether iter 2 should spawn, and no
PRIOR CONTEXT for iter 2 without iter 1's synthesis first.

#### Delivery

**Before delivery:** Read `tmp/glm-plan.md`. Confirm every planned stage is complete or explicitly marked SKIPPED with justification. A stage silently skipped = not delivered yet. Execute it or update the plan. If any code was changed during the fix stage — by fix-agents — confirm that the build-gate passed and that post-fix review and verification both ran (verification runs only if review found new findings), and that the TEST-UPDATE stage (if triggered by TEST-UPDATE findings or missing regression tests) completed with a green gate re-run. Code changes without downstream verification are not deliverable. If any synthesis grid contains CONFIRMED findings, confirm knowledge harvesting ran and the report (`tmp/knowledge-harvest-report.md`) was produced. The user's task instructions (commit, push, report) are the final step after all stages complete — they do not override the mandatory stages that must run first.

Before delivery, mechanically verify all mid-execution decisions:
- If any conditional VERIFY was skipped: read the stage's review reports.
  If any report contains a MEDIUM+ finding with a code reference, the VERIFY
  stage must be run now.
- If any finding was marked as dropped or noted by the lead without routing
  through the verification pipeline: the finding must be routed through the
  verification pipeline now.

After final stage:
- **Reviews/audits:** write report to `tmp/` with verified findings, rejected items, gaps
- **Code changes:** spawn a single agent (executor, default model) to run build + tests, fix all failures, and deliver production-ready result. This is the final production gate.
- **Research/analysis:** synthesize into clear summary, preserving the research agent's confidence tier for each key finding. Do not present research findings as established facts unless they are CONFIRMED (≥2 independent sources); for LIKELY, TENTATIVE, or SPECULATIVE findings, state the tier explicitly in the delivery.
- Write `tmp/session-summary.md`: task goal, stages executed, total agents, agent aborts/failures, iterations per iterative stage, verification stats, key decisions, phase durations (planning, preparation, execution/wait, verification, synthesis)
- **Knowledge harvesting:** If any synthesis grid contains CONFIRMED findings, spawn a single `verification-analyst` agent (default model). It reads all synthesis grids and discovery reports, classifies each CONFIRMED finding as PATTERN (the lesson generalizes beyond this fix) or INCIDENT (one-off specific fix), deduplicates against existing `knowledge.md` entries via `memory.sh search`, and for each PATTERN writes a `memory.sh add` entry (category: `gotcha` or `pattern`, tagged by domain — `numerical`, `concurrency`, `memory`, `ffi`, `io`). For each PATTERN entry, also add a one-line prevention recommendation: (a) mechanically preventable → implement enforcement (CI test, lint rule, type-level, shared base class); (b) review-only → gotcha + lint rule; (c) neither → accept recurrence and budget for it in future checks. For each existing knowledge entry found by search, evaluate whether the current run's fix supersedes it: if yes, update or delete via `memory.sh`; if the entry references code not addressed by current findings, leave it untouched. Conservative: prefer silence over noise; never delete without clear evidence. The agent's report is written to `tmp/knowledge-harvest-report.md`. After the harvester completes, commit and push `knowledge.md` from the orchestrator's root (where `.opencode/` lives — the same `$REPO_ROOT` that `tmp/` paths resolve to) so harvested patterns survive the session. Skip the commit if `knowledge.md` is unchanged (all findings were INCIDENT with no knowledge updates).
- Cleanup: `rm -f tmp/s[0-9]*-task-prompt.txt tmp/s[0-9]*-task.txt`. Keep logs, reports, summary, knowledge-harvest-report

### Agent Prompt Template

The task prompt file (the path the lead passes to the `task` tool as the `prompt` argument, per the read-and-execute spawn convention above) is assembled with cache-aware ordering: stable shared content first (cached across calls), volatile per-instance content last. The assembly order (performed by `assemble-task.sh`):

```
You are a single agent working solo. Do all the work yourself — do not spawn sub-agents, do not delegate to other agents, do not run agentic workflows. Agentic workflows are not allowed in this session.

Before claiming something is missing or broken — grep for existing guards, handlers, or implementations first.

{cat .opencode/templates/coordination-review.txt OR coordination-code.txt — replace {NAME}}

{cat .opencode/templates/severity-guide.txt — REVIEW/audit tasks only}

{cat .opencode/templates/quality-rules-review.txt OR quality-rules-code.txt}

You are an AI agent named {NAME}.

--- TASK ASSIGNMENT ---

{## RESEARCH DATA — research-baked runs only: the routed research report injected via assemble-task.sh --research-file, between template and task. PLAIN runs have no RESEARCH DATA section.}

PROJECT: {working directory and project description}

ENVIRONMENT (code tasks only):
{Runtime, test command (full suite — build-gate/TEST stage only, never per-agent), lint command}

PRIOR CONTEXT (stage 2+ or iteration 2+):
{Navigation aid per Between Stages step 5 — file paths to source reports the agent MUST read (synthesis grid, discovery reports, prior Intent sections), one-line item counts, lead decisions and constraints. NOT a replacement for reading agent reports. Target under 50 lines.}

YOUR TASK: {KEY FILES, CONTEXT, SCOPE, MUST ANSWER questions}

WRITABLE FILES: {code agents only — list source files agent may edit. Review/research/audit agents: omit this section}
```

The agent's `.md` is NOT embedded in the task prompt — opencode auto-loads it as the subagent's system prompt when the lead calls the `task` tool with `subagent_type`.

| Task Type | Coordination | Severity Guide | Quality Rules |
|-----------|--------------|----------------|---------------|
| Review/audit | coordination-review.txt | severity-guide.txt | quality-rules-review.txt |
| Code/refactor | coordination-code.txt | — | quality-rules-code.txt |
| Research | coordination-review.txt | — | quality-rules-review.txt |

Boilerplate templates live in `.opencode/templates/` and are `cat`-ed by `assemble-task.sh` into the task prompt verbatim. The lead only writes the unique parts (TASK ASSIGNMENT). The agent `.md` is auto-loaded by opencode.

### Checkpoints & Recovery

**LEAD-ONLY — subagents NEVER use this section.** Subagents are single-task executors: they do not save checkpoints, do not run recovery, and do not maintain orchestration state. A subagent that does not understand its task decides the best interpretation and proceeds (see Autonomy) — it does NOT run `glm-recover.sh` or read the plan to "figure out the workflow."

**Save after every step — no exceptions.** One active checkpoint (delete previous first). Under 500 chars.

```bash
./.opencode/tools/memory.sh session add context "CHECKPOINT: [task] | DONE: [steps] | NEXT: [remaining] | SKIP: [do not redo — completed agents, failed approaches, skipped stages, decisions already made] | FILES: [key files] | BUILD/TEST: [commands]"
```

The `SKIP:` field prevents rework after compaction/crash recovery. Record:
- Already-completed agents whose reports exist (e.g. `s2-reviewer done`)
- Failed approaches tried 3× (do not retry same thing)
- Stages explicitly skipped with reason (e.g. `verify skipped — 0 findings`)
- Decisions made autonomously on sight (documented so they are not re-litigated)

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
| Agents prepared | Assemble task prompts → delegate via task tool |
| Agents spawned | Check task results/reports → verify or re-delegate |
| Verifying stage N | Read `tmp/stage-N-synthesis.md` — the lead's synthesis from the synthesis agent's grid |
| Iterating stage N, iter K | Read `tmp/stage-N-iter-K-synthesis.md` — the cumulative state file → prepare next iteration |
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

**LEAD-ONLY — subagents NEVER use this section.** Only the lead writes `tmp/glm-continuation.md`, stores the GLM-CONTINUATION memory entry, and picks it up on resume. Subagents do not continue or resume workflows.

For tasks exceeding a single session:

1. Complete current stage fully
2. Write `tmp/glm-continuation.md`: original task, plan, completed stages, next stage, decisions, modified files, blockers
3. `./.opencode/tools/memory.sh add context "GLM-CONTINUATION: [summary]" --tags glm-opencode,continuation`
4. Tell user what's done and what continues

**Pickup:** `./.opencode/tools/memory.sh search "GLM-CONTINUATION"` → read continuation file → read prior synthesis → continue next stage. On final stage, clean up continuation file and memory entry. Never re-do verified prior work.

### Error Handling

| Scenario | Action |
|----------|--------|
| No report after exit | **RESUME FIRST, respawn second:** re-invoke the task tool with the same task_id asking it to deliver — the session keeps its context and writes the report. Only if the resume fails, diagnose the failure (bad prompt? missing dependency? environment?) and re-issue the task call. Do NOT fill gaps yourself — filling gaps is agent work. |
| Agent claims success but output wrong | Diagnose why output is wrong (bad prompt? misunderstood task?). Fix the prompt/task. Re-issue the task call. Do NOT verify or fix the output yourself. |
| Incorrect edits | Diagnose why the agent produced wrong output (bad prompt? misunderstood task?). Fix the prompt/task. Spawn a quick-fix agent to revert and rewrite. Do NOT revert changes yourself. If the quick-fix agent is still wrong, diagnose the issue and retry once with corrected configuration. If the retry also fails: for HIGH/CRITICAL-adjacent changes, escalate to full IMPLEMENT → REVIEW → VERIFY; otherwise (LOW/MEDIUM or workflow-internal clutter), spawn a quick-fix agent to revert the change entirely — better to ship clean than to ship a broken fix. No direct work — the lead never edits project code. Quick-fix agents are the only exception to "every review must be verified." |
| 2+ agents fail same env error | STOP respawning. Diagnose environment first (do NOT fix environment issues directly — spawn an agent if changes needed) |
| Agent aborted (same error 3×) | Diagnose root cause from task result, fix environment/config (spawn an agent if code/config changes needed), then re-issue the task call |
| Stage partially failed (1+ agents produced no useful output or wrong output) | Diagnose root causes across all failed agents. Fix issues (environment, prompts, tasks). Re-issue ALL failed task calls. The stage is incomplete until all agents succeed. Do NOT proceed to the next stage with gaps. |
| Iteration cap hit without convergence | Synthesize all iterations, note "convergence not reached" in delivery, proceed |
| Adversarial verification produces suspicious results (CONFIRMED on obviously-wrong findings or REJECTED with weak evidence) | Diagnose prompt/task quality — adversarial agent may have misunderstood its role. Adjust MUST ANSWER questions or adversarial instructions and re-issue. |

**Deepseek-flash output-budget failure (CLI runs):** high-reasoning agents can burn the entire output budget on heavy reviews (`reason: length`, 0 output). Fix for CLI runs (`opencode run`): `OPENCODE_CONFIG` with `{ "provider": { "deepseek": { "options": { "max_tokens": 65536 } } } }`. TUI sessions unaffected.

### Rules

**Quality over speed — ALWAYS.** Never rush, never cut corners, never try to finish faster. Slow, thorough, methodical work produces quality. Speed produces bugs. Prefer more stages, more agents, more verification over shorter timelines. There is no deadline. The only measure of success is production-ready, bug-free code.

**Limits:** Per-batch limit and agent parallelism rules are defined in Tools and Agent Spawning — don't restate. Need more coverage than the 10-agent per-batch cap allows? Add stages, not more agents per batch. Agents run until done (no turn limit). One task per agent. Respawn naming: `-r2`, `-r3`. No two agents edit same file within a stage (read overlap OK). Balance workload — each agent should cover roughly equal scope.

**Task tool (MANDATORY):** Agent delegation in this project happens ONLY via the opencode `task` tool. All 11 agents in `.opencode/agents/` are native subagents, auto-loaded by opencode. The lead assembles a task prompt with `assemble-task.sh`, then delegates via the `task` tool with `subagent_type` set to the agent name. Agents run as isolated child sessions with full project permissions. The lead never uses `opencode run` to spawn workflow agents.

**Agent count per stage (MANDATORY — fill capacity by task decomposition):** Decompose the task into as many independent subtasks as it naturally splits into, spawn one agent per subtask, maximum 10 agents per batch. Default to what the task genuinely requires — scale to scope. Under-splitting agents creates a detection ceiling where agents can read but not deeply analyze cross-file contracts, producing fewer findings. The 10-agent-per-batch limit is a coordination constraint, not a quality limit. Verification stages scale with findings count and impact surface, not discovery agent count — minimum 1 extraction agent for every stage; adversarial agents run only if extraction finds at least one finding to falsify. When in doubt, decompose into more parallel agents — broader coverage finds more issues. **Never run sequential single-agent stages when those stages could be a single stage with parallel agents (see Workflow → Planning → Stage decomposition rule).**

**Prompts:** The lead's task file (PROJECT, ENVIRONMENT, PRIOR CONTEXT, YOUR TASK, WRITABLE FILES, MUST ANSWER) is assembled by `assemble-task.sh` with the coordination/quality/severity templates into the task prompt passed to the `task` tool. The agent `.md` is auto-loaded by opencode as the subagent's system prompt — the lead does not embed or read the full agent `.md` into its own context. All per-task context must be in the task prompt — AGENTS.md is loaded natively by the platform into every session (lead and subagents alike), so do NOT rely on it as the agent's operating manual for task specifics.

**Verification:** Every finding labeled. Every label backed by Read. 100% complete before proceeding. ALL verified actionable findings fixed via fix-agent — the lead does not fix findings directly.

**Lead code prohibition (MANDATORY):** The lead never writes, edits, or modifies project source code. Every code change — implementation, bug fixes, config adjustments, script changes, one-liners — goes through a spawned agent. The lead's tools (Edit, Write) are for tmp/ artifacts only: task files, prompts, synthesis reports. The only exception is editing AGENTS.md itself (meta-configuration).

**Platform:** `opencode` on all platforms. The lead operates as an opencode session (TUI or `opencode run`); workflow agents are native subagents delegated via the `task` tool.
