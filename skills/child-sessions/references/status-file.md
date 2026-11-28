# Status file contract

The child publishes its report at the absolute path in the brief. Its first line is exactly `STATUS: done`, `STATUS: blocked` or `STATUS: failed`. All three give `wait` exit 0.

Use the fields below in order. Use `None` for an empty section. Include Artifacts only when requested, and Decisions only for answers decided without the user under [auto.md](auto.md#decisions).

```text
STATUS: done
BRANCH: <branch>
CHECKOUT: <absolute path>
HEAD: <full SHA>

## Commits
<git log --oneline <base>..HEAD>

## Checks
<command, actual result and required evidence paths>

## Review
<role-dependent result>

## Out of scope
<what — where (path:line) — why it is out of scope>

## Artifacts
<one absolute path per file created or changed for the task>

## Decisions
- <question> — <answer> — <who answered> — <basis>

## Questions
<when blocked: question, options and recommendation>
```

On a block or failure, record the current checkout, partial work and reason. Identify checks or reviews that did not run. Include decisions made by descendants. When the task requests reusable suite evidence, link every suite record in Checks, including partial and failed runs. The caller verifies [suite handoff](../../independent-review/references/checkout-state.md#run-and-hand-off-a-suite) before reuse.

A phase agent handing a worker back to its orchestrator uses a separate format. Its status and last message are identical: `STATUS: waiting`, then `Handoff record: <absolute path>`, then the record's `## Waiting` block verbatim. This applies to a running worker or one awaiting start or continuation. Only the three worker status lines above end a helper wait. See [Phase endings](nested-calls.md#phase-endings).

## Role-dependent results

- **Implementer.** In Review, give the final refine result alongside the derived reviewer verdict. Use `CLEAN` or `CLEAN EXCEPT DISPUTED` with the disputed findings. Deferring a finding preserves the derived verdict.
- **Reviewer.** Use `done` when the assignment finishes, including with findings. Identify the reviewed branch, checkout and HEAD. Commits is `None`. Separate your checks from inherited evidence. Put the absolute answer file in Artifacts. For native review, name it in Review and write `Verdict: derived by the caller`. For a caller-defined cross-check, give its raw outcome and answer path. On a block or failure, report progress and reason without a final verdict. The controller reports its own dialog counts.

## Publication and reading

Publish the complete report atomically, for example by renaming a finished sibling file. The parent reads the exact first line, then the sections its task needs. For `blocked`, read Questions and rename the file to an unused `<file>-blocked-<n>` before sending the answer. The child publishes a fresh report at the original path. The parent never edits a child's report.
