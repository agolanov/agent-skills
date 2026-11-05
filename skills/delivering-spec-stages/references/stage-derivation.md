Display copy of `delivering-task/SKILL.md` Preflight 2 (the branch and window naming), Worktree 1 (the worktree path) and Worktree 3 (the removed-skill brief stop), and of `delivering-task/references/queue.md` Input 3 (the merged-subject search and the leftovers list) and Input 5–6; keep equal.

# Stage derivation

## Branch and window

Default branch to the task document's stem (the plan's stem for a plan or a spec resolved to its plan); validate with `git check-ref-format --branch`, asking for a valid override if invalid (under `--auto`, routed by [auto.md](../../child-sessions/references/auto.md#deciding)). Use window `<name> = impl-<branch>` for `[A-Za-z0-9_-]+` branches; otherwise replace disallowed branch characters with `-` and use `impl-<slug>-<hash8>` (first eight SHA-256 hex characters of the full branch name). Record the unique name; never alias slash/dot branches by slug alone.

## Worktree

Use the project worktree convention, otherwise `<main-checkout>/.worktrees/<branch>`.

For `--resume`, require the prior runtime brief whose identity block carries `Written by: delivering-task`. Any other brief stops before reopening, naming it: “brief written by a removed skill; finish that run with the catalog that started it, or remove its branch, worktree and runtime files by hand”.

## Merged

Already merged: after Preflight 1–3 and before step 4's question, for each candidate take `<branch>` as step 1 says and search the first-parent history of the project main checkout's main branch (`git log --first-parent --merges --format='%H%x09%cs%x09%s' <main>`, merge commits only) for a subject equal, as a whole fixed string, to `Merge branch '<branch>'` or `Merge branch '<branch>' into <main>`; the most recent match counts.

List its leftovers without acting on them: a worktree or branch under its name (Cleanup not done), a live window with its name (`child-session list`); finishing them is the user's call.

## Leftovers

5. Once Preflight 1–3 are done (before Preflight 4), for each candidate whose branch, worktree (`git worktree list --porcelain -z`) or window (`child-session list`) exists under the names `delivering-task` derives, prove ownership as `delivering-task --resume` does: `<runtime>/<branch>-brief.md` (`<runtime>` comes from `child-session runtime-dir`) exists and names this task document and its spec; its Branch and Checkout match the registered worktree and branch; a live window with its recorded name lists the brief's checkout. No window is normal after a failure. A candidate with only an old brief or status and no branch, worktree or window is proven only when the brief names this task document and its spec and its Checkout is the path `delivering-task` Worktree 1 derives for this branch in this project (no brief: the status's CHECKOUT must be that path); runtime names are shared by every project, so anything else is another task's artifact. A missing brief where a branch, worktree or window exists, a brief there that lacks the `Written by: delivering-task` line (shown with `delivering-task` Worktree 3's message for such a brief), or any mismatch, stops the whole run before any window and before step 6 asks anything: report it, close, delete and rename nothing (branch deletion acts by name; child controls require the matching launch record); the user resolves it and reruns.
6. Only then show each proven unit's leftovers and last status and ask once per unit: resume through the `--resume` path of `delivering-task`, or discard: `close` the window if live, `git worktree remove --force <path>`, `git branch -D <branch>`, archive the old brief and status, then start fresh. Recommend resume when the status reported commits, and discard for a unit that step 3 found merged and the user chose to deliver again, since its branch is already on main. Under `--auto` the question reaches the user whenever discard is [hard to undo](../../child-sessions/references/auto.md#hard-to-undo), whatever the recommendation: `git log --oneline <main>..<branch>` prints a commit, or the worktree has uncommitted changes; otherwise it is routed by [auto.md](../../child-sessions/references/auto.md#deciding). A proven candidate with only an old brief or status cannot resume: show each file's path and the status's first line and Commits, or `no status file`, then archive them without a question. To archive, rename a file to its full name plus `-old-<n>`, `n` the smallest number whose name is unused (`2026-10-29-beta-status.md` → `2026-10-29-beta-status.md-old-1`), never replacing an existing file.
