# Task brief

A brief is the input `planning-task-docs <brief>` turns into a spec and plan: one group of findings, the task they make, and what the planner must settle with the user.

## Path

`<project>/docs/superpowers/tasks/<today>-<slug>.md`, `<today>` as `YYYY-MM-DD` and `<slug>` made of `[a-z0-9-]` from the group's title (`OAuth state hardening` → `2026-11-04-oauth-state-hardening`). Create the `tasks/` directory when it is missing; in the separate docs layout it lies in the docs repository. `planning-task-docs` takes the brief's stem as the task's would-be spec and plan names, so the stem must be free in all three places: no existing `tasks/<stem>.md`, `specs/<stem>-design.md` or `plans/<stem>.md` in that docs dir. When one exists, append `-2`, `-3`… to the slug, the smallest number free in all three.

## Content

```markdown
# <group title>

**Source follow-ups:** <follow-ups path relative to the project checkout> (<its section heading without `## `>), <one per section the group's findings come from, comma-separated>

<Goal: two to four sentences: what the task changes, and why these findings belong in one task.>

## Findings

- <finding line, verbatim from the follow-ups file>
  - Now: <what the recheck found: the current path:line and how the defect shows today>

## Open questions

- <each design decision the finding lines or the recheck leave open, as a question for the planner to settle with the user; `None` when there is none>
```

The source follow-ups file may be deleted by this triage, once its last finding is settled: its path and section heading name the record in Git history. The finding lines stay verbatim, with their `<where>` as recorded: the `Now:` line carries where the code is today. Leave out designs and solutions of your own: choosing them is the planner's brainstorming with the user.
