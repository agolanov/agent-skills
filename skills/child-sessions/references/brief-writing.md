# Writing a child brief

The child starts without the parent's conversation or loaded skills. Write a self-contained brief under the private [runtime directory](platform-runtime.md#runtime-and-backend), outside monitored repositories. Use absolute native paths. Include the [run-contract fields](run-contract.md#brief) when applicable.

- **Checkout.** Give the path, branch, full base SHA and who may write there.
- **Inputs.** Name the required documents, exact sections when sufficient, applicable project rules and accessible skills. Require each selected unit to be read in full. Quote project rules that require verbatim inclusion. For reviewers, apply [Review coverage](../../independent-review/SKILL.md#review-coverage).
- **Work.** State the task, completion conditions, checks, review, commit instructions and limits on authority. For a plan, name the execution skill or the allowed choices.
- **Suite evidence.** When a complete suite feeds review-fix-loop, include `Suite evidence:` with the absolute [suite handoff reference](../../independent-review/references/checkout-state.md#run-and-hand-off-a-suite), external records directory and retained suite-record paths (`None` if absent). Require the recipe before the first complete suite and the record paths in Checks.
- **Findings.** Record each out-of-scope finding as `what — where (path:line) — why it is out of scope`. Continue unless a decision is needed. Keep deferred review findings and the derived verdict visible.
- **Terminal controls.** Use the caller's template line. Without a template, say the root reads controls after opening and the visible window may need direct user attention. Keep launch IDs, backend and capability JSON in the parent's launch records.
- **Autonomy.** Write `Auto: no` or `Auto: yes`. For yes, give the absolute path to [auto.md](auto.md). The child asks nobody directly.
- **Status.** Give the absolute output path. Include the [status schema](status-file.md) or require the child to read it at its absolute path. A block includes the question, options and recommendation.

For a silent-exit reopen or explicit checkout resume, keep the original brief and status path and append the exact [continuation instruction](../SKILL.md#recover-a-silent-exit).
