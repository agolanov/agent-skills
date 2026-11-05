---
name: consolidating-plans
description: Use when the user explicitly asks to consolidate an implementation plan into larger dispatch units before subagent execution
---

# Consolidating Plans

`consolidating-plans <plan> [--run inline|subagent|background|window] [--model M|cli-default] [--effort E|cli-default]`

## Overview

Plans written task-by-task are often over-atomized: every tiny task costs a full subagent dispatch plus a review gate. This skill is a manual post-pass over a written plan: merge adjacent tasks into larger dispatch units — one group = one implementer subagent = one review gate — while preserving every test cycle and checkbox step.

`--run` places the skill. By default (`inline`) the current session consolidates the plan, and `--model` and `--effort` are refused before anything starts: the worker is this session. `subagent`, `background` or `window` move the whole skill to a child ([Run elsewhere](#run-elsewhere)).

## When to Use

- The user explicitly invoked this skill on a plan file.
- Between writing a plan and executing it with subagents.

**When NOT to use:** never auto-run it after writing a plan; do not use while execution is already underway.

## Run elsewhere

Under `--run subagent`, `background` or `window` this session is a thin launcher (run contract [Places](../child-sessions/references/run-contract.md#places)) and performs none of the Process steps: a child of this session's system performs this skill `inline`, and this session writes its brief, launches it, waits, relays its questions and reports its result. A `--run` value other than the four places stops before anything starts.

1. **Before launch.** Read the installed `child-sessions/SKILL.md`, its `references/brief-writing.md`, `references/status-file.md` and `references/run-contract.md`; resolve its platform entrypoint by absolute path and set `<runtime>` from `runtime-dir`. Refuse before anything starts, naming the combination, what run contract [Refused combinations](../child-sessions/references/run-contract.md#refused-combinations) refuses for the place. Locate the plan as Process step 1 does (the path the user gave, else ask); the checkout is its `<repo>`, or the plan's directory when the plan lies outside any Git repository. A Codex `background` child for a plan outside any Git repository is refused before launch, naming the combination: `codex exec` does not run outside a Git repository with the run contract's arguments.
2. **Settings.** Resolve the worker's settings for role `planner` per [launch settings](../independent-review/references/launch-settings.md#precedence): `--model`/`--effort` are explicit values, `cli-default` is a per-field [opt-out](../independent-review/references/launch-settings.md#cli-defaults-opt-out), every other field takes the role default; resolve and pass the pair as launch settings [Places](../independent-review/references/launch-settings.md#places) says for the place. An unresolved or unsupported pair, or one the place cannot select and verify, stops before launch, naming the place and the pair.
3. **Brief.** `<slug>` is the plan's file stem, with every character outside `[A-Za-z0-9_-]` replaced by `-`: window `consolidate-<slug>`, brief `<runtime>/consolidate-<slug>-brief.md`, status `<runtime>/consolidate-<slug>-status.md`, `background` run directories `<runtime>/consolidate-<slug>-run-<n>`. A live window of that name is refused, naming it; leftover runtime files of that name are renamed `<file>-old-<n>`, `n` the smallest unused number. Write the run contract [brief](../child-sessions/references/run-contract.md#brief): `Skill:` this SKILL.md; `Arguments:` the plan's absolute path and every key given except `--run`, `--model` and `--effort`; `Checkout:` the checkout of step 1; `Authority:` the commit of the plan alone that Process step 1 makes, and the rewrite of the plan in place after the user's approval, nothing more; `Place:`; `Auto: no`; `Status file:`; then the `Launch settings:` line of launch settings [Record](../independent-review/references/launch-settings.md#record). Tell the child to read the Skill completely and perform it `inline` with the Arguments, within the Authority, and to write the status by status-file.md, `STATUS: done` once it has reported and `STATUS: failed` with the reason when it stopped, with its Report under a status section `## Report`, after the status contract's sections. The questions of Process steps 2, 3 and 5 (a clarification, the re-run question, the preview approval): in a `window` the child asks the user there; in `subagent` and `background` each question ends its turn with `STATUS: blocked` holding the question, options and its recommendation (the preview table included), and every turn ends with the status file written and its exact first line as the child's last message.
4. **Launch and wait.** Append the `Opened:` line, then launch and wait by run contract [Launch and wait](../child-sessions/references/run-contract.md#launch-and-wait): a `window` through child-sessions' `open --agent <this session's system>` with the pair, omitting a `cli-default` field; a `subagent` with the pair set by the host's native controls; a `background` CLI with the pair and the [Permissions](../child-sessions/references/run-contract.md#permissions) arguments, since the child edits and commits. Run the early child settings check at the first status after each opening; only a mismatch stops for the user's continue-or-stop question. A `blocked` status: show its Questions verbatim with options and recommendation, obtain the user's answer and continue by run contract [Questions and continuation](../child-sessions/references/run-contract.md#questions-and-continuation).
5. **Finish.** After `done` or `failed`, run the final [child settings check](../independent-review/references/launch-settings.md#child-settings-check), then report the status's `## Report` as this skill's report (after `failed`, the failure and what the status lists), one settings line (role `planner`, effective model and effort with their sources, the check outcome and record paths, or the user's acceptance) and, for `background`, each producer exit and session ID. After `done`, `close` a window; otherwise it stays with the status for the user.

## Process

1. **Locate the plan.** Use the path the user gave; otherwise ask. `<repo>` is `git -C <plan-dir> rev-parse --show-toplevel` and `<rel>` the plan's path relative to it; when `rev-parse`, run with `LC_ALL=C`, fails with `not a git repository`, the plan lies outside any Git repository, has nothing to commit, and the skill continues (say so in a short clause, no question); any other `rev-parse` failure stops, reporting Git's error. Run `git -C <repo> --literal-pathspecs status --porcelain=v1 -z --untracked-files=all -- <rel>`: its output alone decides whether the plan has uncommitted changes. When it prints an entry (the plan is untracked, or has staged or unstaged changes), commit the plan alone first, without asking: `git -C '<repo>' --literal-pathspecs add -- '<rel>'`, then `git -C '<repo>' --literal-pathspecs commit -m 'docs: <basename>' -- '<rel>'`, each path and message one literal shell argument, quoted for the shell that runs it (inside POSIX single quotes a single quote is written `'\''`; inside PowerShell single quotes it is doubled). Tell the user `committed <rel> <sha7>`. The pathspec commits the plan alone: other staged changes stay staged, unstaged and untracked paths stay as they are, and when the plan is one side of a staged rename only its own path is committed. When it prints nothing, run `git -C <repo> check-ignore -q -- <rel>`: exit 0 means the plan is ignored, so it is not committed and you say so in one line; exit 1 means it is not ignored, there is nothing to commit, and you continue. Any other failure of the status, `check-ignore`, `add` or `commit` command stops, reporting Git's error.
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
| Plan file has uncommitted changes | Commit it alone first, without asking |

## Worked Example

See [references/example.md](references/example.md): an over-atomized 7-task plan consolidated to 4 dispatch units, including the preview table and the reasoning for merges refused.
