# Agent Directory (11 agents)

Quick selection reference. All workflow instructions live in `AGENTS.md` — the Tier rule (PLAIN/researched), research coverage map + routing, second-opinion rules, verification pipeline. Read it before delegating.

## Workflow-internal agents (process roles)

| File | Agent | Role |
|------|-------|------|
| agentic-planner.md | Planning agent | Researches the project, classifies the task, builds the Research Coverage Map + Routing Table, assigns per-agent tiers (PLAIN/researched) and FOCUS angles, produces the workflow manifest |
| volume-splitter.md | Volume splitter | Mechanical KEY FILES resolution + split/merge (4K/5.5K caps), rewrites the plan in-place |
| agent-organizer.md | Plan organizer | Structural plan review: tiers, routing precision, FOCUS complementarity, exclusion lists, MUST ANSWER redistribution |
| verification-analyst.md | Extraction + synthesis | Deduplicates/tags findings (both-found/single-found/boundary-found), compiles the verification grid, knowledge harvesting |
| adversarial-reviewer.md | Adversarial reviewer | Falsification gate — the single distinct quality gate, ALWAYS at MAX reasoning effort (no lower-effort tier); CRITICAL (1:1), HIGH (1:3), MEDIUM (1:10) batch sizes are volume controls — CONFIRMED/REJECTED/WEAKENED; Findings-Review Mode challenges investigated-and-rejected lists; prioritizes unique findings on merged s2 outputs |

## Research agents (producers — never receive research data)

| File | Agent | Role |
|------|-------|------|
| web-searcher.md | Web researcher | RESEARCH brick — internet research (standards, formats, versions, ecosystems, advisories) |
| research-analyst.md | Research analyst | RESEARCH brick — structured analysis/synthesis; mid-execution research |
| data-researcher.md | Data researcher | RESEARCH brick — dataset research |

## Executor (all execution roles)

| File | Agent | Role |
|------|-------|------|
| executor.md | Executor | The ONE generic executor: DISCOVER, IMPLEMENT, REVIEW, FIX, TEST, TEST-UPDATE, quick-fix, build-gate, final gate, single-session tasks. High reasoning effort (max reserved for planner/adversarial/postfix-reviewer). Post-fix review is NOT its job — that is postfix-reviewer's. PLAIN (task file carries the research) or researched (digest injected as RESEARCH DATA + full report path). Adopts the report's FOCUS as its standpoint. No web research of its own. |
| postfix-reviewer.md | Postfix reviewer | Post-fix review ONLY (always MAX reasoning effort, strictly read-only): verifies applied fixes against their design (correctness, minimality, new bugs, test breakage, race conditions; verdict APPROVED / NEEDS-FIX). Never used for any other task. |

## Single-session-suite agents (for the single-session-workflow skill — not used by the orchestrator pipeline)

| File | Agent | Role |
|------|-------|------|
| prepare-agent.md | Prepare agent | Research generation (single-session workflow): per-technology queries, full research report (no size cap) + compact digest (~10KB). FOCUS parameter = specialist identity. |

## The one general rule

> **Every agent should have research data.** If the data is already gathered and covers everything the agent needs, run PLAIN and pass the already-present data with the task. Research is injected only when the task depends on facts the file does not carry.

Tiers: **PLAIN** (pass-through — the task file carries the research), **researched** (the routed report rides as digest + full path: the digest injects as RESEARCH DATA, the full report path prints under the header — s2, intersections, thin-context primaries). s2 second opinions are always researched with complementary FOCUS. Specialist identity = the research report's FOCUS angle, never a static persona.
