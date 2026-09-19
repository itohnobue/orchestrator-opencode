# Project-Specific — orchestrator-opencode

## Skills (Workflows)

Workflows are available as skills in `.opencode/skills/` directory. Use `/skill-name` to invoke. Skills are orthogonal to the agentic workflow — they are utility operations invoked directly by the lead as needed. Skill output is not routed through the verification pipeline. Exception: the `handoff` skill is workflow-integrated — the continuation rules (Request Workflow step 1, Session Continuation, O-R3) invoke it.

---




## Shared Workflow Infrastructure

The sections below are identical across all repositories that use this workflow system. When propagating to other repos, copy from here to end of file.

---

## Temporary Files

Use the `tmp/` subfolder in the current project folder for temporary files — intermediate results, reports, or data during multi-step workflows.

**Path resolution:** All `tmp/` paths in workflow instructions resolve to `$REPO_ROOT/tmp/` where `$REPO_ROOT` is the absolute path to the repository root (the directory where `opencode` was launched). The tool scripts (`assemble-task.sh`) compute `REPO_ROOT` and use absolute `${REPO_ROOT}/tmp/` paths so that agent reports, logs, and artifacts are always written to the correct location regardless of each agent's working directory or the project under inspection. When writing task files or instructions for agents, always reference `tmp/` paths relative to `$REPO_ROOT`.

`tmp/uv/` is reserved for the local uv installation (tool-use policy R3). Cleanup never touches it; it is not a tmp/ scratch area.

---

## Agents

12 agents for OpenCode. Agents are stored in `.opencode/agents/` as Markdown files with YAML frontmatter. There are no static specialist personas — specialist identity comes from the research stage's FOCUS angles, not from agent files. `prepare-agent` is a single-session-suite agent, provided for the single-session-workflow skill — the orchestrator pipeline does not use it. `executor` is the universal executor used by both pipelines.

**Discovery:** Read `.opencode/agents/INDEX.md` for the full agent directory (12 agents).

**Reasoning effort** is configured in the global OpenCode config (V1: model option `reasoningEffort`; V2: model `settings.reasoningEffort` — and note the root `model` does not retain a `#variant`, so set the default on the model) — agents do not pin their own.

| Agent | Role |
|-------|------|
| `agentic-planner` | Planning: classification, Research Coverage Map + Routing Table, per-agent tiers (PLAIN/researched), FOCUS angles |
| `volume-splitter` | Mechanical KEY FILES resolution, split/merge (4K/5.5K caps) |
| `agent-organizer` | Structural plan review: tiers, routing precision, FOCUS complementarity, exclusion lists |
| `verification-analyst` | Extraction + synthesis — dedups/tags findings (both-found/single-found/boundary-found, PRIOR_FIX_ATTEMPT), routes investigated-and-rejected items into adversarial batches, compiles the verification grid (severity challenges, mechanism categorization, fix-quality metric) |
| `knowledge-harvester` | Knowledge harvesting from verified findings — PATTERN/INCIDENT classification, dedup against knowledge.md, PATTERN entries with prevention recommendations, supersede-evaluate existing entries, writes `tmp/knowledge-harvest-report.md` |
| `adversarial-reviewer` | Falsification gate — the single distinct quality gate; batch sizes CRITICAL (1:1), HIGH (1:3), MEDIUM (1:10) are volume controls; Findings-Review Mode |
| `web-searcher` | RESEARCH brick — internet research |
| `research-analyst` | RESEARCH brick — structured analysis; mid-execution research |
| `data-researcher` | RESEARCH brick — dataset research |
| `executor` | The ONE generic executor: DISCOVER, IMPLEMENT, REVIEW, FIX, TEST, TEST-UPDATE, quick-fix, build-gate, final gate, single-session tasks. Post-fix review is NOT its job — that is `postfix-reviewer`'s. PLAIN or researched (digest injected + full report path). No web research of its own. |
| `postfix-reviewer` | Post-fix review ONLY (strictly read-only) — verifies applied fixes against their design: correctness, minimality, new bugs, test breakage, race conditions; verdict APPROVED / NEEDS-FIX. Never used for any other task. No web research of its own. |
| `prepare-agent` | (single-session-workflow skill) Research generation: per-technology queries, full research report + compact digest (~10KB). FOCUS parameter defines the specialist identity. |

### Agent Selection

All execution → `executor`. Tier per the ONE general rule (PLAIN / researched — see Tier rule). Research → web-searcher / research-analyst / data-researcher. Split hybrid tasks into subtasks with different FOCUS angles.

### The Tier rule (THE ONE general rule)

> **Every agent should have research data.** If the data is already gathered and covers everything the agent needs, we do NOT add a research stage — we run plain and pass the already-present data with the task. Research is injected only when the task depends on facts the file does not carry.

Operational meaning:
- **PLAIN** = pass-through mode: the task file ALREADY carries the research (planner-baked context, contracts, specs, expected behaviors, external facts). No injection needed — the data travels with the task. Never "no research".
- **researched** = the file lacks needed facts; the research stage's report supplies them as a (digest, full report) pair — the digest is injected into the prompt as `## RESEARCH DATA` (`--research-file`), the full report path prints under the header (`--research-report`) for on-demand depth.
- **Baseline:** researched. PLAIN is the optimization when the work is already done — not the default state of ignorance.

**Assemble-time tier verification (MANDATORY, lead — mechanical):** the manifest decides the tier; the lead matches flags. Manifest says researched → assemble with `--research-file <digest> --research-report <full>`; says PLAIN → assemble without them. No judgment re-check per file — tier correctness is the planner's and organizer's job (Stage 0). Mechanical flag-match errors (missing digest, wrong report ID) are fixed by re-assembly, never by changing the tier on sight.

**Precision routing (MANDATORY):** each agent receives ONLY the research data it really needs — nothing unrelated (unrelated data degrades results). Applies to routed (digest + full path) reports AND to PLAIN task files (planner-baked context scoped to the agent's domain, never a global blob). One digest per injection; the full report path rides under it.

---

## Memory System

**NEVER use MEMORY.md** — it is the built-in auto-memory system, completely separate from this project's memory system; do not read, write, or reference it. Use only `knowledge.md` and `session.md` via the `memory.sh` tool.

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

**Lead Knowledge Harvesting (after finishing anything serious — workflow-level learnings only):** the lead harvests its own orchestration-level discoveries in-session, no agents. Scope: workflow lessons (which stages/agents worked, what failed), config facts, decisions — NOT findings-derived patterns, those belong to the `knowledge-harvester` agent (see Delivery → Knowledge harvesting). Steps:
1. **Search first** — for each candidate learning: `memory.sh search <topic>`; skip what already exists
2. **Check old knowledge on the matter** — for every existing entry the task touched: outdated/incorrect → `delete` (reasons go in the report line below); partially right → replace with the better version; still correct → leave untouched. Conservative: prefer silence over noise; never delete without clear evidence
3. **Add new learnings** — categorized (see table above), tagged
4. **Report** — "Memories saved: [list]; updated: [list]; retired: [list] (reasons)" or "Memories saved: None"

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

1. **ALL internet research must go through `web_search.sh`** — no exceptions. This means: no built-in websearch tool, no WebFetch tool, no `curl` against APIs, no manual GitHub API calls, no `wget` for search. Fetching a specific known URL goes through `web_search.sh --url <url>` (direct fetch mode: one URL per run, full page saved to `tmp/webresearch/<run-id>.txt`, path printed to stdout) — the sanctioned way to get a named page when a search would be wasteful. **`--url` is for PAGE CONTENT only — never for downloading files** (full rule: see the `--url` bullet below). Every time you need information from the internet, use `./.opencode/tools/web_search.sh "query"` (or `.opencode/tools/web_search.bat` on Windows)
   - **One query per call** — run each query as a separate `web_search.sh` invocation. Never combine multiple queries into a single call. Run calls **sequentially** (one after another, not in parallel) to avoid hitting API rate limits
   - **Fixed tuned defaults** — the tool has no count or format flags: search always fetches 30 results, fetches up to 20 pages, and outputs plain text only. The only flags are the source flags `--sci`/`--med`/`--tech`, `--url` direct fetch, and `--no-render` (with `--url`; `--usage`/`--quality` are operator telemetry only) — never add count/result-limiting or output-format flags (they do not exist). Let the tool use its built-in defaults
   - **DIGEST + FULL REPORT FILE** — search mode prints a small digest (path FIRST and LAST, stats line, one technical line per page — `N. [size] [trunc] @line L @hit H — Title — URL`, best-first) and writes the full filtered text to `tmp/webresearch/<run-id>.txt` with the IDENTICAL digest at the top of the file — lose the stdout copy and the file's first lines are the digest (find the file by slug: `glob tmp/webresearch/*<slug>*.txt`). Never trim the digest with `tail`/`head`/`grep -m` or any other trimming — it is small by design and carries the FULL REPORT path. The report file IS the product: jump to a page via its `@line` (`read` with `--offset`; the next entry's `@line` marks the page end), `@hit` = first line containing the query's key term, or `grep -n '^=== <url> ==='` for a strict URL match. For a specific page's fresh content, fetch it directly with `--url` (pages only — never file downloads; see the `--url` bullet below). The stats line also carries dropped-page counters (farm/stub/stale/dedup-dropped) when quality filters removed pages.
   - **Direct URL fetch: `--url`** — when you need a specific known page (URL from a search result, docs page, paper), use `web_search.sh --url <url>` instead of WebFetch/curl/wget (no query needed — the query is optional in this mode). ONE URL per call: the full page (no output char cap; HTML extraction bounded by MAX_CONTENT_BYTES) is saved RAW to its own report file in `tmp/webresearch/` — quality filters OFF (no F4/F1 cleanup, full-document text: nav/boilerplate included); stdout prints ONLY `Full web page saved at: <path>`. JS-heavy pages (SPAs) are rendered with a headless Chromium shell automatically when static fetch fails (chromium-headless-shell — official Google build on macOS/Windows, bundled-libs build on Linux; uv-managed, fetched once into a user cache, headless/background only, no system installs); `--no-render` disables the browser. Search mode is static-only (no browser). **PAGES ONLY — never files:** `--url` fetches page content and corrupts binaries (PDFs, datasets, archives, executables). Download actual files directly (`curl -L -o <path> <url>`), never via `--url`.
   - **Scientific queries: add `--sci`** for CS, physics, math, engineering (arXiv + OpenAlex)
   - **Medical queries: add `--med`** for medicine, clinical trials, biomedical (PubMed + Europe PMC + OpenAlex)
   - **Tech queries: add `--tech`** for software dev, DevOps, IT, startups (Hacker News + Stack Overflow + Dev.to + GitHub)
   - **Empty results & timeouts are not tool failures** — a non-zero exit with a "No results: …" message on stderr means the query legitimately produced nothing usable (quality filters dropped every page, or all fetches failed) — retry with a different query angle. Each run is self-bounded by a 300s wall-clock timeout (env-overridable via `WEB_RESEARCH_TIMEOUT_SECONDS`); on timeout it exits non-zero with a "wall-clock timeout" message.
2. Synthesize results into a report

**Note**: Always use forward slashes (`/`) in paths for agent tool run, even on Windows.
Dependencies handled automatically via uv (see `## Tool-use policy: bash vs Python`).

---

## Tool-use policy: bash vs Python

Priority: dedicated tool → bash one-liner → uv run script.
Unsure between bash and script → script. A dedicated tool always wins.

R1. Dedicated tools first
  File I/O: read / write / edit / grep / glob tools. Bash search only when
  the Grep tool can't express it (counts, -o extraction) → then `rg`;
  anything beyond that → script.

R2. Bash allowed when the shell IS the interface
  - git, docker, ssh, launchctl, package managers, test/build runners,
    gh, date, ls, git status / docker ps, running apps/servers, tail -f
  - workflow scripts (memory.sh, web_search.sh, assemble-task.sh);
    skill operations via the skill tool
  - plain single-file fs ops with simple names: one mv/cp/rm/mkdir
    (no globs, no patterns, no shell-metadata in names)
  - read-only selection chains over command output only:
    filter | sort | head/tail | wc  (NOT file reads — those are R1/Read)

R3. Python — always via uv; no global pip installs, no repo venvs
  deps live only in uv's ephemeral env; uv may use a suitable system
  interpreter as base (managed Python is downloaded when required)
  - one script per tmp/ file; PEP 723 inline metadata (# /// script:
    requires-python, dependencies) → `uv run file.py` is self-contained
  - ad-hoc deps: `uv run --with <pkg> file.py`; always `--no-project`
    so a stray pyproject.toml can never switch to project mode
  - uv lives at $REPO_ROOT/tmp/uv/ (bootstrap once: UV_INSTALL_DIR +
    UV_NO_MODIFY_PATH) — never ~/.local/bin, never profile edits
  - before a parallel agent fan-out, ensure uv is already installed
    (`tmp/uv/uv --version` or one `memory.sh` call); never let parallel subagents bootstrap it
    simultaneously — first-install races can corrupt the binary
  - cross-platform reads: binary or newline='', explicit ordering
  Use a script when ANY holds:
  (a) quoting exposure: spaces, quotes, $, backticks, globs, unicode,
      user/untrusted data → argv/file only, never shell interpolation
  (b) data transform: parse, aggregate, extract fields, regex into values,
      rewrite across ≥2 files; fs ops across multiple files or with
      patterns (bash stays for selection only)
  (c) re-runnable / stateful / checks & gates / would run twice
  (d) must behave identical on macOS/Windows/vespa-linux
  (e) needs validation: error messages, invariant checks

R4. IMPORTANT — two strikes, then escalate
  An ad-hoc bash command failing on shell semantics (quoting, escaping,
  globbing, bad option, portability) → do NOT retry bash. Write the R3
  script now. Same failure class twice = violation; no third attempt.
  NOT strikes: service/process/network/tool failures (docker daemon down,
  registry hiccup, test infra) — route those per Error Handling instead.
  (Repo workflow tools: their failures go to the Error Handling path —
  diagnose, fix, respawn, max 3 — they are not rewritten on the spot.)

R5. Output discipline
  Scripts print compact results; long output → file; one progress line
  per step only if runtime > 1 min.

R6. Anti-over-engineering
  No script for one thing a dedicated tool or one trivial command does.

### Tool output & concurrency (single source — lead and agents)

Each tool/command declares two things: how much output enters context, and whether it may run alongside other agents.

- **Output budget:** `inline` (short, as-is) · `artifact` (full output → file, inline a summary/stub + path) · `N lines` (cap).
- **Concurrent-safe:** `yes` · `no` (solo only) · `conditional`.

| Category | Output budget | Concurrent-safe |
|---|---|---|
| File read / search (`read`, `grep`, `glob`) | inline; slice with offset/limit; trim hit lists | yes |
| File edit / write | diff/confirmation only | different files: yes · same file: no |
| Shell — read-only (status, diff, list, search, small reads) | inline | yes |
| Shell — build / test / lint | artifact; inline pass/fail counts + failures + last 40 lines | **no** — solo for the full build/suite; targeted checks of your own change are parallel-safe |
| Shell — install / env-mutating | artifact; inline last 15 lines + errors | **no** |
| Shell — diagnostic | inline `2>&1 \| tail -40` | read-only: yes · else no |
| Web fetch / search | digest or path inline; full page/report → artifact file | **no** — sequential (rate limits) |

Follow this table for output budgets and concurrency; the quality rules' reading-strategy and verification rules stand.

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

The ONLY agent-delegation mechanism is the opencode `task` tool. The lead assembles a task prompt with `assemble-task.sh`, then calls the `task` tool with `subagent_type` set to the agent name from `.opencode/agents/`. The 12 agents are native opencode subagents, auto-loaded from `.opencode/agents/*.md`. Agents run as in-process child sessions with full permissions inherited from the project config.

### Agent Loading Rules

Agents folder: `.opencode/agents/`. Use agents for all non-trivial subtasks — code writing, analysis, design, debugging, testing, documentation.

**Rules:**
- Before any subtask: select the agent (executor for execution; research agents for research rows)
- All agent delegation goes through the `task` tool — see Tools → Agent Spawning

**Discovery:** Glob `.opencode/agents/*.md` to list, Grep by keyword. All execution uses executor — the FOCUS angles and routed research define the specialist standpoint.

**How the lead uses agents:** The lead selects the agent by role from the INDEX (executor for execution; web-searcher/research-analyst/data-researcher for research rows), writes task files with KEY FILES, tier, and MUST ANSWER questions, and uses `assemble-task.sh` to build the task prompt (the agent's `.md` is auto-loaded by opencode as the subagent's system prompt). The lead does NOT load agent `.md` content into its own working context and never applies agent instructions itself. Agent `.md` files reach agents natively — opencode loads them for the `task` tool's `subagent_type`.

### Request Workflow

1. **Handoff check:** look for the active handoff — `tmp/handoff-*.md` (the `handoff:` session note from `memory.sh session show` names it) — resume if present
   - **If found:** Read the handoff file and the prior synthesis; once fully restored, delete the handoff + its `handoff:` session note (handoff skill → Consuming a handoff), then continue from its Next Step. The plan is already finalized and partially executed — pick up at the next uncompleted stage.
   - **If not found:** Proceed to step 2.
2. **Re-read Verification and Iterative Convergence sections:** Before spawning ANY stage agents, re-read the Verification section AND Iterative Convergence section in full. Verification defines the severity-routed pipeline (extraction → route findings by severity → synthesis). Iterative Convergence defines the planner-set iteration ceiling (ONCE default / LOOP rare) and the mechanical synthesis-grid trigger (≥1 CONFIRMED HIGH/CRITICAL). Skipping these re-reads is the #1 cause of plans missing appropriate verification and convergence. MANDATORY.

   **Do NOT read source files, skim the project, or try to understand scope before spawning.** The planner is your research — spawn it immediately. Fill in the project path, spawn, and let the planner do everything else. Any attempt to "understand the codebase first" IS the research we forbid. Go directly to step 3.

3. **Planning phase (3 batches, 3 agents) — ALWAYS run, never skipped:**
   a. **Initial planner:** Copy `.opencode/templates/planner-task-template.txt`, fill in the project path (just the working directory — the planner researches the codebase itself), assemble with `assemble-task.sh -a agentic-planner -t research -n s0-planner`, then delegate via the `task` tool (subagent_type `agentic-planner`, prompt = read-and-execute instruction + path to the assembled file — see **Spawn** below). Researches the project, classifies the task on 5 axes (size, domains, ambiguity, severity, type), selects bricks from the palette, and produces a custom workflow manifest with FILE SCOPES to `tmp/glm-plan.md`.
   b. **Volume splitter (ALL plans):** Create a task targeting `tmp/glm-plan.md` with MUST ANSWER questions covering splits, merge-backs, and path verification. Include `WRITABLE FILES: tmp/glm-plan.md` in the task file. Assemble with `assemble-task.sh -a volume-splitter -t code -n s0-volume`, then delegate via the `task` tool (subagent_type `volume-splitter`). The volume-splitter resolves FILE SCOPES to exact KEY FILES with `wc -l` counts, applies mechanical split/merge rules, builds the volume audit table, rewrites the plan in-place, and writes `tmp/s0-volume-report.md`.
   c. **Mandatory plan review (ALL plans):** Create a review task targeting `tmp/glm-plan.md` with MUST ANSWER questions covering brick selection, severity classification, agent assignment, verification placement, convergence decisions, and dependency analysis. Include `WRITABLE FILES: tmp/glm-plan.md` in the task file. Assemble with `assemble-task.sh -a agent-organizer -t review -n s0-organize`, then delegate via the `task` tool (subagent_type `agent-organizer`). The agent-organizer reviews the plan using its structural analytical framework (the volume-splitter has already resolved KEY FILES and applied mechanical splits):

       *MUST ANSWER redistribution:* When the volume-splitter created sub-agents, the original MUST ANSWER questions were copied verbatim. The organizer redistributes them — assigning each question to the sub-agent whose scope covers the relevant code, writing new scoped questions when needed.

       *Workflow quality (native anti-patterns):* Check for stale agent references, ignored dependencies, missing intersection agents, FOCUS/exclusion-list violations, missing second opinions, and missing/incomplete tier assignments. The organizer FIXES mechanical violations directly in the plan — its anti-patterns list defines the Fix/Flag split (see agent-organizer.md).

       *Structural validation (embedded rules in task):* the organizer's exact checklist is embedded in the s0-organize task (see planner-task-template.txt `TASK (s0-organize)`): stage pairings (VERIFY/REVIEW, build-gate + post-fix review), second opinions at MEDIUM+ incl. intersection seconds (post-fix primary-only), s2 complementary FOCUS + in-scope routing (Routing Table precision), exclusion-list cross-check, boundary triage + reviewers, dependency validity, and volume spot-checks. Apply structurally; flag judgment calls.

       After review, the organizer applies all structural fixes directly to `tmp/glm-plan.md`. For judgment-level findings (see agent-organizer.md Fix/Flag split), the organizer flags them in its report but does not modify them — the lead reviews and decides during Step 4. The organizer's output IS the final plan — no separate merge agent is needed. This runs on EVERY plan.
4. **Review final plan:** Read `tmp/glm-plan.md`, confirm classification, brick selection, and stage structure are sound. Review the volume-splitter's audit report (`tmp/s0-volume-report.md`) for split correctness, merge-back decisions, and close-call justifications. Review the organizer's flag report — for each flagged judgment call: accept the flag and adjust the plan (spawn a quick-fix agent if needed), reject the flag with documented justification, or if uncertain revert to the planner's original decision (conservative default). Verify each stage's CONVERGE ceiling is sound (ONCE default; LOOP only with justification for highly ambiguous or production-critical work) — firing is mechanical per Iterative Convergence (never judged by task type or codebase cleanliness). If gaps remain, spawn a quick-fix agent to correct the plan.
5. **Decompose:** List subtasks from the plan, map each to best agent, report to user

**CRITICAL — Plan Display Rule:** After the planning phase completes and before spawning ANY stage agent, you MUST output the full stage plan as text to the user — see Workflow → Planning for the format. Writing the plan to `tmp/glm-plan.md` does NOT replace showing it. Display first, then proceed.

### Subtask Workflow

The lead's role in each subtask:
1. Select the best agent, prepare the task file using the planner's KEY FILES and MUST ANSWER questions from the manifest. For DISCOVER agents that follow a RESEARCH stage: copy the research report digest's `## Discovery Questions` section verbatim into the YOUR TASK section — the research agent wrote them, the lead transports them untouched.
2. Assemble the task prompt via `assemble-task.sh`, delegate via the `task` tool (subagent_type = agent name)
3. Wait for the task/subagent tool result, check operational status (was the report produced? no EMPTY/MISSING?)
4. Delegate ALL substantive verification to the verification pipeline — the lead never evaluates output quality, judges findings, or assesses results
5. Save non-trivial discoveries to knowledge — run the **Lead Knowledge Harvesting** discipline (see Memory System): search-first, supersede-evaluate, add, report. Lead-scoped to orchestration-level learnings; findings-derived patterns are harvested by the `knowledge-harvester` agent, not here

**Mid-execution research:** When something is unclear during workflow execution (scope ambiguity, technical approach, a specific question the plan didn't cover), the lead may spawn a single unplanned agent using the default model to research that question. The lead chooses the exact agent for the job (e.g. `research-analyst`, `web-searcher`), prepares a prompt with the specific question and MUST ANSWER directives, and delegates via the `task` tool. Its report follows the research dual-output format (full report + digest with Discovery Questions) so it can be routed to an executor per the tier rules if needed. Use the agent's report to clarify the next action. This is an ad-hoc clarifying agent — NOT a replacement for the planner pipeline, not a way to re-do planning, not a substitute for discovery stages. Limit to one agent per question. Do NOT use this to research things the lead could discover by reading source code — the lead does not read source code.

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

When a task has multiple independent angles (multi-file refactor, audit + test review, etc.), spawn all in parallel within a SINGLE stage. Sequential stages are ONLY correct when the next stage actually consumes the previous stage's verified output. **Default: fan out within a stage; sequence only when there's a real dependency.** More coverage finds more issues — fan-out (parallel agents) and convergence iterations are both ways to add coverage.

### Lead Role

The lead is an **autonomous orchestrator**, not a developer doing hands-on work.

**Does:** delegate planning to the agentic-planner pipeline, review manifest, decompose, execute workflow stages from the manifest, write agent prompts, spawn agents, delegate verification according to manifest (ratios: Verification section), spawn fix-agents and quick-fix agents, synthesize, deliver.

**Does not:** run the full test suite, do comprehensive audits unprompted, write, edit, or modify ANY project source code (even a single line), do any codebase research (reading source files, skimming files, tracing logic, discovering project structure), or design workflows from scratch (that's the planner's job). These are agent work.

**Lead success metrics:**
- **Success:** Decomposable subtasks went to agents. Findings were verified. The full mandated workflow ran to completion.
- **Failure:** You did any implementation work an agent should have done (writing, editing, or modifying code). You read raw domain data that would have been better isolated in an agent's context. You produced analysis without verification. You skipped, shortened, or altered mandated work.

**Context is not the lead's concern (MANDATORY — read this before everything):**
- Your context window is a platform resource managed by opencode (auto-compaction). It is not your problem to budget, conserve, or worry about. You never manage context.
- The workflow is designed so the platform's compaction safely compresses your context mid-run, and the checkpoint + handoff protocol restores full state — you (or a replacement lead) resume exactly where you left off. Running low on context is impossible to lose work over.
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
- Verification (lead delegates): After stage agents complete, spawn the verification pipeline — extraction → severity-routed adversarial batches → synthesis — exactly as specified in the Verification section below. The lead coordinates batches, never investigates findings manually, never classifies or re-rates findings, and writes the final synthesis from the synthesis agent's grid.
- Implementation (agent does): Writing/editing code, running test suites, fixing bugs, adding tests, refactoring
- After the verified checklist is produced, if many fixes are needed across many files: collect them into a fix-agent prompt and spawn

**Quick-fix agents:** For two specific scenarios — (1) agent output needs minor finishing, (2) reverting incorrect edits — spawn a single quick-fix agent (executor, PLAIN) using the default model. No verification pipeline — this is a quick, informal fix. If the fix is wrong, diagnose the issue (bad prompt? wrong tier?) and retry once with corrections. If the retry also fails: for HIGH/CRITICAL-adjacent changes, escalate to full IMPLEMENT → REVIEW → VERIFY; otherwise (LOW/MEDIUM or workflow-internal clutter), spawn a quick-fix agent to revert the change entirely — better to ship clean than to ship a broken fix. Quick-fix agents are the only exception to "every review must be verified."

**Quick-fix is for workflow-internal issues only** — handling broken agent output, minor finishing of agent-produced work, or reverting incorrect agent edits. Quick-fix agents are NOT a substitute for running the full workflow. For any task, no matter how small, the planner pipeline must run first. Quick-fix operates inside an existing workflow — never as a standalone replacement for planning, review, or verification.

**Workflow autonomy:** The lead runs the workflow to completion without waiting for user approval. The planner agent designs the initial workflow (stages, agents, verification placement); the lead reviews, adapts, and refines it — adding or modifying non-PLAN stages as understanding deepens during execution. Each stage follows the prepare → spawn → verify cycle. A stage is complete ONLY when ALL its agents have produced their expected output. A stage with failed or missing agents is incomplete — diagnose failures, fix root causes, re-spawn. Proceeding to the next stage with an incomplete current stage — outside the narrow gap-acceptance rules in Execution step 3 — is a protocol violation. The lead has full authority to adapt non-PLAN parts of the plan mid-execution. PLAN stages (3-agent planning pipeline) cannot be removed. DISCOVER, RESEARCH, IMPLEMENT, REVIEW, FIX, and TEST stages may be SKIPPED only when the planner's manifest explicitly marks them as NONE for the given task severity — never for speed or convenience. VERIFY is skipped when extraction finds 0 findings or when the lead may mark it as SKIPPED for non-code-level findings. Prior workflow runs do not excuse skipping — every code change requires fresh verification regardless of what previous sessions found.

### Tools

**Maximum 10 agents per parallel batch within a stage.** A stage that has independent subtasks SHOULD use as many parallel agents as the task naturally decomposes into — spawn only what the work requires. Under-splitting discovery agents (cramming too much code into one context) degrades quality by creating a detection ceiling — the agent can read everything but cannot deeply analyze cross-file contracts, producing fewer findings. Default to splitting discovery agents at the volume caps below; only merge sub-agents back when the post-split re-evaluation confirms the scope is truly trivial. When a stage genuinely needs more than 10 independent subtasks, split into sequential sub-batches within the stage. The 10-agent-per-batch limit is a coordination constraint, not a quality limit. Single-agent stages are normal for tightly-scoped implementation work; single-agent discovery stages are correct only for small domains (<4,000 LOC). Each agent is an independent unit; a stage is a parallel-batch boundary that may contain multiple agents.

**Spawn:**
```bash
.opencode/tools/assemble-task.sh -a executor -t TYPE -n NAME --task tmp/{NAME}-task.txt [--research-file tmp/research/R-xx-digest.md --research-report tmp/research/R-xx.md]
```
Produces `tmp/{NAME}-task-prompt.txt` (templates + optional RESEARCH DATA injection + TASK ASSIGNMENT + WRITABLE FILES directive; the agent `.md` is auto-loaded by opencode). The `--research-file` flag injects the routed research DIGEST as the `## RESEARCH DATA` section, and `--research-report` prints the full report's path under the header for on-demand consultation (researched runs: s2, intersections, thin-context primaries). PLAIN runs omit both — the task file's context is the briefing. Then delegate via the `task` tool — pass the **file path** with a read-and-execute instruction, NOT the full content:
```bash
task(description="<3-5 words>", prompt="Read this file. Strictly follow instructions there and execute the described task: tmp/{NAME}-task-prompt.txt", subagent_type="executor")
```
The `task` tool runs the agent as a native opencode subagent (isolated child session, full project permissions). It returns only its final summary to the lead. Report: `tmp/{NAME}-report.md` (the subagent writes it).

**Stage types and model usage** — all agents use the opencode default model unless their `.md` sets `model:`. To pin a subagent to a different model than the lead, add `model: provider/model-id` to the agent `.md` frontmatter (e.g. `model: deepseek/deepseek-v4-flash`); without it, the subagent inherits the invoking lead's model.

| Stage Type | Description |
|-----------|-------------|
| **Plan** (always runs) | Planner researches and produces the plan draft with FILE SCOPES. Volume-splitter (`volume-splitter`) resolves to exact KEY FILES, applies split/merge rules. Organizer (agent-organizer) reviews structural compliance, redistributes MUST ANSWER questions, produces final plan. All use default model. |
| **Research** (gather external information) | Gathers EXTERNAL facts beyond what the codebase provides — web search, documentation, standards, community knowledge, dataset analysis. Placed before DISCOVER when findings inform what to look for in code. Can run standalone for pure research tasks. Uses web-searcher, research-analyst, data-researcher (research producers — never receive research data themselves). Internal codebase facts are executor work, not research rows. Scales by topic specialization, not second opinions. VERIFY skipped for purely informational findings (no code-level refs). CONVERGE available for ambiguous/critical questions. |
| **Discovery** (review, audit, analysis of existing code) | Executor with dedicated context focused on one domain. When a stage has independent subtasks (different files, modules, concerns), spawn one agent per subtask — as many as the task naturally decomposes into, maximum 10 in parallel. At MEDIUM+ severity: research-backed s2 runs in parallel (executor, complementary-FOCUS report as digest + full path). |
| **Implementation** (write code) | Single agent writes code directly to original files. For multi-domain changes, one agent per domain writes to respective files in parallel. |
| **Review** (after implementation) | Reviews implementation for bugs, quality, correctness. Every implementation MUST be followed by a review agent. At MEDIUM+ severity: research-backed second opinion agent runs in parallel (executor, complementary-FOCUS report as digest + full path). (Post-fix review inside FIX is primary-only — no second opinions; see FIX brick.) |
| **Fixing** (fix verified findings) | Applies known fixes mechanically. Fix ALL confirmed findings from the synthesis grid. Every fix MUST be followed by a build-gate and a post-fix review agent (`postfix-reviewer`); stale tests and missing regression tests route to a test-update agent after convergence. |
| **Adversarial verification** (falsification) | For CRITICAL findings — 1 agent per finding (1:1). For HIGH findings — 1 agent per batch of 3 findings. For MEDIUM findings — 1 agent per batch of 10 findings. All use exhaustive falsification: read cited code, search for counter-evidence at every level (same function, caller, framework, type system, tests). Label CONFIRMED / REJECTED / WEAKENED with evidence. |
| **Test** (build + test suite) | Runs build and test commands, fixes compilation/test failures, reports results. |
| **Quick-fix** (minor finishing, reverts) | Short, informal fix for workflow-internal issues — fixing broken agent output or reverting incorrect edits. Not a substitute for the planning pipeline. No verification. If wrong, diagnose and retry once. If retry also fails: escalate to full IMPLEMENT → REVIEW → VERIFY for HIGH/CRITICAL changes; revert for everything else. |

**Wait:**
The `task` tool blocks until the subagent completes — no separate wait step. For parallel batches, issue multiple `task` calls in ONE message; all run concurrently and the lead receives all results together.

### Workflow

The planner designs the initial workflow, the lead reviews and adapts it. Typical flow: delegate to planner → review plan → for each stage in the manifest: prepare → spawn → wait → verify (severity-routed pipeline) → between stages → next stage. **Stages may be iterative (see Iterative Convergence).** The lead refines the plan and decides stage adjustments mid-execution.

#### Planning

**MANDATORY: Planner first, always.** The planning pipeline runs in full before any workflow begins. The lead does NOT research the codebase — the planner agent researches and produces the plan.

The lead's role in preparation:
0. If the user's request is vague, interpret it autonomously with best judgment — do NOT ask clarifying questions and do NO codebase research. State your interpretation and any assumptions in the plan so the planner can resolve scope. Clarifying the user's intent is a judgment call the lead makes on sight (per the Autonomy section above); reading source files (how to do it) is the planner's job.
1. Pass the user's request as-is and the current working directory to the planner — no summarization or research, the planner reads the codebase itself
2. Review the planner-generated manifest for classification accuracy, brick selection, severity justification, and agent assignments
3. If the manifest has discovered scope ambiguity, add discovery/research stages — these are agent work, not lead work. Never open source files to fill gaps yourself
4. Write well-scoped prompts using the manifest's context, KEY FILES, and MUST ANSWER questions (provided by the planner per stage).
5. If the plan is insufficiently informed, re-run the planner with more specific questions or add a discovery stage. Under no circumstances does the lead read source files to research gaps directly

**Spawning research agents** (even iteratively to convergence) is encouraged when scope is unclear — thorough research almost always produces better results in later stages. Decompose into stages. **Plan format:**

```
# DYNAMIC BRICK MANIFEST — planner selects bricks per task.
# No fixed skeleton. Each task gets a custom workflow.

Plan: [N stages, M total agents]

  Stage 0: Plan — 3 agents (planner + volume-splitter + organizer)
    Classification: size=[], domains=[], ambiguity=[], severity=[], type=[]

  Stage 1: [Brick name] — [Variant] — N agents
    Justification: [why this brick, why this variant]
    Agent: [executor — tier (PLAIN/researched) + routed report IDs + FOCUS angles]
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
                No variants. Never skipped. Pipeline: Request Workflow step 3 (planner produces
                the plan draft with FILE SCOPES; volume-splitter resolves them to exact KEY FILES;
                organizer reviews and fixes the plan; the organizer's output IS the final plan).

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
                RESEARCH builds the reference library that
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
                `R-xx | topic | scope | agent | FOCUS angle`. Each row
                produces DUAL OUTPUT: the full report `R-xx.md` (no size cap)
                + the compact digest `R-xx-digest.md` (soft max ~10KB —
                1-2KB over is fine; Discovery Questions inclusion outranks
                the cap). The Routing
                Table maps agents → report IDs + tier (PLAIN | researched):
                every researched agent gets EXACTLY the reports covering
                its scope — each as a (digest, full report) pair — nothing
                more (precision rule: unrelated data
                degrades results). PLAIN agents have no routed reports.

                Every research report MUST include a `## Discovery Questions`
                section at the end. This section contains 2-5 MUST ANSWER
                questions for the downstream DISCOVER agents, each with the
                relevant spec text or reference quoted inline so the
                discovery agent can verify against the actual specification
                without reading the full research report. The digest carries
                this section verbatim (it outranks the digest size cap).
                Format:

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
                copies them verbatim from the digest into discovery agent
                task files. Zero
                lead interpretation; zero summarization; zero claim extraction.
                The instruction to include this section must be in the task
                file (see Agent Preparation) — the lead owns this transport.

                Research findings are informational, not authoritative.
                The ground truth is the project code and the task at
                hand — research fills gaps and provides context. When
                research and code conflict, code wins. Always preserve
                the research agent's confidence tier (CONFIRMED/LIKELY/
                TENTATIVE/SPECULATIVE) when passing research into PRIOR
                CONTEXT or delivery. "Independent" in the CONFIRMED
                definition means distinct provenance clusters (group
                sources by origin — syndicated copies, press-release
                derivatives, mirrored posts — before counting
                corroboration; one origin = one line of evidence,
                however many URLs it spans). Source credibility never
                substitutes for claim confidence: official/vendor docs
                are high-credibility for what they state, not for
                operational reality. Exception: tasks with no codebase
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
│               At MEDIUM+ severity: +1 second opinion agent per domain (parallel; see Second Opinion Guidelines).
└── MULTI       N agents, one per domain. Split by domain → volume
                (≤4,000 LOC/12f per agent — see Domain Splitting caps).

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
                either domain executor alone. Intersection agents MUST be placed in the first DISCOVER
                stage — never deferred to CONVERGE iterations.
                Intersection agents run in parallel with domain primaries and
                second opinions within the same stage. At MEDIUM+ severity: each
                intersection agent gets its own second opinion (a different
                FOCUS angle, not the same as the intersection's). Intersection
                agents audit gaps between domains — second opinions audit the
                intersection audit itself for missed concerns.

                Each intersection agent is executor, researched
                with a boundary-integrity FOCUS report (digest + full path) covering both sides'
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
│               At MEDIUM+ severity: +1 second opinion agent per domain (parallel; see Second Opinion Guidelines — no restriction gate).
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
│               what the caller expects.
└── MULTI       N agents, one per domain.

VERIFY          Verify findings from DISCOVER, REVIEW, RESEARCH (code-ref findings), or post-fix review.
                Always includes extraction (1 agent, default model); tags both-found/single-found,
                boundary-found/domain-only, PRIOR_FIX_ATTEMPT. Routing, adversarial methodology,
                synthesis grid, CHALLENGED + docs exception, post-fix grids: see `#### Verification`.
                When CONFIRMED findings exist at MEDIUM+, FIX=DOMAINS must follow. Skipped only for
                purely informational findings (no code-level references).

CONVERGE        Repeat DISCOVER, REVIEW, or RESEARCH for additional passes. Ceiling set by the planner;
                firing is mechanical off the prior VERIFY synthesis grid. No CONVERGE=NONE. Trigger,
                ceilings, inheritance, research trigger, VERIFY-between-iterations, FOCUS exclusion,
                research extension: see `#### Iterative Convergence`.

FIX             Apply verified findings. Always 3-4 sequential stages — includes build-gate and post-fix review.
                When DOMAINS: 1 fix agent per domain → BUILD-GATE
                (1 executor, PLAIN, default model — runs the full suite solo after
                the parallel batch; the sole exception to the per-agent
                parallel-safety rule. It compiles the tree and runs the tests
                covering the changed files plus grep-derived test files importing
                changed modules. One session, bounded repair protocol:
                  1. Run the full suite. Green → report `GATE PASS`, no changes.
                  2. Red → attribute each failure to file:line via `git diff`,
                     repair production-code defects within its writable scope
                     (union of the fix batch's production files), re-run.
                     At most K=3 repair iterations.
                  3. Report the final status plus every repair (file:line, root
                     cause, diff). Status: `GATE PASS` / `GATE PASS (N repairs)`
                     / `GATE FAIL (unresolved)`.
                GUARDRAILS (non-negotiable): production code only — NEVER edit
                tests to force green (no assertion weakening, skip/xfail, or
                deletion; a test asserting pre-fix behavior is TEST-UPDATE class
                → report it untouched); minimal diff + root-cause discipline
                (quality-rules-code.txt); never create files; every change
                reported. A repair needing edits outside the writable scope is
                reported unresolved, not improvised. The lead assembles this
                prompt as `-t code` with WRITABLE FILES = the fix batch's
                production files; its report is code-flavored.) → post-fix REVIEW (via `postfix-reviewer`; primary-only per domain — NO
                second opinions, per Second Opinion Guidelines; cross-domain
                integration reviewers for triaged boundaries still apply; the
                review object is the combined diff — fix-batch changes + build-gate
                repairs),
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

                GATE FAIL ROUTING: the lead reads the gate report's final status.
                `GATE PASS` / `GATE PASS (N repairs)` → post-fix REVIEW proceeds.
                `GATE FAIL (unresolved)` → route to the responsible fix agent (or
                a full fix pass) with the gate report as PRIOR CONTEXT. Mechanical
                trigger, no judgment — the repair loop is inside the one agent, so
                no separate re-run stage exists. The gate MUST reach PASS (or be
                reported unresolved and escalated) before post-fix REVIEW starts.

                GATE REPORT USE: the gate report is both the verdict and an action
                log — a workflow-internal artifact, not a finding source: no
                severity classification, no adversarial routing. Post-fix REVIEW
                agents (`postfix-reviewer`) receive a one-line gate status + report
                path in PRIOR CONTEXT (informational — the diff remains the review
                object).

                GATE SKIP RULES: no fix stage → no gate. No build/test infra
                (TEST=NONE justification) → gate skipped with the same
                justification. Machine-constrained repos (operator no-execution
                constraint): the gate runs bounded verification (changed targets
                only, `-j1`, memory caps) or reports `GATE NOT RUN: constraint`
                and the workflow falls back to the pre-gate protocol (no repairs
                attempted).

                CONVERGENCE: the FIX brick is a convergence loop — one pass is never final while
                CONFIRMED CODE-FIX findings survive verification. Repeat fix → build-gate →
                post-fix review → conditional VERIFY until post-fix review is clean, then
                proceed to TEST-UPDATE. Auto-add mechanics: Between Stages step 2.

                TEST-UPDATE (conditional post-convergence sub-stage): ONE agent updates stale
                tests + writes regression tests pinning the fixes (no production code),
                followed by a build-gate re-run and 1 review agent (no weakened pins, no
                scope creep; no adversarial pipeline). Auto-add: Between Stages step 2.
                The final TEST brick remains the acceptance gate.
├── NONE        No verified findings.
└── DOMAINS     1 fix agent per domain → BUILD-GATE → post-fix REVIEW (`postfix-reviewer`) → conditional VERIFY → TEST-UPDATE (conditional).
                BUILD-GATE may repair only production-code defects in the fix batch's writable scope; TEST-UPDATE-class failures are reported, never repaired.

                REGRESSION-AWARE FIX SCRUTINY: when the grid flags a regressing function, the
                lead spawns a pre-fix audit agent BEFORE the fix stage — its localized
                structural recommendation is MANDATORY INPUT for the fix agent; regressing-
                region findings are delivered as SINGLE-FINDING fixes with their own review.
                Details: Between Stages step 2.

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

Score 3 tiebreak: Q5=NO → MEDIUM. Q5=YES → HIGH (irreversible harm outweighs contained blast radius). Score 4 is always HIGH regardless of Q5 answer — the tiebreak does not apply to score 4. Score 2 always has Q5=NO (Q5 alone is 1 point). CRITICAL requires all five.

See agentic-planner.md Phase 2 for the 5-question checklist. Base answers on code understanding, NOT keyword matching. A function named `validatePassword` that handles UI password strength scores 0-1 (Q2=NO, Q3=NO). A log statement in a payment module scores 0-1 unless the logging itself writes to persistent state.

##### Domain Splitting

When a task spans multiple domains, split in two steps. **Domain breadth is measured by distinct source-code specialists (languages, frameworks), not package count and not audit roles.** A task touching 5 Swift packages that all use the same language/framework is single-domain. A task touching Python + TypeScript files is few-domain. Audit lenses (test quality, security, documentation, performance) apply to the same source code — they do not increase domain breadth.

1. **Split by domain** — identify each file/concern's domain (language/framework/concern area). ALL execution uses executor; specialist identity comes from the research stage's FOCUS angles. Per-domain tiers (PLAIN/researched) are assigned per the ONE general rule; researched domains get rows in the Research Coverage Map.
2. **Split by volume** — keep each discovery agent within these mechanical limits:
   - LOC ≤ 4,000 AND files ≤ 12 → **do not split.**
   - LOC > 5,500 OR files > 18 → **must split** (no exceptions — "cohesive code" does not override exceeding the caps).
   - 4,001 ≤ LOC ≤ 5,500 OR 13 ≤ files ≤ 18 → **split UNLESS:** (a) all files form a single cohesive module, AND (b) no individual file exceeds 300 LOC. If both conditions hold, do not split (with one-line justification). Otherwise, split.
   Discovery agents must read every file — a 20-line header costs the same context as a 200-line implementation file because the agent must understand the API and cross-reference every caller. After splitting, re-count each resulting sub-group to verify none still exceeds the limits.

   **Post-split re-evaluation.** After mandatory splits, verify the resulting agents
   are not fragmented. If any sub-agent has fewer than 6 files AND fewer than 2,000 LOC,
   the split produced an under-utilized agent — standalone agents this small add
   coordination overhead without proportional audit depth. Merge sub-agents back into
   the parent domain and accept the parent as within the narrow cap instead.
   A 6f/2,000-LOC agent is better than two 3f/1,000-LOC agents that have almost nothing to
   audit. When file count exceeds the 18f cap but total LOC is under 2,000, the files
   are likely thin stubs — accept as within the narrow cap instead of splitting
   into fragments. The thin-stub clause takes precedence over the file-count cap:
   a scope with >30 files but <2,000 total LOC is accepted as a single agent, never
   split on file count alone.

   **Scope overlap at integration boundaries.** When volume-splitting a large
   single-domain scope, do NOT cut cleanly between architectural layers — that
   creates blind spots where no sub-agent reads the interface between them. Instead,
   design scopes that intentionally overlap: each sub-agent reads its core scope PLUS
   the integration-layer files that bridge to adjacent scopes. For a 200K LOC Python
   app with GPG, DB, Mail, and UI areas, the GPG sub-agent includes the GPG↔DB
   interface layer, the DB sub-agent overlaps to read the DB↔GPG storage layer and
   the DB↔Mail bridge. Each sub-agent traces BOTH sides of its adjacent integration
   points as part of its natural audit. The overlap files count toward both sub-agents'
   volume caps — factor this in when sizing scopes. Scope boundaries from volume splits are
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
   core/GPGHandler.py, core/gpg_utils/*.py") with exact LOC counts from Phase 1
   research (`wc -l`); the volume-splitter resolves every scope to exact individual
   file paths with `wc -l` counts, applies the split rules mechanically, and rewrites
   the plan with the resolved KEY FILES + exact LOC counts — preserving the planner's
   MUST ANSWER questions, domain descriptions, and agent assignments. The organizer
   then redistributes MUST ANSWER questions across split domains and validates
   structural compliance (see Request Workflow step 3).

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

##### Size Classification

The planner assesses scope along with severity. Size gates DISCOVER=NONE decisions.

| Size | Criteria |
|------|----------|
| **tiny** | Single file, single change, under 10 lines. Trivial fix, no structural impact. |
| **small** | Single module, few files. Well-scoped change with clear boundaries. Under ~12 source files and ~4K source LOC. |
| **medium** | Multiple modules, cross-file changes. Moderate scope, may touch different concerns. Under ~18 source files and ~5.5K source LOC. |
| **large** | Exceeds ~18 source files OR ~5.5K source LOC in any domain, OR spans multiple domains (different languages/frameworks). Requires volume splitting. |

For `medium` and `large`, DISCOVER is mandatory.

##### Mid-Execution Amendment

After VERIFY produces confirmed findings at MEDIUM severity or above: if the manifest does not include IMPLEMENT, the lead auto-adds IMPLEMENT followed by FIX (unconditional — all confirmed MEDIUM+ findings are fixed regardless of task intent; LOW findings are reported but not auto-fixed). See Between Stages step 2.

When auto-adding IMPLEMENT or planning implementation stages from the synthesis grid, apply the edit-density split (Domain Splitting step 3) to the confirmed MEDIUM+ findings.

FIX convergence: repeat the fix pass until post-fix review produces zero CONFIRMED CODE-FIX findings. TEST-UPDATE findings do NOT re-trigger the code-fix pass (they route to the TEST-UPDATE sub-stage after convergence); IMPLEMENT presence does not block re-entry. See Between Stages step 2.

**Implementation stages** use write → review → verification (see Agent Spawning).

**Fix agents:** use default model; split by domain — one agent per domain; every fix stage MUST be followed by a build-gate and a post-fix review. Self-verify rule: FIX brick. See Between Stages step 2.

**Delegation mapping (MANDATORY in every plan):** During planning you MUST answer:
1. What subtasks exist? (list each one)
2. Which agent handles each subtask? (map agent name to subtask — all execution → executor with the tier (PLAIN/researched) + routed report IDs + FOCUS angles from the manifest)
3. Where is verification in this plan? Confirm verification runs after every DISCOVER, REVIEW, and RESEARCH (code-ref findings) stage that produces findings, or mark it explicitly as SKIPPED with justification.

Answer these explicitly in your plan. Every subtask must have an assigned agent — no subtask goes to the lead.

**Stage decomposition rule (MANDATORY):** If stage N+1 does NOT consume stage N's verified output — they're independent — MERGE them into a single stage with parallel agents. Sequential stages are only correct when the next stage actually needs the previous stage's verified findings as `PRIOR CONTEXT:`.

Write full plan to `tmp/glm-plan.md`. Quick-fix agents (see Lead Role) always run on the default model but outside the plan's stage structure — they handle agent output issues within an existing workflow, never as a standalone workflow replacement. Checkpoint.

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

CAUTION: Never use broad patterns like `tmp/*-report.md` or `tmp/*-log.txt` — they will delete non-workflow files (e.g. `log-analysis-report.md`). Agent names follow `s{digit}...` prefix (e.g. `s1-researcher`, `s2i1-reviewer-r2`), so `tmp/s[0-9]*` safely matches only workflow artifacts.

**Session boundaries:** Each session is independent — treat every task as a fresh start. Do not assume prior sessions' findings still hold. Every code change, even from previous sessions, requires fresh verification through the full workflow. Only reference prior sessions when the task explicitly asks you to. If task will likely need >4 stages, plan explicit session splits using the handoff skill (Mode B). Long sessions degrade from compaction pressure.

#### Agent Preparation

Consult `.opencode/agents/INDEX.md` for the full agent directory (12 agents). All execution uses `executor` — specialist identity comes from the research stage's FOCUS angles and the routed research reports, not from agent personas.

For each agent in the current stage:

1. Define task with KEY FILES, CONTEXT, SCOPE, tier (PLAIN/researched per the ONE general rule), `WRITABLE FILES` (code agents only — list source files agent may edit), and `MUST ANSWER:` questions (mandatory — prompts without these are invalid). MUST ANSWER questions come from two sources: (a) the planner's manifest per-stage technical questions from Phase 1 codebase research, (b) for DISCOVER agents following a RESEARCH stage, the research report digest's `## Discovery Questions` section, copied verbatim. The lead may add 1-2 supplementary workflow-level questions (e.g., "Was the linter run?") but does not write code-level or spec-level technical questions. For RESEARCH agents: the YOUR TASK section MUST instruct the agent to include a `## Discovery Questions` section at the end of their report (and in their digest) with 2-5 MUST ANSWER questions for downstream DISCOVER agents, each with inline spec quotes (see RESEARCH brick catalog for the format template). This instruction is the lead's responsibility — research agents only know their domain; they don't know the downstream Discovery Questions protocol unless the task file tells them. For RESEARCH rows, the task file MUST pin both output paths in a `DELIVERABLES:` section — `tmp/research/<R-xx>.md` + `tmp/research/<R-xx>-digest.md` (the assembler resolves bare `tmp/`; the auto `tmp/{NAME}-report.md` applies only without DELIVERABLES).
2. Write the TASK ASSIGNMENT block (PROJECT, ENVIRONMENT if code, PRIOR CONTEXT if stage 2+, YOUR TASK, WRITABLE FILES) to `tmp/{name}-task.txt`. NOTE: Do NOT include the report file path in WRITABLE FILES — the script auto-injects `tmp/{NAME}-report.md` automatically.
3. Assemble the task prompt (command + flags: Tools → Spawn):
    Types: `review` (coordination-review + severity + quality-rules-review), `code` (coordination-code + quality-rules-code), `research` (coordination-review + quality-rules-review). The script selects templates, substitutes `{NAME}` in the task file content, and writes `tmp/{name}-task-prompt.txt`. Output: `ASSEMBLED|name|path|bytes`. The agent `.md` is NOT embedded — opencode loads it natively as the subagent's system prompt.
4. **Validate task prompt contains ALL:** TASK ASSIGNMENT with MUST ANSWER questions, quality rules, severity guide (review only), environment (code only), coordination, report format. The script handles all boilerplate automatically — you only own the task file. Missing ANY = do not spawn
5. **Pre-spawn prompt check (MANDATORY — run before every delegation spawn; failure = fix the prompt, then spawn — never spawn on a failed check):**
   1. **Intent** — does this prompt's scope match the manifest's stage scope AND the user's request, no more, no less? (no scope drift between plan and prompt)
   2. **Verifiable done** — is the deliverable checkable by a fresh reviewer — the manifest's MUST ANSWER questions carried with evidence expectations (file:line)?
   3. **Decisions baked** — are the manifest's decisions reflected in the task file, no unresolved forks left to the agent?
   4. **Fresh-read** — reading the prompt alone, no conversation memory: anything ambiguous or assumed? The prompt is self-contained (planner/manifest context), not lead conversation memory
   5. **References exist** — every path the prompt points to verified present: KEY FILES, routed research reports (digest + full), PRIOR CONTEXT paths (synthesis grids, discovery reports)
6. Match agent type to task: all execution → executor (git/history analysis included).
7. **WRITABLE FILES:** Code agents: task file MUST list the exact source files/directories the agent may modify.
   - **Implementation agents:** WRITABLE FILES must list the exact source files the agent may modify directly. The task must instruct them to produce their implementation and run the mandatory parallel-safe verification (per quality-rules-code.txt: compile/syntax check of changed files or targeted tests — NEVER the full suite; the build-gate/TEST stage runs it). The task MUST also instruct them to write an Intent section in their report before coding: a description of their understanding of the task and their intended approach, in their own words, at whatever level of detail they think is useful for the reviewer. The agent decides what to communicate — architectural reasoning, assumptions about the codebase, trade-offs considered, alternatives rejected, or anything else that helps someone else understand why they built what they built. This is the first thing they write, before any code.
   - **Implementation and Fix agents — mandatory pre-work reading:** The YOUR TASK section MUST instruct the agent to read the verification pipeline's synthesis grid report (full confirmed findings with adversarial evidence: grep results, call-chain traces, cross-file context) BEFORE writing any code. Include the exact file paths in the task (e.g., `tmp/sN-synth-report.md`). When the task involves specific finding IDs (e.g., "Fix finding F-03"), the agent MUST read that finding's full entry in the synthesis report — the lead's one-line PRIOR CONTEXT summary is navigational, not authoritative. The synthesis report is the authoritative source of finding details, evidence context, and original discovery analysis. For FIX convergence passes (re-fixes of surviving findings), also include the path to the prior-pass synthesis report so the agent can see what was already attempted and why it failed.
   - **Review/audit/research agents:** omit WRITABLE FILES entirely — the script auto-injects the correct report path and marks all source files as read-only.
Describe problems and desired behavior — do NOT paste exact fix code unless precision is critical (regex, API signatures, security logic). Name agents with stage prefix: `s1-researcher`, `s2-impl-auth`.

#### Agent Spawning

All agents use the opencode default model; the `-m` flag is not used. Model pinning (`.md` `model:` frontmatter): see Tools — Stage types and model usage.

**How it works for review/research/audit stages:**
1. A single agent gets the agent `.md` (auto-loaded) and the task assignment — it works independently
2. When a stage has independent subtasks (different files, modules, concerns), spawn one agent per subtask in parallel (decomposition + cap: Tools)
3. Each agent's report feeds into the verification pipeline (see Verification section)
4. **Naming:** see Naming convention overview below.

**How it works for implementation stages:**
1. **Write step:** A single agent writes the implementation directly to the original files. The agent reads the full task, understands the requirements, and produces a complete implementation.
2. **Review step:** A single review agent reviews the implementation — same task description, independent assessment.
3. **Fix and iterate:** The review report is processed by the verification pipeline to produce a verified checklist. ALL verified findings are fixed via fix-agents split by domain. The lead does NOT fix findings directly, regardless of how few or how trivial. Every fix MUST be followed by a build-gate and a post-fix review agent (`postfix-reviewer`). Every review MUST be followed by verification — review findings are not deliverable until they've been verified. The review → fix → re-review loop iterates until the post-fix review produces zero CONFIRMED CODE-FIX findings — this FIX-brick convergence is the final gate; TEST-UPDATE findings route to the test-update agent after convergence.

**Spawn:** assemble the prompt and delegate via the `task` tool per Tools → Spawn (command, flags, read-and-execute convention).

**Prompt assembly:** Assemble ONE task prompt per agent via `assemble-task.sh` (command + flags: Tools → Spawn).

**Implementation spawn pattern:** write step (`-t code`) → review step (`-t review`), each assembled via `assemble-task.sh`; delegate the review step AFTER the write completes (see Tools → Spawn).

**Naming convention overview:**
- Plan: `s0-planner`, `s0-volume`, `s0-organize`
- Research: `sN-research-{topic}`
- Discovery: `sN-discover-{domain}`, `sN-discover-2-{domain}` (second opinion),
  `sN-discover-{domainA}-{domainB}` (intersection, e.g., `s1-discover-crypto-services`)
- Implementation: `sN-impl-{domain}`, `sN-review-{domain}`, `sN-review-2-{domain}` (second opinion),
  `sN-review-{domainA}-{domainB}` (intersection, e.g., `s6-review-crypto-services`)
- Verification: `sN-extract`, `sN-adv-{domain}`, `sN-adv-cross`, `sN-synth` (ratios: Verification section)
- Fix: `sN-fix-{domain}`
- Build-gate: `sN-gate` (e.g., `s7-gate` — gate between fix agents and post-fix review: runs the full suite solo, repairs production-code failures in its writable scope, re-runs, bounded K=3)
- Test-update: `sN-test-update` (e.g., `s8-test-update` — updates stale tests + writes regression tests after fix convergence)
- Test: `sN-test`
- Iterations: `s{N}i{K}-name` (e.g., `s2i1-researcher`, `s2i2-researcher`)
- Respawns: re-issue the `task` call with corrected configuration. Add `-r2`, `-r3` suffix to the name when re-delegating a failed agent (e.g., `s2i1-reviewer-r2` = stage 2 iteration 1 reviewer, respawn attempt 2). Maximum 3 respawn attempts per agent.

#### Second Opinion Guidelines

For DISCOVERY and post-implementation REVIEW stages at MEDIUM+ severity, spawn a second opinion agent — executor with a complementary-FOCUS research report (digest injected + full path, research-backed s2). The primary and the s2 review the same code but through different analytical standpoints, producing complementary findings. The s2's standpoint IS its injected report's FOCUS angle — never the same FOCUS twice. PLAN always has an agent-organizer review (mandatory, all tasks) — see Planning phase step 3c. The planner specifies the s2's complementary FOCUS per stage (the tables below show recommended default pairings; the planner selects based on task context).

**Post-fix REVIEW (inside the FIX brick) is PRIMARY-ONLY — no second opinions.** The both-found confidence signal is lost for fix-stage findings — adversarial verification remains the quality floor.

> **No mutual reuse (independence):** primary and s2 runs always start fresh and never reuse each other's sessions. Same for planner and organizer: the organizer's structural validation never reuses the planner's session, and the planner is never reused from the organizer's. Within-run continuity (own follow-ups/hardening fixes) stays allowed; merged evidence travels in reports, never in sessions.

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

**REVIEW-seconds tagging:** extraction tags review-second findings (source) for yield analysis. Second opinions remain mandatory at MEDIUM+ for post-implementation REVIEW. DISCOVER seconds stay mandatory.

**Same-FOCUS prohibition:** The second opinion MUST use a complementary FOCUS angle — never the primary's. Using the same FOCUS twice — even with "different task scoping" — does not create a different analytical framework. The complementarity effect depends on genuinely different standpoints. If no complementary angle fits, split the review into smaller per-domain reviews where each can get a truly different second opinion.

**Task-framing guideline:** The task file for the second opinion agent uses the same KEY FILES as the primary; its standpoint comes from the injected complementary-FOCUS report. The s2 report MUST state which findings are unique to its standpoint vs also found by the primary (uniqueness reporting — improves extraction both-found/single-found fidelity).

#### Execution

1. Spawn current batch of agents via the `task` tool, respecting the per-batch limit from Tools and the dependency analysis above. Issue multiple `task` calls in ONE message for parallel batches (all run concurrently). Checkpoint with agent names and task descriptions. If stage has multiple batches, wait for current batch to finish before spawning next
2. Do verification prep (for VERIFY stages): read the extraction agent's output, create verification task files per batch, assemble prompts. **Batch cross-check (MANDATORY):** Before spawning, verify that every batch the extraction report prescribes has a corresponding task file, and each task file targets the exact finding IDs from the extraction's batch assignment table (e.g., ADV-1 → B1-B4). A task file for different findings than prescribed does not satisfy the batch assignment. The extraction report is authoritative — the lead does NOT substitute finding targets.
3. **Review output.** Check operational status only — was the report produced? Is it non-empty? Any EMPTY/MISSING? This is NOT quality review (do NOT evaluate findings, accuracy, or correctness). If ANY agent produced EMPTY REPORT / MISSING REPORT / FAILED TASK:
    - Diagnose root cause. Fix the issue (environment, prompt, task file, dependencies).
    - Re-issue the task call with corrected configuration.
    - Do NOT proceed to the next stage with incomplete stage output.
    - Accept a gap and proceed ONLY for trivial gaps in discovery stages (e.g. a single agent in a 10-agent discovery stage failed after 3 respawn attempts with different approaches, AND its domain is partially covered by other agents). Every such decision must be explicitly justified in `tmp/glm-plan.md` with `STAGE GAP ACCEPTED: [domain] [reason] [coverage from other agents]`. Do NOT accept gaps in implementation or fix stages — those stages must produce complete, correct output. Do NOT silently skip failed agents.

#### Verification

Verification uses the severity-routed verification pipeline. The lead does NOT manually verify findings — that's the agents' job. The pipeline runs in batches with sequential dependencies:

**Batch 0: Extraction agent** (single, default model; use `verification-analyst` agent `.md`). Reads all reports from the stage, extracts every finding with file:line and severity, deduplicates (same file:line + same issue → merge, note both sources), classifies each finding by severity, and splits into batches grouped by domain. When the originating stage (DISCOVERY or REVIEW) used a second opinion agent, tag each finding as "both-found" (both agents reported independently) or "single-found" (one agent only). When intersection agents were present, also tag findings as "boundary-found" (reported by an intersection agent auditing a domain boundary — inherently invisible to within-domain executors) or "domain-only" (reported only by domain primaries/second opinions). Both-found and boundary-found carry elevated confidence for different reasons: both-found signals cross-agent agreement within a domain; boundary-found signals issues spanning domains that no within-domain executor could have detected. A finding that is both "both-found" AND "boundary-found" carries the highest confidence. Surface all tags in synthesis.

**Investigated-and-rejected routing (MANDATORY):** extraction additionally collects each report's `### Investigated-and-Rejected` section (dismissed items with reasoning + file:line) and routes them into the adversarial batches as RE-EXAMINE items (label CONFIRMED / WEAKENED / REJECTED like findings). Dismissals at HIGH/CRITICAL claim severity are always re-examined; MEDIUM/LOW dismissals batched with findings. Dismissals are not trusted.

When the codebase is a git repository with prior production check commits: for each finding, check whether the cited file:line was introduced or modified in a prior production check commit (`git log --all --format="%h %s" | grep -i "production\|check\|fix\|audit"`). Tag findings that fall on previously-fixed lines as `PRIOR_FIX_ATTEMPT: <commit-hash>`. A file with ≥3 PRIOR_FIX_ATTEMPT findings signals a repeat-regression hotspot — surface this count in the extraction report for synthesis routing. A function with ≥3 PRIOR_FIX_ATTEMPT findings clustered within ~40 lines (same logical block) signals a function-level regression hotspot — surface both file-level and function-level counts.

Findings from documentation work-type tasks (docs task type) are domain-verified — route them directly to synthesis at the agent's rated severity, skipping adversarial verification.

**Mechanical trigger — MANDATORY:** If extraction finds any finding at MEDIUM severity or above, the lead MUST spawn ALL verification batches the extraction report prescribes — every adversarial batch, at the exact finding IDs listed in the extraction's batch assignment table. Spawning an adversarial agent against different findings than prescribed does NOT satisfy this trigger. The synthesis agent runs after all routing agents complete — even if every routed finding was REJECTED or WEAKENED. The lead does NOT evaluate routing agent outputs to decide whether synthesis is needed. The synthesis grid — not the lead's judgment — determines which findings are fixed. Skipping verification for MEDIUM+ findings is a protocol violation.

**Batch 1: Findings routed by severity.** All findings extracted by Batch 0 are routed. For merged second-opinion outputs, carry each finding's both-found/single-found tag into the adversarial task files and tell the adversarial to prioritize single-found findings — the both-found core is already double-verified by the two independent reviews. Label semantics: **CONFIRMED** — exhaustive search found NO counter-evidence (describe what patterns were searched, which grep commands were run, why nothing was found); **REJECTED** — clear counter-evidence disproves the claim (paste exact code with file:line); **WEAKENED** — partial counter-evidence reduces severity/scope but doesn't fully disprove (state the correct severity and what portion of the original claim still stands):

- **CRITICAL findings** → Adversarial agent (single agent per finding (1:1), default model). Tries to FALSIFY every finding: reads cited code with full surrounding context (minimum 30 lines), exhaustively searches for counter-evidence (guards, validation, framework protections, type system invariants, test coverage), labels each CONFIRMED / REJECTED / WEAKENED with evidence. Adversarial methodology: assume the claimed issue is a misunderstanding and search exhaustively before confirming. Every CONFIRMED label must be hard-won with grep evidence. For "missing X" findings, searching for X and finding it in no reachable code path IS valid evidence — document all searched locations.

- **HIGH findings** → Adversarial agent (single agent per batch of 3 findings, default model). Same exhaustive falsification methodology as CRITICAL — reads cited code with full surrounding context, exhaustively searches for counter-evidence (guards, validation, framework protections, type system invariants, test coverage), labels each CONFIRMED / REJECTED / WEAKENED with evidence. Adversarial methodology: assume the claimed issue is a misunderstanding and search exhaustively before confirming. Every CONFIRMED label must be hard-won with grep evidence.

- **CRITICAL/HIGH findings from intersection or cross-domain integration review** (any finding spanning domain boundaries, from DISCOVER or REVIEW) → Adversarial cross-domain agent (single agent per finding (1:1), default model). Same exhaustive falsification but verifies from BOTH sides of the integration boundary (Domain A producer + Domain B consumer + bridge between them). Finding only survives if no counter-evidence on either side or in the bridge.

- **MEDIUM findings** → Adversarial agent (single agent per batch of 10 findings, default model). Same exhaustive falsification methodology as CRITICAL — reads cited code with full surrounding context, exhaustively searches for counter-evidence (guards, validation, framework protections, type system invariants, test coverage), labels each CONFIRMED / REJECTED / WEAKENED with evidence. Adversarial methodology: assume the claimed issue is a misunderstanding and search exhaustively before confirming. Every CONFIRMED label must be hard-won with grep evidence.

- **LOW findings** → NOTED. Recorded in the report. No further agent spend.

**Batch 2: Synthesis agent** (single, default model; use `verification-analyst` agent `.md`). Reads all verdicts. Builds a cross-reference grid per finding using unified vocabulary:

| CONFIRMED | REJECTED | WEAKENED |
|---------------|--------------|---------------|
| → fix list | → dropped | severity downgraded → fix list at lower priority |

Surfaces PRIOR_FIX_ATTEMPT regression signals from extraction (hotspot thresholds: see extraction above) — regressing functions trigger the pre-fix audit protocol (see Between Stages). Hotspot flags are informational for the lead; post-fix REVIEW is primary-only (no second-opinion reviewer).

Also sanity-checks severity assignments against the severity classification criteria — if a finding's severity appears mismatched (e.g., "SQL injection" labeled MEDIUM), flag it as CHALLENGED. Challenged findings are re-routed through adversarial verification. Exception: documentation-domain challenged findings skip adversarial — documentation severity is inherently subjective (is "10 missing API docs" HIGH or MEDIUM?) and adversarial review of severity ratings adds no meaningful verification. Documentation-domain challenged findings stay at their challenged severity; the lead accepts the downgrade directly. (The documentation-domain exception is keyed to the DOCS WORK-TYPE — task type = docs — not to any agent.)

For POST-FIX grids, the synthesis agent additionally classifies each CONFIRMED finding as **CODE-FIX** (code defect — re-triggers the fix pass) or **TEST-UPDATE** (test asserting pre-fix behavior — does NOT re-trigger the code-fix pass; routes to the TEST-UPDATE sub-stage after convergence). For post-fix grids in convergence passes, also compare CONFIRMED CODE-FIX findings against the prior pass's grid: a finding mapping to the same function region (~40 lines) as a finding that already failed verification in a previous pass flags that region as an **in-run regressing function (N attempts)** — surface the flag for the lead's pre-fix audit trigger. Also classify each CONFIRMED finding as fix-introduced vs new-mechanism (PRIOR_FIX_ATTEMPT lines) and report the ratio — the program's fix-quality metric.

**If the synthesis grid shows zero CONFIRMED findings at MEDIUM or above** (all MEDIUM+ findings were REJECTED or WEAKENED below MEDIUM, or only LOW-severity survivors remain), FIX is SKIPPED — there is nothing significant to fix. LOW verified findings are acknowledged in the synthesis as non-blocking. The lead writes the synthesis with `FIX SKIPPED: Zero MEDIUM+ verified findings — nothing to fix.` This is mechanical — no lead judgment.

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
- Adversarial pairs: `sN-adv-{domain}` (single agent per finding for CRITICAL — 1:1; single agent per batch of 3 for HIGH; single agent per batch of 10 for MEDIUM)
- Adversarial cross: `sN-adv-cross` (single agent per finding — 1:1)
- Synthesis: `sN-synth`

#### Between Stages

1. Write `tmp/stage-N-synthesis.md` — verified results from the synthesis grid, decisions, context for next stage
2. **Mid-execution amendment (new findings):** If VERIFY produces confirmed findings at MEDIUM severity or above and IMPLEMENT is NOT in the manifest, the lead auto-adds IMPLEMENT followed by FIX (always 3-4 sequential stages: fix + build-gate + post-fix review + conditional VERIFY, plus conditional TEST-UPDATE). This is unconditional — all confirmed MEDIUM+ findings are fixed regardless of task intent. LOW findings are reported but not auto-fixed. This is mechanical — verify the condition, add the stages.
   **FIX convergence (incomplete fixes):** After a FIX stage's post-fix VERIFY produces CONFIRMED CODE-FIX findings in the synthesis grid, auto-add another FIX pass regardless of whether IMPLEMENT is already in the manifest. IMPLEMENT presence does not block FIX convergence — surviving CODE-FIX findings mean the fix was incomplete. Repeat until post-fix review produces zero CONFIRMED CODE-FIX findings and VERIFY is skipped. Each convergence pass re-runs the build-gate before its post-fix review. TEST-UPDATE findings (tests asserting pre-fix behavior) do NOT re-trigger the code-fix pass. After convergence, if the grid contains TEST-UPDATE findings or CONFIRMED fixes lack regression tests, auto-add a TEST-UPDATE stage (1 agent: executor — updates stale tests + writes regression tests pinning the fixes; PRIOR CONTEXT = the synthesis grid; WRITABLE FILES = the named test files; does NOT touch production code), followed by a build-gate re-run and 1 review agent (no weakened pins, no scope creep; no adversarial pipeline for test-only changes). When convergence is reached, proceed to Delivery — convergence does not end the workflow.
   **Regression-aware fix scrutiny:** When the synthesis grid flags any file as a repeat-regression hotspot (≥3 PRIOR_FIX_ATTEMPT findings on the same file) or a regressing function (≥3 PFA clustered ~40 lines, OR in-run ≥2 consecutive failed fix attempts), the lead notes the flag for fix-agent assignment awareness — these locations have a demonstrated pattern of incomplete fixes. Post-fix REVIEW is primary-only (no second-opinion reviewer per Second Opinion Guidelines); the elevated-review mechanism for regressing functions is the pre-fix audit below.

   When the synthesis grid flags a regressing function (≥3 PRIOR_FIX_ATTEMPT findings clustered within ~40 lines of the same function, OR an in-run regressing function flagged by the synthesis agent — ≥2 consecutive failed fix attempts on the same function region within this run), the lead spawns a single pre-fix audit agent (executor, PLAIN) BEFORE the fix stage. The audit agent:
   - Reads only the flagged function and its immediate context (the function body plus its callers in the same file — not the full module)
   - Reads the git history of prior failed fix attempts for that function
   - Produces a localized structural recommendation: extract a helper, consolidate duplicate guards, hoist a validation check — a change strictly within that function's own file, touching no public APIs or cross-file interfaces
   - The recommendation is MANDATORY INPUT for the fix agent — the fix agent MUST apply it or explicitly justify rejecting it in its report. If the recommendation spans beyond the function's file, the lead rejects it and the fix proceeds without the structural change (standard primary-only post-fix review). The audit agent writes no code; the fix agent owns implementation. Function-scoped, no cross-file interface changes.

   Confirmed findings landing in a known regressing region are delivered as SINGLE-FINDING fixes with their own review — never batched with other findings in the same file.

   **Recurrence-class escalation:** synthesis categorizes every CONFIRMED finding by MECHANISM (validation gap, state-machine ordering, dispatch gap, cross-module divergence, error swallowing, etc.). Between stages, the lead checks category recurrence across consecutive checks: ≥2 findings in the same category as a prior check → stop surgical fixing of that category, escalate to a structural fix (centralize validation, extract shared logic, enforce ordering at the type level). Oscillating finding counts across ≥3 consecutive checks → stop the audit loop, structural refactor before more audits.
3. If scope changed from original plan, update `tmp/glm-plan.md` with actual stages and revised goals
4. Checkpoint. Clean up: `rm -f tmp/s[0-9]*-task-prompt.txt tmp/s[0-9]*-task.txt`
5. Next stage prompts include synthesis as `PRIOR CONTEXT:` section. PRIOR CONTEXT is a navigation aid that guides the agent to complete source artifacts — it is NOT a replacement for reading agent reports. Structure it as: (a) file paths to agent reports the downstream agent MUST read before beginning work (synthesis grid with adversarial evidence, discovery reports with cross-file analysis, Intent sections from prior implementation), (b) one-line item counts for orientation (e.g., "3 MEDIUM confirmed findings, 2 LOW noted"), (c) lead-level decisions and constraints (what scope was decided, what was explicitly excluded). Do NOT flatten cross-file analysis, call-chain traces, adversarial grep evidence, or architectural reasoning from agent reports into PRIOR CONTEXT — point to the source report and trust the agent to read it. When a downstream agent receives a finding ID (e.g., "F-03: null dereference at auth.py:42"), the agent MUST read the synthesis grid report for the full finding with adversarial evidence and the original discovery report for cross-file context. Target under 50 lines total (navigation pointers + item counts + decisions). When PRIOR CONTEXT includes research findings, include their confidence tier and instruct downstream agents to check claims against code, not trust them blindly. **Discovery Questions:** copy the research report digest's `## Discovery Questions` section verbatim into the discovery agent's YOUR TASK as MUST ANSWER questions (protocol: `##### Brick Catalog` RESEARCH). Include the research report file path in PRIOR CONTEXT for reference.
6. Never re-do verified work unless evidence shows it was wrong
7. Never skip a planned stage without explicitly marking it in `tmp/glm-plan.md` as `SKIPPED` with a reason. A stage is only complete when its agents have been spawned, waited, their reports processed by the verification pipeline, and findings verified — incomplete stages cannot be proceeded past, outside the narrow gap-acceptance rules in Execution step 3. PLAN stages cannot be SKIPPED for speed or token savings — only for genuine blockers (environment failure, missing files, corrupted state).
8. After writing synthesis, read `tmp/glm-plan.md` to confirm the next stage. If the plan has remaining stages, execute them — do not deliver early unless remaining stages are explicitly marked SKIPPED.

**Iterative stages:** Between iterations, follow the Iterative Convergence protocol below — skip steps 1-5 until convergence is reached. On convergence, write final stage synthesis (step 1) and resume normal between-stages flow (steps 2-5).

#### Iterative Convergence

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
  the trigger — they cannot cause an iteration to fire. (Keyed to the docs work-type.)
- A stage with zero CONFIRMED HIGH+ in its VERIFY grid is CONVERGED after one pass,
  regardless of task type, codebase cleanliness, or prior production-check history.

Factors the planner considers when setting the ceiling: ambiguity, codebase complexity,
finding volume, production impact of missed findings, change type (exploratory vs.
mechanical), time sensitivity.

**Not used for:** Production stages (implementation and fixing) and verification stages. These produce or evaluate output rather than discovering issues. RESEARCH stages use the confidence-tier trigger, not the CONFIRMED HIGH+ trigger: spawn iter 2 when any research finding critical to downstream stages is rated LIKELY or lower. Each iteration narrows scope — iter 1 asks "What does [SPEC] require?" at broad scope; iter 2 asks "What does [SPEC], Section X, Subsection Y specifically require?" on the area where iter 1 was uncertain. Research iterations inherit the same FOCUS/report exclusion rules (no research report or FOCUS angle reused across iterations) — also conditional-by-default, with the ceiling model applied.

**Mandatory rules apply:** CONVERGE iterations of DISCOVERY, REVIEW, or RESEARCH stages inherit ALL mandatory rules from the parent stage type — including second-opinion requirements at MEDIUM+ severity for DISCOVERY/REVIEW iterations. When the original DISCOVER/REVIEW required a second opinion agent, every CONVERGE iteration must also include a second opinion. The planner's decision table must list all agents to spawn per iteration — the lead spawns exactly what the plan lists. Intersection agents inherited by CONVERGE are ADDITIONAL agents, not replacements — the first DISCOVER stage must have its own intersection agents for ALWAYS/DEFAULT boundaries; CONVERGE iter 2 adds fresh intersection agents with different FOCUS angles.

**FOCUS-angle exclusion (planner, mechanical):** before writing iter 2, the planner MUST list every FOCUS angle/research report used in iter 1 and exclude them all from iter 2 — no angle may appear in any role in both iterations. Swapping primary and second-opinion angles between iterations does NOT count as different standpoints — the same pair in opposite roles is still the same analytical framework. The exclusion list must be explicit in the plan.

**RESEARCH EXTENSION on iterations:** when an iteration fires beyond the pre-baked coverage map (no unused FOCUS rows for its scope), the lead spawns ONE research agent per needed angle — fresh research on the spot, same research-producer rules, same report format, new FOCUS angle complementary to ALL prior iterations' angles. The fresh research then feeds the iteration per the tier rules. Bounded by the iteration CEILING — the ceiling remains the only stop; iteration depth is never research-blocked.

**Execution is mechanical — the lead does NOT re-evaluate the CONVERGE decision.** If the plan sets a ceiling (ONCE/LOOP) and the prior VERIFY grid contains ≥1 CONFIRMED HIGH+ finding, the lead spawns the iteration agents unconditionally (up to the ceiling). If the grid contains no CONFIRMED HIGH+ finding, the stage is converged — the lead skips unconditionally. The planner's ceiling assessment was already baked into the plan during Phase 1 research. The lead does NOT substitute judgment based on finding volume, "isolated"-vs-"specific" appearance, or task type — whether the trigger fired is read directly off the synthesis grid.

**Mechanics:**
1. Each iteration = full prepare → spawn → verify cycle
2. After verification: check the synthesis grid mechanically — does it contain any CONFIRMED HIGH/CRITICAL finding?
    - **Yes** → write iteration synthesis to `tmp/stage-N-iter-K-synthesis.md`, prepare next iteration. Each iteration's synthesis file is the cumulative state — the lead does not accumulate iterations in its own context; the files hold the history (see Context is not the lead's concern above).
    - **No** → convergence reached; write final stage synthesis and move on
3. Lead SHOULD vary approach between iterations — different agents, focus areas, or angles — to avoid blind spots. Running identical agents repeatedly is wasteful.
4. Lead can adjust agent count and type between iterations based on what prior iterations revealed
5. If iteration cap hit without convergence → synthesize what's known, note "convergence not reached" in delivery, proceed
6. **Naming:** `s{N}i{K}-name` (see Naming convention overview).

**VERIFY between iterations (MANDATORY):** The plan must include a VERIFY stage
between every pair of DISCOVER/REVIEW CONVERGE iterations. The structure is:
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
- **Knowledge harvesting:** If any synthesis grid contains CONFIRMED findings, spawn a single `knowledge-harvester` agent (default model) — it reads all synthesis grids and discovery reports. Report: `tmp/knowledge-harvest-report.md`. After the harvester completes, commit and push `knowledge.md` from the orchestrator's root (where `.opencode/` lives — the same `$REPO_ROOT` that `tmp/` paths resolve to) so harvested patterns survive the session. Skip the commit if `knowledge.md` is unchanged (all findings were INCIDENT with no knowledge updates).
- Cleanup: `rm -f tmp/s[0-9]*-task-prompt.txt tmp/s[0-9]*-task.txt`; delete the active handoff (`rm -f tmp/handoff-*.md` + its `handoff:` session note via `session show` → `session delete <id>`) — the task is done, a stale handoff must never trigger a false resume. Keep logs, reports, summary, knowledge-harvest-report. NEVER delete `tmp/uv/` — the locally installed uv binary per the tool-use policy; removing it forces a ~30 MB re-download on the next use.

### Agent Prompt Template

The task prompt file (the path the lead passes to the `task` tool as the `prompt` argument, per the read-and-execute spawn convention above) is assembled with cache-aware ordering: stable shared content first (cached across calls), volatile per-instance content last. The assembly order (performed by `assemble-task.sh`):

```
{cat .opencode/templates/coordination-review.txt OR coordination-code.txt — replace {NAME}; each template opens with the solo-agent and grep-first rules}

{cat .opencode/templates/severity-guide.txt — REVIEW/audit tasks only}

{cat .opencode/templates/quality-rules-review.txt OR quality-rules-code.txt}

You are an AI agent named {NAME}.

--- OUTPUT DIRECTORY ---
All reports and output files go to: {REPO_ROOT}/tmp/

--- TASK ASSIGNMENT ---

{## RESEARCH DATA — researched runs only: the routed research digest injected via assemble-task.sh --research-file, with the FULL RESEARCH REPORT path line under the header (--research-report), between template and task. PLAIN runs have no RESEARCH DATA section.}

PROJECT: {working directory and project description}

ENVIRONMENT (code tasks only):
{Runtime, test command (full suite — build-gate/TEST stage only, never per-agent), lint command}

PRIOR CONTEXT (stage 2+ or iteration 2+):
{Navigation aid per Between Stages step 5 — file paths to source reports the agent MUST read (synthesis grid, discovery reports, prior Intent sections), one-line item counts, lead decisions and constraints. NOT a replacement for reading agent reports. Target under 50 lines.}

YOUR TASK: {KEY FILES, CONTEXT, SCOPE, MUST ANSWER questions}

WRITABLE FILES: {code agents only — list source files agent may edit. Review/research/audit agents: omit this section}

--- WRITABLE FILES (automatic) ---
You must write your report to EXACTLY `{REPO_ROOT}/tmp/{NAME}-report.md` UNLESS the task file has a DELIVERABLES section specifying explicit report paths — then use those.
(This is your orchestrator working directory. NOT the PROJECT directory.)
```

The agent's `.md` is NOT embedded in the task prompt — opencode auto-loads it as the subagent's system prompt when the lead calls the `task` tool with `subagent_type`.

| Task Type | Coordination | Severity Guide | Quality Rules |
|-----------|--------------|----------------|---------------|
| Review/audit | coordination-review.txt | severity-guide.txt | quality-rules-review.txt |
| Code/refactor | coordination-code.txt | — | quality-rules-code.txt |
| Research | coordination-review.txt | — | quality-rules-review.txt |

Boilerplate templates live in `.opencode/templates/` and are `cat`-ed by `assemble-task.sh` into the task prompt verbatim. The lead only writes the unique parts (TASK ASSIGNMENT).

### Checkpoints & Recovery

**LEAD-ONLY — subagents NEVER use this section.** Subagents are single-task executors: they do not save checkpoints, do not run recovery, and do not maintain orchestration state. A subagent that does not understand its task decides the best interpretation and proceeds (see Autonomy) — it does NOT run the recovery sequence or read the plan to "figure out the workflow."

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
1. `./.opencode/tools/memory.sh session show` — restore session/checkpoint state (a `handoff:` note, if present, names the active handoff)
2. Read the active handoff — the newest `tmp/handoff-*.md` (skip if none)
3. Read the state the checkpoint names: `tmp/glm-plan.md` (plan) and/or the latest `tmp/stage-N-iter-K-synthesis.md` / `tmp/stage-N-synthesis.md` / `tmp/sN-synth-report.md` (verification/iteration/stage state) — see the Recovery table below
4. **Re-read AGENTS.md in full and STRICTLY follow its instructions** — ALWAYS, no exceptions, no partial reads. Nothing does this for you
5. Only then resume work: first delete the consumed handoff + its `handoff:` session note (full restore complete; handoff skill → Consuming a handoff)

Do not rely on the handoff alone. Do not skip the AGENTS.md re-read — this is the #1 cause of workflow deviation after compaction.

| Checkpoint | Recovery |
|-----------|----------|
| Plan done | Read `tmp/glm-plan.md` → prepare agents |
| Agents prepared | Assemble task prompts → delegate via task/subagent tool |
| Agents spawned | Check task results/reports → verify or re-delegate |
| Verifying stage N | Read `tmp/stage-N-synthesis.md` — the lead's synthesis from the synthesis agent's grid |
| Iterating stage N, iter K | Read `tmp/stage-N-iter-K-synthesis.md` — the cumulative state file → prepare next iteration |
| Stage N done | Read synthesis + plan → next stage |

**Long-stage state:** when a long-running stage risks compaction, write or update the active handoff (handoff skill, Mode B) — do not duplicate process state into synthesis. The recovery sequence reads the newest handoff.

### Session Continuation (handoff skill)

**LEAD-ONLY — subagents NEVER use this section.** For tasks exceeding a single session, the lead uses the **`handoff` skill (Mode B)**: one active handoff (`tmp/handoff-<slug>.md`) in the fixed 8-section template (see the skill; includes task_ids of completed/in-flight agents so a replacement lead resumes them instead of redoing them). A `session add note "handoff: <path>"` entry records it; updates replace the same active handoff.

**Pickup:** Request Workflow step 1 (newest `tmp/handoff-*.md`, named by the `handoff:` session note). **Cleanup:** delete the handoff + its session note once fully restored from it (handoff skill → Consuming a handoff); delivery cleanup (see Delivery) removes any that was never consumed. Never re-do verified prior work.

### Error Handling

| Scenario | Action |
|----------|--------|
| No report after exit | **RESUME FIRST, respawn second:** re-invoke the task/subagent tool with the same task_id asking it to deliver — the session keeps its context and writes the report. Only if the resume fails, diagnose the failure (bad prompt? missing dependency? environment?) and re-issue the task call. Do NOT fill gaps yourself — filling gaps is agent work. |
| Report exists but structurally incomplete (missing mandatory template sections — no Findings block, no Investigated-and-Rejected, skipped MUST ANSWER, missing file paths) | **Lead option — resume is the cheapest win:** re-invoke with the same `task_id` asking it to complete exactly the missing sections. Structural check only — the lead does NOT evaluate claim quality (that is the verification pipeline's job). Still incomplete after a resume → diagnose (bad prompt/task), re-issue fresh. |
| MUST ANSWER question skipped | **Lead option — resume is the cheapest win:** re-invoke with the same `task_id` asking only the missing question. Still missing → diagnose, re-issue fresh. |
| Agent claims success but output wrong | Diagnose why output is wrong (bad prompt? misunderstood task?). Fix the prompt/task. Re-issue the task call. Do NOT verify or fix the output yourself. |
| Incorrect edits | Diagnose why the agent produced wrong output (bad prompt? misunderstood task?). Fix the prompt/task. Spawn a quick-fix agent to revert and rewrite. Do NOT revert changes yourself. If the quick-fix agent is still wrong, diagnose the issue and retry once with corrected configuration. If the retry also fails: for HIGH/CRITICAL-adjacent changes, escalate to full IMPLEMENT → REVIEW → VERIFY; otherwise (LOW/MEDIUM or workflow-internal clutter), spawn a quick-fix agent to revert the change entirely — better to ship clean than to ship a broken fix (see Lead Role — Quick-fix agents). |
| 2+ agents fail same env error | STOP respawning. Diagnose environment first (do NOT fix environment issues directly — spawn an agent if changes needed) |
| Agent aborted (same error 3×) | Diagnose root cause from task result, fix environment/config (spawn an agent if code/config changes needed), then re-issue the task call |
| Stage partially failed (1+ agents produced no useful output or wrong output) | Diagnose root causes across all failed agents. Fix issues (environment, prompts, tasks). Re-issue ALL failed task calls. The stage is incomplete until all agents succeed. Do NOT proceed to the next stage with gaps. |
| Iteration cap hit without convergence | Synthesize all iterations, note "convergence not reached" in delivery, proceed |
| Adversarial verification produces suspicious results (CONFIRMED on obviously-wrong findings or REJECTED with weak evidence) | Diagnose prompt/task quality — adversarial agent may have misunderstood its role. Adjust MUST ANSWER questions or adversarial instructions and re-issue. |

> **Reuse ≠ respawn** — resuming the same `task_id` takes no access to the respawn budget (`-r2`/`-r3`); respawn stays a separate path (same name, fresh run). Recovery resumes (this table) count toward the 3-resume threshold (O-R3). Re-issued fresh replacements start a new run with a new threshold. **R2 agents (adversarial verification, `postfix-reviewer`, second opinions, planner↔organizer — O-R2) are never resumed: recovery is a fresh respawn.**

> **Structural-check legality:** the structural checklist is *template membership* only — the EXACT sections from coordination-*.txt REPORT FORMAT: review/research → `### Summary`, `### Findings`, `### Investigated-and-Rejected`, `### Fix Design (DISCOVER/REVIEW findings)`, `### MUST ANSWER Responses`, `### Gaps`; code → `### Summary`, `### Changes`, `### Test Results`, `### Investigated-and-Rejected`, `### MUST ANSWER Responses`, `### Gaps` — plus, per quality-rules-review.txt, every finding carries file:line + severity. Checked against the report body: present/absent + line count, NEVER content.

> **Thin ≠ wrong (guard):** wrong output is diagnose → re-issue fresh (resuming risks a confirmation loop); only structural incompleteness / skipped questions are resumable.

**Deepseek-flash output-budget failure (CLI runs):** high-reasoning agents can burn the entire output budget on heavy reviews (`reason: length`, 0 output). Fix for CLI runs (`opencode run`): `OPENCODE_CONFIG` with `{ "provider": { "deepseek": { "options": { "max_tokens": 65536 } } } }`. TUI sessions unaffected.

### Rules

**Quality over speed — ALWAYS.** Never rush, never cut corners, never try to finish faster. Slow, thorough, methodical work produces quality. Speed produces bugs. Prefer more stages, more agents, more verification over shorter timelines. There is no deadline. The only measure of success is production-ready, bug-free code.

**Limits:** Per-batch limit and agent parallelism rules are defined in Tools and Agent Spawning — don't restate. Need more coverage than the 10-agent per-batch cap allows? Add stages, not more agents per batch. Agents run until done (no turn limit). One task per agent. Respawn naming: `-r2`, `-r3`. No two agents edit same file within a stage (read overlap OK). Balance workload — each agent should cover roughly equal scope.

- **Subagent reuse (resume same session via `task_id`)** — reuse is ALWAYS the lead's call; the envelope below defines what it is and the boundaries against regressions, not when it must be used:
  - **O-R1 Same-run, same-scope only** — a reuse continues one run about its own deliverable; it never becomes a second task ("one task per agent" unchanged). New stage ⇒ fresh agents; cross-stage continuity runs through the checkpoint + handoff protocol, never through subagent reuse. Follow-up questions on a stage agent's own deliverable (ask-don't-respawn) are the canonical use. **Reuse lives inside the open stage window:** once the stage closes, the run is done — a later stage never reopens it. Convergence iterations are separate standpoints (different FOCUS = different deliverable) — reuse never crosses iterations (each `sNiM-` run stays inside its own iteration).

> **[O-8 Planning clarification]:** during manifest review, the lead may reuse the planner run to answer targeted review questions on the planner's own deliverable (why a brick is NONE, what assumptions it made) — the planner's full codebase research cannot be cheaply redone, and the lead never researches instead. Scope-bound: answers concern the SAME plan draft only — no new planning, no stage execution (the planner's "STOP" discipline holds); and the resumed planner always answers from ITS OWN run context, never from stale artifacts (its Phase 1 "fresh plan, never a continuation" rule concerns stale files, not its own session). Option *beside* the Planning step-5 "re-run the planner" fallback: targeted ambiguity → reuse; fundamentally under-informed plan → full re-run (unchanged). The organizer still reviews the final manifest independently — O-3's planner↔organizer guard is untouched.

  - **O-R2 Never reuse:** adversarial verification batches, `postfix-reviewer`, ALL second opinions (DISCOVER/REVIEW s2 runs), and planner↔organizer (plan-review independence). Fix agents never reuse the review/verification run that produced the verified findings — the design travels in files (checked checklist), never through session continuity.
  - **O-R3 Threshold (not hard cap) — watch at 3 reuses per `task_id`:** each reuse replays the full prior transcript into the subagent's window; past ~3 the replay growth degrades attention to the current ask (output-quality regression). At the threshold: retire via the **`handoff` skill** (Mode A) — the retiring run writes `tmp/<retiring-name>-handoff.md`; boot a fresh successor (new name, new run) that reads the handoff first, full report as backup. The lead may retire earlier. Quality framing only — this rule is never justified by token/context cost. **Successor naming:** `{stage-run}-c2` (e.g. `s1-discover-c2`) — never `-r2/-r3` (respawn slots) and never `-s2` (stage-2 numbering — `s2i1-` already means stage 2, iteration 1).
  - **O-R4 Self-contained reuse messages** — state the question, constraints, and task path as if the reader were fresh. A lead compacted or replaced must be able to reissue the same reuse prompt from files alone; a lost `task_id` then costs a clean replacement, not a re-brief.
  - **O-R5 Record task_ids after every spawn** — `tmp/{NAME}-task-id.txt` beside the report; additionally list task_ids of completed/in-flight agents in the handoff file (Session Continuation) so a replacement lead resumes instead of redoing ("Do not redo" guarantee).
  - **O-R6 Audit header + stage sequencing** — reused runs append `> resumed ×N` to the same report path; the reused run must complete BEFORE the stage closes (stage-completeness rule) — extraction in the verification pipeline must read the final report version, never a report being hardened.
  - **O-R7 Files stay the memory** — report/PRIOR CONTEXT conventions unchanged; reuse is invocation-level only, zero tooling.

**Task/subagent tool (MANDATORY):** Agent delegation happens ONLY via the `task` tool (V1) or the `subagent` tool (V2) (mechanism: Agent Loading Rules). The lead never uses `opencode run` to spawn workflow agents.

**Agent count per stage (MANDATORY — fill capacity by task decomposition):** Decompose the task into as many independent subtasks as it naturally splits into, spawn one agent per subtask (per-batch limit and decomposition guidance: Tools). Default to what the task genuinely requires — scale to scope. Verification stages scale with findings count and impact surface, not discovery agent count — minimum 1 extraction agent for every stage; adversarial agents run only if extraction finds at least one MEDIUM+ finding to falsify. When in doubt, decompose into more parallel agents — broader coverage finds more issues. **Never run sequential single-agent stages when those stages could be a single stage with parallel agents (see Workflow → Mid-Execution Amendment → Stage decomposition rule).**

**Prompts:** All per-task context must be in the task prompt (assembly + template: Agent Prompt Template) — AGENTS.md is loaded natively by the platform into every session (lead and subagents alike), so do NOT rely on it as the agent's operating manual for task specifics.

**Verification:** Every finding labeled. Every label backed by Read. 100% complete before proceeding. ALL verified actionable findings fixed via fix-agent — the lead does not fix findings directly.

**Lead code prohibition (MANDATORY):** the lead never writes, edits, or modifies project source code — every code change goes through a spawned agent (see Lead Role — self-check rules). The only exception is editing AGENTS.md itself (meta-configuration).

**Platform:** `opencode` on all platforms. The lead operates as an opencode session (TUI or `opencode run`); workflow agents are native subagents delegated via the `task` tool.
