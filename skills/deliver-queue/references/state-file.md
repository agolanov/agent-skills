# State file and batch points

## Names

- `<runtime>` is `${XDG_RUNTIME_DIR:-/tmp}/child-sessions`, outside Git.
- `<queue-slug>`: the queue file's stem (`2026-10-29-fixture` for `queues/2026-10-29-fixture.md`); for a plain list, the first plan's stem plus `-list`.
- `<slug>`: the queue file's slug as `prepare-tasks` named it, the stem without its `YYYY-MM-DD-` date prefix. It appears only in commit messages.

## State file

Path: `<runtime>/<queue-slug>-state.md`. An existing file from an earlier run is read first (a plain list takes its states from it only when its header names the same absolute plans in the same order; a different header means another input, and every unit starts `ready`), then renamed to an unused `<file>-old-<n>` suffix; the new file starts fresh.

Header: `# <absolute queue file>`, or for a plain list `# plain list` followed by one `# plan: <absolute plan path>` line per plan in order. Then one line per unit in queue order:

```text
<unit> | <state> | <branch> | <window> | <status-file> | <base-sha>
```

- `<state>` comes from the vocabulary in `prepare-tasks/references/queue-file.md`: `ready`, `not ready: <reason>` (kept from preparation), `running`, `done awaiting merge`, `rebasing`, `delivered <sha7>`, `failed: <reason>`, `blocked: <question>`, `not started: depends on failed <unit>`, `not started: depends on not ready <unit>`, `stopped by the user`. No other spelling.
- `<branch>` and `<window>` exactly as `deliver-task` derives them; `<status-file>` the absolute status path; `<base-sha>` the full recorded base, rewritten when a main-moved return updates the runtime brief's Base SHA. Use `-` for a field not known yet.
- Rewrite the unit's line at every state change, before acting on the next step. It is the root's only live record; the queue file is touched only at batch points.

## Batch points

A batch point is the only moment the queue file changes. Exactly three kinds:

1. **(a)** after the first scheduling (units about to start are `running`) and before any worktree is created;
2. **(b)** after a successful merge's Tails and Cleanup and the scheduling that follows, in the same breath as that unit's tails commit, before any newly started unit's worktree is created;
3. **(c)** at the end of the run.

Never at any other moment: a failure, a block, a Verify return, a failed rebase or a freed slot is never a batch point (nothing merged, so nothing is committed). With documents tracked by the project, a commit at such a moment would move main under every open child and force a needless main-moved rebase.

At a batch point:

1. Require the docs main checkout on its main branch with empty `git status --short` (with tracked documents this is the project main checkout).
2. Rewrite only the `State` cell of each queue-file row from the state file, matching rows by `Unit`. Leave every other line unchanged.
3. If the file changed: stage only the queue file and commit it in the docs repository, on its current branch, as `queue: <slug> progress`. No empty commit.
4. Require the docs main checkout clean afterwards.

A plain list has no queue file: its batch points write nothing, and the final report carries the table.
