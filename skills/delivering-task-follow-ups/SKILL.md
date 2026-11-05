---
name: delivering-task-follow-ups
description: Takes the follow-ups left after delivered tasks to their final outcome from one invocation, fixing the small findings, dropping resolved ones, and turning the groups that need design into tasks that are planned, reviewed and delivered to the main branch through the existing task skills. Use when a task's follow-ups should all be settled and merged without running each skill by hand.
---

# Delivering Task Follow-ups

`delivering-task-follow-ups <follow-ups file|directory>... [--review] [--agent claude|codex] [--parallel N] [--execution inline|subagents|direct] [--model M|cli-default] [--effort E|cli-default] [--reviewer-model M|cli-default] [--reviewer-effort E|cli-default]`

The root writes no code and no document of its own. Every phase is a sub-skill's sections, read from its installed SKILL.md at run time and performed exactly as written, with that skill's own questions, child windows, settings checks, verification and stops; every brief, question and refusal is that skill's text, never a paraphrase. This skill decides what runs next (the choice each sub-skill leaves to the user) and with which arguments, and reports. It asks no question of its own.

A **task** here is one brief the triage writes, followed through its plan, review and delivery. A task's **chain** ends at the first phase that does not reach its result; the other tasks go on.

## Preflight

1. **Checkout.** The project checkout is found as `triaging-task-follow-ups` Input 3 finds it. Require it, and a separate docs repository when there is one, on its main branch, as `delivering-task` [queue](../delivering-task/references/queue.md) Preflight 1 does: the small fixes land on main, and every merge goes there. Uncommitted changes are allowed and stay untouched. Staged changes in the main checkout hold every merge (`delivering-task` Merge 2): when there are any, name them to the user now, as information, so that they can be committed or unstaged before the deliveries reach their merges.
2. **Skills.** Locate the installed `triaging-task-follow-ups`, `planning-task-docs`, `refining-task-docs` and `delivering-task`, and read each SKILL.md and its references completely; locate the skills they run in turn, `child-sessions` and `independent-review`. A missing one stops before anything runs, named for the user to install, so that no run stops for a missing skill after its triage commit. Each sub-skill still checks its own dependencies when it runs.
3. **Agent.** Take `--agent`, else identify the root's own system from session identity as independent-review's [Session system](../independent-review/SKILL.md#session-system) does; an unknown identity requires clarification. Every sub-skill that takes `--agent` gets it. Planner and refiner settings are each sub-skill's own role defaults; `--execution`, `--model`, `--effort` and `--parallel` go to `delivering-task` only, and `--reviewer-model`/`--reviewer-effort` to every `refining-task-docs` and `delivering-task` run.

## Triage

Perform `triaging-task-follow-ups` with the given files and directories, plus `--review` when given, Input through Report. A stop or refusal there ends the run: go to Report. The tasks are the briefs its Report lists, in that order. With no brief, go to Report: every finding is fixed, dropped or kept.

## Plan and refine

For each task, in brief order, one task at a time, since the user answers each planner's questions in its window:

1. **Plan.** Perform `planning-task-docs <brief> --agent <agent>`, Input through Report. Its Report names the task's spec and plan.
2. **Refine.** Perform `refining-task-docs <plan> --agent <agent>` with the reviewer flags, Input through Report. It adds the plan's spec by its own matching rules.

A phase that refuses, stops, or ends `failed` or `blocked` without the user's answer ends that task's chain, recorded with the skill and its reason; nothing it left (window, status, documents) is undone. A refine whose Report leaves the plan `not marked` (no clean verdict) ends the chain too, with the open findings it names: an unreviewed plan is not delivered. Go on with the next task.

## Deliver

The tasks whose refine Report shows the plan with a `Review:` mark (a new one, or `fresh, context only`) are delivered together: perform `delivering-task <plan>...`, their plans in brief order, with the agent, `--parallel`, `--execution`, `--model`, `--effort` and the reviewer flags as given, through its final report. With several plans, the queue's Dependencies bullet makes a plan without a `**Depends on:**` line depend on the previous one unless the user says they are independent: the user said so by confirming the groups at the triage's Select, where every group is a task independent of the others. Give the queue that answer and show it to the user as one line; a `**Depends on:**` line a planner wrote still counts as the queue says. Every other question of the queue (an already merged unit, leftovers to resume or discard) is the queue's own, asked as it says. With no task to deliver, go to Report.

## Report

- The triage's finding table (`# | file | class | outcome`), its commit or `not committed: <reason>`, and its review result when `--review` ran.
- A table of the tasks: `task | brief | spec | plan | refine | delivery | merge SHA | follow-ups count`, each phase's outcome as its skill reported it, `-` for a phase the chain did not reach, and the reason where a chain ended. The follow-ups count comes from `delivering-task`'s report for each delivered task.
- What remains, as commands to run by hand:
  - each task whose chain ended, with the next skill for it (`planning-task-docs <brief>`, `refining-task-docs <plan>` or `delivering-task <plan>`), and where to look (the status file and window the stopping skill names);
  - each follow-ups file still holding kept findings, with its count of `- ` lines;
  - each follow-ups file the delivered tasks left, for another `delivering-task-follow-ups` run. This run does not take them up itself.
