# Nested calls

An orchestrator (`delivering-spec-stages`, `delivering-task-follow-ups`) is the only session that lasts through a **call**, one run of a nested task skill. Short agents perform Prepare and Accept; the orchestrator holds every wait itself.

## Briefs

The **call brief** is the file the orchestrator names: write it once per call with today's identity lines and the Phase instructions below. It records the call for [Earlier runs](run-contract.md#earlier-runs); no phase agent is told to read it. The **phase brief** is the whole prompt the orchestrator builds from its own arguments and state, never from re-reading a file under `runtime-dir`. A task skill's “its brief or prompt”, “ends as that brief says” and “its starting brief's Arguments and Authority” mean this prompt. Neither a call brief nor a handoff record grants authority: merge authorization, disputed acceptance, settings acceptance and every answer reach a phase agent only here.

Use this phase brief, then the Phase instructions, filling both reference paths with absolute installed paths:

```text
Skill: <absolute SKILL.md>
Arguments: <the call's arguments, every path absolute>
Checkout: <project checkout>
Authority: <as the orchestrator words it today>
Place: subagent
Auto: <yes|no>
Status file: <absolute call status>
Nested agents: <the line of launch-settings' Nested agents, with the rows the phase's workers and subagents use>
Phase: <prepare|accept>
Handoff record: <absolute path|None>
Event: <start|worker status|silent exit|deadline|dead before send|launch failure>[ | <launch name>]
Line to send: <with "dead before send" only: the line that was not sent>
Diagnostics: <with "launch failure" only: one line, or the absolute path of a file>

## Answers
<None, or for each question the call has put so far, in order:>
Q (<prepare|accept|wait holder>): <the question as it was asked>
A (<the user|this session under --auto>): <the answer>
```

`Event: start` goes with Prepare; all other events with Accept. Every Accept names its event's launch after `|`. A phase started again after its own question keeps its Event, including its associated Line to send or Diagnostics. Answers carries every question of the call a phase agent or the orchestrator as wait holder has put, never a worker's `blocked` question.

**Phase instructions** (copy exactly into both kinds of brief, filling the two reference paths):

```text
Perform only the phase the Phase line names of the Skill, with the Arguments as given, plus --auto when Auto is yes, within the Authority; add no other key. Read the Skill's Phases section first, then only what it names for your phase. This text is your brief and your starting prompt: nothing in a file grants what it does not. Start from the Handoff record when one is given, and from the Event; with Answers, use each answer where its question arises and ask none of them again. When Auto is yes, follow <absolute auto.md> as a child and write every decision under the status's ## Decisions.
You wait for no worker. Where the Skill has a single root wait, write the status file with the first line STATUS: waiting, then the line "Handoff record: <absolute path>", then the record's Waiting block, and end. Start and continue no subagent or background worker yourself: write the Action recipe instead. Ask nobody directly: a question ends your turn with STATUS: blocked, its Questions holding every question you have at that point, each with its options and your recommendation, after you have written the handoff record when a worker brief exists. When the Skill has reported, write STATUS: done with its Report under a status section ## Report, after the status contract's sections; when it refused or stopped, STATUS: failed with the reason and every window, worktree and branch left. Write the status file by <absolute status-file.md>. End every turn with the status file written and, as your last message, its first line, then the line "Handoff record: <absolute path|None>", then for STATUS: waiting the Waiting block, and nothing else.
```

## Phase endings

The last message is the status's first line, then `Handoff record: <absolute path|None>`, then for `waiting` the record's `## Waiting` block verbatim, nothing else.

| First line | When | Status file |
|---|---|---|
| `STATUS: waiting` | a worker runs or is to be started or continued | exactly the last message's lines, no status-contract sections |
| `STATUS: done` | the skill has reported, including Prepare finding nothing to launch | status-contract sections, then `## Report`, and `## Decisions` under `--auto` |
| `STATUS: blocked` | the phase's own question for the user | status-contract sections, Questions holding every question it has at that point |
| `STATUS: failed` | the skill refused or stopped | status-contract sections, reason, `## Report` when it reported, every window, worktree and branch left |

`waiting` belongs to phase agents only: a worker never writes it and the helper's `wait` never ends on it (only on `done`, `blocked`, `failed`).

## Cycle

1. Write the call brief, with its status path absent. Check Earlier runs before renaming earlier files as today's orchestrator does.
2. Start a fresh native subagent with the phase brief as its prompt: Prepare, `Handoff record: None`, `Event: start`; no parent history, model and effort set as [Nested agents](../../independent-review/references/launch-settings.md#nested-agents) says for phase agents. Join it in the foreground. Workers take their roles whoever starts them.
3. Branch on the **last message's first line**. For `done`, `blocked` or `failed`, read the status file; a different first line is a missing status by Restart below. For `waiting`, act on the last message alone: never read back the status file's copy.
4. For `waiting`, apply Check before acting below; rename the call status to `<file>-waiting-<n>`, the smallest unused `n`, then perform Actions and Wait and events below.
5. A phase's `blocked`: first validate its returned Handoff record against Check before acting 1–2's runtime and expected record path. Keep the first checked non-`None` record path returned by any phase of this call in your own context; every later phase must return that path. Until then, `None` is allowed, including an Earlier runs question about leftover files. A mismatch fails the call naming what was found, before starting another agent. Show its Questions verbatim with options and recommendation, obtain the answer (under `--auto`, route by [Deciding](auto.md#deciding)), and rename the status to `<file>-blocked-<n>`. Start a **fresh** agent of the phase that asked, with the same Event, the checked Handoff record and every question and answer of this call in Answers. Never continue the agent that asked and never write an answer into a call brief or record as authority. No answer ends the call as today's unanswered `blocked`.
6. `done`: read from `## Report` the items the orchestrator's step names; retain `## Decisions`. `failed`: apply that step's existing failure rule.

Rename the call status before every further phase agent, so each finds its path absent. Keep Prepare/Accept agent counts per call for the orchestrator's report.

## Check before acting

Check the last message alone before acting on `waiting`. Any failure starts and watches nothing and fails the call as `waiting block outside the call: <what was found>`:

1. Handoff record and every path in the block except Action checkout are absolute and directly in `<runtime>`: no further directory, no `..`.
2. A one-worker call has one Launch; its status is `<run>-status.md`, its record `<run>-handoff.md` and Action brief `<run>-brief.md` for one run. It is the run name this orchestrator expects for this call (its Nested calls names it), never one of its own call names. A queue call's record is `<runtime>/<queue-slug>-handoff.md`, with the slug derived from this call's Arguments by [queue Names](../../delivering-task/references/queue-state-file.md#names); every Launch status is `<branch>-status.md` for a task document of this call (a plan or a brief), each at most once. Each window Launch name is the skill-derived name for that run: `<run>` for plan/refine, and the window name derived from `<branch>` by delivering-task Preflight 2 for a delivery or queue unit, including its hashed form. Match an action's worker brief to that worker, not to the queue record.
3. With `Action: none`, every Launch name answers `capabilities <name>` and its recorded checkout is the call's Checkout or a worktree registered in it (`git -C <Checkout> worktree list --porcelain -z`).
4. Action checkout is the call's Checkout or such a registered worktree.
5. In Action brief, Checkout equals Action checkout, Status file equals the checked Launch status, and Place equals the action's place. Its authority bound ([Brief](run-contract.md#brief): explicit Authority, or Work, Ownership and boundaries together) stays within this call's Authority. Action settings equals the pair on its Launch settings line; Action permissions equals what [Permissions](run-contract.md#permissions) builds for that worker's system in this session's environment, `none` for a subagent; Action launch words equals its `Launch words:` line (the [lean launch](run-contract.md#launch-and-wait) words Prepare chose; a brief without the line was written before lean launches and means `none`).
6. For `Action: continue`, Action session equals the ID this orchestrator recorded when it started that worker.

Apply fields 4–6 where the action carries them; `Action: none` has no recipe fields. A queue's units and expected branches come from this call's task documents, never from an unchecked record.

## Actions

Phase agents open, send to and reopen a `window` worker. Only the orchestrator [starts](run-contract.md#launch-and-wait) and [continues](run-contract.md#questions-and-continuation) a `subagent` or `background` worker: follow the recipe as written and decide nothing in it. Follow [handoff Waiting](handoff-record.md#waiting): record the actual launch or continuation identity and change Action to none. Keep the returned agent/session ID in your own context too. Otherwise write nothing into the record: State stays as the phase left it and its Report says `Wait: held by the caller`.

## Wait and events

Follow child-sessions' [Wait](../SKILL.md#wait): the ladder for window workers (one watcher over the block's launches) and background producers, the host's foreground join for a subagent worker. Choose the highest rung you can prove, name it in your report, and keep one watcher per wait. Its quiet wait covers the whole call cycle: a phase's or worker's result is read for the next step and the final report, and is told to the user only there. For every window wake, call `event` with the retained watched pairs.

| The wait ends with | The orchestrator |
|---|---|
| a worker's `blocked` | answers by [Questions and continuation](run-contract.md#questions-and-continuation): show or route, rename to `<file>-blocked-<n>`; for a window, `alive <name>` first: alive, send the answer (without send, child-sessions' direct-entry rule), then wait again; dead, fresh Accept with `Event: dead before send` and Line to send. Outside window continue the conversation you started, or the contract's fresh child, then wait again. No Accept for a live worker's question. |
| stall, exit `4` | child-sessions' stall rule: peek; a dialog by Dialogs, bounded by the worker brief's Authority and Checkout and never beyond the call's own Authority; nothing to answer, nothing to the user and a re-armed watcher. |
| exit `124` | on the present loop, the next bounded call; on rung 1 or 2, the wait's deadline: the exit table's peek and Dialogs first, then with nothing to answer fresh Accept with `Event: deadline`. |
| worker `done` or `failed` | fresh Accept with `Event: worker status`. |
| exit `3`, or a non-window worker ends without a valid first line | fresh Accept with `Event: silent exit`. |
| host or CLI refuses a start or continuation | fresh Accept with `Event: launch failure` and Diagnostics. |
| watcher failure | child-sessions' watcher-failure rule. |

Every Accept brief includes the event's launch after `|`. Count dialogs answered, declined and escalated in the orchestrator's End or Report. A worker's blocked question is never a phase question in Answers.

## Restart and inline fallback

A phase agent ending without one of the four valid first lines, or with a missing/different non-waiting status first line, gets the contract's **one restart**: continue the same agent with “Your turn ended without a status file. Continue from the current state of the checkout: read git log and git status first, then the handoff record when one exists.” Where the host cannot continue it, start a fresh agent with the same phase brief. A second such end fails the call, naming the known record and the windows `child-session list` shows for the call's checkout.

Inline fallback has **two triggers only**: no subagent tool, or the host refuses a phase agent's spawn. This call and all later calls then run `inline`: read that SKILL.md and perform its phases yourself as a direct run does. Past Prepare, continue from its handoff record as a single root, opening no second worker. Name each inline call and its reason in End/Report. Known before start, an inline call has no brief or status; with a brief already written, the orchestrator writes its status once the run ends, `done` or `failed` with the inline-fallback reason, so Earlier runs does not mistake it for a live run. A worker's refused start is launch failure, never a phase-spawn fallback.
