# Plan brief (Phase 2)

Fill this template with absolute resolved paths and write it to `<runtime>/prep-<slug>-plan-brief.md`; the status is `<runtime>/prep-<slug>-plan-status.md`. A reused Phase 1 window receives it by `send` of exactly `Read the brief at <abs plan-brief> completely and carry it out.`; a new window opens with it. It is self-contained either way, so a silent-exit reopen can start from it.

Rules for filling:

- Keep every labelled line at the start of its line, exactly as shown (label, colon, one space); tools read `Status file:`, `Spec:`, `Plan paths:`, `Documents to review:` and `Base SHA:` literally. Use `Spec:` for the unit's existing spec; `Spec path:` belongs only to the Phase 1 brief and means "write a spec here".
- `Plan paths:` lists the plans to write, in confirmed order, separated by `, `. `Documents to review:` lists every existing document of this spec's units lacking a fresh mark (the spec too when it is not fresh), never a fresh one. Omit a line that would be empty; never write `None` on it. At least one of the two is present. Without `Plan paths:` (review only), drop the Planning skill line and the Plan headers section.
- Every document path is absolute inside this window's worktree. `Base SHA:` is the window's branch base, unchanged for a reused window.
- Plan headers, per plan to write: `**Spec:** <spec path relative to the project checkout>`, then one `**Depends on:** <predecessor plan path relative to the project checkout> (merged first)` per predecessor from the confirmed order; from the second plan of this window on, the previous plan of this window is one of them. Write `None` under Predecessors when there are none.

```text
Write and/or cross-review the plans of one spec in this docs worktree.

Checkout: <absolute window worktree of the docs repository>
Branch: prep-<slug>
Base SHA: <full base sha>
Docs repository main checkout: <absolute docs main checkout> (read only)
Project checkout: <absolute project checkout> (read code there; never write there)
Agent: <claude|codex>
Window name: prep-<slug>
Spec: <absolute spec path inside this worktree>
Plan paths: <absolute plan path inside this worktree>[, <absolute plan path>...]
Documents to review: <absolute document path inside this worktree>[, <absolute document path>...]
Ownership: you are the only writer in this worktree. The root owns merging, cleanup and the queue file.

Predecessors (merged before this spec's plans; read their specs completely, never edit them):
- <unit>: <absolute predecessor spec, in whichever checkout holds it> — <one-line reason>

Plan headers (put these lines under each plan's title):
- <absolute plan path>: <the plan's **Spec:** and **Depends on:** lines>

Read and honor all applicable project rules: <absolute AGENTS.md/CLAUDE.md paths, plus any rule to repeat verbatim>.

Required installed skills (read these absolute SKILL.md paths):
- Planning: <absolute superpowers writing-plans SKILL.md>
- Automatic cross review: <absolute auto-cross-refine SKILL.md>
- Opposite CLI launcher: <absolute refine-with-codex or refine-with-claude SKILL.md>
- Shared review protocol: <absolute review-fix-loop SKILL.md>

Work:
1. Read the Spec, every predecessor spec and every document to review completely, and read the project code they concern.
2. For each path on the Plan paths line, in that order: write the plan with writing-plans against the Spec and its predecessors, at that path (it replaces writing-plans' default location), with its header lines; commit it on this branch. Planning ends at the committed plan; execution belongs to deliver-task later.
3. Invoke auto-cross-refine over every plan written and every document to review, plans checked against the Spec, and run it until it ends clean or clean except disputed. Do not squash.
4. Mark each of those documents, and any other document of this spec you changed:
   a. Delete every line matching the regular expression '^Review: (clean|clean except disputed), ' anywhere in the document.
   b. For clean except disputed, keep the disputed findings and both positions in the document.
   c. git add the file and commit it as "docs: <basename>" when anything changed; <sha> is the full git rev-parse HEAD.
   d. Append exactly one last line: Review: <clean|clean except disputed>, <today YYYY-MM-DD>, reviewer <the opposite system that reviewed: claude|codex>, commit <sha>
   e. Commit it as "mark: <basename>".
   f. Check freshness: the last line is the only line matching that expression and diff <(git show <sha>:<path relative to this worktree>) <(sed '$d' <file>) prints nothing. A document changed after marking is reviewed and marked again.
5. Write the status file (below) with STATUS: done, then stay in this window; the root closes it.

Boundaries: commit only on this branch in this worktree. Do not merge, push, rebase, delete the branch or worktree, or touch the docs main checkout or the project checkout. Edit only this spec and its plans; predecessor specs and every document owned by another window are read only. A defect in one of them goes into Out of scope; if a plan cannot be written without fixing it, end STATUS: blocked with the question. Ask the user your own questions in this window; use STATUS: blocked only for what the root must resolve (a missing predecessor, a Git problem).

Record each out-of-scope finding as: what — where (path:line) — why it is out of scope. In Review, report the final refine mode separately from the raw reviewer verdict; a clean except disputed closure may keep raw CHANGES. Never rename that raw verdict CLEAN. Include disputed findings and both positions.

Status file: <absolute status path>
Read and follow the complete child-sessions status contract at <absolute child-sessions/references/status-file.md>, including the optional ## Artifacts section, which this task requires. Write every identity field and section for done, blocked or failed. Commits must match git log --oneline <base sha>..HEAD, cumulative across earlier briefs in this window. Checks: one line per marked document, the freshness check -> PASS or FAIL. Artifacts: the Spec, every plan you wrote or reviewed and any other document you changed, one absolute path per line. Use None where empty and state unrun work honestly. For blocked, Questions includes the question, options and recommendation. Write the complete report atomically (temporary file, then rename); its exact first line must be STATUS: done, STATUS: blocked or STATUS: failed. The root reads it and never edits it.
```

For a silent-exit reopen, retain the brief and append:

> Continue from the current state of the checkout: read git log and git status first.
