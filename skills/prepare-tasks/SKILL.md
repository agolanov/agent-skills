---
name: prepare-tasks
description: "Turns any mix of ideas, specs and plans into tasks ready for deliver-task: opens a visible child session for each spec that still needs a spec, plan or clean cross review, proposes the task order, verifies review marks and writes a queue file. Use when the user wants several tasks prepared for delivery without writing the documents in the current session."
metadata:
  internal: true
---

# Prepare Tasks

`prepare-tasks [<path|dir|"idea text">...] [--agent claude|codex] [--model M] [--effort E]`

Children own specs, plans, reviews and review marks, and talk to the user in their own windows. The root resolves units, opens and waits on windows, proposes the order, verifies Git/status facts, merges planning branches and writes the queue file. It writes no spec, plan or mark and never edits a child status; its only commits are the queue file and the merges.

## Preflight

1. Resolve the project checkout (top level of the current repository), applicable project rules, and the docs dir: the one `docs/superpowers` holding every explicit path, else `<project>/docs/superpowers`; paths spread over several docs dirs need the user's decision. With no inputs, scan its `specs/` and `plans/`, show the units found and ask which to include.
2. Docs repository = `git -C <docs-dir> rev-parse --show-toplevel` (resolve from the project when the docs dir does not exist yet); its toplevel is the docs main checkout. If `git -C <project> check-ignore -q <docs-dir>` exits 0 and that toplevel is the project, stop before any window: the docs dir needs its own repository, `cd docs/superpowers && git init`. Require the docs main checkout on its main branch with empty `git status --short`. Every document Git operation (branch, worktree, commit, merge, mark SHA) happens in the docs repository.
3. Select `--agent`, otherwise identify the root's own system from session identity as `auto-cross-refine` does; unknown identity requires clarification. Never infer the agent from executable availability, environment, directory names or model.
4. Check the selected child's actual installed catalogs exactly as `deliver-task` does (Claude: `~/.claude/skills`, enabled `~/.claude/plugins`; Codex: `~/.codex/skills`; plus the project's `.claude/skills` and `.agents/skills`). Resolve readable absolute SKILL.md paths for superpowers `brainstorming` (when a unit needs a spec) and `writing-plans` (when a plan is to be written), `auto-cross-refine`, the opposite launcher (`refine-with-codex` for a Claude child, `refine-with-claude` for Codex) and `review-fix-loop`. Missing ones stop before any window; report them for the user to install, without substitution.
5. Locate the installed `child-sessions/SKILL.md`; read it, its `references/brief-writing.md` and `references/status-file.md`. Call `scripts/child-session` beside it by absolute path, never through PATH; its command/status contract governs every call. `<runtime>` is `${XDG_RUNTIME_DIR:-/tmp}/child-sessions`.

## Units

1. Read [units.md](references/units.md). Map inputs to units, match specs to plans, derive slugs and paths, and classify every existing spec and plan fresh or stale by its freshness rule (a mark's presence proves nothing).
2. Before opening anything, show the unit table: unit, spec, plan, lacks (`spec, plan, review`, `plan, review`, `review of <documents>`, or `nothing: ready`), naming each stale mark and why, plus the windows it implies. Ready units get no window.

## Windows (both phases)

1. One window per spec, name and branch `prep-<slug>`. Worktree: the docs repository's worktree convention, else `<docs-main>/.worktrees/prep-<slug>`; a path inside the docs repository must be ignored by it (`git -C <docs-main> check-ignore -q <path>`), else tell the user and stop without changing ignore rules. Refuse an existing `prep-<slug>` branch, worktree or window, naming it. Record full docs main HEAD as `<base-sha>`; `git -C <docs-main> worktree add -b prep-<slug> <path> <base-sha>`.
2. Brief and status live in `<runtime>`; the status path must not exist. Every document path in a brief is absolute inside that window's worktree (`<worktree>/<path relative to the docs repository>`); predecessor specs are absolute in whichever checkout holds them. Fill every placeholder, following child-sessions' brief checklist.
3. Open with `open --agent <agent> [--model M] [--effort E] prep-<slug> <worktree> <brief>`. Open every window of a phase before its first `wait`.
4. Wait round-robin: cycle through the phase's open windows with `wait prep-<slug> <status> 150` each, one call per window per turn; never a long wait on one window. A Codex tool yield is not a timeout: poll the same command until it exits. Exit `0` → exact first line: `done` per phase below; `blocked` is a root-level problem (missing predecessor, Git): show it, archive the status to `<file>-blocked-<n>`, answer, wait again; `failed` → show it, keep window, worktree and status, record its units `not ready: <reason>`, continue with the others. `124` → next window; peek now and then for a dialog, answer within authority or ask the user. `3` → peek, show, append “Continue from the current state of the checkout: read git log and git status first.” to the retained brief, close, reopen once with the same options; a second silent exit counts as `failed`. Other errors: report, preserve, count as `failed`.
5. A phase ends when every one of its windows has ended `done` or `failed`. A unit the user stops is `not ready: stopped by the user`.

## Phase 1: specs

1. For each unit without a spec (idea, plan without spec): open a window with [spec-brief.md](references/spec-brief.md) at `<runtime>/prep-<slug>-spec-brief.md`, status `<runtime>/prep-<slug>-spec-status.md`.
2. On `done`, confirm the spec at `Spec path:` exists and is listed under Artifacts. The window and its worktree stay open for Phase 2: never merge, remove or close after a Phase 1 `done`.

## Order

1. Once Phase 1 has ended, read every unit's spec where it lives (main checkout or window worktree): title, intent, goals, constraints, not whole long documents; also existing `**Depends on:**` plan headers.
2. Propose a numbered order: unit, depends on, one-line reason. Ask the user to confirm or correct; apply corrections.
3. Write the queue file per [queue-file.md](references/queue-file.md) with the confirmed order and commit it as `queue: <slug>` before Phase 2.

## Phase 2: plans and reviews

1. For every spec with unready units, skipping units whose Phase 1 window failed (they keep `not ready`; that window receives no further brief), fill [plan-brief.md](references/plan-brief.md) at `<runtime>/prep-<slug>-plan-brief.md`, status `<runtime>/prep-<slug>-plan-status.md`: `Spec:`; plans to write on `Plan paths:` in confirmed order; every existing document of the spec's units lacking a fresh mark (by its freshness on the window's branch for Phase 1 specs) on `Documents to review:`, never a fresh one; predecessors and plan headers from the order.
2. A spec with an alive Phase 1 window (`alive prep-<slug>`): `send prep-<slug> "Read the brief at <abs plan-brief> completely and carry it out."`. A Phase 1 window whose agent is gone: `close`, then `open` in the same worktree with the plan brief. Any other spec: new worktree and window. Send or open all before the first `wait`, then wait round-robin.

## Verify and merge

1. Start once every Phase 2 window has ended (a worktree may hold a spec another window reads). Per `done` window, in confirmed order: full status format; BRANCH/CHECKOUT/HEAD match the worktree, its branch and full HEAD; worktree `git status --short` empty; Commits equal `git log --oneline <base-sha>..prep-<slug>`; Review `CLEAN` or `CLEAN EXCEPT DISPUTED`; every Artifacts path of the window's statuses (both phases) exists; every unit's spec and plan is fresh on `prep-<slug>` per units.md. A mismatch goes back to the child for a fresh report; nothing merges before it passes.
2. Immediately before merging require docs main still on its branch and clean, then in the docs main checkout `git merge --no-ff prep-<slug>`. Conflict → `git merge --abort`, report, keep window and worktree, units `not ready: merge conflict`.
3. Convert each of those Artifacts paths to its path relative to the window's worktree root (a path outside it stops with a report) and require `git diff --quiet prep-<slug> HEAD -- <relative paths>` in the docs main checkout. Compare per artifact: whole-tree equality fails once a second branch from the same base is merged.
4. Non-forced `git worktree remove <path>`, `git branch -d prep-<slug>`, then `close prep-<slug>`; a failure is reported, not forced. Each window merges exactly once.

## Queue file

1. Update the queue file per queue-file.md with final states and the ordered `deliver-task` lines; stage only it, commit `queue: <slug>` in the docs repository, and require docs main clean.
2. Report the queue path, the `deliver-task` lines, not-ready units with reasons and their kept windows/worktrees, merge SHAs, and every child's Out of scope lines.
