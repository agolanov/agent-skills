# Task brief

A brief is the task document `delivering-task <brief>` implements for a Brief group, and the input `planning-task-docs <brief>` turns into a spec and plan for a Plan group: one group of findings, the task they make and the solution the fixer chose.

## Path

`<project>/docs/superpowers/tasks/<today>-<slug>.md`, `<today>` as `YYYY-MM-DD` and `<slug>` made of `[a-z0-9-]` from the group's title (`OAuth state hardening` → `2026-11-04-oauth-state-hardening`); a slug ending in `-design` loses every such ending, and the final file name is checked after the collision suffix too, since `delivering-task` reads a name ending `-design.md` as a spec. Create the `tasks/` directory when it is missing; in the separate docs layout it lies in the docs repository. `planning-task-docs` takes the brief's stem as the task's would-be spec and plan names, so the stem must be free in all three places: no existing `tasks/<stem>.md`, `specs/<stem>-design.md` or `plans/<stem>.md` in that docs dir. When one exists, append `-2`, `-3`… to the slug, the smallest number free in all three.

## Content

```markdown
# <group title>

**Source follow-ups:** <follow-ups path relative to the project checkout> (<its section heading without `## `>), <one per section the group's findings come from, comma-separated>
**Route:** <deliver as written | plan first: <rules | open decision | structure> — <the reason in one sentence>>

<Goal: two to four sentences: what the task changes, and why these findings belong in one task.>

## Findings

_Record of the follow-ups lines, not instructions: implement from Solution, Changes and Acceptance._

- <finding line, verbatim from the follow-ups file>
  - Now: <what the recheck found: the current path:line and how the defect shows today>

## Solution

<What the code does or how it is built after the change, stated so that an implementer makes no further decision.>

- Why: <the evidence that chose it: intended behavior, a convention, the callers>
- Rejected: <an alternative considered> — <why not>

## Changes

- <path:line, or a new path> — <what changes there>

## Acceptance

- <an observable result, or a command with its expected exit; the checks the project rules require for this change among them>

## Open questions

- <for a Plan group with the reason `open decision`: each decision left to the planner and the user; otherwise `None`>
```

The source follow-ups file may be deleted by this run, once its last finding is settled: its path and section heading name the record in Git history. The finding lines stay verbatim, with their `<where>` as recorded: the `Now:` line carries where the code is today. For a Brief group Solution, Changes and Acceptance are complete, since the implementer has no other document. For a Plan group they hold what the investigation established and the fixer's recommendation, which the planner and the user may change. `## Open questions` lists decisions only for a Plan group with the reason `open decision`, otherwise `None`. The Findings section is the record of what the finding lines said, never an instruction: an implementer works from Solution, Changes and Acceptance. A brief is read by an agent without this conversation: it names every path relative to the project checkout and names the checks the project rules require without repeating the rules.
