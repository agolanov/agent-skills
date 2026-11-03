# Refiner brief

Fill this template with absolute resolved paths and write it to `<runtime>/refine-<stem>-brief.md`; the status is `<runtime>/refine-<stem>-status.md`. The child has no parent conversation or loaded skills. Keep every labelled line at the start of its line, exactly as shown (label, colon, one space); tools read `Status file:`, `Documents to review:`, `Base SHA:`, `Launch settings:` and `Reviewer settings:` literally. The root appends one `Opened: <UTC time, ISO 8601 to the second>` line at the end before each `open`; those lines are the root's record and need no action from the child. `<absolute launch-settings.md>` is the installed independent-review `references/launch-settings.md`. `Documents to review:` lists every stale document and `Context documents:` every fresh one, absolute paths separated by `, `; omit `Context documents:` when there are none, never write `None` on it. `Review mark rules:` is the absolute path of this skill's installed `references/review-mark.md`. `Stage convention:` is the absolute path of this skill's installed `references/stages-section.md`. Replace every placeholder, including the owned status-contract path.

```text
Cross-review one task's documents and mark them, working in this checkout.

Checkout: <absolute project checkout> (read the code here)
Docs repository: <absolute top level of the repository holding the documents> (commit the documents here)
Base SHA: <full docs repository HEAD>
Agent: <claude|codex>
Launch settings: model <exact | cli-default> (<policy | explicit | cli-default>), effort <exact | cli-default> (<policy | explicit | cli-default>); resolved <YYYY-MM-DD> from <discovery evidence, one phrase>
Reviewer settings: <reviewer policy | model <M> (explicit) and/or effort <E> (explicit), the rest by reviewer policy>
Terminal controls: <backend and supported capabilities from the root; plain-terminal questions need direct user attention>
Window name: refine-<stem>
Documents to review: <absolute document path>[, <absolute document path>]
Context documents: <absolute document path>[, <absolute document path>]
Review mark rules: <absolute refining-task-docs/references/review-mark.md>
Stage convention: <absolute refining-task-docs/references/stages-section.md>
Git checks: <absolute installed independent-review/references/checkout-state.md>. Read it for each clean/path gate and continuation: verify checkout/branch/HEAD, record the four ordinary Git commands with actual exits/raw outputs, and compare exact repository-relative paths. Use ordinary Git for other read-only checks with GIT_OPTIONAL_LOCKS=0. Failed evidence blocks. Carry its ignored/untracked-content, Git flags/normalization, nested-repository and transient-write limits; the legacy Python helper is optional.

Ownership: you are the only writer of these documents. The root verifies your report; it writes no document or mark.

Read and honor all applicable project rules: <absolute AGENTS.md/CLAUDE.md paths, plus any rule to repeat verbatim>.

Required installed skills (read these absolute SKILL.md paths):
- Automatic cross review: <absolute auto-cross-refine SKILL.md>
- Opposite CLI launcher: <absolute refine-with-codex or refine-with-claude SKILL.md>
- Shared review protocol: <absolute review-fix-loop SKILL.md>
- Reviewer launch: <absolute independent-review SKILL.md>

Work:
1. Read every document to review, every context document and the Review mark rules completely, and read the project code the documents concern.
2. Invoke auto-cross-refine over the documents to review and run it until it ends clean or clean except disputed. Do not squash. A plan is checked against its spec like any requirement of the spec, including the spec's Verification section. A plan whose header carries "**Stage:** NN" is checked against its spec through that stage's **Scope:** and **Done when:** lines in the spec's "## Stages" section: requirements outside that Scope belong to other stages and are not findings. A spec with a "## Stages" section is checked against the Stage convention: its Parsing rules, order as the only dependency, and, when the section has a Coverage line, that it leaves no unit without a stage; a hand-written section without one is not a finding. A spec's Verification section is reviewed for proportion in both directions: a check the change's risks do not need is a finding, and so is a risk no check covers. Context documents are already reviewed: read them for context and edit one only to fix a finding. Pass the Reviewer settings' explicit values to auto-cross-refine as explicit model/effort; with `reviewer policy` pass none. Launch settings govern only this session; subagents you start follow the skill and host that start them (see `<absolute launch-settings.md>`, section Nested agents).
3. After the review ends clean or clean except disputed, apply the Marking procedure of the Review mark rules to every document to review and every context document you changed, committing in the docs repository. Run its freshness check on each marked document.
4. Write the status file (below) with STATUS: done, then stay in this window; the root closes it.

When the review cannot end clean or clean except disputed, mark nothing and write STATUS: failed, naming under Review the open findings and the documents left unmarked.

Boundaries: commit only on the current branch of the docs repository, and only the documents to review and the context documents you changed, always naming them with a pathspec (git add -- <paths>, then git commit -m <message> -- <paths>), so that other staged changes stay staged and out of your commits. Do not create a worktree or branch, merge, push or rebase. Edit no other file, and leave every other uncommitted change, staged or not, as it is: the user works in this checkout too and may commit there meanwhile. Ask the user your own questions in this window; use STATUS: blocked only for what the root must resolve (a Git problem, a missing input).

Record each out-of-scope finding as: what — where (path:line) — why it is out of scope. In Review, report the final refine mode separately from the raw reviewer verdict; a clean except disputed closure may keep raw CHANGES. Never rename that raw verdict CLEAN. Include disputed findings and both positions.

Status file: <absolute status path>
Read and follow the complete child-sessions status contract at <absolute child-sessions/references/status-file.md>, including the optional ## Artifacts section, which this task requires. Write every identity field and section for done, blocked or failed; BRANCH, CHECKOUT and HEAD name the docs repository (current branch, top level, full HEAD). Commits lists exactly your own commits in the docs repository, one git log --oneline line each, oldest first; leave out commits by anyone else. Checks: one line per marked document, the freshness check -> PASS or FAIL. Review: the final refine mode and the raw reviewer verdict, separately. Artifacts: every document you marked or changed, one absolute path per line. Use None where empty and state unrun work honestly. For blocked, Questions includes the question, options and recommendation. Write the complete report atomically (temporary file, then rename); its exact first line must be STATUS: done, STATUS: blocked or STATUS: failed. The root reads it and never edits it.
```

For a silent-exit reopen, retain the brief and append:

> Continue from the current state of the checkout: read git log and record the ordinary Git evidence and verify checkout/branch/HEAD first. Uncommitted changes on your owned paths are your earlier session's work: inspect them and continue from them.
