---
name: deliver-queue
description: "Delivers every ready task of a prepare-tasks queue file (or a list of plans) through deliver-task, running independent tasks in parallel in visible child sessions up to a limit, merging in order of readiness and recording each task's state in the queue file. Use when several reviewed plans are ready and the user wants them all delivered to the main branch without running deliver-task by hand."
---

# Deliver Queue

`deliver-queue <queue-file> [--parallel N] [--agent claude|codex] [--model M] [--effort E]`
`deliver-queue <plan>... [--parallel N] [--agent claude|codex] [--model M] [--effort E]`

The root writes no code. Per-unit work is `deliver-task`'s sections, read from its installed SKILL.md at run time and performed exactly as written, with this queue's `--agent/--model/--effort` passed to every unit. Every brief and message a child receives (implementer brief, main-moved authorization, continuation line, answers) is `deliver-task`'s or `child-sessions`' exact text, never a paraphrase. This skill only decides when each unit starts, waits and merges, and records states. `--parallel N` (default 3) bounds live windows (Scheduling 3).

## Input

1. Queue file: rows give unit, order `#`, `Depends on`, plan, spec and `State` (format and state vocabulary: `prepare-tasks/references/queue-file.md`). Plain list: one unit per plan, named by its full stem (`2026-10-29-alpha`), spec `<plan-stem>-design.md` beside it, each depending on the previous plan unless the user says they are independent. In both forms branch and window are exactly what `deliver-task` Preflight 2 derives from the plan: no `--branch` override, no shortened names.
2. Normalize states: `delivered <sha7>` is done; `not ready: <reason>` is skipped and reported; every other state is a candidate again, its dependencies re-evaluated against delivered units. A plain list takes states from an earlier run's state file only when its header lists the same absolute plans in the same order (state-file.md), else every unit is `ready`.
3. Before any batch point or window, list the candidates with a `not ready` dependency and ask the user once, for each: run it as independent (drop that dependency), or skip it as `not started: depends on not ready <unit>`; units depending on a skipped one get the same state. The user decides; never choose for them.
4. Once Preflight 1–3 are done (before Preflight 4), for each candidate whose branch, worktree (`git worktree list`) or window (`child-session list`) exists under the names `deliver-task` derives, prove ownership as `deliver-task --resume` does: `<runtime>/<branch>-brief.md` (`<runtime>` = `${XDG_RUNTIME_DIR:-/tmp}/child-sessions`) exists and names this plan and spec; its Branch and Checkout match the registered worktree and branch; a live window with its recorded name lists the brief's checkout. No window is normal after a failure. A missing brief or any mismatch stops the whole run before any batch point or window: report it, close and delete nothing (`close` and `git branch -D` act by name); the user resolves it and reruns.
5. Only then show each proven unit's leftovers and last status and ask once per unit: resume through `deliver-task --resume` (recommended when the status reported commits), or discard: `close` the window if live, `git worktree remove --force <path>`, `git branch -D <branch>`, rename the old brief and status to unused `<file>-old-<n>` suffixes, then start fresh. A candidate with only an old brief or status and no branch, worktree or window: rename those the same way.

## Preflight

1. Project main checkout (the queue's `Project checkout:`, else the top level of the current repository as `prepare-tasks` Preflight 1 resolves it; when that is a separate docs repository rather than the project, ask the user for the project checkout) on its main branch with empty `git status --short`. Docs repository by `prepare-tasks` Preflight 2; both layouts are allowed (documents tracked by the project, or a separate docs repository). A queue file must live in it and match its `Docs repository:` line. Require docs main on its main branch and clean.
2. Locate the installed `deliver-task/SKILL.md` and its references, `child-sessions/SKILL.md` with its references and `scripts/child-session` (absolute path, never PATH), and `prepare-tasks`; read them completely.
3. Select the agent as `deliver-task` Preflight 2 does. Run `deliver-task` Preflight 3–4 (child-sessions and the child's dependency check) once for that agent; missing dependencies stop before anything opens.
4. Create the runtime state file per [state-file.md](references/state-file.md) with every unit and its normalized state.

## Scheduling

Runs at the start, after each merge, and whenever a slot frees.

1. Startable: a candidate not yet started whose dependencies are all `delivered`.
2. Read [overlap.md](references/overlap.md). Hold back a startable unit that overlaps a unit with a live window or an earlier unit chosen in the same pass; it waits until that window is gone, normally after its merge.
3. Live windows: `running`, `blocked`, `rebasing` and `done awaiting merge` (its agent stays alive for a possible main-moved return until Cleanup), plus a `failed` window until `close` and `alive` returning 1, and a delivered unit's window whose Cleanup `close` failed, while `alive` (rechecked at each Scheduling) returns 0. Choose startable units in queue order until live windows reach `--parallel`.
4. Mark the chosen units `running` in the state file. At the start and after a merge, the batch point comes next; after a freed slot, go straight to the start half.

## Start half

For each chosen unit in queue order, perform `deliver-task` Preflight 1–2, Worktree, Brief and Open and wait 1 (open), exactly as written; a resumed unit takes its `--resume` path. The Wait loop below replaces Open and wait 2. Record branch, window, status file and base SHA in the state file. A stop inside the start half makes the unit `failed: <reason>` (Wait loop 4).

## Batch point

Write the queue file's `State` column from the state file and commit `queue: <slug> progress` per state-file.md, only: (a) after the first scheduling, before any worktree is created; (b) after a merge's Tails and Cleanup and the next scheduling, before any new worktree; (c) at End. A failure, a block, a Verify return or a failed rebase is never a batch point. Because (a) and every (b) precede the next Worktree step, each new child starts from a main that already holds the queue commit: with documents tracked by the project, no child is ever moved past by a documentation-only commit.

## Wait loop

1. Round-robin over windows whose agent is working (`running`, `rebasing`, a `blocked` window after its answer): one foreground `wait <name> <status-file> 150` per window per turn, then the next window, with the host's command timeout set above the wait (180 s or more) so the host can never move it to the background; a wait still running beside other commands is not the loop. Never 120 or less, never several waits in one shell call or in the background, never one long wait on a single window. A Codex tool yield is not a timeout: poll the same command as child-sessions says. `done awaiting merge` windows are not waited on again.
2. Exit 0: read the first status line of every working window. Each `done` of a `running` unit becomes `done awaiting merge`; a `rebasing` unit keeps its state until its finish half ends. Then go to Finish half, or back to the loop when the hold allows none.
3. `blocked`: state `blocked: <question>`; answer it per `deliver-task` Open and wait 3; back to its previous state (`running` or `rebasing`). A hold set on the unit persists throughout. Other windows keep going.
4. `failed`, unlike `deliver-task`'s stop, because an interactive agent stays alive after writing `failed` and would hold a slot: state `failed: <reason>` in the state file only, `peek <name> 40` for the report, `close <name>`, free the slot only once `alive <name>` returns 1. Keep worktree, branch and status file. Its dependents, transitively, become `not started: depends on failed <unit>`; other units continue; run Scheduling, then drain (Finish half 2). A unit the user stops is `stopped by the user`, handled the same way.
5. Exit 124: next window; `peek` now and then for a dialog, answer within authority or ask the user. Exit 3: `deliver-task` Open and wait 4's single reopen; a second silent exit or any other error counts as `failed`.

## Finish half

1. One finish half at a time. Pick, among `done awaiting merge` units, the one whose status file has the earliest modification time, not the window whose wait returned. The hold: from a main-moved return (step 4) until that unit is `delivered`, `failed` or `stopped by the user`, through any block or Verify return, the only finish half allowed is that unit's, once its fresh status says `done`.
2. Drain: whenever a finish half is allowed (after a Wait loop exit 0, a delivery, a failure or stop, a Verify return), run it at once; the Wait loop runs only while none is allowed.
3. Perform `deliver-task` Verify, Merge, Tails and Cleanup exactly as written.
4. Merge returns the child for main-moved: state `rebasing`, base SHA updated as `deliver-task` records it, back to the Wait loop with the hold set. Fresh `done`: this unit resumes at Verify. `failed`: Wait loop 4, which releases the hold with no batch point; drain.
5. Verify or a disputed-findings decision returns the unit to its child: a `rebasing` unit stays `rebasing` and keeps the hold, any other becomes `running` (nothing merged, no hold); drain.
6. Merged and cleaned up: `delivered <sha7>` with tails count and follow-up brief path (a Cleanup failure is reported; the unit is still delivered, and a window left alive keeps its slot per Scheduling 3); Scheduling; batch point (b); start halves; drain.
7. A stop before the merge commit is `failed: <reason>` (conflict) or `stopped by the user`, both per Wait loop 4. A stop after it (tree inequality, failed required post-merge check) leaves main suspect: record `failed: <reason>`, start and merge nothing more, go to End leaving other windows as they are.

## End

When no window is working or awaiting merge and nothing is startable: batch point (c), then report a table `unit | state | merge SHA | tails count | follow-up brief path`, then every unit never started with its reason, and the kept worktree, branch and status file of each failed unit.
