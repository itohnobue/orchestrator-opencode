## Agents

110 specialized AI agents for OpenCode. Agents are stored in `.opencode/agents/` as Markdown files with YAML frontmatter.

**Discovery:** Consult `.opencode/agents/INDEX.md` for the full categorized agent directory (110 agents grouped by domain). Pick the MOST specialized agent — domain-specific checklists and anti-patterns only work when the agent matches the domain.

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

Checkpoints are session-context entries written after every workflow step. Full protocol — when to checkpoint, format, and compaction recovery sequence — is in GLM-OpenCode → Checkpoints & Recovery.

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

## GLM-OpenCode

Dynamic orchestration where the lead delegates work to specialized agents. Evaluates every task, designs the workflow, spawns agents, verifies output, delivers results. **Automatic by default.**

The ONLY agent-delegation pipeline is `spawn-glm.sh` → `assemble-prompt.sh` → `wait-glm.sh`. The `Task` tool's `subagent_type` parameter is forbidden — see Rules → Task tool prohibition for the full statement.

### Agent Loading Rules

Agents folder: `.opencode/agents/`. Use agents for all non-trivial subtasks — code writing, analysis, design, debugging, testing, documentation.

**Rules:**
- Before any subtask: select the best agent and read its `.md` file (always fresh re-read)
- Load ONE agent at a time (Exception: GLM-OpenCode may read multiple for prompt building)
- All agent delegation goes through `spawn-glm.sh` — see Rules → Task tool prohibition
- Agent instructions are TEMPORARY — apply to current subtask only, discard after

**Discovery:** Glob `.opencode/agents/*.md` to list, Grep by keyword. Prefer specialized over general agents.

### Request Workflow

1. **Memory:** `./.opencode/tools/memory.sh context "<keywords>"` — extract from entities, technologies, services, error types. MANDATORY for non-trivial tasks
2. **Continuation:** `./.opencode/tools/memory.sh search "GLM-CONTINUATION"` — resume if exists
3. **Evaluate GLM:** If any GLM-OpenCode delegate trigger matches → enter GLM flow (skip 4-5)
4. **Plan:** For multi-step tasks: `./.opencode/tools/memory.sh session add plan "..."`
5. **Decompose:** List subtasks, map each to best agent, report to user

**CRITICAL — Plan Display Rule:** Before spawning ANY agent you MUST output the full stage plan as text to the user — see Workflow → Planning for the exact format. Writing the plan to `tmp/glm-plan.md` does NOT replace showing it. Display first, then proceed.

### Subtask Workflow

1. Read agent `.md` → apply to current subtask → complete fully → verify quality
2. Save discoveries to knowledge if non-trivial
3. Discard agent instructions → next subtask
4. After all subtasks: compose into one report

### When to Delegate

Delegation is the default. Evaluate EVERY task before starting.

**Why delegation produces better results:** A specialist agent with a dedicated context window focused exclusively on one domain will find issues you would miss while context-switching between multiple concerns. For most non-trivial work, delegation maximizes correctness by giving each problem domain undivided analytical attention.

**Handle directly ONLY when ALL of these are true:**
- You already have full context (no discovery needed)
- Single domain, single concern

**Delegate when ANY of these match:**
- Multiple distinct topics/domains/areas involved
- Task requires synthesizing information from different sources
- Involves any kind of audit, review, or comprehensive analysis
- Combines research with any follow-up action
- Task has natural subtask boundaries that could run in parallel
- Independent parallelizable subtasks
- Production checks, security audits, code reviews

Prefer higher agent count over faster execution — more coverage finds more issues.

### Lead Role

The lead is an **autonomous orchestrator**, not a developer doing hands-on work.

**Does:** plan, decompose, design workflow stages, write agent prompts, spawn agents, delegate verification to finding-verifier, review verified checklists, spawn fix-agents for verified findings, synthesize, deliver.

**Does not:** run test suites, do comprehensive audits unprompted, write substantial code, do deep research. These are agent work.

**Lead success metrics:**
- **Success:** Decomposable subtasks went to specialists. Your context stayed clean for coordination. Findings were verified. Direct work, when used, was justified and proportionate.
- **Failure:** You did substantial work an agent should have done. You read raw domain data that would have been better isolated in a specialist's context. You produced analysis without verification.

**Self-check rules (MANDATORY) — run before working on ANY subtask:**
- Heavy Read/Grep usage for planning and verification is expected and allowed
- If a specialized agent in `.opencode/agents/INDEX.md` matches the subtask domain → **SPAWN it.** Don't reproduce its work yourself
- If the subtask requires writing code, running test suites, or deep analysis across many files → that's agent work. Delegate it via `spawn-glm.sh` (see Rules → Task tool prohibition for the absolute rule)
- When direct work is truly needed (agent failed, small cleanup, trivial single-domain task with full context already): justify with `DIRECT WORK: [reason]`

**Verification vs implementation boundary:**
- Verification (lead delegates): After stage agents complete, spawn finding-verifier to process their reports → review the verified checklist at high level (spot-check 3-5 findings) → act on VERIFIED findings
- Implementation (agent does): Writing/editing code, running test suites, fixing bugs, adding tests, refactoring
- **When to delegate:** Large implementation work (new features, 5+ files, 50+ lines of new code) → always spawn an agent
- **When lead does direct work:** Agent failed or produced poor results AND the remaining fix is manageable (under ~50 lines, few files). Justify with `DIRECT WORK: [reason]`. This is expected and efficient — don't respawn for small cleanup
- After the finding-verifier produces a verified checklist, if many fixes are needed across many files: collect them into a fix-agent prompt and spawn

**Workflow autonomy:** The lead designs the complete workflow and runs it to completion without waiting for user approval. The lead chooses what stages are needed (research, implement, test, audit, or any combination), their order, agent count, and can add or modify stages during execution as understanding deepens. Each stage follows the prepare → spawn → verify cycle. The lead has full authority to adapt the plan mid-execution — no restrictions on total agents or stages if the task requires them. (Plan must be displayed to user before spawning — see Plan Display Rule above.)

### Tools

Max 3 agents running in parallel.

**Spawn:**
```bash
.opencode/tools/spawn-glm.sh -n NAME -f PROMPT_FILE [-m MODEL]
```
Returns `SPAWNED|name|pid|log_file`. Backgrounds immediately. Report: `tmp/{NAME}-report.md`, log: `tmp/{NAME}-log.txt`. Also writes to `tmp/{NAME}-status.txt` (reliable on Windows — stdout can be lost when parallel `.cmd` processes launch).

**Wait:**
```bash
.opencode/tools/wait-glm.sh name1:$PID1 name2:$PID2 name3:$PID3
```
Blocks until all finish (Bash timeout: 600000). Do NOT use bare `wait` or `sleep` + poll loops. Prefer `name:pid` format — enables progress monitoring (first at 30s, then every 60s) and STALLED detection (0-byte log after 2min). Bare PIDs still work but skip log monitoring. If Bash times out before agents finish, re-invoke with same arguments — this is normal for long-running agents.

### Workflow

The lead designs the workflow. Typical flow: plan → for each stage: prepare → spawn → wait → verify (finding-verifier agent) → between stages → next stage. **Stages may be iterative (see Iterative Convergence).** The lead decides what stages are needed and in what order. After all stages complete, a final verification pass by the finding-verifier reviews the complete accumulated workflow output.

#### Planning

**MANDATORY: Research before implementation.** Before writing ANY agent prompt for a new component, the lead MUST:
1. Read the plan section for the component
2. Read the ACTUAL reference source code for the equivalent feature — the plan may have misinterpreted, oversimplified, or missed fields/logic
3. Compare plan's proposed design against reference reality — fix discrepancies BEFORE spawning
4. Only spawn agents when confident enough to write well-scoped prompts — remaining uncertainty should be captured in MUST ANSWER questions for agents to resolve
5. Invest time in preparation — perfect prompts produce better results than fast prompts. No time pressure on research.

Research enough to write well-scoped prompts — skim files (structure, function names, imports, sizes), understand project layout, identify the right agents. Don't trace logic chains or do deep analysis — that's agent work. **When scope is unclear, start with one or more research stages before implementation.** Spawning research agents (even iteratively to convergence) is encouraged — thorough research almost always produces better results in later stages. Decompose into stages. **ALWAYS output the full plan to the user before spawning any agents:**
```
Plan: [N stages, M total agents]
  Stage 1: [purpose] — [agents] → delivers [what]
  Stage 2: [purpose] — [agents, batch 1: A,B | batch 2: C] → delivers [what] [iterative] (discretionary)
  Stage 3: [purpose] — uses Stage 2 output → delivers [what] [iterative] (mandatory)
```
Iterative stages MUST be marked with `[iterative]` in the brief. Mark `(mandatory)` vs `(discretionary)`. **Do NOT wait for user approval — output the plan and proceed immediately.**

**Delegation mapping (MANDATORY in every plan):** During planning you MUST answer:
1. What subtasks exist? (list each one)
2. Which agent handles each subtask? (map agent name to subtask — consult `.opencode/agents/INDEX.md`)
3. Which subtasks, if any, do you handle directly? (justify against the Self-check rules above)

Answer these explicitly in your plan. If a subtask is unassigned ("I'll do it myself") without justification, stop and find the right agent. (Inter-subtask dependencies are handled separately by the Dependency analysis step below.)

Write full plan to `tmp/glm-plan.md`. Checkpoint.

Single-stage when all agents can work independently. Multi-stage when later work depends on earlier results, or when scope is too large for a single agent to cover thoroughly.

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

**Session start:** Clean ALL stale GLM artifacts: `rm -f tmp/glm-plan.md tmp/stage-*-synthesis.md tmp/stage-*-iter-*-synthesis.md tmp/s[0-9]*.txt tmp/s[0-9]*-report.md tmp/plan-review-*`

CAUTION: Never use broad patterns like `tmp/*-report.md` or `tmp/*-log.txt` — they will delete non-workflow files (e.g. `log-analysis-report.md`). GLM agent names follow `s{digit}...` prefix (e.g. `s1-researcher`, `s2i1-reviewer-r2`), so `tmp/s[0-9]*` safely matches only workflow artifacts.

**Session boundaries:** If task will likely need >4 stages, plan explicit session splits using the continuation protocol. Long sessions degrade from compaction pressure.

#### Agent Preparation

Consult `.opencode/agents/INDEX.md` for the full agent directory (110 agents grouped by domain). Pick the MOST specialized agent (see Agent Selection above) — a PostgreSQL task should use postgres-pro, not database-optimizer. The agent's domain checklists and anti-patterns are the primary value — they only work when the agent matches the domain.

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
6. **WRITABLE FILES:** Code agents: task file MUST list the exact source files/directories the agent may modify. Review/audit/research agents: omit WRITABLE FILES entirely — the script auto-injects the correct report path and marks all source files as read-only.
7. **Pre-spawn check:** Before spawning code agents, verify the build/test commands work (quick run). For review agents, confirm key files are readable. A 30-second check prevents multi-agent failures from broken environments.

Describe problems and desired behavior — do NOT paste exact fix code unless precision is critical (regex, API signatures, security logic). Name agents with stage prefix: `s1-researcher`, `s2-impl-auth`.

#### Execution

1. Spawn current batch of agents via `spawn-glm.sh`, respecting the per-batch limit from Tools and the dependency analysis above. If stdout is empty (Windows `.cmd` issue), read `tmp/{NAME}-status.txt` to get PID. Checkpoint with PIDs and names. If stage has multiple batches, wait for current batch to finish before spawning next
2. Do verification prep (pre-read key files for spot-checks)
3. `wait-glm.sh name1:$PID1 name2:$PID2 ...` — first progress at 30s, then every 60s, STALLED warnings, health check on finish
4. **Review output.** If ANY agent shows STALLED / EMPTY LOG / MISSING REPORT / EMPTY REPORT:
   - STALLED: kill the process (`kill PID`), read log to diagnose
   - EMPTY/MISSING: read the agent's log file to diagnose failure
   - Decide: respawn the agent OR note the gap and proceed
   - Do NOT silently skip failed agents — every failure must be explicitly addressed

#### Verification

After all agents in a stage complete, the lead spawns the **finding-verifier** agent to process their reports. The lead does NOT manually verify every finding — that's the agent's job.

**a) Spawn finding-verifier.** The finding-verifier agent reads all agent reports from the stage, cross-references findings across reports, reads cited source files, applies all verification rules, and produces a verified checklist with every finding labeled. It runs with a clean context focused solely on evaluating claims against evidence — use a strong reasoning model for best re-evaluation quality.

The finding-verifier is MANDATORY after every stage that produces findings/reports. Exception: trivial context-gathering stages with no findings to verify — lead may mark the verification step as SKIPPED with explicit justification.

**b) Review verified checklist.** After the finding-verifier completes, the lead reviews its output at a high level:
- Read the summary (total findings, label breakdown, suspect reports)
- Spot-check 3-5 findings across different labels and agents (read cited file:line, confirm label is reasonable)
- If spot-checks reveal issues (>2 of 5 disagree with verifier's label) → investigation may be needed
- If the verifier flagged any report SUSPECT (>30% rejected) → note for reduced confidence in remaining findings from that report

**c) Handle cross-report issues:**
- Findings VERIFIED by the verifier that appear in multiple reports → highest confidence, fix first
- Findings flagged as contradictory between reports → lead makes judgment call or spawns a focused agent to resolve
- Findings UNABLE TO VERIFY → lead decides whether to investigate further or accept the gap

**d) Act on verified findings:**
- Fix ALL VERIFIED actionable findings, regardless of severity. Deduplicate across agents.
- If many fixes needed across many files: collect findings into a fix-agent prompt and spawn
- If few fixes: lead may apply directly (DIRECT WORK must be justified)

**e) Verification agent quality check:**
- If the finding-verifier produced SUSPECT output (inconsistent labels, obviously wrong rejections, missed cross-report agreements) → re-spawn with different params: adjusted focus areas, different MUST ANSWER questions, or re-worded task
- Do NOT revert to manual per-finding verification — the point is delegation. If the verifier consistently underperforms, escalate (different model, different prompt strategy) rather than falling back

**f) Final verification pass.** After ALL stages complete (not just each individual stage), spawn the finding-verifier one final time on the complete accumulated workflow output. This ensures cross-stage issues (contradictions between stages, gaps that emerged only in integration, regressions introduced by later fixes) are caught before delivery.

#### Between Stages

1. Write `tmp/stage-N-synthesis.md` — verified results from the finding-verifier's checklist, decisions, context for next stage
2. If scope changed from original plan, update `tmp/glm-plan.md` with actual stages and revised goals
3. Checkpoint. Clean up: `rm -f tmp/sN-*-prompt.txt tmp/sN-*-task.txt`
4. Next stage prompts include synthesis as `PRIOR CONTEXT:` section. PRIOR CONTEXT should contain only factual project context the next stage needs: what was discovered, what was decided, what constraints exist, what was already fixed. Do NOT include verification process details, rejected findings, or behavioral instructions — these compete with the agent .md. Target under 50 lines
5. Never re-do verified work unless evidence shows it was wrong
6. Never skip a planned stage without explicitly marking it in `tmp/glm-plan.md` as `SKIPPED` with a reason. A stage is only complete when its agents have been spawned, waited, their reports processed by the finding-verifier, and findings verified.
7. After writing synthesis, read `tmp/glm-plan.md` to confirm the next stage. If the plan has remaining stages, execute them — do not deliver early unless remaining stages are explicitly marked SKIPPED.

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
4. Lead SHOULD vary approach between iterations — different agents, focus areas, or angles — to avoid blind spots. Running identical agents repeatedly is wasteful. For iteration 2+ in convergence stages on implementation work, add a review pair as a new stage to verify the iteration's output cross-iteration.
5. Lead can adjust agent count and type between iterations based on what prior iterations revealed
6. Lead sets max iterations per stage (default 2, use 3 for high-stakes security/production audits). If cap hit without convergence → synthesize what's known, note "convergence not reached" in delivery, proceed
7. **Mandatory convergence is mechanical, not discretionary.** Mandatory iterative stages CANNOT be declared converged after a single iteration, regardless of lead assessment. An iteration that produces ANY actionable finding is not empty — fix the issue, then run the next iteration. Only 2 consecutive empty iterations satisfy convergence
8. **Naming:** iteration agents follow `s{N}i{K}-name` — e.g. `s2i1-reviewer`, `s2i2-researcher` (stage 2, iteration 1/2). Respawn within iteration: `s2i1-reviewer-r2`

#### Delivery

**Before delivery:** Read `tmp/glm-plan.md`. Confirm every planned stage is complete or explicitly marked SKIPPED with justification. A stage silently skipped = not delivered yet. Execute it or update the plan.

After final stage:
- **Reviews/audits:** write report to `tmp/` with verified findings, rejected items, gaps
- **Code changes:** run build + tests as final smoke test (if failures, spawn fix-agent)
- **Research/analysis:** synthesize into clear summary
- Write `tmp/session-summary.md`: task goal, stages executed, total agents, agent aborts/failures, iterations per iterative stage, verification stats, key decisions, phase durations (planning, preparation, execution/wait, verification, synthesis)
- Cleanup: `rm -f tmp/*-prompt.txt tmp/*-task.txt`. Keep logs, reports, summary
- Save workflow lessons to knowledge if applicable

### Agent Prompt Template

Prompt = full agent `.md` + task-specific sections + boilerplate from templates:

```
You are an AI agent named {NAME}.

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
1. Run `.opencode/tools/glm-recover.sh` — prints memory session, plan, continuation (if any), newest synthesis (iter or stage, by mtime), and latest verifier report in one stream. Replaces steps 1, 3, 4 below with a single command
2. **Re-read AGENTS.md in full and STRICTLY follow its instructions** — ALWAYS, no exceptions, no partial reads. `glm-recover.sh` does NOT do this for you
3. Only then resume work

If `glm-recover.sh` is unavailable, fall back to the manual sequence:
1. `./.opencode/tools/memory.sh session show` — restore session state
2. Read `tmp/glm-plan.md` — restore current plan
3. Read the latest `tmp/sN-verifier-report.md`, `tmp/stage-N-iter-K-synthesis.md`, or `tmp/stage-N-synthesis.md` — restore verification/iteration/stage state

Do not rely on continuation summary alone. Do not skip the AGENTS.md re-read — this is the #1 cause of workflow deviation after compaction.

| Checkpoint | Recovery |
|-----------|----------|
| Plan done | Read `tmp/glm-plan.md` → prepare agents |
| Agents prepared | List prompts → spawn |
| Agents spawned | Check PIDs/reports → verify or re-wait |
| Verifying stage N | Read finding-verifier report at `tmp/sN-verifier-report.md` → spot-check 3-5 findings → review summary |
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
| No report after exit | Read log, note gap, fill critical items only |
| >30% false claims | Flag unreliable, rely on own verification |
| STALLED (flagged by wait-glm.sh) | Kill process, read log to diagnose, respawn or note gap |
| Agent claims success but output wrong | Flag report SUSPECT, verify independently |
| Zero issues on substantial task | Spot-check 2-3 key areas |
| Incorrect edits | Revert and fix directly |
| 2+ agents fail same env error | STOP respawning. Diagnose environment first |
| Agent aborted (same error 3×) | Read log to diagnose root cause, fix environment/config, then respawn |
| Iteration cap hit without convergence | Synthesize all iterations, note "convergence not reached" in delivery, proceed |
| Finding-verifier produces SUSPECT checklist (inconsistent labels, obviously wrong rejections, missed cross-report agreements) | Re-spawn with different params — adjusted focus areas, different MUST ANSWER questions, or re-worded task. Do NOT revert to manual per-finding verification |

### Rules

**Quality over speed — ALWAYS.** Never rush, never cut corners, never try to finish faster. Slow, thorough, methodical work produces quality. Speed produces bugs. Prefer more stages, more agents, more verification over shorter timelines. There is no deadline. The only measure of success is production-ready, bug-free code.

**Limits:** Per-batch limit defined in Tools — don't restate. Need more coverage? Add stages, not agents. Agents run until done (no turn limit). One task per agent. Respawn naming: `-r2`, `-r3`. No two agents edit same file within a stage (read overlap OK). Balance workload — each agent should cover roughly equal scope.

**Task tool prohibition (MANDATORY — single most important rule):** Agent delegation in this project happens ONLY via `spawn-glm.sh`. The `Task` tool with its `subagent_type` parameter is FORBIDDEN — never call it, regardless of the use case (exploration, code review, implementation, research, anything).

The Task tool's built-in `subagent_type` list happens to share names with our agent `.md` files in `.opencode/agents/` (`code-reviewer`, `ios-pro`, `swift-pro`, etc.) — these are TWO DIFFERENT THINGS. The Task tool ships a separate sub-agent runtime that bypasses our review pipeline, the `spawn-glm.sh` flow, verification, report formats, and quality rules. Our agent `.md` files are reached ONLY by passing `-a AGENT_NAME` to `assemble-prompt.sh` and then spawning via `spawn-glm.sh`.

If you catch yourself about to call `Task(subagent_type=...)` — stop, use `spawn-glm.sh` instead.

**Agent count per stage (MANDATORY — no shortcuts):** Always use ALL available slots per stage. Spawn up to 3 agents filling all parallelizable work. When the task naturally decomposes into independent subtasks, split them across more agents. In doubt, prefer more agents over fewer — broader parallel coverage produces higher quality results.

**Prompts:** Include the FULL agent `.md` file — agents are optimized and every section earns its place. Do NOT trim or skip sections. Boilerplate (quality rules, severity guide, coordination, report format) comes from `.opencode/templates/` and is appended after the agent .md. Agents don't load AGENTS.md — all context must be in prompt.

**Verification:** Every finding labeled. Every label backed by Read. 100% complete before proceeding. ALL verified actionable findings fixed — via fix-agent if many, directly if few.

**Platform:** `opencode` on all platforms (spawn-glm.sh handles invocation). Always redirect output to log files.

---

## Skills (Workflows)

Workflows are available as skills in `.opencode/skills/` directory. Use `/skill-name` to invoke. Skills are project-specific — define them as needed for your workflow.
