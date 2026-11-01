---
name: delivering-task
description: Takes one task document from implementation in a visible child agent session through cross review to a merge into the main branch and cleanup, recording follow-ups. Use when a task is ready to implement and the user wants it executed, reviewed and merged without writing code in the current session.
---

# Delivering Task

For every checkout cleanliness or changed-path gate below and in child briefs/references, use [checkout-state Direct-use preflight](../independent-review/references/checkout-state.md#direct-use-preflight). Resolve its installed helper, retain fresh evidence, and require `uncommitted: false` for clean. Unavailable verification stops the dependent action; raw status/diff is not a fallback. Path allowlists use the result's decoded exact `paths`. This applies separately to project, docs and child checkouts. Every read-only Git verification below and in references/child briefs (log, refs, roots, ancestry and diffs included) uses that reference's `git-read` command; displayed `git <read-command>` notation means this wrapper, never a raw invocation. Resolve paths relative to the containing checkout root. Mutating commands keep their explicit authorization.


`delivering-task <task-document> [--spec <spec>] [--agent claude|codex] [--model M] [--effort E] [--branch B] [--resume]`

Two halves: Execute, then Merge and Cleanup. Standalone they run in sequence; `delivering-task-queue` decides when each half runs. The child owns implementation, refinement and, in the tracked layout, its follow-ups commit. The root checks Git/status facts and integrates; it does not write product code, add commits to the task branch, or repeat the child's tests or review. Follow-ups are written only by `executing-task-docs` End; the merge half carries them to main with the branch.

## Execute

Locate the root's installed `executing-task-docs/SKILL.md`, read it and its references completely, and perform it exactly as written with this run's task document and options, through its End. A refusal, a stop or a `failed` status ends the run here, with nothing merged.

## Merge

1. Immediately before merging, require main still on its branch and clean, and compare full main HEAD to recorded base. If changed, archive status, retain the prior brief and append the new target plus this one-time authorization: “main moved to <sha>: rebase onto it, rerun the checks and one fix-review round, write a new status”. Tell the child to use `<sha>` as its reporting/review base. Send that sentence word for word, with `<sha>` filled in, to the same child through `executing-task-docs` Open and wait 5: a dead child gets that step's reopen with the authorization as the line to send, counted against the same run. Then wait, verify a fresh report against that target, then update the recorded Base SHA in the runtime brief. Perform `executing-task-docs` Verify and End again, then repeat this latest-main check; no stale status or merge before refresh.
2. In the main checkout run `git merge --no-ff <branch>` with Git's default message: no `-m`, no `-F`, no edited message (`delivering-task-queue` Input 3 finds merged units by the subject `Merge branch '<branch>'`). On conflict run `git merge --abort`, report and preserve the child/worktree. Capture the merge SHA, then explicitly compare `git rev-parse HEAD^{tree}` with `git rev-parse <branch>^{tree}`. Inequality stops cleanup. Run checks again only when project rules explicitly require them after merge; ordinary “after changing code” requirements are satisfied by the child's verified results. Post-merge check failures stop with evidence preserved.

## Cleanup

1. After tree equality and required post-merge checks succeed, run non-forced `git worktree remove <path>`, `git branch -d <branch>`, then `child-session close <name>` using the resolved executable and recorded window name. A failure is reported, not forced away.
2. Report merge SHA, child commits, follow-ups path and count (with its commit, or where it was written locally), and required post-merge check results. Root writes only runtime artifacts and what `executing-task-docs` End records; one task yields one merge.
