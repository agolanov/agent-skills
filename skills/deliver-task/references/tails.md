# Tails and follow-up brief

After merge, gather the child's Out of scope plus deferred minor, outside-scope and disputed review findings. Append one line per finding to `<plan-path-without-extension>-tails.md` beside the plan:

```text
- <branch> <merge-sha7>: <what> — <where> — <why>
```

Use the merge commit's seven-character SHA, a concrete `path:line` location, and the scope/deferral reason. For a dispute, preserve both positions and the unresolved question. Preserve prior entries; do not invent a finding for zero tails. Report the count.

The docs repository is the nearest Git root at or above the plan's directory: `git -C <plan-dir> rev-parse --show-toplevel`. It is the project repository when the project tracks the plans, or a nested repository inside a directory the project ignores. Record tails immediately after merge:

1. If the toplevel is the project and `git -C <main-checkout> check-ignore -q <plan-dir>` exits 0, the plans directory is ignored without its own repository: append locally, no commit, no force-add.
2. Otherwise, before staging, the docs repository's `git status --short` may show only this tails file; any other dirt stops rather than joining the commit. Stage only the tails file and commit it in the docs repository, on its current branch, as `tails: <branch>` with the task branch name.
3. With no findings there is no tails commit. Do not put tails on the reviewed child branch. Afterwards require empty `git status --short` in the main checkout and, after a commit, in the docs repository.

Write `${XDG_RUNTIME_DIR:-/tmp}/child-sessions/<branch>-tails-brief.md` outside Git even when there are no tails. Fill this ready follow-up template with absolute paths and actual findings:

```text
Follow up on leftovers from <branch>, merge <full-merge-sha>.

Main checkout: <absolute-main-checkout>
Source plan: <absolute-plan>
Source spec: <absolute-spec>
Project rules: <absolute-rules-paths>
Recorded tails: <absolute-tails-path, or None: no findings>
To prepare through prepare-tasks: prepare-tasks <absolute-tails-path>

Findings:
<one line per finding, including provenance, location, scope reason and both positions for disputes; or None>

Read the source inputs, project rules and findings. Establish current code locations and ask the user to select scope/resolve disputes before implementation. The original delivery did not authorize fixing these leftovers. Prepare a reviewed follow-up spec/plan for selected work; use a fresh branch for separately authorized implementation. Do not alter the completed task branch or assume merge/push/deploy authority. The `To prepare through prepare-tasks:` line is for the user; do not run prepare-tasks in this session.

Original review: <final refine mode and unchanged raw reviewer verdict>
```

The `To prepare through prepare-tasks:` line is present only when there are findings; with none, omit it.

Print the absolute follow-up brief path. The user chooses whether to open it with child-sessions; deliver-task never launches it automatically. With findings, also print the line `To prepare through prepare-tasks: prepare-tasks <absolute-tails-path>`; nothing runs it automatically.
