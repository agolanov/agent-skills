# Implementer brief

Fill this template with absolute resolved paths before opening. Keep the identity labels for resume and the fixed `Status file:` line; `Written by:`, `Execution mode:`, `Launch settings:`, `Reviewer settings:` and `Reviewer run:` are identity labels kept for resume. `Written by: delivering-task` is fixed text, the first line of the identity block; `--resume` accepts only a brief that carries it (Worktree 3). The root appends one `Opened: <UTC time, ISO 8601 to the second>` line at the end before each `open`; those lines are the root's record and need no action from the child. `<absolute launch-settings.md>` is the installed independent-review `references/launch-settings.md`. Project rules list absolute applicable AGENTS.md/CLAUDE.md paths plus any required verbatim rules. Fill the `Execution mode:` line with the mode, its source and its reason as Preflight 2 decided them per [Execution mode](../SKILL.md#execution-mode), and the Execution line, for a plan, with the absolute SKILL.md of the one skill that mode names (`executing-plans` for `inline`, `subagent-driven-development` for `subagents`, as Preflight 4 found it), or `None: direct implementation` for any other task document. Fill the Follow-ups line with its first form in the tracked layout (the follow-ups path inside this worktree and the absolute path of this skill's installed [follow-ups.md](follow-ups.md)), else with `the root records them`. Replace every placeholder, including the owned status-contract path; the child has no parent conversation or loaded skills.

```text
Implement one task document in this checkout.

Written by: delivering-task
Checkout: <checkout>
Branch: <branch>
Base SHA: <base-sha>
Task document: <document>
Plan kind: <plan|other>
Execution mode: <inline | subagents | direct> (<rule | explicit>); <reason, one sentence>
Spec: <spec or None>
Agent: <agent>
Terminal controls: not part of this brief; the root reads them from each launch of this window after it opens and may be unable to see or answer this window, so a question or dialog shown here can wait for the user to answer it directly.
Window name: <name>
Launch settings: model <exact | cli-default> (<policy | explicit | cli-default>), effort <exact | cli-default> (<policy | explicit | cli-default>); resolved <YYYY-MM-DD> from <discovery evidence, one phrase>
Reviewer settings: <reviewer policy | model <M> (explicit) and/or effort <E> (explicit), the rest by reviewer policy>
Reviewer run: <background|subagent|window> (<default | explicit>)
Git checks: <absolute installed independent-review/references/checkout-state.md>. Read it for each clean/path gate and continuation: verify checkout/branch/HEAD, record the four ordinary Git commands with actual exits/raw outputs, and compare exact repository-relative paths. Use ordinary Git for other read-only checks with GIT_OPTIONAL_LOCKS=0. Failed evidence blocks. Carry its ignored/untracked-content, Git flags/normalization, nested-repository and transient-write limits; the legacy Python helper is optional.

Ownership: you are the only implementation writer in this checkout. The root owns integration, cleanup and any follow-ups the Follow-ups line leaves to it.

Layout facts (gitignored material is not in this worktree):
Docs repository: <abs docs main checkout> (task documents live here; read-only except inside the Ignored test material path below; never commit there)
Ignored test material: <abs path or None>
Follow-ups: <commit them on this branch at <abs path in this worktree> through <abs delivering-task/references/follow-ups.md> | the root records them>
Edit ignored material by absolute path in the main checkout; commit only files inside this worktree.

Read the task document and the spec completely. Read and honor all applicable project rules: <project-rules>.

Required installed skills (read these absolute SKILL.md paths):
- Execution: <absolute SKILL.md of the skill the Execution mode line names | None: direct implementation>
- Review loop: <absolute review-fix-loop SKILL.md>
- Reviewer launch: <absolute independent-review SKILL.md>

The root decided the execution mode; you make no choice of execution skill. For Plan kind plan, execute the entire plan with the skill on the Execution line in this existing isolated worktree, and never switch to another execution skill. For Plan kind other, implement the task directly from the task document in this existing isolated worktree. Either way, write `Execution mode: <mode> — <skill | direct: not a plan>; <reason from the brief>` as the first line under Checks in the status file. Never create a task document: no spec, plan or brief. Run the required checks below and commit task changes on this branch. Every commit message ends with its own content, unsigned: no `Co-Authored-By` trailer and no "Generated with" line, even when your harness asks for one; give this rule to every subagent that commits. Keep only task implementation, review-fix and follow-ups commits here.

Launch settings govern only this session; subagents an execution skill starts follow that skill and the host (see `<absolute launch-settings.md>`, section Nested agents).

When the spec has a `## Verification` section, run exactly the checks it names, no fewer. A further check is allowed only with its reason written under Checks in the status file. A named check that cannot run (an absent suite, a missing validator) is reported unavailable, never recreated or replaced by another check. That section takes precedence over any loaded skill's rule to test more: follow such a skill for how to run a check, not for how many to run. Without such a section, run the checks the task document and the project rules require.

After the task is complete and all checks pass, invoke `review-fix-loop` with `--reviewer-run` set to the place on the Reviewer run line and the Reviewer settings' explicit values as `--reviewer-model`/`--reviewer-effort` (none with `reviewer policy`), and run it until it ends `clean` or `clean except disputed`. Do not squash. This final `review-fix-loop` replaces the execution skill's own final review of the whole implementation; per-task reviews inside the execution skill stay at its discretion. In Review, name the full SHA of the last commit the review covered as `Reviewed HEAD: <sha>`.

Work only inside this checkout, except the ignored-material paths named under Layout facts, which you may edit in the main checkout; never write anything else there and never commit there. Do not merge, push, rebase, touch the main checkout beyond those Layout-facts paths, delete the branch/worktree, or fix out-of-scope findings. A later explicit main-moved message may authorize one rebase onto its named SHA, checks and one fix-review round; until then the rebase prohibition holds. That message also changes the reporting/review base for the fresh result.

Record each out-of-scope finding as: what — where (path:line) — why it is out of scope. Continue unless completing the task requires a user decision. Retain deferred minor/outside-scope/disputed review findings. In Review, report final refine mode separately from the raw reviewer verdict; a permitted clean except disputed closure may keep raw CHANGES. Never rename that raw verdict CLEAN. Include disputed findings, both positions and the fix-or-dismiss question.

Follow-ups are the Out of scope findings plus the deferred minor, outside-scope and disputed review findings, one line each as `- <what> — <where> — <why>` (for a dispute, both positions and the open question in `<why>`). List them in the status in every layout. When the Follow-ups line names a path: after the review ends clean or clean except disputed, read the follow-ups.md it names and perform its Write follow-ups operation with `--doc <the task document's path inside this checkout> --branch <branch> --head <Reviewed HEAD> --checkout <this checkout>` and every follow-up, also when there are none (that removes an older section of this branch). Its `follow-ups: <branch>` commit is the branch's last commit and is listed under Commits. Whenever you add commits after it (a main-moved rebase round, a return from the root), perform it again once the new review is clean; it replaces this branch's section and is again the last commit. When the Follow-ups line says the root records them, the status is the only place you write them.

Status file: <status-file>
Read and follow the complete child-sessions status contract at <absolute child-sessions/references/status-file.md>. It owns the schema; write every identity field and section for done, blocked or failed. Commits must match git log --oneline <base-sha>..HEAD (or the explicitly updated base). Report actual Checks and Review results, using None where empty and stating unrun work honestly. For blocked, Questions includes the question, options and recommendation. Write the complete report atomically; its exact first line must be STATUS: done, STATUS: blocked or STATUS: failed. The root reads it and never edits its contents. After any archived status, write a fresh report at this same path.
```

For explicit resume or silent-exit recovery, retain the original identity/task and append this line before opening:

> Continue from the current state of the checkout: read git log and record the ordinary Git evidence and verify checkout/branch/HEAD first.
