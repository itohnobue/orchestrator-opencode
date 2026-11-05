---
name: propagate-workflow-mbp
description: Propagate workflow changes from orchestrator-opencode (source of truth) to all 7 repos using the same opencode workflow. Use ONLY when the user explicitly commands propagation in the current session — never launch it automatically. Some repos gitignore the workflow files (only knowledge.md is in git) — those still get the files copied locally, just without committing.
disable-model-invocation: false
argument-hint: []
---

# Propagate Workflow to All Repos

> **MANDATORY — NEVER LAUNCH WITHOUT AN EXPLICIT USER COMMAND.** This skill mutates 7 repositories and pushes commits; it must never be started on the model's own initiative — not automatically, not proactively, and not as a follow-up after workflow files change in orchestrator-opencode. It runs only when the user explicitly commands propagation in the current session (e.g. `/propagate-workflow-mbp` or a direct instruction to propagate). If the user has not explicitly asked for it, do not start it.

Synchronize generic workflow changes from `orchestrator-opencode` (the authoritative version) to all repos that use the same workflow system. This is a careful, diligent operation — every step is verified, and on completion a full cross-repo check is performed.

## Destination Type

All 7 targets run the orchestrator pipeline directly (they execute these exact agents, templates, and tools). They are all **full-payload destinations** — each receives the ENTIRE workflow, byte-identical from source:
- the `AGENTS.md` workflow section (from `## Shared Workflow Infrastructure` down, below their project-specific section)
- `.opencode/agents/*.md`, `.opencode/templates/*.txt`, `.opencode/tools/*`, `.opencode/plugin/*` (excluding `__pycache__`)

The legacy `.opencode/plugins/` directory is **not** part of the payload. Upstream moved the plugin to `.opencode/plugin/` with a V1/V2 dual entrypoint (commit `1bdb64b`), so the stale `.opencode/plugins/fix-prompt.js` must be **removed** from any target that still has it (see Step 4). The installers (`install.sh`/`install.ps1`) are repo-root tooling of the source repos, not a target payload — no target carries them, so they are never propagated.

There are no skill-only destinations in this propagation — every target is a full working copy.

## Source of Truth

- **`orchestrator-opencode`** — the authoritative version. All propagation originates here. Run this skill from the orchestrator-opencode repo root; source paths below (`.opencode/...`) are relative to it.

## Target Repos

| Repo | Path | Branch | Remote | Workflow files in git? |
|------|------|--------|--------|----------------------|
| fallout2-ce-extended | `../fallout2-ce-extended` | main | aoizora.ru | NO (`.opencode/`, `AGENTS.md` gitignored; only knowledge.md tracked) |
| hpgl-reborn | `../hpgl-reborn` | master | aoizora.ru | NO (`.opencode/`, `AGENTS.md` gitignored) |
| pylasdev-reborn | `../pylasdev-reborn` | master | aoizora.ru | NO (`.opencode/`, `AGENTS.md` gitignored) |
| arcaios | `/Volumes/work/pe/arcaios` | main | git.privacyeverywhere.net | YES |
| arcaandroid | `/Volumes/work/pe/arcaandroid` | main | git.privacyeverywhere.net | YES |
| pe_mac | `/Volumes/work/pe/pe_mac` | casa **and** stable | git.privacyeverywhere.net | YES |
| peoutlook | `/Volumes/work/pe/peoutlook` | stable | git.privacyeverywhere.net | YES |

**Always verify each repo's actual branch with `git -C <repo> branch --show-current` — never assume the branch. Verify the git-tracking state with the checks in Rule 6 — it can change.**

**pe_mac propagates to TWO branches: `casa` (if it exists) and `stable`.** For pe_mac, apply the full per-repo sequence (pull → propagate → check → commit → push) on `casa`, then repeat on `stable`. Check `git -C pe_mac branch -a` to confirm which branches exist; propagate to `stable` only if it exists.

## Core Rules (MANDATORY)

### 1. No Contamination
Never propagate orchestrator-opencode's **project-specific** content into other repos. This includes:
- orchestrator-opencode skills (propagate-workflow-mbp, etc.)
- `knowledge.md`
- `session.md`, `.opencode/current_session`
- Any server/VM-specific config (vespa, aoizora, storage mounts)
- Anything unique to orchestrator-opencode's own setup

### 2. No Destruction
Never delete, overwrite, or modify a target repo's **project-specific** content:
- Their AGENTS.md project-specific section (above the workflow seam)
- Their `knowledge.md`, skills, session files
- Their own per-repo files (custom skills, etc.)
- Files unique to that repo
- **Never delete or skip-copy destination-only files** — only copy/overwrite files that exist in the source

### 3. AGENTS.md Seam
AGENTS.md has a clean boundary:
- **Above `## Shared Workflow Infrastructure`** = project-specific → preserve, never touch
- **From `## Shared Workflow Infrastructure` down** = generic workflow → propagate

To update AGENTS.md, splice the workflow section from orchestrator-opencode (from the seam to end) into each target, preserving everything above the seam.

### 4. General / Diff-Driven
Workflow changes can be any type. Do NOT hardcode a file list. Instead:
- Diff orchestrator-opencode's workflow area against each target
- Propagate **all** generic workflow changes: AGENTS.md workflow section, templates, agents, tools, plugin
- Handle **add / modify / delete** uniformly
- A file added in orchestrator-opencode → add it to targets; deleted in orchestrator-opencode → delete from targets (if it was propagated, not project-specific)
- **Skip-copying a source file is FORBIDDEN** — a skipped file means the target silently keeps a stale version

### 5. Selective Propagation
Propagate only **confirmed generic workflow files**. Never:
- Force-add optional files a target deliberately doesn't have
- Delete a target file that may be project-specific
- Touch `tools/` scripts that differ per-repo (verify content before syncing)

### 6. Gitignore-Aware Committing (MANDATORY)
Some target repos **gitignore the workflow files** — only `knowledge.md` is in git. For those repos, the workflow files must still be propagated (copied into the local working tree) **but must NOT be committed or pushed**.

Determine per repo whether workflow files are git-tracked:
```bash
git -C <repo> ls-files | grep -c "^.opencode/"     # 0 => .opencode/ is gitignored/untracked
git -C <repo> ls-files | grep -c "^AGENTS.md$"     # 0 => AGENTS.md is gitignored/untracked
git -C <repo> check-ignore .opencode/templates     # non-empty output => ignored
```

Known tracking state per repo: see the Target Repos table above — verify before each run (state can change).

For the gitignored repos (fallout2-ce-extended, hpgl-reborn, pylasdev-reborn):
- Copy all generic workflow files into the local working tree exactly as for committed repos.
- Skip Step 6 (Commit) and Step 7 (Push) entirely — the files are not tracked, so committing would fail or, worse, accidentally force-add ignored files.
- Verify the copy with `diff -rq .opencode/templates/ <repo>/.opencode/templates/` and friends.

## Per-Repo Sequence

For **each** of the 7 targets, in sequence. **Exception: pe_mac runs the full sequence TWICE — once on `casa`, then on `stable`** (the two branches carry the same workflow and must stay in sync).

For each branch of each repo, run:

### Step 1: Inspect
```bash
git -C <repo> branch --show-current
git -C <repo> status --short
```
- Note the branch
- Note any **pre-existing uncommitted changes** — these must NOT be touched or committed

### Step 2: Pull (tracked repos only)
```bash
git -C <repo> pull
```
- Pull the current branch (do not assume `main`)
- If the tree is dirty, pull may fail — handle carefully, never force

### Step 3: Determine what to propagate
Diff orchestrator-opencode's generic workflow files against the target:
```bash
diff -rq .opencode/templates/ <repo>/.opencode/templates/
diff -rq .opencode/agents/ <repo>/.opencode/agents/
diff -rq .opencode/tools/ <repo>/.opencode/tools/
diff -rq .opencode/plugin/ <repo>/.opencode/plugin/     # "No such file or directory" until first propagated
```
Plus the AGENTS.md workflow section (seam to end). Also check for the legacy plugin: `ls <repo>/.opencode/plugins/fix-prompt.js` (present => stale, must be removed). Build the change list.

### Step 4: Propagate (careful)
- Copy templates, agents, tools, plugin — ALL the generic workflow files that differ (never skip a differing source file). `.opencode/plugin/` may not exist in a target yet — create it. If the target tracks `.opencode/` in git, ensure `.opencode/handoff/` is gitignored — the compaction plugin writes per-session handoff files there at runtime.
- Remove the legacy `.opencode/plugins/fix-prompt.js` where present (upstream deleted it in `1bdb64b`); remove the `.opencode/plugins/` directory too if it becomes empty. Delete **only** that known-legacy file, never other repo-specific plugins.
- Splice the AGENTS.md workflow section (from `## Shared Workflow Infrastructure` down), preserving the project section above
- Handle add/modify/delete of agents/templates/tools/plugin
- Skip anything project-specific (per Core Rules)
- **Drift guard (MANDATORY):** before overwriting any file that differs from the source, check whether the target's version is a LOCAL change not yet in orchestrator-opencode (compare `git -C <target> log -1 -- <file>` vs source; or diff the file — if the target has content absent from the source, it may be a destination-first change). If the target version is newer than the source (work-in-progress), do NOT overwrite — report it and stop for a decision. If the source is newer (or the file matches), overwrite.

### Step 5: Final checks (per repo)
- `git diff` the target — verify ONLY the intended workflow files changed
- Verify the project-specific AGENTS.md section is byte-identical to before
- Verify no project-specific file (knowledge.md, skills, session, etc.) was touched
- Verify the propagated files match orchestrator-opencode (md5/diff) — every payload file, byte-for-byte

### Step 6: Commit — **ONLY if the repo's workflow files are git-tracked** (per Rule 6)
```bash
git -C <repo> add <only the propagated files>
git -C <repo> commit -m "sync: workflow changes from orchestrator-opencode"
```
- Stage ONLY the propagated files
- NEVER stage pre-existing dirty changes (knowledge.md, current_session, etc.)
- NEVER use `git add -A` if the tree has pre-existing changes
- **Skip this step entirely for gitignored-workflow repos** (fallout2-ce-extended, hpgl-reborn, pylasdev-reborn)

### Step 7: Push — **only if the commit was made** (per Rule 6)
```bash
git -C <repo> push
```

## Global Final Check (after ALL repos done)

Full-scale cross-repo verification:
1. For every changed workflow file, verify the content is **identical across all 7 targets** (md5 comparison) — for pe_mac, check both `casa` and `stable` branches
2. Verify the AGENTS.md workflow sections (seam to end) are **identical across all 7 targets** and match orchestrator-opencode — for pe_mac, on both branches
3. Verify `.opencode/plugin/` is present and byte-identical to source in every target, and that **no** target retains the legacy `.opencode/plugins/fix-prompt.js` — for pe_mac, on both branches
4. For each repo with git-tracked workflow files, run `git log --oneline -1` to confirm the sync commit landed — for pe_mac, on both branches
5. For gitignored-workflow repos, confirm the files are present in the working tree and match orchestrator-opencode (they will appear as untracked in `git status` — that is expected)
6. Cross-check each repo's `git diff HEAD~1` to confirm only intended files changed (skip for gitignored repos)
7. Confirm no target has project-specific content damaged

## Working Notes

- `orchestrator-opencode` itself is the source — do not modify it during propagation
- **Shared tools + plugin:** the shared tools, `plugin/fix-prompt.js`, `plugin/handoff-compaction.js`, `templates/severity-guide.txt`, and `agents/prepare-agent.md` originate from `single-session-opencode` (source of truth). Before propagating, ensure they are in sync via the local `sync-shared-tools` skill; edits to those files are made in single-session-opencode first. The compaction plugin's 8-section template mirrors the shared `handoff` skill — propagate both in the same run, and never let the two templates diverge.
- orchestrator-opencode is public: if the workflow change is user-facing (e.g., a documented feature in the README), update its README in the same commit
- Different remotes (aoizora.ru vs git.privacyeverywhere.net) — push uses each repo's own origin, no cross-remote assumptions
- If a step fails or a repo has conflicts: STOP, diagnose, fix before proceeding — do not skip or force
- Work carefully and diligently; verify every step. Errors here propagate to 7 repos.
- fallout2-ce-extended, hpgl-reborn, pylasdev-reborn may need their workflow files fetched/cloned from the origin before propagation if they are missing locally (e.g. `git clone ssh://git@git.aoizora.ru:2222/nobu/<repo>.git`)
- The two failure classes here — skipping a differing file, or overwriting a destination-first change — are prevented by the drift guard (Step 4) and the no-skip rule (Rule 4). When making ANY workflow change in orchestrator-opencode (AGENTS.md or agents/templates/tools/plugin), this skill should be run afterwards — but only upon the user's explicit command (see the MANDATORY rule at the top); never launch it yourself.