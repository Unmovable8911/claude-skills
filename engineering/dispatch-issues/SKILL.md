---
name: dispatch-issues
description: Orchestrate issue slices from .docs/issues/ to TDD sub-agents in dependency order. Reads the latest PRD and 00-outline.md, computes a dependency wave plan, dispatches each unresolved slice to its own sub-agent (which runs the tdd skill against the slice's issue doc), then commits and marks the slice resolved. Use when the user wants to execute/implement an issue backlog, run the outline, dispatch slices to sub-agents, or drive issues to completion wave by wave.
---

# Dispatch Issues

Drive any project's issue backlog to completion by dispatching each slice to a dedicated TDD sub-agent, strictly respecting dependencies. Project-agnostic: works for any backlog laid out in the structure below, not just one repo or domain.

## Inputs

- **Outline** *(orchestrator reads this)*: `.docs/issues/00-outline.md`. Each line is one slice:
  `<N>. <title> — blocked by: <deps|none> — status: <pending|resolved>`. This is the only doc the orchestrator opens.
- **Latest PRD** *(sub-agent reads)*: newest file in `.docs/prd/` (sort by filename — typically `yyyy-MM-dd-HH:mm.md`). Product context for the implementer.
- **Issue docs** *(sub-agent reads)*: `.docs/issues/<NN>-<title>.md`, where `<NN>` matches the slice number in the outline. The orchestrator only resolves their paths via `ls`, never their contents.

## Core rules (non-negotiable)

1. **One slice per sub-agent.** Never give a sub-agent two or more slices.
2. **No level-skipping.** A slice is *ready* only when every slice in its `blocked by` list has `status: resolved`. Never dispatch an unready slice.
3. **Skip resolved.** Ignore slices already marked `resolved`.
4. **Parallel within a wave, capped.** Slices ready at the same time form a wave — dispatch concurrently (multiple Agent calls in one message), but no more than **MAX_PARALLEL = 3** at once. If a wave exceeds the cap, dispatch in batches of 3.
5. **Commit + mark per slice.** After each slice's sub-agent finishes successfully, make one git commit for that slice and set its outline status to `resolved`.
6. **Keep the orchestrator's context clean.** The orchestrator MUST NOT open any individual slice issue doc (`.docs/issues/<NN>-<title>.md`) or the PRD body. It plans via `scripts/outline.py` (which returns each slice's `issue_path`) and passes that path to the sub-agent. Reading slice/PRD bodies is the sub-agent's job — pass the path, not the contents.

## Workflow

0. **Preflight: require the `tdd` skill.** This skill depends on `tdd` (every sub-agent runs it). Verify it with a command — query the runtime's own skill discovery, do not search directories:
   ```
   claude -p "List the exact names of all skills available to you, one per line, nothing else." 2>/dev/null | grep -qiw tdd
   ```
   Exit code `0` = present (continue). Non-zero = **missing**: **abort immediately** — do not plan, dispatch, or commit. Tell the user the session is stopping because the required `tdd` skill is missing — state the missing dependency only, no install instructions.
1. **Load + plan via script.** Run `python3 scripts/outline.py plan` (pass `--issues-dir` if not the default `.docs/issues`). It parses `00-outline.md`, resolves each slice's `issue_path`, and returns JSON with `ready` (the ready set), `unresolved`, `resolved`, `missing_issue_files`, `deadlock`, and `all_done`. Do **not** parse the outline by hand and do **not** read slice issue docs or the PRD body — the script computes the plan; the sub-agent reads the docs. This keeps the orchestrator's context lean and the wave logic deterministic.
2. **Plan waves.** Use the script's `ready` list. If `deadlock` is true (exit code 2) — unresolved slices remain but none are ready — stop and report a dependency cycle / unmet blocker. If `all_done`, finish.
3. **Dispatch a wave (cap 3).** For each ready slice, spawn one `general-purpose` sub-agent in the same message, up to MAX_PARALLEL. Use the prompt below. Wait for the batch to finish, then dispatch the next batch if the wave had more than 3.
4. **Handle each result:**
   - **Success (tests green):** `git add -A && git commit -m "feat(slice-<NN>): <title>"`, then run `python3 scripts/outline.py resolve <NN>` to flip that slice to `resolved` (deterministic edit — don't hand-edit the outline). Do finalization one slice at a time so each commit is clean.
   - **Failure (tests red / blocked):** retry once — re-spawn a fresh sub-agent for the same slice with the failure summary appended. If it fails again, leave the slice `pending`, report it, and do not let dependents proceed.
5. **Next wave.** Recompute the ready set (now larger because deps resolved) and repeat from step 3 until all slices are resolved or blocked.
6. **Report.** Summarize resolved slices, commits made, retries, and anything still blocked.

## Sub-agent prompt template

Spawn with `subagent_type: general-purpose`. One slice only:

```
You are implementing exactly ONE issue slice for this project. Do not touch any other slice.

Slice: <NN> — <title>
Issue doc: .docs/issues/<NN>-<title>.md   (read it fully first)
Product context: latest PRD in .docs/prd/ (read for background)

Use the `tdd` skill (red-green-refactor, vertical slices) to implement this slice's
acceptance criteria from the issue doc.

Do NOT git commit and do NOT edit 00-outline.md — the orchestrator handles commits and
status updates. When done, report: tests written, what passes, and any deviations.
```

(On a retry, append: `Previous attempt failed: <summary>. Fix and complete the slice.`)

## Notes

- The orchestrator — not the sub-agent — owns commits and outline edits, so the audit trail stays one-commit-per-slice and concurrent agents don't race on git state.
- Tune `MAX_PARALLEL` if the host has more/less capacity; 3 is a safe default.
- If a sub-agent fails twice, hold the wave: any slice depending on the failed one is by definition not ready, so the dependency rule already prevents it from running.
