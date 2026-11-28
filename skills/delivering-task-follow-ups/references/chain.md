# Chain

After Review, run the selected Brief and Plan tasks. Brief tasks go directly to delivery; Plan tasks go through Plan and refine first. A failed task stops at its first incomplete phase, and the other tasks continue.

### Nested calls

Follow child-sessions' [nested-call setup](../../child-sessions/references/nested-calls.md#setup) and [cycle](../../child-sessions/references/nested-calls.md#cycle). Supply the absolute skill/arguments, the project checkout, today's authority for that skill's windows, documents and commits (including merge to main and cleanup for delivery), and `Auto` from this invocation.

Use call paths `<runtime>/follow-ups-<slug>-<phase>-brief.md` and `<runtime>/follow-ups-<slug>-<phase>-status.md`. Derive the slug from the first argument's file stem or directory name, replacing each character outside `[A-Za-z0-9_-]` with `-`. The phase is `plan-<k>` or `refine-<k>` in brief order, `deliver` or `deliver-2`. Expected worker identities are `plan-<brief stem>`, `refine-<plan stem>`, and the document's stem for one delivery. For a delivery queue use [the queue check](../../child-sessions/references/nested-calls.md#check-before-acting).

Take the requested fields together from each call's Report and retain its status path for diagnostics. Keep Decisions, Prepare/Accept counts, inline worker/fallback details and wait/dialog evidence for the final report.

### Plan and refine

For each Plan task, in brief order, one task at a time, since the user answers each planner's questions in its window; with no Plan task this section is skipped:

1. **Plan.** Nested call `planning-task-docs <brief>`, with `--agent` when given. Read from its Report the task's spec and plan paths.
2. **Refine.** Nested call `refining-task-docs <plan>`, with `--agent` and the reviewer flags when given. It adds the plan's spec by its own matching rules. Read from its Report each document's mark state (its new `Review:` line, `fresh, context only` or `not marked: <why>`) and the open findings.

A nested call that ends `failed`, or `blocked` without the user's answer, ends that task's chain, recorded with the skill and its reason. Nothing a phase left (window, status, documents) is undone. A refine whose Report leaves the plan `not marked` ends the chain too, with the open findings it names: an unreviewed plan is not delivered. Go on with the next task.

### Deliver

The documents delivered together are, in the order Select listed the groups, each Brief task's brief and each Plan task's plan whose refine Report shows a `Review:` mark (a new one, or `fresh, context only`); a brief carries no review mark and needs none. They go in one nested call: `delivering-task <document>...`, with `--agent`, `--impl` and the reviewer flags when given, and `--run` with the implementer's place when the user's words or the brief's `Implementer place:` line set it. One document runs `delivering-task`'s one-document path; its stops and questions are that path's own. Several documents run its queue, with `--parallel` when given and with `--independent`, since every group is a task independent of the others; `--independent` is not passed for one document, which `delivering-task` refuses it for. A `**Depends on:**` line a planner wrote still counts as the queue says. `delivering-task` stops a queue in which an explicit `--impl` is invalid for a unit's kind (`subagents` for a brief, `direct` for a plan). With `--impl` `subagents` or `direct`, pass it only to the documents it is valid for and send the others in a call without it: two nested calls when the delivery holds both kinds, the one with `--impl` first and the other as phase `deliver-2`; one call without `--impl` when only documents of the invalid kind remain. A `**Depends on:**` line naming a document of the other call puts that call first, and a document of the second call is held, not started, when a prerequisite in the first call is not verified as delivered on main after that call or when it depends on a held document; dependencies between documents of the second call stay the queue's; dependencies both ways go to the user (under `--auto`, routed by [auto.md](../../child-sessions/references/auto.md#deciding)). A first call that ends with main suspect (a failed post-merge check, the queue's integrity stop) leaves the second call unstarted. `--impl solo` and no `--impl` keep the single call. For several documents use the shared [queue cycle](../../child-sessions/references/nested-calls.md#cycle) and [queue phase rules](../../delivering-task/references/queue.md#phase-agents). Read from its Report, for each document, the merge SHA or ready branch, or its state with the worktree and branch it kept; the follow-ups path and count; and the settings lines. With no task to deliver, go to Report.
