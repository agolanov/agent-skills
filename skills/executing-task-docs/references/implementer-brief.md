# Implementer brief

Fill this template with absolute resolved paths before opening. Keep the identity labels for resume and the fixed `Status file:` line. Project rules list absolute applicable AGENTS.md/CLAUDE.md paths plus any required verbatim rules. For a plan, list every execution skill the child has (`executing-plans`, `subagent-driven-development`, as Preflight 4 found them) on the Execution line; for any other task document write `None: not a plan` there. Include the actual opposite CLI launcher, shared loop and `independent-review`, not just the selector. Fill the Follow-ups line with its first form in the tracked layout (the follow-ups path inside this worktree and the child's `writing-task-follow-ups` SKILL.md), else with `the root records them`. Replace every placeholder, including the owned status-contract path; the child has no parent conversation or loaded skills.

```text
Implement one task document in this checkout.

Checkout: <checkout>
Branch: <branch>
Base SHA: <base-sha>
Task document: <document>
Plan kind: <plan|other>
Spec: <spec or None>
Agent: <agent>
Window name: <name>
Launch options: <explicit model/effort, or CLI defaults>
For every clean/path gate and continuation, use the installed independent-review checkout-state reference, Direct-use preflight and Other read-only Git gates. Run all verification Git reads through its git-read wrapper; displayed git read commands mean this wrapper. Unavailable verification blocks.

Ownership: you are the only implementation writer in this checkout. The root owns integration, cleanup and any follow-ups the Follow-ups line leaves to it.

Layout facts (gitignored material is not in this worktree):
Docs repository: <abs docs main checkout> (task documents live here; read-only except inside the Ignored test material path below; never commit there)
Ignored test material: <abs path or None>
Follow-ups: <commit them on this branch at <abs path in this worktree> through <abs writing-task-follow-ups SKILL.md> | the root records them>
Edit ignored material by absolute path in the main checkout; commit only files inside this worktree.

Read the task document and the spec completely. Read and honor all applicable project rules: <project-rules>.

Required installed skills (read these absolute SKILL.md paths):
- Execution (choose one by the plan; None for another document): <absolute SKILL.md of every one of executing-plans and subagent-driven-development the child has>
- Automatic cross review: <absolute auto-cross-refine SKILL.md>
- Opposite CLI launcher: <absolute refine-with-codex or refine-with-claude SKILL.md>
- Shared review protocol: <absolute review-fix-loop SKILL.md>
- Reviewer launch: <absolute independent-review SKILL.md>

For Plan kind plan, choose one execution skill from the Execution line by the plan: `executing-plans` when the plan is a few tasks done in order, where a task builds on an earlier one or edits the same files; `subagent-driven-development` when it has many tasks independent of each other. When only one is listed, use it. Write the skill and the reason as the first line under Checks in the status file. Execute the entire plan with it in this existing isolated worktree. For Plan kind other, implement the task directly from the task document in this existing isolated worktree, and write `direct: not a plan` as the first line under Checks. Never create a task document: no spec, plan or brief. Run the required checks below and commit task changes on this branch. Every commit message ends with its own content, unsigned: no `Co-Authored-By` trailer and no "Generated with" line, even when your harness asks for one; give this rule to every subagent that commits. Keep only task implementation, review-fix and follow-ups commits here.

When the spec has a `## Verification` section, run exactly the checks it names, no fewer. A further check is allowed only with its reason written under Checks in the status file. A named check that cannot run (an absent suite, a missing validator) is reported unavailable, never recreated or replaced by another check. That section takes precedence over any loaded skill's rule to test more: follow such a skill for how to run a check, not for how many to run. Without such a section, run the checks the task document and the project rules require.

After the task is complete and all checks pass, invoke `auto-cross-refine` and run it until it ends `clean` or `clean except disputed`. Do not squash. This final `auto-cross-refine` replaces the execution skill's own final review of the whole implementation; per-task reviews inside the execution skill stay at its discretion. In Review, name the full SHA of the last commit the review covered as `Reviewed HEAD: <sha>`.

Work only inside this checkout, except the ignored-material paths named under Layout facts, which you may edit in the main checkout; never write anything else there and never commit there. Do not merge, push, rebase, touch the main checkout beyond those Layout-facts paths, delete the branch/worktree, or fix out-of-scope findings. A later explicit main-moved message may authorize one rebase onto its named SHA, checks and one fix-review round; until then the rebase prohibition holds. That message also changes the reporting/review base for the fresh result.

Record each out-of-scope finding as: what — where (path:line) — why it is out of scope. Continue unless completing the task requires a user decision. Retain deferred minor/outside-scope/disputed review findings. In Review, report final refine mode separately from the raw reviewer verdict; a permitted clean except disputed closure may keep raw CHANGES. Never rename that raw verdict CLEAN. Include disputed findings, both positions and the fix-or-dismiss question.

Follow-ups are the Out of scope findings plus the deferred minor, outside-scope and disputed review findings, one line each as `- <what> — <where> — <why>` (for a dispute, both positions and the open question in `<why>`). List them in the status in every layout. When the Follow-ups line names a path: after the review ends clean or clean except disputed, read the writing-task-follow-ups SKILL.md it names and invoke it with `--doc <the task document's path inside this checkout> --branch <branch> --head <Reviewed HEAD> --checkout <this checkout>` and every follow-up, also when there are none (that removes an older section of this branch). Its `follow-ups: <branch>` commit is the branch's last commit and is listed under Commits. Whenever you add commits after it (a main-moved rebase round, a return from the root), invoke it again once the new review is clean; it replaces this branch's section and is again the last commit. When the Follow-ups line says the root records them, the status is the only place you write them.

Status file: <status-file>
Read and follow the complete child-sessions status contract at <absolute child-sessions/references/status-file.md>. It owns the schema; write every identity field and section for done, blocked or failed. Commits must match git log --oneline <base-sha>..HEAD (or the explicitly updated base). Report actual Checks and Review results, using None where empty and stating unrun work honestly. For blocked, Questions includes the question, options and recommendation. Write the complete report atomically; its exact first line must be STATUS: done, STATUS: blocked or STATUS: failed. The root reads it and never edits its contents. After any archived status, write a fresh report at this same path.
```

For explicit resume or silent-exit recovery, retain the original identity/task and append this line before opening:

> Continue from the current state of the checkout: read git log and run the checkout-state preflight first.
