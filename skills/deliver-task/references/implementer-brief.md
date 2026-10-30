# Implementer brief

Fill this template with absolute resolved paths before opening. Keep the identity labels for resume and the fixed `Status file:` line. Project rules list absolute applicable AGENTS.md/CLAUDE.md paths plus any required verbatim rules. Select one available execution skill; include the actual opposite CLI launcher and shared loop, not just the selector. Replace every placeholder, including the owned status-contract path; the child has no parent conversation or loaded skills. `Delivery mode:` carries the spec's mode, read from the first line of the spec that starts with `**Delivery mode:** `: a value of exactly `light` or `full` is carried as written, and a spec with no such line gives `full`. Any other value, `Light` or `light` with trailing spaces included, is carried as `full` and named, with the spec path and the raw value, in the final report only; the root asks no question about it and leaves the spec as it is. The root copies the value and never judges it. Copy the fenced text whole: the paragraph that starts "When Delivery mode is light" stays in every brief, whatever the mode.

```text
Implement one reviewed plan in this checkout.

Checkout: <checkout>
Branch: <branch>
Base SHA: <base-sha>
Plan: <plan>
Spec: <spec>
Delivery mode: <light|full>
Agent: <agent>
Window name: <name>
Launch options: <explicit model/effort, or CLI defaults>
Ownership: you are the only implementation writer in this checkout. The root owns integration, cleanup and recording tails.

Layout facts (gitignored material is not in this worktree):
Docs repository: <abs docs main checkout> (spec and plan live here; read-only except inside the Ignored test material path below; never commit there)
Ignored test material: <abs path or None>
Edit ignored material by absolute path in the main checkout; commit only files inside this worktree.

Read the spec and plan completely. Read and honor all applicable project rules: <project-rules>.

Required installed skills (read these absolute SKILL.md paths):
- Execution: <absolute executing-plans or subagent-driven-development SKILL.md>
- Automatic cross review: <absolute auto-cross-refine SKILL.md>
- Opposite CLI launcher: <absolute refine-with-codex or refine-with-claude SKILL.md>
- Shared review protocol: <absolute review-fix-loop SKILL.md>

Execute the entire plan with the selected execution skill in this existing isolated worktree. Run all required checks and commit task changes on this branch. Keep only task implementation and review-fix commits here; delivery notes/tails belong to the root after merge.

When Delivery mode is light, the whole task is: the edit the plan describes, the checks the plan and the project rules name, and the one `auto-cross-refine` below. Create no fixtures, fake scenarios, replay cases, RED or GREEN runs or notes entries, edit no test material, and do not escalate to the project's full process on your own. If the change does not meet the project rules' criteria for light, do not change the header or widen the change: end STATUS: blocked with the question (widen to full, or narrow the change). When Delivery mode is full, this paragraph does not apply.

After the plan is complete and all checks pass, invoke `auto-cross-refine` and run it until it ends `clean` or `clean except disputed`. Do not squash.

Work only inside this checkout, except the ignored-material paths named under Layout facts, which you may edit in the main checkout; never write anything else there and never commit there. Do not merge, push, rebase, touch the main checkout beyond those Layout-facts paths, delete the branch/worktree, or fix out-of-scope findings. A later explicit main-moved message may authorize one rebase onto its named SHA, checks and one fix-review round; until then the rebase prohibition holds. That message also changes the reporting/review base for the fresh result.

Record each out-of-scope finding as: what — where (path:line) — why it is out of scope. Continue unless completing the plan requires a user decision. Retain deferred minor/outside-scope/disputed review findings. In Review, report final refine mode separately from the raw reviewer verdict; a permitted clean except disputed closure may keep raw CHANGES. Never rename that raw verdict CLEAN. Include disputed findings, both positions and the fix-or-dismiss question.

Status file: <status-file>
Read and follow the complete child-sessions status contract at <absolute child-sessions/references/status-file.md>. It owns the schema; write every identity field and section for done, blocked or failed. Commits must match git log --oneline <base-sha>..HEAD (or the explicitly updated base). Report actual Checks and Review results, using None where empty and stating unrun work honestly. For blocked, Questions includes the question, options and recommendation. Write the complete report atomically; its exact first line must be STATUS: done, STATUS: blocked or STATUS: failed. The root reads it and never edits its contents. After any archived status, write a fresh report at this same path.
```

For explicit resume or silent-exit recovery, retain the original identity/task and append this line before opening:

> Continue from the current state of the checkout: read git log and git status first.
