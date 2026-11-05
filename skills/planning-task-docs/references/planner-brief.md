# Planner brief

Fill this template with absolute resolved paths and write it to `<runtime>/plan-<slug>-brief.md`; the status is `<runtime>/plan-<slug>-status.md`. The child has no parent conversation or loaded skills. Keep every labelled line at the start of its line, exactly as shown (label, colon, one space); tools read `Status file:`, `Base SHA:` and `Launch settings:` literally. The root appends one `Opened: <UTC time, ISO 8601 to the second>` line at the end before each launch (each `open` included) and each fresh child; those lines are the root's record and need no action from the child. `Place:` is the place of SKILL.md Preflight 2 and `Auto:` is `no`. Outside `window` drop the `Terminal controls:` and `Window name:` lines. Keep the one `Talking to the user` paragraph whose parenthesis names the brief's Place, and drop the parenthesis. Keep exactly one of the `Task text:`, `Brief:`, `Spec:` and `Follow-ups file:` lines: the task text verbatim, or the input file's absolute path. For a staged spec keep the `Stage:`, `Stage scope:`, `Stage done when:` and `Plan path:` lines and the `Earlier stages:` lines; drop them otherwise. They describe the next stage NN of SKILL.md Input rule 3: `Stage:` is `NN — <name>`; `Stage scope:` and `Stage done when:` carry the values of its `**Scope:**` and `**Done when:**` lines verbatim, without the labels; `Plan path:` is the absolute path of its stage plan, `plans/<spec-stem>-NN-<stage-slug>.md` in the spec's sibling `plans/` directory. `Earlier stages:` is one line per stage 01 to NN-1, in stage order, each `Earlier stages: MM — <absolute path of the plan Input rule 3 matched to stage MM>`, followed by ` — follow-ups <absolute path>` for each follow-ups file that exists beside that plan (`<plan stem>-follow-ups.md`, or the older `<plan stem>-tails.md`); for stage 01 it is the single line `Earlier stages: None`. Drop the `Brainstorming:` line for a spec input. Replace every placeholder, including the owned status-contract path.

```text
Write one task's spec and plan with superpowers, working in this checkout.

Checkout: <absolute project checkout>
Docs repository: <absolute top level of the docs repository; the project checkout itself when the documents are tracked by it>
Base SHA: <full docs repository HEAD>
Agent: <claude|codex>
Place: <window|subagent|background>
Auto: no
Launch settings: model <exact | cli-default> (<policy | explicit | cli-default>), effort <exact | cli-default> (<policy | explicit | cli-default>); resolved <YYYY-MM-DD> from <discovery evidence, one phrase>
Terminal controls: not part of this brief; the root reads them from each launch of this window after it opens and may be unable to see or answer this window, so a question or dialog shown here can wait for the user to answer it directly.
Window name: plan-<slug>
Task text: <the task text, verbatim>
Brief: <absolute brief path>
Spec: <absolute spec path>
Stage: NN — <name>
Stage scope: <Scope line's value, verbatim>
Stage done when: <Done when line's value, verbatim>
Plan path: <absolute path plans/<spec-stem>-NN-<stage-slug>.md>
Earlier stages: <absolute plan paths of stages 01..NN-1, one per line, with the follow-ups file of each when it exists, each line as the preamble says; None for stage 01>
Follow-ups file: <absolute follow-ups file path>
Status file: <absolute status path>
Git checks: <absolute installed independent-review/references/checkout-state.md>. Read it for each clean/path gate and continuation: verify checkout/branch/HEAD, record the four ordinary Git commands with actual exits/raw outputs, and compare exact repository-relative paths. Use ordinary Git for other read-only checks with GIT_OPTIONAL_LOCKS=0. Failed evidence blocks. Carry its ignored/untracked-content, Git flags/normalization, nested-repository and transient-write limits; the legacy Python helper is optional.

Ownership: you are the only writer of the new spec and plan. The root verifies your report; it writes no document.

Read and honor all applicable project rules: <absolute AGENTS.md/CLAUDE.md paths, plus any rule to repeat verbatim>.

Required installed skills (read these absolute SKILL.md paths):
- Brainstorming: <absolute superpowers brainstorming SKILL.md>
- Planning: <absolute superpowers writing-plans SKILL.md>

Work, by the input line present:
- Task text or Brief: read the brief completely. Run brainstorming with the user, starting from the task text or the brief and asking as Talking to the user says. Then run writing-plans against the approved spec.
- Spec without a Stage: line: read it completely and run writing-plans against it.
- Spec with a Stage: line: read the whole spec, then plan only this stage, within its Stage scope and to its Stage done when. Read the Earlier stages plans and follow-ups files; a follow-ups finding that this stage's scope covers goes into the plan, any other stays in its file untouched. Plan against the code as it is now on the current branch, not as the earlier plans describe it. Write the plan at Plan path exactly, with the headers "**Spec:** <spec path relative to the project checkout>" and "**Stage:** NN", and run writing-plans against the spec read through this stage's scope.
- Follow-ups file (each of its lines starting with "- " is one finding):
  a. Read the follow-ups file, the plan beside it (the same path without its -follow-ups or -tails suffix) and that plan's spec (its naming pair specs/YYYY-MM-DD-<slug>-design.md, else its **Spec:** header) when they exist, and the project code. Recheck every finding against the current code: it may have been fixed or moved since it was recorded.
  b. Ask the user which findings to fix, showing each with what the recheck found. When the user selects none, write the status file with STATUS: failed and "no follow-ups selected" under Checks and under Review, and stop.
  c. Run brainstorming with the user from the selected findings. Put the header line "**Source follow-ups:** <follow-ups path relative to the project checkout>" in the spec. Then run writing-plans against the approved spec.

Write the spec and plan where those skills do, honoring the project rules. They are your owned paths. Before writing each, run the own-paths gate of the Direct-use preflight on the repository that will hold that document (the top level of its directory: the docs repository, or the project checkout when the project rules place the document there), with the document's exact path relative to that repository as the owned path; a hit is another writer's uncommitted change: write STATUS: blocked naming the path, unless this brief carries a line starting "Continue from the current state of the checkout". Commit each document alone, even where those skills commit their own way: git --literal-pathspecs add -- PATH, then git --literal-pathspecs commit -m MESSAGE -- PATH, where PATH is the document's path and MESSAGE its commit message, so that other staged changes stay staged and out of your commit; --literal-pathspecs keeps Git from reading a file name such as ":(glob)…" as pathspec magic. Quote each value yourself as one literal shell argument, for the shell you run in, so that `(`, spaces, `$` and quotes reach Git unchanged: in a POSIX shell inside single quotes, a single quote in the value written `'\''`; in PowerShell inside single quotes, a single quote doubled. When the project rules ask a spec for a verification section, write it while brainstorming as the rules say, without a separate question to the user; when the spec has one, the plan's check steps are exactly those checks, each with how to run it; with a Stage: line, exactly those of them that this stage's Stage scope and Stage done when call for, plus every check the spec applies to each change or delivery as a whole. The plan's header carries "**Spec:** <spec path relative to the project checkout>". Planning ends at the committed plan: decline any offer of those skills to start execution.

Boundaries: work on the current branch of each repository. Do not create a worktree or branch, merge, push or rebase, even where those skills suggest it. Write no line starting with "Review:" into any document: review marks belong to a later review. The input file is read only: leave it byte-identical. Edit no document other than the spec and plan you write, and leave every other uncommitted change, staged or not, as it is: the user works in this checkout too and may commit there meanwhile.

Talking to the user (window): the user is beside this window: ask your questions here, and use STATUS: blocked only for what the root must resolve (a Git problem, a missing input). After writing the status file, stay in this window; the root closes it.

Talking to the user (subagent, background): nobody is beside you. Ask every question, the spec's approval included, by writing STATUS: blocked with the question, options and your recommendation; continue when the answer arrives. End every turn by writing the status file, with its exact first line as your last message and nothing after it.

Record each out-of-scope finding as: what — where (path:line) — why it is out of scope.

Read and follow the complete child-sessions status contract at <absolute child-sessions/references/status-file.md>, including the optional ## Artifacts section, which this task requires. Write every identity field and section for done, blocked or failed; BRANCH, CHECKOUT and HEAD name the repository holding the documents (current branch, top level, full HEAD). Commits lists exactly your own commits in that repository, one git log --oneline line each, oldest first; leave out commits by anyone else. Checks: None unless the project rules required a check. Review: Not run: planning only. Artifacts: the spec and plan you wrote, one absolute path per line. Use None where empty and state unrun work honestly. For blocked, Questions includes the question, options and recommendation. Write the complete report atomically (temporary file, then rename); its exact first line must be STATUS: done, STATUS: blocked or STATUS: failed. The root reads the report and never edits it.
```

For a silent-exit reopen, retain the brief and append:

> Continue from the current state of the checkout: read git log and record the ordinary Git evidence and verify checkout/branch/HEAD first. Uncommitted changes on your owned paths are your earlier session's work: inspect them and continue from them.
