# Planner brief

Fill this template with absolute resolved paths and write it to `<runtime>/plan-<slug>-brief.md`; the status is `<runtime>/plan-<slug>-status.md`. The child has no parent conversation or loaded skills. Keep every labelled line at the start of its line, exactly as shown (label, colon, one space); tools read `Status file:`, `Base SHA:` and `Launch settings:` literally. The root appends one `Opened: <UTC time, ISO 8601 to the second>` line at the end before each `open`; those lines are the root's record and need no action from the child. Keep exactly one of the `Task text:`, `Brief:`, `Spec:` and `Follow-ups file:` lines: the task text verbatim, or the input file's absolute path. Drop the `Brainstorming:` line for a spec input. Replace every placeholder, including the owned status-contract path.

```text
Write one task's spec and plan with superpowers, working in this checkout.

Checkout: <absolute project checkout>
Docs repository: <absolute top level of the docs repository; the project checkout itself when the documents are tracked by it>
Base SHA: <full docs repository HEAD>
Agent: <claude|codex>
Launch settings: model <exact | cli-default> (<policy | explicit | cli-default>), effort <exact | cli-default> (<policy | explicit | cli-default>); resolved <YYYY-MM-DD> from <discovery evidence, one phrase>
Window name: plan-<slug>
Task text: <the task text, verbatim>
Brief: <absolute brief path>
Spec: <absolute spec path>
Follow-ups file: <absolute follow-ups file path>
Status file: <absolute status path>
For every clean/path gate and continuation, use the installed independent-review checkout-state reference, Direct-use preflight and Other read-only Git gates. Run all verification Git reads through its git-read wrapper; displayed git read commands mean this wrapper. Unavailable verification blocks.

Ownership: you are the only writer of the new spec and plan. The root verifies your report; it writes no document.

Read and honor all applicable project rules: <absolute AGENTS.md/CLAUDE.md paths, plus any rule to repeat verbatim>.

Required installed skills (read these absolute SKILL.md paths):
- Brainstorming: <absolute superpowers brainstorming SKILL.md>
- Planning: <absolute superpowers writing-plans SKILL.md>

Work, by the input line present:
- Task text or Brief: read the brief completely. Run brainstorming with the user in this window, starting from the task text or the brief; the user is beside this window, ask your questions here. Then run writing-plans against the approved spec.
- Spec: read it completely and run writing-plans against it.
- Follow-ups file (each of its lines starting with "- " is one finding):
  a. Read the follow-ups file, the plan beside it (the same path without its -follow-ups or -tails suffix) and that plan's spec (its naming pair specs/YYYY-MM-DD-<slug>-design.md, else its **Spec:** header) when they exist, and the project code. Recheck every finding against the current code: it may have been fixed or moved since it was recorded.
  b. Show the findings with what the recheck found, and have the user select here which to fix. When the user selects none, write the status file with STATUS: failed and "no follow-ups selected" under Checks and under Review, and stop.
  c. Run brainstorming with the user from the selected findings. Put the header line "**Source follow-ups:** <follow-ups path relative to the project checkout>" in the spec. Then run writing-plans against the approved spec.

Write and commit the spec and plan where and how those skills do, honoring the project rules. When the project rules ask a spec for a verification section, write it while brainstorming as the rules say, without a separate question to the user; when the spec has one, the plan's check steps are exactly those checks, each with how to run it. The plan's header carries "**Spec:** <spec path relative to the project checkout>". Planning ends at the committed plan: decline any offer of those skills to start execution.

Boundaries: work on the current branch of each repository. Do not create a worktree or branch, merge, push or rebase, even where those skills suggest it. Write no line starting with "Review:" into any document: review marks belong to a later review. The input file is read only: leave it byte-identical. Edit no document other than the spec and plan you write. Ask the user your own questions in this window; use STATUS: blocked only for what the root must resolve (a Git problem, a missing input).

Record each out-of-scope finding as: what — where (path:line) — why it is out of scope.

Read and follow the complete child-sessions status contract at <absolute child-sessions/references/status-file.md>, including the optional ## Artifacts section, which this task requires. Write every identity field and section for done, blocked or failed; BRANCH, CHECKOUT and HEAD name the repository holding the documents (current branch, top level, full HEAD). Commits must match git log --oneline <base>..HEAD in that repository, <base> being Base SHA when it is the docs repository. Checks: None unless the project rules required a check. Review: Not run: planning only. Artifacts: the spec and plan you wrote, one absolute path per line. Use None where empty and state unrun work honestly. For blocked, Questions includes the question, options and recommendation. Write the complete report atomically (temporary file, then rename); its exact first line must be STATUS: done, STATUS: blocked or STATUS: failed. Then stay in this window; the root closes it. The root reads the report and never edits it.
```

For a silent-exit reopen, retain the brief and append:

> Continue from the current state of the checkout: read git log and run the checkout-state preflight first.
