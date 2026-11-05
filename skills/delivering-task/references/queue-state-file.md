# State file

## Names

- `<runtime>` is the resolved installed child helper's successful `runtime-dir` output, outside Git.
- `<queue-slug>`: for a list, the first input document's stem as given plus `-list` (`2026-10-29-alpha-list`); for a directory, its basename plus `-dir` (`2026-10-29-b1-dir`).

## State file

Path: `<runtime>/<queue-slug>-state.md`. An existing file from an earlier run is read first and its states are taken only when its header is identical to this run's: same form, same documents, same order. Otherwise every unit starts `ready`. Then the old file is renamed to an unused `<file>-old-<n>` suffix and the new file starts fresh. When there is no file (the runtime directory was cleared by a logout or reboot) or the header differs, Git is the durable record: [queue](queue.md) Input 3 finds merged units by their merge subject, and Input 5–6 find leftover branches, worktrees and briefs.

Header: `# list`, or for a directory `# directory <absolute dir>`; then one `# doc: <absolute resolved document>` line per unit in queue order. Then one line per unit in queue order:

```text
<unit> | <state> | <branch> | <window> | <status-file> | <base-sha>
```

- `<state>` is one of the states below. No other spelling.
- `<branch>` and `<window>` exactly as `delivering-task` Preflight 2 derives them; `<status-file>` the absolute status path; `<base-sha>` the full recorded base, rewritten when a main-moved return updates the runtime brief's Base SHA. Use `-` for a field not known yet.
- Rewrite the unit's line at every state change, before acting on the next step. It is the root's only live record.

## States

- `ready`: not started in this run.
- `running`: its start half ran; the child is working.
- `blocked: <question>`: the child asked; the root is answering.
- `done awaiting merge`: verified `done`, waiting for its finish half.
- `rebasing`: returned to the child after main moved; the hold is set.
- `merge held: <paths>`: `delivering-task` Merge stopped on the main checkout's uncommitted changes; the root asks the user to retry or stop; window, worktree, branch and status file are kept.
- `delivered <sha7>`: merged, `<sha7>` the merge commit.
- `done: branch ready`: with `--no-merge`, verified and its End done; its window closed, its worktree, branch and status file kept.
- `failed: <reason>`: a stop, a `failed` status or a merge conflict; worktree, branch and status file are kept.
- `stopped by the user`.
- `not started: depends on failed <unit>`, `not started: depends on stopped <unit>`: a dependency, directly or transitively, failed or was stopped.
- `not started: depends on unmerged <unit>`: with `--no-merge`, the unit depends on `<unit>`, a unit of the run that this run never merges ([queue](queue.md) Scheduling 1).
- `not started: depends on missing <entry>`: the user chose to skip the unit over a `**Depends on:**` entry that is neither in the run nor merged on main (Input 4); its dependents get the same state.

On a rerun with an identical header, `delivered <sha7>` units are done and every other state is a candidate again, its dependencies re-evaluated (Input 2).

Nothing is committed: the state file is the run's only record, and the final report carries the table.
