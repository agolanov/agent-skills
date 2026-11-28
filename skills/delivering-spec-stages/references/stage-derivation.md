# Stage derivation

## Branch and window

Use delivery's [branch and window names](../../delivering-task/references/task-names.md#branch-and-window).

## Worktree

Use delivery's [worktree path](../../delivering-task/references/task-names.md#worktree-path). For an older brief without the delivery writer identity use the [resume refusal](../../delivering-task/references/resume.md).

## Merged

Use [delivery merge history](../../delivering-task/references/merge-history.md). Scan once for all candidate branches in a listing, then derive again from current main when acting on a stage or checking delivered stages after refinement.

Report a merged stage's leftover branch, worktree or live window. Leave those artifacts for the user.

## Leftovers

5. Once Preflight 1–3 are done (before Preflight 4), for each candidate whose branch, worktree (`git worktree list --porcelain -z`) or window (`child-session list`) exists under the names `delivering-task` derives, prove ownership as `delivering-task --resume` does: `<runtime>/<branch>-brief.md` (`<runtime>` comes from `child-session runtime-dir`) exists and names this task document and its spec; its Branch and Checkout match the registered worktree and branch; a live window with its recorded name lists the brief's checkout. No window is normal after a failure. A candidate with only an old brief or status and no branch, worktree or window is proven only when the brief names this task document and its spec and its Checkout is the path `delivering-task` Worktree 1 derives for this branch in this project (no brief: the status's CHECKOUT must be that path); runtime names are shared by every project, so anything else is another task's artifact. A missing brief where a branch, worktree or window exists, a brief there that lacks the `Written by: delivering-task` line (shown with `delivering-task` Worktree 3's message for such a brief), or any mismatch, stops the whole run before any window and before step 6 asks anything: report it, close, delete and rename nothing (branch deletion acts by name; child controls require the matching launch record); the user resolves it and reruns.
6. Only then show each proven unit's leftovers and last status and ask once per unit: resume through the `--resume` path of `delivering-task`, or discard: `close` the window if live, `git worktree remove --force <path>`, `git branch -D <branch>`, archive the old brief and status, then start fresh. Recommend resume when the status reported commits, and discard for a unit that step 3 found merged and the user chose to deliver again, since its branch is already on main. Under `--auto` the question reaches the user whenever discard is [hard to undo](../../child-sessions/references/auto.md#hard-to-undo), whatever the recommendation: `git log --oneline <main>..<branch>` prints a commit, or `git -C <path> status --porcelain=v1 --untracked-files=all --ignored` prints any entry (uncommitted changes, untracked files or ignored files, all of which `--force` deletes), or either command fails, since unavailable evidence proves nothing safe; otherwise it is routed by [auto.md](../../child-sessions/references/auto.md#deciding). A proven candidate with only an old brief or status cannot resume: show each file's path and the status's first line and Commits, or `no status file`, then archive them without a question. To archive, rename a file to its full name plus `-old-<n>`, `n` the smallest number whose name is unused (`2026-10-29-beta-status.md` → `2026-10-29-beta-status.md-old-1`), never replacing an existing file.
