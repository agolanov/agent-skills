---
name: consolidating-plans
description: Use when the user explicitly asks to consolidate an implementation plan into larger dispatch units before subagent execution
---

# Consolidating Plans

## Overview

Plans written task-by-task are often over-atomized: every tiny task costs a full subagent dispatch plus a review gate. This skill is a manual post-pass over a written plan: merge adjacent tasks into larger dispatch units — one group = one implementer subagent = one review gate — while preserving every test cycle and checkbox step.

## When to Use

- The user explicitly invoked this skill on a plan file.
- Between writing a plan and executing it with subagents.

**When NOT to use:** never auto-run it after writing a plan; do not use while execution is already underway.

## Process

1. **Locate the plan.** Use the path the user gave; otherwise ask. If the file has uncommitted changes, offer to commit them first.
2. **Parse tasks.** For each task note: files touched, interfaces (Consumes/Produces or similar), test cycle. If you cannot identify distinct tasks, say so and ask for clarification — do not guess and do not rewrite.
3. **Check the header.** If it already has a `Consolidated:` line, tell the user and ask whether to run again.
4. **Group adjacent tasks** with the rubric below. Never reorder tasks; only adjacent tasks may merge. If nothing merges, say the plan is already right-sized and leave the file untouched.
5. **Show the preview and wait for approval.** A table: group ← original tasks, merge rationale, combined files, parallel notes. Do not modify the file before the user approves. Rework the grouping if they object.
6. **Rewrite in place.** Keep the plan's header, structure, and style; add no sections of your own. The only additions are the `Consolidated: YYYY-MM-DD (N→M tasks)` header line and the per-task fields in [Output Format](#output-format).
7. **Report:** "N tasks → M groups, order preserved."

## Grouping Rubric

**Merge candidates** — adjacent tasks with at least one signal:

- they touch the same files or the same module/directory;
- the later task consumes an interface the earlier task produces.

**Deciding test — the review gate.** Merge only when a reviewer could not meaningfully reject one task while approving its neighbor. Signals alone never justify a merge: tasks with independent review risks stay separate even when they touch the same files.

*What counts as an independent review risk:* the task changes a contract observable outside the group — a breaking change, a public API / CLI flag / DB schema / wire format — or it belongs to a different subsystem. Such a task can be reverted on its own, so it gets its own gate.

*What does not:* choices internal to the module the group is building — default values, a validation policy, an error-aggregation format, which helper lives in which file. A reviewer judges those as part of "does this module work", not on their own. Adjacent tasks forming an unbroken Consumes/Produces chain inside one module or directory, none of which changes an outside contract, are one review gate — merge them.

**Task size is not a signal.** "This task is only ten lines" and "this wastes a dispatch" are not reasons to merge. A three-line breaking change carries its own review risk and stays its own dispatch unit. Every merge must name the signal *and* pass the deciding test.

**Independence is recorded, not dissolved.** When you notice a task shares no files and no interface links with its neighbors, that is a reason to keep it separate — never a reason to fold it into an adjacent group to save a subagent. Record the observation as a `Parallel-safe with:` marker (below).

**Safety valve.** A group of more than 5 original tasks, or whose file set sprawls across unrelated subsystems, must be reconsidered and split.

**Parallel notes.** A group sharing no files and no interface links with another group gets `Parallel-safe with: Task M`. It is a hint for future parallel dispatch; execution order stays sequential.

## Output Format

Each group becomes one task of the rewritten plan:

- `### Task N: <combined name>`
- `Merged from: original tasks A–B` (right under the heading)
- `Parallel-safe with: Task M` (when applicable)
- body: the original tasks' steps in their original order — every test cycle and checkbox step preserved as stages of the one task.

Unmerged tasks keep their content unchanged (only renumbered).

### Merging is concatenation, not rewriting

The body of a merged task is the bodies of the original tasks, in order, one after the other. Merge the `**Files:**` and `**Interfaces:**` blocks; renumber the `- [ ]` steps so they run 1..n across the group. Leave every step's text, code block, command, and expected result byte-identical to the original.

You are not redesigning the work. Do not fold several tasks' failing tests into one step, do not combine their verification runs, do not squash their commits, do not re-annotate their code blocks.

These counts are identical before and after — check them:

| Count | Before | After |
|-------|--------|-------|
| `- [ ]` checkbox steps | N | N |
| test-run / verification steps | N | N |
| `git commit` invocations | N | N |

If a count dropped, you rewrote instead of concatenating. Redo the group.

## Edge Cases

| Situation | Behavior |
|-----------|----------|
| Header already has `Consolidated:` | Say so; ask whether to run again |
| Nothing to merge | Say so; leave the file untouched |
| Task structure not recognizable | Say so; ask for clarification; do not rewrite |
| Plan file has uncommitted changes | Offer to commit first |

## Worked Example

See [references/example.md](references/example.md): an over-atomized 7-task plan consolidated to 4 dispatch units, including the preview table and the reasoning for merges refused.
