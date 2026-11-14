---
name: delivering-task-follow-ups
description: Settles the findings of follow-ups files left after delivered tasks from one invocation, fixing the localized ones directly on the main branch in one checked, committed and reviewed batch, dropping resolved ones, and taking only those that need design or a large refactor through planning, review and delivery. Use when a task's follow-ups should be fixed, sorted out or merged without running each skill by hand.
---

# Delivering Task Follow-ups

`delivering-task-follow-ups <follow-ups file|directory>... [--run inline|background|window] [--model M|cli-default] [--effort E|cli-default] [--agent claude|codex] [--parallel N] [--impl solo|subagents|direct] [--reviewer-run background|subagent|window] [--reviewer-model M|cli-default] [--reviewer-effort E|cli-default] [--auto]`

The **fixer**, the session performing this skill, gives every finding one outcome: **fix** (fixed in the batch), **drop** (removed with no change), **brief** (moved into a task brief for the [chain](#chain)) or **keep** (left in its file). The fixes form one **batch**, made by the fixer itself on the main branch of the project checkout with no worktree, spec, plan or subagent per finding: the checks run once after all fixes, one commit holds the batch and one `review-fix-loop` reviews it. Only the brief findings go through `planning-task-docs`, `refining-task-docs` and `delivering-task`.

Keys:

- `--run` places the fixer: `inline`, the default, is this session; `background` or `window` moves the whole skill to one child ([Run elsewhere](#run-elsewhere)). Any other value, `subagent` included, stops before anything starts, naming it: the fixer starts subagents and a reviewer, which a subagent cannot hold on every host.
- `--model` and `--effort` set the fixer. Under `inline` they are refused before anything starts: "the fixer is this session". Elsewhere the launcher consumes them.
- `--review` (an older key) is refused before anything starts: the batch is always reviewed by `review-fix-loop`.
- `--reviewer-run`, `--reviewer-model` and `--reviewer-effort`: to the batch's `review-fix-loop` and to every `refining-task-docs` and `delivering-task` call of the chain.
- `--agent`: to every chain call. `--impl` and `--parallel`: to the chain's `delivering-task` call. A key not given is not passed: each nested skill resolves its own defaults, validates what it receives and decides its implementation mode. The implementer runs in `delivering-task`'s default place unless the user's words set it ("implement without a window"): announce the mapping and pass that place as `--run` to the `delivering-task` call.

Under `--auto` read child-sessions' [auto.md](../child-sessions/references/auto.md): every question below that would go to the user is routed by its Deciding, every brief this skill writes says `Auto: yes`, and the Report lists `## Decisions`.

## Run elsewhere

Under `--run background` or `window` this session is a thin launcher (run contract [Places](../child-sessions/references/run-contract.md#places)) and performs none of the sections below: a child of this session's system performs this skill `inline`, its chain included, and this session writes its brief, launches it, waits, relays its questions and reports its result.

Follow child-sessions' [Thin launchers](../child-sessions/references/run-contract.md#thin-launchers) with these local parameters.

- **Inputs.** Find the project checkout as [Input](#input) 3 says and resolve each argument to an absolute path. When the user's words set the implementer's place, announce the mapping now and add `Implementer place: <place> (the user's words)` to the brief.
- **Worker and arguments.** Role `follow-ups fixer`; consume `--run`, `--model` and `--effort`. `Arguments:` holds the absolute arguments and every other key as given. `Checkout:` is the project checkout.
- **Name.** `follow-ups-<slug>`, where `<slug>` is the first argument's file stem or directory name, with every character outside `[A-Za-z0-9_-]` replaced by `-`.
- **Authority.** The batch's fixes, briefs and follow-ups file updates, respecting the outcomes the user selected (under `--auto`, those [auto.md](../child-sessions/references/auto.md#deciding) routes); the batch commit on the main branch; `review-fix-loop`'s commits and its follow-ups writing; the chain's windows, documents, commits, merges into main and cleanup; nothing more.
- **Questions and result.** The Select question and every question the chain relays follow the shared window/blocked routing; a blocked Select question includes the table with its groups. The child writes `STATUS: done` once it has reported, or `STATUS: failed` with the reason when it stopped, and its Report under `## Report` after the status contract's sections. Report that `## Report` as this skill's Report (after `failed`, the failure and what the status lists), with the shared launch evidence.

## Preflight

1. **Checkout.** Find the project checkout as [Input](#input) 3 says. Require it, and its separate docs repository when there is one, each on its main branch, by a four-command boundary of [checkout state](../independent-review/references/checkout-state.md#direct-use-preflight) each, with process-local `GIT_OPTIONAL_LOCKS=0`; failed Git evidence stops. Uncommitted changes are allowed and stay untouched. Staged changes in the main checkout hold every merge of the chain (`delivering-task` merges only while the index equals HEAD): when there are any, name them to the user now, as information.
2. **Skills.** Locate the installed `review-fix-loop`, `planning-task-docs`, `refining-task-docs`, `delivering-task` and `child-sessions` SKILL.md files by absolute path, and read none of them yet. A missing one stops before anything runs, named for the user to install, so that no run stops for a missing skill after its batch commit.

## Input

1. Each argument is a follow-ups file (a name ending `-follow-ups.md`, or `-tails.md`, the older format of the same file) or a directory, which contributes every such file directly inside it (not recursive), in file-name order. Any other file is refused, naming it, before any work.
2. A file holds sections headed `## <branch> @ <sha7> (<YYYY-MM-DD>)` (an older file may have none); each line starting with `- ` is one finding, in the form `- <what> — <where> — <why>`. Take a line in another form (older files) as written. With no finding in any file, report "nothing to settle" and stop.
3. The project checkout is the top level of the current repository. When that top level is itself a separate docs repository (a `docs/superpowers` directory with its own repository), the project checkout is `git -C <docs-top>/../.. rev-parse --show-toplevel`; when that fails, ask the user (under `--auto`, routed by [auto.md](../child-sessions/references/auto.md#deciding)). Every follow-ups file must lie in the project checkout or in its separate docs repository (`<project>/docs/superpowers`), and a tracked one must have no uncommitted changes (`git status --porcelain=v1 -z -- <file>` empty, with `GIT_OPTIONAL_LOCKS=0`); refuse any other file, naming it and the reason, before any work. Each finding's `<where>` resolves against the project checkout.
4. Read the project rules (`AGENTS.md`, `CLAUDE.md` and the like): they decide what a fix must satisfy and which checks [Verify](#verify) runs.

## Recheck

Read every finding against the code as it is now. A finding was recorded at its section's commit, so its paths and line numbers may have moved: find the described code by its content. Read the plan beside the file (the same path without the `-follow-ups` or `-tails` suffix) and that plan's spec only when the finding cannot be understood without them. Put each finding in one class:

- **Resolved**: the defect no longer exists (fixed later, the code removed, the point made moot). Evidence: the `path:line` or commit that shows it.
- **Fix**: you can state the exact change now, and it stays local to one or a few files. A change of behaviour still belongs here, whatever checks the project rules require for it: the checks never decide the class, since [Verify](#verify) runs them once for the whole batch.
- **Large**: the finding leaves a design decision open (a behaviour, a contract or an interface to choose), or its change is a refactor across many modules or skills. It belongs in a task.
- **Disputed**: the finding's `<why>` carries two positions, or your recheck disagrees with the finding. The user decides (under `--auto`, routed by [auto.md](../child-sessions/references/auto.md#deciding)).

Put the Large findings into groups, one group per future task. Findings that share a mechanism, a module boundary or a design decision go together, and findings whose fixes depend on each other always go together, so that every group is a task independent of the others. A group may hold a single finding. Give each group a short title naming the change (`OAuth state hardening`).

The recheck is done when every finding has a class and its evidence, exact change or current `path:line`, and every Large finding has a group.

## Select

Show one table: `# | file | finding (short) | class | group | evidence or change`, followed by one line per group: its title and its findings' numbers. Propose an outcome for each finding: Fix → **fix**, Resolved → **drop**, Large → **brief** in its group; a Disputed finding gets no proposal, the user chooses among fix, drop, brief and keep. Ask the user one question: confirm or change the outcomes and the groups (move a finding, merge or split groups, retitle one, keep a finding instead of briefing it). Say in it that, on confirmation, the fixes are made, checked, committed on the main branch and reviewed by `review-fix-loop`, whose fix commits land on the main branch too, and the briefs go through planning and delivery: the answer is the consent to those commits, and no other question about them follows. No edit starts before the answer.

A finding the user moves changes the groups as the user says; a Disputed or Fix finding the user chooses to brief joins the group the user names, or a group of its own. A grouping that splits a dependency is not accepted: name the dependency and ask again. **fix** is chosen only for a finding whose exact change you can state; when the user disputes a Large finding's class, recheck it. Under `--auto` the proposed outcomes and groups are the skill's recommended options and settle this question by [auto.md](../child-sessions/references/auto.md#deciding); a Disputed finding, which has no proposal, is routed by it.

## Fix

1. Record the checkout's status (`git status --porcelain=v1 -z`, with `GIT_OPTIONAL_LOCKS=0`) before the first edit. A file with uncommitted changes holds another writer's work: never edit, revert, stage or commit it. A chosen finding whose fix needs such a file is not fixed: its outcome becomes keep, with the reason `uncommitted changes in <path>`.
2. Take the chosen findings file by file: read each file once and make every chosen change in it, each the smallest change that removes the defect, following the project rules. Run no check between fixes.
3. A fix that turns out larger than chosen (it needs a design decision) is abandoned: undo your own edits for it, change its outcome to keep with the reason, and go on.
4. Anything you notice outside the chosen findings goes into the Report, unfixed.

## Verify

After the last fix and before the commit, run once the checks the project rules require for the batch's changes, together covering every fixed finding:

- A check the rules require on the code before the change (a baseline) runs on the version at HEAD: nothing of the batch is committed yet.
- Checks independent of each other may run in parallel.
- A failing check is repaired within the batch when the repair stays inside the chosen findings. Otherwise undo the edits of the findings it implicates, change their outcome to keep with the reason, and run the checks that failed again.
- A required check that cannot run here is reported as unavailable, never replaced by another check; the commit still follows.
- Keep each check's command, cwd and exit, and for a check that is an agent run (a fresh subagent following a skill or a scenario) its record paths. A record a check writes into a tracked path the project does not ignore is an owned path of the [Commit](#commit).

Verify is done when every required check has an exit or an unavailable reason, and every fixed finding is covered by a passing check or named as uncovered. A check covers a finding only when it exercises the changed code: a suite that passes without reaching that code leaves the finding uncovered.

## Briefs and files

1. Write one brief per group that holds at least one finding with the outcome brief, from [task-brief.md](references/task-brief.md): its path, name and content rules are there. Every finding with the outcome brief stands, verbatim, in exactly one written brief.
2. In each follow-ups file, delete the lines of the fixed, dropped and briefed findings; every other line stays byte-identical, headings included (they record the original review). A section left with no `- ` line is removed, from its `## ` line to the next line starting with `## ` or the end of the file. A file left with no `- ` line is deleted. A written file has one blank line between sections and ends with exactly one newline.

## Commit

1. The owned paths are the files changed for fixes, the check records Verify named, each written brief that lies in this repository (new, so not yet tracked), and each changed or deleted follow-ups file tracked in this repository. A follow-ups file or brief the project ignores (`git check-ignore -q` exits 0) or one in the separate docs repository stays uncommitted; report where it is. With no owned path, commit nothing, report `not committed: nothing to commit` and go to the [chain](#chain); run no commit command, since `commit --` with no path commits the whole index.
2. Commit the owned paths on the current branch, with no further question: Select's answer is the consent. Stage and commit with `git --literal-pathspecs add -- <paths>` and `git --literal-pathspecs commit -m <message> -- <paths>`, each path and the message one literal shell argument, so that other staged changes stay out of the commit; `add` of a deleted follow-ups file stages its removal. The message follows the project rules; by default `follow-ups: settle <n> findings`, `<n>` the fixed, dropped and briefed findings, with one body line per finding, `fixed: <what>`, `dropped: <what>` or `brief <brief file name>: <what>`.
3. After the commit, require its changed paths (`git show --name-only --format= --no-renames <sha>`) to equal the owned paths; report a mismatch with the commit SHA.

## Review

When the batch commit holds at least one fixed finding, perform the installed `review-fix-loop` `inline` in this session, which is its loop owner, with `--reviewer-run`, `--reviewer-model`, `--reviewer-effort` and `--auto` as given and no system key. Select's answer is the request's authorization of its task-state and fix commits on the main branch, so it asks no branch confirmation. Its step 1 scope:

- **Task:** the project checkout and its main branch; the fixed task base is the full HEAD before the batch commit.
- **Requirements:** each fixed finding's line with the change made for it.
- **Task paths:** none; the uncommitted paths recorded in Fix 1 are unrelated work, excluded.
- **Checks:** the Verify checks that are commands form its suite, which it runs by its own rules. The agent-run checks are evidence, passed as completed results with their record paths and never part of the suite; its fixes start no new agent run. A required check Verify reported unavailable is passed as unavailable coverage, so the review cannot end clean; report that with its result.

Its fix commits land on the main branch. Its `clean except disputed` and `blocked` ends follow its own rules; a blocked review is reported and the chain still runs. Write its deferred, outside-scope and disputed findings by `delivering-task`'s [Write follow-ups](../delivering-task/references/follow-ups.md) with `--doc <dir>/<stem>-fixes.md`, where `<dir>` and `<stem>` are the directory and the stem without `-follow-ups` or `-tails` of the first follow-ups file Input took (no document needs to exist at that path), `--branch fixes-<batch commit sha7>`, `--head` the reviewed HEAD and `--checkout` the repository holding `<dir>`. Its Commit section decides whether the file is committed or written locally. With no such finding, write nothing.

## Chain

With no brief, go to [Report](#report). Otherwise read child-sessions' [run-contract.md](../child-sessions/references/run-contract.md), [brief-writing.md](../child-sessions/references/brief-writing.md), [status-file.md](../child-sessions/references/status-file.md) and [platform-runtime.md](../child-sessions/references/platform-runtime.md), resolve its installed platform entrypoint by absolute path and set `<runtime>` from its `runtime-dir`. Also read child-sessions SKILL.md Wait, Dialogs and Other operations and environment, and [handoff-record.md Waiting](../child-sessions/references/handoff-record.md#waiting); read launch-settings Child settings check and Places only when a Waiting block carries `Action: start` or `continue`. The chain starts after Review, so that its planners see the fixed code. A **task** is one brief, followed through its plan, review and delivery; a task's chain ends at the first phase that does not reach its result, and the other tasks go on.

### Nested calls

Each `planning-task-docs`, `refining-task-docs` and `delivering-task` run below follows run contract [Nested calls](../child-sessions/references/run-contract.md#nested-calls):

1. **Brief.** With `<slug>` as Run elsewhere names it, write `<runtime>/follow-ups-<slug>-<phase>-brief.md`, status `<runtime>/follow-ups-<slug>-<phase>-status.md` absent. Phase is `plan-<k>` or `refine-<k>` for task k in brief order, or `deliver`. Check Earlier runs before renaming earlier files to `<file>-old-<n>`, the smallest unused n. Identity lines: `Skill:` the absolute SKILL.md Preflight 2 located; `Arguments:` those the section names, every path absolute; `Checkout:` the project checkout; `Authority:` that skill's windows, documents and commits, and for `delivering-task` its merges into main and cleanup, nothing more; `Place: subagent`; `Auto:` yes under `--auto`, else no; `Status file:`. Append the contract's Phase instructions exactly, with absolute auto.md and status-file.md paths; no Launch settings or Opened line, since phase agents use the host's default settings, neither set nor verified.
2. **Cycle.** Build every phase brief from this session's arguments and state and perform the shared cycle, with this session holding every wait. Expect worker run names: plan `plan-<brief stem>`; refine `refine-<plan stem>`; one-plan delivery the plan's stem; several plans, the contract's queue rule (each Launch status matches a plan's branch, once). These never name this orchestrator's own calls. Read the Report items each section names; retain Decisions, agent counts and this session's wait/dialog evidence. Archive call statuses as `<file>-waiting-<n>` before acting on Waiting, or `<file>-blocked-<n>` before an answer.
3. **Inline fallback.** Only no subagent tool or a refused phase spawn invokes the shared fallback for this call and later calls. Read that SKILL.md then and perform it as a direct run; past Prepare continue from its record as one root, opening no second worker. Name every inline call and reason in Report; its brief and status follow the shared contract's inline rule.

### Plan and refine

For each task, in brief order, one task at a time, since the user answers each planner's questions in its window:

1. **Plan.** Nested call `planning-task-docs <brief>`, with `--agent` when given. Read from its Report the task's spec and plan paths.
2. **Refine.** Nested call `refining-task-docs <plan>`, with `--agent` and the reviewer flags when given. It adds the plan's spec by its own matching rules. Read from its Report each document's mark state (its new `Review:` line, `fresh, context only` or `not marked: <why>`) and the open findings.

A nested call that ends `failed`, or `blocked` without the user's answer, ends that task's chain, recorded with the skill and its reason. Nothing a phase left (window, status, documents) is undone. A refine whose Report leaves the plan `not marked` ends the chain too, with the open findings it names: an unreviewed plan is not delivered. Go on with the next task.

### Deliver

The tasks whose refine Report shows the plan with a `Review:` mark (a new one, or `fresh, context only`) are delivered together in one nested call: `delivering-task <plan>...`, their plans in brief order, with `--agent`, `--impl` and the reviewer flags when given, and `--run` with the implementer's place when the user's words or the brief's `Implementer place:` line set it. One plan runs `delivering-task`'s one-document path; its stops and questions are that path's own. Several plans run its queue, with `--parallel` when given and with `--independent`, since every group is a task independent of the others; `--independent` is not passed for one plan, which `delivering-task` refuses it for. A `**Depends on:**` line a planner wrote still counts as the queue says. Under phase agents, several plans follow [queue Phase agents](../delivering-task/references/queue.md#phase-agents) and its [queue record](../delivering-task/references/queue-state-file.md#queue-record): one watcher over the block's launches, a fresh Accept per event, no agent between events. This session answers a live unit worker's blocked status and waits again; a done event gets Accept to verify, merge or return that unit and drain what the queue allows. Every phase agent's blocked status, a queue question or one unit's, is relayed through the shared cycle to a fresh agent of that phase. Every other question of the queue (an already merged unit, leftovers to resume or discard) follows that rule too. Read from its Report, for each plan, the merge SHA or ready branch, or its state with the worktree and branch it kept; the follow-ups path and count; and the settings lines. With no task to deliver, go to Report.

## Report

- A table of every finding: `# | file | class | outcome` (fixed, dropped, brief `<brief file name>`, kept with reason, abandoned with reason).
- The files changed, each check with its command and exit (or its unavailable reason), run once, and the batch commit SHA or `not committed: <reason>`; each follow-ups file updated, deleted or left local.
- The review: `review-fix-loop`'s final verdict, rounds and commits, its deferred and disputed findings, and the follow-ups file they were written to with its count and commit (or where it was written locally); or `review skipped: no fixed finding`.
- The briefs, in the order Select listed the groups, and a table of their tasks: `task | brief | spec | plan | refine | delivery | merge SHA | follow-ups count`, each phase's outcome as its nested call's Report gave it, `-` for a phase the chain did not reach, and the reason where a chain ended.
- The settings lines of the delivery's Report, and for each call: phase agents: `subagent`, the host's default settings, not verified; `<p>` Prepare and `<a>` Accept agents. Add this session's own `Wait:` line and dialog counts (answered, declined, escalated), each worker whose inline place ran as `subagent`, and each call that ran `inline` with the shared contract's reason.
- Under `--auto`, the `## Decisions` of [auto.md](../child-sessions/references/auto.md#decisions): this session's own and those of every nested call's status.
- What remains, as commands to run by hand:
  - each task whose chain ended, with the next skill for it (`planning-task-docs <brief>`, `refining-task-docs <plan>`, `delivering-task <plan>`, or `delivering-task <plan> --resume` when its delivery left a branch or worktree), and where to look (the nested call's brief and status file, its last phase's handoff record including the queue record/state file for a queue, and the worker status file and window its Report names). After a stop inside a cycle, a rerun derives states from Git and the documents: a planner/refiner's live window is its skill's own refusal when that call runs again; a delivery branch/worktree takes resume or discard. Settle Earlier runs before another watcher on a possibly live child;
  - each follow-ups file still holding kept findings, with its count of `- ` lines, and anything noticed outside the chosen findings;
  - each follow-ups file the review or the delivered tasks left, for another `delivering-task-follow-ups` run. This run does not take them up itself.
