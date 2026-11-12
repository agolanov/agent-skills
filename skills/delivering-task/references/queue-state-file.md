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
- `done awaiting merge`: verified `done`, waiting for its finish half; with `--no-merge` that finish half merges nothing and ends `done: branch ready`.
- `rebasing`: returned to the child by `delivering-task` Merge 1, after main moved or for its merge-candidate checks; the hold is set.
- `merge held: <paths>`: `delivering-task` Merge stopped on the main checkout's uncommitted changes; the root asks the user to retry or stop ([queue](queue.md) Finish half 7, which says how `--auto` answers); window, worktree, branch and status file are kept.
- `delivered <sha7>`: merged, `<sha7>` the merge commit.
- `done: branch ready`: with `--no-merge`, verified and its End done; its window closed, its worktree, branch and status file kept.
- `failed: <reason>`: a stop, a `failed` status or a merge conflict; worktree, branch and status file are kept.
- `stopped by the user`: the user stopped the unit, or under `--auto` the session that answered for them, as its `## Decisions` line records.
- `not started: depends on failed <unit>`, `not started: depends on stopped <unit>`: a dependency, directly or transitively, failed or was stopped.
- `not started: depends on unmerged <unit>`: with `--no-merge`, the unit depends on `<unit>`, a unit of the run that this run never merges ([queue](queue.md) Input 3, No merge hold).
- `not started: depends on missing <entry>`: the user (under `--auto`, the session that answered for them) chose to skip the unit over a `**Depends on:**` entry that is neither in the run nor merged on main (Input 4); its dependents get the same state.

On a rerun with an identical header, `delivered <sha7>` units are done and every other state is a candidate again, its dependencies re-evaluated (Input 2).

Nothing is committed: the state file is the run's only record, and the final report carries the table.


## Queue record

Only queue phase agents write `<runtime>/<queue-slug>-handoff.md`, atomically, in the [handoff format](../../child-sessions/references/handoff-record.md#format) with these readings: `Run: <queue-slug>`; `Worker brief: None`; `Status file: None`; Place is the run's place; Checkout is the project main checkout. Reopen and Return to worker stay `unused` (each unit's record counts its own). Openings holds `None`. Waiting holds one `Launch:` line per unit whose agent is working, then the action; a recipe appears only in a one-at-a-time place. A queue performed by one root writes no queue record.

Facts holds exactly these labelled lines, one Unit per unit in queue order:

```text
State file: <absolute path>
Agent: <claude|codex>
Parallel: <N>
Merge: <merge|no-merge>
Hold: <None|unit>
Drain end: <none|pending>
Unit: <unit> | depends on: <units, comma-separated|none> | mode: <mode> (<rule|explicit|recorded>); <reason> | settings: <model M (source), effort E (source)|recorded> | result: <-|merged <sha7>; follow-ups <path|-> <count|->|branch ready; follow-ups <path|-> <count|->>
```

Report carries retains Preflight 4's count lines and what Input 3 listed. Decisions and Told the user work as in every handoff record. Hold and Drain end retain the hold and the pending drain end of queue Finish half across agents; each result cell retains the unit's final report data for End.

**Authority.** For this queue record use these checks in place of the per-worker record's checks: its units and order equal the state file's header; a unit it or the state file calls merged has that merge on main (queue Input 3's search); a started unit has its registered worktree and branch, or the branch it kept. Apply each unit's own record checks when acting on that unit. A disagreement stops, naming both values and retaining the files. Merge authority comes from the phase brief alone; neither this record nor the state file grants it.
