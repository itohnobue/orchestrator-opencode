## Temporary Files

You can use the `tmp/` subfolder in the current project folder to save any temporary files if needed.
This is useful for storing intermediate results, reports, or data during multi-step workflows.

---

## Agents

Agents folder: `.claude/agents/`. Use agents for all non-trivial subtasks — code writing, analysis, design, debugging, testing, documentation.

**Rules:**
- Before any subtask: select the best agent and read its `.md` file (always fresh re-read)
- Load ONE agent at a time (Exception: Opus-GLM may read multiple for prompt building)
- DO NOT use the Task tool for agents — use in-session loading (Exception: Opus-GLM uses spawn-glm.sh)
- Agent instructions are TEMPORARY — apply to current subtask only, discard after

**Discovery:** Glob `.claude/agents/*.md` to list, Grep by keyword. Prefer specialized over general agents.

### Request Workflow

1. **Memory:** `./.claude/tools/memory.sh context "<keywords>"` — extract from entities, technologies, services, error types. MANDATORY for non-trivial tasks
2. **Continuation:** `memory.sh search "GLM-CONTINUATION"` — resume if exists
3. **Evaluate GLM:** If any Opus-GLM delegate trigger matches → enter GLM flow (skip 4-5)
4. **Plan:** For multi-step tasks: `memory.sh session add plan "..."`
5. **Decompose:** List subtasks, map each to best agent, report to user

**Agent selection:** Most specialized wins (e.g., postgres-pro over database-optimizer). Split hybrid tasks into subtasks with different agents.

### Subtask Workflow

1. Read agent `.md` → apply to current subtask → complete fully → verify quality
2. Save discoveries to knowledge if non-trivial
3. Discard agent instructions → next subtask
4. After all subtasks: compose into one report

---

## Opus-GLM

Dynamic orchestration where Opus delegates work to GLM agents. Evaluates every task, designs the workflow, spawns agents, verifies output, delivers results. **Automatic by default.**

### When to Delegate

Evaluate every non-trivial task. Delegation is the default.

1. **Changes < 50 lines AND full context** → handle directly
2. **Otherwise**, any match → delegate:

- Independent parallelizable subtasks
- Production checks, security audits, code reviews
- Large refactors (5+ files) or deep research
- 3+ unrelated modules or domains
- Requires both research and implementation
- Would need >10 lead turns of direct work
- Analysis of >200 lines of code
- Requires shell commands to test/validate

| Scope | Agents/Stage | When |
|-------|--------|------|
| Focused | 1 | Single heavy task |
| Small | 2-3 | Few independent subtasks |
| Full | 3 | Project-wide analysis |

Prefer fewer well-prompted agents over many thin ones.

### Lead Role

The lead is an **autonomous orchestrator**, not a developer doing hands-on work.

**Does:** plan, decompose, design workflow stages, write agent prompts, spawn agents, verify results, fix gaps, synthesize, deliver.

**Does not:** run test suites, do comprehensive audits unprompted, write substantial code, do deep research. These are agent work.

**Self-check rules (MANDATORY):**
- Heavy Read/Grep usage for planning and verification is expected and allowed
- But if you find yourself writing code, running test suites, or doing deep analysis across many files — that's agent work. Delegate it
- When direct work is truly needed (agent failed, small cleanup): justify with `DIRECT WORK: [reason]`

**Verification vs implementation boundary:**
- Verification (lead does): Read files, compare to agent claims, label findings, update checklist, write synthesis
- Implementation (agent does): Writing/editing code, running test suites, fixing bugs, adding tests, refactoring
- **When to delegate:** Large implementation work (new features, 5+ files, 50+ lines of new code) → always spawn an agent
- **When lead does direct work:** Agent failed or produced poor results AND the remaining fix is manageable (under ~50 lines, few files). Justify with `DIRECT WORK: [reason]`. This is expected and efficient — don't respawn for small cleanup
- After verification, if many fixes are needed across many files: collect them into a fix-agent prompt and spawn

**Workflow autonomy:** The lead designs the complete workflow and runs it to completion without user interaction. The lead chooses what stages are needed (research, implement, test, audit, or any combination), their order, agent count, and can add or modify stages during execution as understanding deepens. Each stage follows the prepare → spawn → verify cycle. The lead has full authority to adapt the plan mid-execution — no restrictions on total agents or stages if the task requires them.

### Tools

All GLM agents use **opus** (GLM-5.1). Max 3 agents running in parallel.

**Spawn:**
```bash
.claude/tools/spawn-glm.sh -n NAME -f PROMPT_FILE
```
Returns `SPAWNED|name|pid|log_file`. Backgrounds immediately. Report: `tmp/{NAME}-report.md`, log: `tmp/{NAME}-log.txt`. Also writes to `tmp/{NAME}-status.txt` (reliable on Windows — stdout can be lost when parallel `.cmd` processes launch).

**Wait:**
```bash
.claude/tools/wait-glm.sh name1:$PID1 name2:$PID2 name3:$PID3
```
Blocks until all finish (Bash timeout: 600000). Do NOT use bare `wait` or `sleep` + poll loops. Prefer `name:pid` format — enables progress monitoring (first at 30s, then every 60s) and STALLED detection (0-byte log after 2min). Bare PIDs still work but skip log monitoring. If Bash times out before agents finish, re-invoke with same arguments — this is normal for long-running agents.

### Workflow

The lead designs the workflow. Typical flow: plan → for each stage: prepare → spawn → verify → synthesize → deliver. **Stages may be iterative (see Iterative Convergence).** The lead decides what stages are needed and in what order.

#### Planning

**MANDATORY: Research before implementation.** Before writing ANY agent prompt for a new component, the lead MUST:
1. Read the plan section for the component
2. Read the ACTUAL reference source code for the equivalent feature — the plan may have misinterpreted, oversimplified, or missed fields/logic
3. Compare plan's proposed design against reference reality — fix discrepancies BEFORE spawning
4. Only spawn agents when confident enough to write well-scoped prompts — remaining uncertainty should be captured in MUST ANSWER questions for agents to resolve
5. Invest time in preparation — perfect prompts produce better results than fast prompts. No time pressure on research.

Research enough to write well-scoped prompts — skim files (structure, function names, imports, sizes), understand project layout, identify the right agents. Don't trace logic chains or do deep analysis — that's agent work. **When scope is unclear, start with one or more research stages before implementation.** Spawning research agents (even iteratively to convergence) is encouraged — thorough research almost always produces better results in later stages. Decompose into stages. Brief user before spawning:
```
Plan: [N stages, M total agents]
  Stage 1: [purpose] — [agents] → delivers [what]
  Stage 2: [purpose] — [agents, batch 1: A,B | batch 2: C] → delivers [what] [iterative] (discretionary)
  Stage 3: [purpose] — uses Stage 2 output → delivers [what] [iterative] (mandatory)
```
Iterative stages MUST be marked with `[iterative]` in the brief. Mark `(mandatory)` vs `(discretionary)`. Do not wait for the user to ask.

Write full plan to `tmp/glm-plan.md`. Checkpoint.

Single-stage when all agents can work independently. Multi-stage when later work depends on earlier results or agents would need 30+ turns.

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

**Session start:** Clean ALL stale GLM artifacts: `rm -f tmp/glm-plan.md tmp/stage-*-{checklist,synthesis}.md tmp/stage-*-iter-*-synthesis.md tmp/*-log.txt tmp/*-report.md tmp/*-status.txt tmp/*-prompt.txt`

**Session boundaries:** If task will likely need >4 stages, plan explicit session splits using the continuation protocol. Long sessions degrade from compaction pressure.

#### Agent Preparation

Consult `.claude/agents/INDEX.md` for the full agent directory (109 agents grouped by domain). Pick the MOST specialized agent — a PostgreSQL task should use postgres-pro, not database-optimizer. The agent's domain checklists and anti-patterns are the primary value — they only work when the agent matches the domain.

For each agent in the current stage:

1. Define task with KEY FILES, CONTEXT, SCOPE, `WRITABLE FILES`, and 3-5 `MUST ANSWER:` questions (mandatory — prompts without these are invalid)
2. Read `.claude/agents/{agent}.md`, include in full (see Prompts rule below), build prompt per Agent Prompt Template
3. Append boilerplate from `.claude/templates/`: quality rules (review or code variant), severity guide (review only), coordination + report format (review or code variant). Replace `{NAME}` placeholder in coordination template
4. Write to `tmp/{name}-prompt.txt`
5. **Validate prompt contains ALL:** full agent .md, TASK ASSIGNMENT with MUST ANSWER questions, WRITABLE FILES list, quality rules, severity guide (review only), environment (code only), coordination, report format. Missing ANY = do not spawn
6. Match agent type to task: REVIEW → code-reviewer, security-reviewer, backend-architect. CODE → language-pro, debugger
7. **WRITABLE FILES:** Every code agent prompt MUST include a `WRITABLE FILES:` section listing the exact files/directories the agent may create or modify. Review/audit agents: `WRITABLE FILES: tmp/{NAME}-report.md` (report only, no source modifications)
8. **Pre-spawn check:** Before spawning code agents, verify the build/test commands work (quick run). For review agents, confirm key files are readable. A 30-second check prevents multi-agent failures from broken environments.

Describe problems and desired behavior — do NOT paste exact fix code unless precision is critical (regex, API signatures, security logic). Name agents with stage prefix: `s1-researcher`, `s2-impl-auth`.

#### Execution

1. Spawn current batch of agents via `spawn-glm.sh` (max 3 per batch — see dependency analysis). If stdout is empty (Windows `.cmd` issue), read `tmp/{NAME}-status.txt` to get PID. Checkpoint with PIDs and names. If stage has multiple batches, wait for current batch to finish before spawning next
2. Do verification prep (pre-read key files for spot-checks)
3. `wait-glm.sh name1:$PID1 name2:$PID2 ...` — first progress at 30s, then every 60s, STALLED warnings, health check on finish
4. **Review output.** If ANY agent shows STALLED / EMPTY LOG / MISSING REPORT / EMPTY REPORT:
   - STALLED: kill the process (`kill PID`), read log to diagnose
   - EMPTY/MISSING: read the agent's log file to diagnose failure
   - Decide: respawn the agent OR note the gap and proceed
   - Do NOT silently skip failed agents — every failure must be explicitly addressed

#### Verification

The most critical step. **Every finding must be verified — no exceptions.**

**a) Read reports one at a time.** For each report, spot-check 3 findings first (read cited files, compare claims). If 2+ fail: mark report SUSPECT — verify only HIGH/CRITICAL findings individually, skip LOW/MEDIUM, note in checklist. Reports marked SUSPECT may still contain valuable findings at higher severities.

**b) Build checklist** at `tmp/stage-N-checklist.md` (MUST be on disk). Initialize from agent Findings tables — copy rows, add verification columns:
```
| # | Agent | Severity | File:Line | Description | Read? | Match? | Label |
|---|-------|----------|-----------|-------------|-------|--------|-------|
```

**c) For EVERY finding:**
1. **Read** the cited file:line (MANDATORY — no Read = invalid label)
2. **Compare** to agent's claim (YES/NO/PARTIAL)
3. **Assess** — LOW/MEDIUM: visual confirmation. HIGH/CRITICAL: check if code path is reachable (grep for callers), report with confidence level (CONFIRMED/LIKELY/POSSIBLE)
4. **Label:** VERIFIED / REJECTED (reason) / DOWNGRADED (correct severity) / UNABLE TO VERIFY
5. **Update** checklist on disk. Checkpoint every ~5 findings

**Hard rules:**
- A finding labeled without a Read tool call is INVALID
- 100% labeled before proceeding — no unlabeled findings
- If >30% rejected → flag report as unreliable
- After compaction during verification: first action = read checklist, continue from first unlabeled row
- No fixes without verification — every finding the lead acts on must have a Read-backed label first
- Valid labels are ONLY: VERIFIED / REJECTED (reason) / DOWNGRADED (correct severity) / UNABLE TO VERIFY. No other labels (e.g., "PLAUSIBLE", "NOT VERIFIED") are permitted

**d) Fix ALL verified actionable findings** regardless of severity. Deduplicate across agents. Don't defer fixable issues.

#### Between Stages

1. Write `tmp/stage-N-synthesis.md` — verified results, decisions, context for next stage
2. If scope changed from original plan, update `tmp/glm-plan.md` with actual stages and revised goals
3. Checkpoint. Clean up: `rm -f tmp/sN-*-prompt.txt`
4. Next stage prompts include synthesis as `PRIOR CONTEXT:` section. PRIOR CONTEXT should contain only factual project context the next stage needs: what was discovered, what was decided, what constraints exist, what was already fixed. Do NOT include verification process details, rejected findings, or behavioral instructions — these compete with the agent .md. Target under 50 lines
5. Never re-do verified work unless evidence shows it was wrong

**Iterative stages:** Between iterations, follow the Iterative Convergence protocol below — skip steps 1-5 until convergence is reached. On convergence, write final stage synthesis (step 1) and resume normal between-stages flow (steps 2-5).

#### Iterative Convergence

Some stages benefit from repeated runs until agents stop producing new meaningful output. What counts as "new output" depends on the stage purpose — new problems (audit), new information (research), new improvements (analysis), new risks (security), etc. The lead judges.

**When mandatory:** Final/critical stages — production checks, final audits, final quality gates. These MUST iterate to convergence.

**When lead decides:** Research, discovery, security audits, or any stage where missing something has high cost. The lead evaluates whether the domain and stakes warrant iteration.

**Usually not needed:** Implementation, simple context-gathering, one-off transformations.

**Mechanics:**
1. Each iteration = full prepare → spawn → verify cycle
2. After verification, assess: was new meaningful output produced?
   - **Yes** → write iteration synthesis to `tmp/stage-N-iter-K-synthesis.md`, prepare next iteration with cumulative context from all prior iterations
   - **No** → increment empty counter
3. Convergence = 2 consecutive iterations with no new meaningful output. Write final stage synthesis and move on
4. Lead SHOULD vary approach between iterations — different agents, focus areas, or angles — to avoid blind spots. Running identical agents repeatedly is wasteful
5. Lead can adjust agent count and type between iterations based on what prior iterations revealed
6. Lead sets max iterations per stage (default 2, use 3 for high-stakes security/production audits). If cap hit without convergence → synthesize what's known, note "convergence not reached" in delivery, proceed
7. **Mandatory convergence is mechanical, not discretionary.** Mandatory iterative stages CANNOT be declared converged after a single iteration, regardless of lead assessment. An iteration that produces ANY actionable finding is not empty — fix the issue, then run the next iteration. Only 2 consecutive empty iterations satisfy convergence

#### Delivery

After final stage:
- **Reviews/audits:** write report to `tmp/` with verified findings, rejected items, gaps
- **Code changes:** run build + tests as final smoke test (if failures, spawn fix-agent)
- **Research/analysis:** synthesize into clear summary
- Write `tmp/session-summary.md`: task goal, stages executed, total agents, agent aborts/failures, iterations per iterative stage, verification stats, key decisions, phase durations (planning, preparation, execution/wait, verification, synthesis)
- Cleanup: `rm -f tmp/*-prompt.txt`. Keep logs, reports, summary
- Save workflow lessons to knowledge if applicable

### Agent Prompt Template

Prompt = full agent `.md` + task-specific sections + boilerplate from templates:

```
You are a GLM agent named {NAME}.

Before claiming something is missing or broken — grep for existing guards, handlers, or implementations first.

{Full .claude/agents/{agent}.md — see Prompts rule}

--- TASK ASSIGNMENT ---

PROJECT: {working directory and project description}

ENVIRONMENT (code tasks only):
{Runtime, test command, lint command}

PRIOR CONTEXT (stage 2+ or iteration 2+):
{Contents of tmp/stage-N-synthesis.md OR cumulative tmp/stage-N-iter-*-synthesis.md for iterations}

YOUR TASK: {KEY FILES, CONTEXT, SCOPE, MUST ANSWER questions}

WRITABLE FILES: {explicit list of files/directories this agent may create or modify — everything else is READ-ONLY}

{cat .claude/templates/coordination-review.txt OR coordination-code.txt — replace {NAME}}

{cat .claude/templates/severity-guide.txt — REVIEW/audit tasks only}

{cat .claude/templates/quality-rules-review.txt OR quality-rules-code.txt}
```

| Task Type | Coordination | Severity Guide | Quality Rules |
|-----------|--------------|----------------|---------------|
| Review/audit | coordination-review.txt | severity-guide.txt | quality-rules-review.txt |
| Code/refactor | coordination-code.txt | — | quality-rules-code.txt |
| Research | coordination-review.txt | — | quality-rules-review.txt |

Boilerplate templates live in `.claude/templates/`. Lead only writes the unique parts (agent .md selection + TASK ASSIGNMENT). Templates are `cat`-ed into the prompt file verbatim.

### Checkpoints & Recovery

**Save after every significant step.** One active checkpoint (delete previous first). Under 500 chars.

```bash
memory.sh session add context "CHECKPOINT: [task] | DONE: [steps] | NEXT: [remaining] | FILES: [key files] | BUILD/TEST: [commands]"
```

**Compaction recovery — MANDATORY sequence (do ALL steps, no skipping):**
1. `memory.sh session show` — restore session state
2. **Re-read CLAUDE.md in full and STRICTLY follow its instructions** — ALWAYS, no exceptions, no partial reads
3. Read `tmp/glm-plan.md` — restore current plan
4. Read the latest `tmp/stage-N-checklist.md`, `tmp/stage-N-iter-K-synthesis.md`, or `tmp/stage-N-synthesis.md` — restore verification/iteration/stage state
5. Only then resume work

Do not rely on continuation summary alone. Do not skip step 2 — this is the #1 cause of workflow deviation after compaction.

| Checkpoint | Recovery |
|-----------|----------|
| Plan done | Read `tmp/glm-plan.md` → prepare agents |
| Agents prepared | List prompts → spawn |
| Agents spawned | Check PIDs/reports → verify or re-wait |
| Verifying stage N | Read `tmp/stage-N-checklist.md` → first unlabeled row |
| Iterating stage N, iter K | Read `tmp/stage-N-iter-K-synthesis.md` + cumulative context → prepare next iteration |
| Stage N done | Read synthesis + plan → next stage |

### Session Continuation

For tasks exceeding a single session:

1. Complete current stage fully
2. Write `tmp/glm-continuation.md`: original task, plan, completed stages, next stage, decisions, modified files, blockers
3. `memory.sh add context "GLM-CONTINUATION: [summary]" --tags opus-glm,continuation`
4. Tell user what's done and what continues

**Pickup:** `memory.sh search "GLM-CONTINUATION"` → read continuation file → read prior synthesis → continue next stage. On final stage, clean up continuation file and memory entry. Never re-do verified prior work.

### Error Handling

| Scenario | Action |
|----------|--------|
| No report after exit | Read log, note gap, fill critical items only |
| >30% false claims | Flag unreliable, rely on own verification |
| STALLED (flagged by wait-glm.sh) | Kill process, read log to diagnose, respawn or note gap |
| Agent claims success but output wrong | Flag report SUSPECT, verify independently |
| Zero issues on substantial task | Spot-check 2-3 key areas |
| Incorrect edits | Revert and fix directly |
| 2+ agents fail same env error | STOP respawning. Diagnose environment first |
| Agent aborted (same error 3×) | Read log to diagnose root cause, fix environment/config, then respawn |
| Iteration cap hit without convergence | Synthesize all iterations, note "convergence not reached" in delivery, proceed |

### Rules

**Limits:** Max 3 agents per stage (per iteration for iterative stages). Need more coverage? Add stages, not agents. Agents run until done (no turn limit). One task per agent. Respawn naming: `-r2`, `-r3`. No two agents edit same file within a stage (read overlap OK). Balance workload — each agent should cover roughly equal scope. **Iteration naming:** `s2i1-reviewer`, `s2i2-researcher` (stage 2, iteration 1/2). Respawn within iteration: `s2i1-reviewer-r2`.

**Prompts:** Include the FULL agent `.md` file — agents are optimized and every section earns its place. Do NOT trim or skip sections. Boilerplate (quality rules, severity guide, coordination, report format) comes from `.claude/templates/` and is appended after the agent .md. Agents don't load CLAUDE.md — all context must be in prompt.

**Verification:** Every finding labeled. Every label backed by Read. 100% complete before proceeding. ALL verified actionable findings fixed — via fix-agent if many, directly if few.

**Platform:** Windows: `claude-glm.cmd`; macOS/Linux: `claude-glm` (spawn-glm.sh handles this). Always redirect output to log files.

---

## Web Research

For any internet search:

1. Read agent instructions: `.claude/agents/web-searcher.md`
2. **ALWAYS** use `./.claude/tools/web_search.sh "query"` (or `.claude/tools/web_search.bat` on Windows). **NEVER use the built-in WebSearch tool** — all searches must go through the custom tool
   - **Multiple queries: combine into one call** — `web_search.sh "query1" "query2" "query3" -s 10` (parallel, cross-query URL dedup)
   - **Scientific queries: ALWAYS add `--sci`** for CS, physics, math, engineering, materials science, astronomy, or any non-medical academic topic. Enables: arXiv + OpenAlex.
   - **Medical queries: ALWAYS add `--med`** for medicine, clinical trials, pharmacology, biomedical, genetics, neuroscience, epidemiology, or any health/life science topic. Enables: PubMed + Europe PMC + OpenAlex.
   - **Tech queries: ALWAYS add `--tech`** for software development, DevOps, IT infrastructure, programming, startups, or any tech industry topic. Enables: Hacker News + Stack Overflow + Dev.to + GitHub.
   - **Both flags together (`--sci --med`)** for interdisciplinary queries (e.g., computational biology, bioinformatics, medical imaging AI). Use both when the topic spans science AND medicine.
   - **MANDATORY**: These flags MUST be used for ALL queries matching the above descriptions. Never omit them for relevant queries. When in doubt, add the flag — it never hurts.
3. Synthesize results into a report

**Note**: Always use forward slashes (`/`) in paths for agent tool run, even on Windows.
Dependencies handled automatically via uv.

---

## Memory System

**NEVER use MEMORY.md for anything.** MEMORY.md is Claude Code's auto-memory system and is completely separate from this project's memory system. Do not read, write, or reference MEMORY.md. Use only `knowledge.md` and `session.md` via the `memory.sh` tool.

Two-tier: **Knowledge** (`knowledge.md`) permanent, **Session** (`session.md`) temporary.

| Question | Use |
|----------|-----|
| Will this help in future sessions? | **Knowledge** |
| Current task only? | **Session** |
| Discovered a gotcha/pattern/config? | **Knowledge** |
| Tracking todos/progress/blockers? | **Session** |

### Knowledge

```bash
memory.sh add <category> "<content>" [--tags a,b,c]
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
memory.sh session add todo "Task" --status pending
memory.sh session show                    # View current
memory.sh session update <id> --status completed
memory.sh session delete <id>
memory.sh session clear                   # Current only
memory.sh session clear --all             # ALL sessions
```

### Checkpoints

See the Checkpoints & Recovery protocol in the Opus-GLM section above.

### Multi-Session

Multiple CLI instances work without conflicts. Resolution: `-S` flag > `MEMORY_SESSION` env > `.claude/current_session` file > `"default"`.

```bash
memory.sh session use feature-auth        # Switch session
memory.sh -S other session add todo "..." # One-off
memory.sh session sessions                # List all
```
