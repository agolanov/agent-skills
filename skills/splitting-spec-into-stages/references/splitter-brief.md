# Splitter brief

Fill this template with absolute resolved paths and write it to `<runtime>/split-<spec-stem>-brief.md`; the status is `<runtime>/split-<spec-stem>-status.md`. The child has no parent conversation or loaded skills. Keep every labelled line at the start of its line, exactly as shown (label, colon, one space); tools read `Spec:`, `Stage convention:`, `Status file:`, `Base SHA:` and `Launch settings:` literally. The root appends one `Opened: <UTC time, ISO 8601 to the second>` line at the end before each `open`; those lines are the root's record and need no action from the child. `Stage convention:` is the absolute path of the installed `planning-task-docs/references/stages-section.md` that SKILL.md Input located. In the Work lines, `<rel>` is the spec's path relative to the docs repository and `<basename>` its file name. Replace every placeholder, including the owned status-contract path.

```text
Split one design spec into stages, working in this checkout.

Checkout: <absolute project checkout>
Docs repository: <absolute top level of the docs repository; the project checkout itself when the spec is tracked by it>
Base SHA: <full docs repository HEAD>
Agent: <claude|codex>
Launch settings: model <exact | cli-default> (<policy | explicit | cli-default>), effort <exact | cli-default> (<policy | explicit | cli-default>); resolved <YYYY-MM-DD> from <discovery evidence, one phrase>
Terminal controls: not part of this brief; the root reads them from each launch of this window after it opens and may be unable to see or answer this window, so a question or dialog shown here can wait for the user to answer it directly.
Window name: split-<spec-stem>
Spec: <absolute spec path>
Stage convention: <absolute installed planning-task-docs/references/stages-section.md>
Status file: <absolute status path>
Git checks: <absolute installed independent-review/references/checkout-state.md>. Read it for each clean/path gate and continuation: verify checkout/branch/HEAD, record the four ordinary Git commands with actual exits/raw outputs, and compare exact repository-relative paths. Use ordinary Git for other read-only checks with GIT_OPTIONAL_LOCKS=0. Failed evidence blocks. Carry its ignored/untracked-content, Git flags/normalization, nested-repository and transient-write limits; the legacy Python helper is optional.

Ownership: you are the only writer of the spec. The root verifies your report; it writes no document.

Read and honor all applicable project rules: <absolute AGENTS.md/CLAUDE.md paths, plus any rule to repeat verbatim>.

Work:
- Read the spec completely, the project rules and the code the spec names. Read the Format and Parsing rules sections of the Stage convention file.
- Write a "## Stages" section that follows the Stage convention, its Coverage line included: here that line is required. Split the spec by these criteria, in this order of precedence:
  1. after every stage main works and passes the project's checks, and the stage has a result someone can observe (a behaviour, a boundary, a removed dependency) — never "preparation only";
  2. a stage fits one `delivering-task` run: one plan an implementing child can finish in one session, with roughly three to eight plan tasks — a guideline, not a hard count; the child says in the status when a stage is larger and why;
  3. order reduces risk: stages that establish boundaries other stages rely on come first; stages that change user-visible behaviour come after the ones that only move code;
  4. every requirement of the spec is covered by at least one stage; the Coverage line proves it;
  5. fewer stages are better when the criteria above still hold.
- Ask the user in this window only where a boundary cannot be derived from the spec and the code; the user is beside this window.
- Before writing, run the own-paths gate of the Direct-use preflight on the docs repository, with <rel> as the owned path; a hit is another writer's uncommitted change: write STATUS: blocked naming the path, unless this brief carries a line starting "Continue from the current state of the checkout".
- When the spec's last line, without its line ending, matches ^Review: (clean|clean except disputed), [0-9]{4}-[0-9]{2}-[0-9]{2}, reviewer (claude|codex), commit [0-9a-f]{40}$ (a review mark), remove that line with its line ending: the split makes the mark stale. Remove nothing else: every other byte of the spec stays as it is, trailing empty lines included. Then append the section after the remaining content, with nothing but line endings, in the spec's style, before "## Stages": two line endings when the content's last line has none; none when the content ends with an empty line (two line endings in a row); one otherwise, so that the section follows an empty line.
- Commit the spec alone, in the docs repository: git --literal-pathspecs add -- SPEC, then git --literal-pathspecs commit -m MESSAGE -- SPEC, where SPEC is <rel> and MESSAGE is docs: stages for <basename>, so that other staged changes stay staged and out of your commit; --literal-pathspecs keeps Git from reading a file name such as ":(glob)…" as pathspec magic. Quote each value yourself as one literal shell argument, for the shell you run in, so that `(`, spaces, `$` and quotes reach Git unchanged: in a POSIX shell inside single quotes, a single quote in the value written `'\''`; in PowerShell inside single quotes, a single quote doubled.

Boundaries: work on the current branch of the docs repository. Do not create a worktree or branch, merge, push or rebase. Write no line starting with "Review:" into any document: review marks belong to a later review. Edit no document other than the spec, and leave every other uncommitted change, staged or not, as it is: the user works in this checkout too and may commit there meanwhile. Ask the user your own questions in this window; use STATUS: blocked only for what the root must resolve (a Git problem, a missing input).

Record each out-of-scope finding as: what — where (path:line) — why it is out of scope.

Read and follow the complete child-sessions status contract at <absolute child-sessions/references/status-file.md>, including the optional ## Artifacts section, which this task requires. Write every identity field and section for done, blocked or failed; BRANCH, CHECKOUT and HEAD name the docs repository (current branch, top level, full HEAD). Commits lists exactly your own commits there, one git log --oneline line each, oldest first; leave out commits by anyone else. Checks: one line per stage larger than criterion 2's guideline, "criterion 2 → stage NN larger: " followed by the reason; None when no stage is larger. Review: Not run: splitting only. Artifacts: the spec's absolute path, alone. Use None where empty and state unrun work honestly. For blocked, Questions includes the question, options and recommendation. Write the complete report atomically (temporary file, then rename); its exact first line must be STATUS: done, STATUS: blocked or STATUS: failed. Then stay in this window; the root closes it. The root reads the report and never edits it.
```

For a silent-exit reopen, retain the brief and append:

> Continue from the current state of the checkout: read git log and record the ordinary Git evidence and verify checkout/branch/HEAD first. Uncommitted changes on your owned paths are your earlier session's work: inspect them and continue from them.
