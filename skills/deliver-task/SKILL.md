---
name: deliver-task
description: Takes one reviewed spec and plan from a fresh worktree through a visible child agent session and cross review to a merge into the main branch, then records leftovers. Use when a plan is ready to implement and the user wants it executed, reviewed and merged without writing code in the current session.
---

# Deliver Task

`deliver-task <plan> [--spec <spec>] [--agent claude|codex] [--model M] [--effort E] [--branch B] [--resume]`

The child owns implementation and refinement. The root checks Git/status facts, integrates, and records tails; it does not write product code, add commits to the task branch, or repeat the child's tests or review.

## Preflight

1. Resolve the main checkout, main branch, absolute plan/spec paths, and applicable project rules. Read the reviewed inputs; default spec to `<plan-stem>-design.md` beside the plan, asking if absent. Require the main checkout on its main branch with empty `git status --short`.
2. Select `--agent`, otherwise identify the root's own system from session identity as `auto-cross-refine` does; unknown identity requires clarification. For `--resume`, recover recorded launch identity subject to the provenance checks below; conflicting explicit overrides stop. Never infer the agent from executable availability, environment, directory names, or model. Default branch to `<plan-stem>`; validate with `git check-ref-format --branch`, asking for a valid override if invalid. Use window `<name> = impl-<branch>` for `[A-Za-z0-9_-]+` branches; otherwise replace disallowed branch characters with `-` and use `impl-<slug>-<hash8>` (first eight SHA-256 hex characters of the full branch name). Record the unique name; never alias slash/dot branches by slug alone.
3. Locate root's installed `child-sessions/SKILL.md`; read it and its owned `references/brief-writing.md` and `references/status-file.md`. Resolve its executable relative to that SKILL.md as `scripts/child-session`, never through PATH. Its command/status contract governs every call below.
4. Check the selected child's actual installed catalog/directories: Claude's `~/.claude/skills`, enabled `~/.claude/plugins`; Codex's `~/.codex/skills`, `~/.agents/skills`, enabled `~/.codex/plugins`; plus project `.claude/skills` and `.agents/skills` available to that child. Resolve readable absolute paths for `auto-cross-refine`, the opposite-system launcher (`refine-with-codex` for Claude, `refine-with-claude` for Codex), `review-fix-loop`, and at least one of `executing-plans`/`subagent-driven-development`. Verify checkout-local paths remain available in the worktree. Executables or the root's catalog alone do not prove child skill availability. Missing dependencies stop before opening; report them for the user to install, without substitution.

## Worktree

1. Use the project worktree convention, otherwise `<main-checkout>/.worktrees/<branch>`. Resolve the main checkout and selected path, including existing symlinks. For a path inside the main checkout, run `git check-ignore`; if it is not ignored, tell the user and stop without changing ignore rules. For an external path, apply the same ownership/existence checks without an ignore prerequisite. Refuse any existing branch or worktree, naming both, unless `--resume`.
2. For a new task record full main HEAD as `<base-sha>` and run `git worktree add -b <branch> <path> <base-sha>`. Verify its branch and HEAD match. Keep runtime files under `${XDG_RUNTIME_DIR:-/tmp}/child-sessions/` outside Git, creating parent directories for nested branch names.
3. For `--resume`, require the prior runtime brief with base, absolute plan/spec task identity, branch, checkout, window name and launch options. Match it to the requested task and registered Git worktree/branch; validate the recorded base exists and belongs to the task history. Reuse the recorded base/window identity, never today's main as a guessed replacement. Missing, conflicting or ambiguous provenance stops. Preserve current work for the child, archive any prior status to an unused suffix, and append the continuation instruction from child-sessions. An old terminal report cannot complete a resumed run.

## Brief

1. Read [implementer-brief.md](references/implementer-brief.md), fill every placeholder, including `Delivery mode:` from the spec's header per implementer-brief.md's rules, and write `<runtime>/<branch>-brief.md`; status is `<runtime>/<branch>-status.md`. Persist task identity/base and selected launch options for resume. Resolve required skill paths for the child's actual checkout/catalog, and provide the absolute owned status-contract path. Fill Layout facts: docs repository is `git -C <plan-dir> rev-parse --show-toplevel` (see Tails), named by its main-checkout absolute path even when it is the project itself; ignored test material is the test path the project rules state, else `tests/`, resolved against the main checkout to an absolute path; use it when it exists and `git -C <main-checkout> check-ignore -q <path>` exits 0, otherwise `None`. A stated path that fails either check is `None`, never replaced by `tests/`; before opening, tell the user which path failed which check. Follow child-sessions' self-contained brief checklist.
2. Keep the exact `Status file: <status-file>` line. A new task requires an absent status path; an existing artifact needs provenance validation or a stop, not silent reuse. Only the child writes status contents.

## Open and wait

1. Call the resolved script: `open --agent <agent> [--model M] [--effort E] <name> <path> <brief>`, quoting paths. On explicit resume reuse the recorded window/options and continuation brief; close any owned stale window before reopening, never an unrelated session.
2. Follow child-sessions' foreground loop: `wait <name> <status-file> 240` on Codex, `540` on Claude. A Codex tool yield is not timeout: poll the same returned foreground session in intervals at most 60 seconds until it exits. Repeated fresh 20-second waits reset silent-exit grace and are invalid.
3. On exit `0`, read the exact first status line. `done` proceeds to Verify; `blocked` shows Questions/options/recommendation, obtains the user's answer, archives to `<file>-blocked-<n>`, sends one line or an absolute answer-file instruction, then waits for fresh status. `failed` shows the failure and stops, preserving window/worktree/status.
4. Exit `3`: `peek <name> 40`, show diagnostics, append “Continue from the current state of the checkout: read git log and git status first.” to the retained brief, close the stale window if present and reopen once with the same options. Second silent exit stops. Exit `124`: `peek <name> 40`; wait again for work in progress, or handle a dialog per child-sessions Dialogs. Other errors stop with artifacts preserved.

## Verify

1. Require the full owned status format. Match BRANCH/CHECKOUT/HEAD to the registered task worktree, its current branch and full HEAD; validate recorded base ancestry. Require empty `git status --short` and exact `git log --oneline <base>..<branch>` agreement with Commits. Any mismatch stops integration; return it to the child for a fresh report, preserving evidence.
2. Read Checks, Review and Out of scope. Require successful required checks and final refine mode `CLEAN` or `CLEAN EXCEPT DISPUTED`. Preserve the separate raw reviewer verdict: dispute-only closure can retain raw `CHANGES` under review-fix-loop; never relabel it CLEAN. Missing completion evidence goes back to the child, without root re-review.
3. For `CLEAN EXCEPT DISPUTED`, show disputed findings and both positions; ask the user whether to merge, return to the child, or stop. Accept merge only after that decision; retain all deferred/outside-scope findings for tails.

## Merge

1. Immediately before merging, require main still on its branch and clean, and compare full main HEAD to recorded base. If changed, archive status, retain the prior brief and append the new target plus this one-time authorization: “main moved to <sha>: rebase onto it, rerun the checks and one fix-review round, write a new status”. Tell the child to use `<sha>` as its reporting/review base. Send to the same child (reopen with continuation only if necessary), wait, verify a fresh report against that target, then update the recorded Base SHA in the runtime brief. Repeat Verify and this latest-main check; no stale status or merge before refresh.
2. In the main checkout run `git merge --no-ff <branch>` with Git's default message: no `-m`, no `-F`, no edited message (`deliver-queue` Input 3 finds merged units by the subject `Merge branch '<branch>'`). On conflict run `git merge --abort`, report and preserve the child/worktree. Capture the merge SHA, then explicitly compare `git rev-parse HEAD^{tree}` with `git rev-parse <branch>^{tree}`. Inequality stops cleanup. Run checks again only when project rules explicitly require them after merge; ordinary “after changing code” requirements are satisfied by the child's verified results. Post-merge check failures stop with evidence preserved.

## Tails

1. Read [tails.md](references/tails.md). Immediately after the verified merge append every out-of-scope, deferred minor and disputed finding beside the plan in `<plan-stem>-tails.md`, with branch and merge-SHA provenance. Keep the reviewed task branch unchanged.
2. Find the docs repository with `git -C <plan-dir> rev-parse --show-toplevel`: the project repository or a nested one inside an ignored directory. If the toplevel is the project and `git -C <main-checkout> check-ignore -q <plan-dir>` exits 0, append locally: no commit, no force-add. Otherwise stage only the tails file and commit it in the docs repository, on its current branch, as `tails: <branch>`. No empty commit for zero findings. Require the main checkout clean and, after a commit, the docs repository too, then write the ready `<runtime>/<branch>-tails-brief.md` and print its absolute path. Opening a follow-up is the user's call; do not auto-open it.

## Cleanup

1. After tree equality, required post-merge checks and tails recording succeed, run non-forced `git worktree remove <path>`, `git branch -d <branch>`, then `child-session close <name>` using the resolved executable and recorded window name. A failure is reported, not forced away.
2. Report merge SHA, child commits, tails count/commit if any, follow-up brief path and required post-merge check results, and an unknown `**Delivery mode:**` value carried as `full`, with the spec path and the raw value. Root writes only runtime artifacts and the docs repository's tails record; one task yields one merge. When the tails count is above zero, also print `To prepare through prepare-tasks: prepare-tasks <absolute-tails-path>`.
