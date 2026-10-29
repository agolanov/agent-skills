# Spec brief (Phase 1)

Fill this template with absolute resolved paths and write it to `<runtime>/prep-<slug>-spec-brief.md`; the status is `<runtime>/prep-<slug>-spec-status.md`. The child has no parent conversation or loaded skills. Keep every labelled line at the start of its line, exactly as shown (label, colon, one space): `Spec path:` marks this as a spec brief, and tools read `Status file:`, `Spec path:` and `Base SHA:` literally. Keep exactly one of the `Idea:` and `Existing plan:` lines. `Spec path:` and `Existing plan:` are paths inside this window's worktree. Replace every placeholder, including the owned status-contract path.

```text
Write and cross-review one spec in this docs worktree.

Checkout: <absolute window worktree of the docs repository>
Branch: prep-<slug>
Base SHA: <full base sha>
Docs repository main checkout: <absolute docs main checkout> (read only)
Project checkout: <absolute project checkout> (read code there; never write there)
Agent: <claude|codex>
Window name: prep-<slug>
Spec path: <absolute spec path inside this worktree>
Idea: <the user's idea text, verbatim>
Existing plan: <absolute plan path inside this worktree>
Ownership: you are the only writer in this worktree. The root owns merging, cleanup and the queue file.

Read and honor all applicable project rules: <absolute AGENTS.md/CLAUDE.md paths, plus any rule to repeat verbatim>.

Required installed skills (read these absolute SKILL.md paths):
- Brainstorming: <absolute superpowers brainstorming SKILL.md>
- Automatic cross review: <absolute auto-cross-refine SKILL.md>
- Opposite CLI launcher: <absolute refine-with-codex or refine-with-claude SKILL.md>
- Shared review protocol: <absolute review-fix-loop SKILL.md>

Work:
1. Run brainstorming with the user in this window, starting from the idea, or from the existing plan, which the spec must fully cover. The user is beside this window: ask your questions here. Write the spec to Spec path (it replaces brainstorming's default location) and commit it on this branch. Brainstorming ends here at the approved, committed spec; the plan comes in a later instruction.
2. Invoke auto-cross-refine on the spec and run it until it ends clean or clean except disputed. Do not squash.
3. Mark the spec:
   a. Delete every line matching the regular expression '^Review: (clean|clean except disputed), ' anywhere in the document.
   b. For clean except disputed, keep the disputed findings and both positions in the document.
   c. Make sure the file ends with a newline, then git add it and commit it as "docs: <basename>" when anything changed; <sha> is the full git rev-parse HEAD.
   d. Append exactly one last line: Review: <clean|clean except disputed>, <today YYYY-MM-DD>, reviewer <the opposite system that reviewed: claude|codex>, commit <sha>
   e. Commit it as "mark: <basename>".
   f. Check freshness: the last line is the only line matching that expression and diff <(git show <sha>:<path relative to this worktree>) <(sed '$d' <file>) prints nothing. A document changed after marking is reviewed and marked again.
4. Write the status file (below) with STATUS: done.
5. Then stay in this window and wait for the next instruction; keep the session running.

Boundaries: commit only on this branch in this worktree. Do not merge, push, rebase, delete the branch or worktree, or touch the docs main checkout or the project checkout. Documents other than your spec are read only. Ask the user your own questions in this window; use STATUS: blocked only for what the root must resolve (a Git problem, a missing input).

Record each out-of-scope finding as: what — where (path:line) — why it is out of scope. In Review, report the final refine mode separately from the raw reviewer verdict; a clean except disputed closure may keep raw CHANGES. Never rename that raw verdict CLEAN. Include disputed findings and both positions.

Status file: <absolute status path>
Read and follow the complete child-sessions status contract at <absolute child-sessions/references/status-file.md>, including the optional ## Artifacts section, which this task requires. Write every identity field and section for done, blocked or failed. Commits must match git log --oneline <base sha>..HEAD. Checks: one line per marked document, the freshness check -> PASS or FAIL. Artifacts: every document you created or changed, one absolute path per line. Use None where empty and state unrun work honestly. For blocked, Questions includes the question, options and recommendation. Write the complete report atomically (temporary file, then rename); its exact first line must be STATUS: done, STATUS: blocked or STATUS: failed. The root reads it and never edits it.
```

For a silent-exit reopen, retain the brief and append:

> Continue from the current state of the checkout: read git log and git status first.
