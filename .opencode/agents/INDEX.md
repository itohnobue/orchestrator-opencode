# Agent Directory (11 agents)

Quick selection reference. All workflow instructions live in `AGENTS.md` — the Tier rule (PLAIN/POINTER/INJECT), research coverage map + routing, second-opinion rules, verification pipeline. Read it before delegating.

## Workflow-internal agents (process roles — unchanged)

| File | Agent | Role |
|------|-------|------|
| agentic-planner.md | Planning agent | Researches the project, classifies the task, builds the Research Coverage Map + Routing Table, assigns per-agent tiers (PLAIN/POINTER/INJECT) and FOCUS angles, produces the workflow manifest |
| volume-splitter.md | Volume splitter | Mechanical KEY FILES resolution + split/merge (3K/3.5K caps), rewrites the plan in-place |
| agent-organizer.md | Plan organizer | Structural plan review: tiers, routing precision, FOCUS complementarity, exclusion lists, MUST ANSWER redistribution |
| verification-analyst.md | Extraction + synthesis | Deduplicates/tags findings (both-found/single-found/boundary-found), compiles the verification grid, knowledge harvesting |
| adversarial-reviewer-max.md | Adversarial reviewer (MAX) | Falsification gate for CRITICAL (1:1) and HIGH (1:3) batches — CONFIRMED/REJECTED/WEAKENED; Findings-Review Mode challenges investigated-and-rejected lists; prioritizes unique findings on merged s2 outputs |
| adversarial-reviewer-high.md | Adversarial reviewer (HIGH) | Falsification gate for MEDIUM (1:8) batches — same methodology, lower effort tier |

## Research agents (producers — never receive research data)

| File | Agent | Role |
|------|-------|------|
| web-searcher.md | Web researcher | RESEARCH brick — internet research (standards, formats, versions, ecosystems, advisories) |
| research-analyst.md | Research analyst | RESEARCH brick — structured analysis/synthesis; mid-execution research |
| data-researcher.md | Data researcher | RESEARCH brick — dataset research |

## Executor (all execution roles)

| File | Agent | Role |
|------|-------|------|
| executor.md | Executor | The ONE generic executor: DISCOVER, IMPLEMENT, REVIEW, FIX, TEST, TEST-UPDATE, quick-fix, build-gate, final gate, single-session tasks. High reasoning effort (max reserved for planner/adversarial). PLAIN (task file carries the research) or research-baked (routed report injected as RESEARCH DATA). Adopts the report's FOCUS as its standpoint. No web research of its own. |

## Single-session-suite agents (for the single-session-workflow skill — not used by the orchestrator pipeline)

| File | Agent | Role |
|------|-------|------|
| prepare-agent.md | Prepare agent | Research generation for T2/T3 tasks (single-session tiered pipeline): per-technology queries, one ≤15KB research-data file. FOCUS parameter = specialist identity. |

## The one general rule

> **Every agent should have research data.** If the data is already gathered and covers everything the agent needs, run PLAIN and pass the already-present data with the task. Research is injected only when the task depends on facts the file does not carry.

Tiers: **PLAIN** (pass-through — the task file carries the research), **POINTER** (report path + Discovery Questions), **INJECT** (full report as RESEARCH DATA — s2, intersections, thin-context primaries). s2 second opinions are always research-baked with complementary FOCUS. Specialist identity = the research report's FOCUS angle, never a static persona.
