# Writing a child brief

The child starts without the root's conversation or loaded skills. Write a self-contained task brief outside the repository, using absolute native paths for every input and output under the owner's resolved `runtime-dir`. Read [platform-runtime.md](platform-runtime.md), retain the native entrypoint vector and resolved runtime, and record each launch's capability JSON in your own records after its `open`, never in the brief; native Windows consumers use its literal-array `Invoke-ChildSessionDispatch` recipe. A brief written under the [run contract](run-contract.md) also carries its [identity lines](run-contract.md#brief). Include each checklist item before opening the session:

- **Checkout and ownership:** absolute checkout path, branch, full base SHA, and who may write there. If the child is the only writer, state it.
- **Inputs:** absolute paths to the specification, plan, and other required material; instruct the child to read the required inputs completely. Name needed skills and verify that the child's agent can access them.
- **Project rules:** paths to applicable `AGENTS.md`/`CLAUDE.md` files, with any project rule that must be repeated verbatim.
- **Work:** concrete task, completion conditions, required checks, review, and commit behavior. For a plan, name the execution skill or give the child the permitted execution-skill choices. Include the actual required review process; this lifecycle skill does not assign one.
- **Boundaries:** what the child must not do, including any restrictions on merge, push, rebase, other checkouts, branch deletion, or out-of-scope changes. Grant only authority the caller already has.
- **Findings:** record each out-of-scope finding as `what — where (path:line) — why it is out of scope`; proceed unless the task needs a decision to continue. Keep any deferred review findings and raw verdict visible.
- **Terminal controls:** the brief is written before `open` and names no backend, launch identity or control. A calling skill's template supplies its fixed `Terminal controls:` line; a brief written without such a template states the same facts: the root reads the controls from each launch after it opens and may be unable to see or answer the window, so questions and dialogs there can wait for the user. For a plain terminal, tell the user at launch that questions/dialogs need direct user attention and counts are not observable; continue through files. A timeout alone is no question or approval requirement. Preserve complete-command inspection and existing authority; absent peek/key/send grants no guessed input.
- **Autonomy:** the line `Auto: yes` under `--auto`, with the absolute path of the installed [auto.md](auto.md) for the child to follow as a child (it asks nobody, in its window either); otherwise `Auto: no`.
- **Status:** absolute output path and the complete [status-file contract](status-file.md). Include the schema in the brief, or provide an absolute readable path and explicitly require reading it. Require a full report for done, blocked, or failed, with Questions carrying a block's question, options, and recommendation.

For a reopened silent exit or an explicitly resumed checkout, retain the original task and append:

> Continue from the current state of the checkout: read git log and git status first.

That instruction is required: restarting the same unchanged brief can repeat completed work or ignore partial changes. The parent keeps the same status path and permits only the single automatic reopen defined in SKILL.md. The brief itself does not grant further recovery attempts.
