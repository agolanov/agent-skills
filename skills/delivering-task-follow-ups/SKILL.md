---
name: delivering-task-follow-ups
description: Use when findings left in a delivered task's follow-ups files need investigation, correction and verification, including difficult defects, or when follow-ups that require new behavior or architectural decisions need to become tasks and be delivered.
---

# Delivering Task Follow-ups

`delivering-task-follow-ups <follow-ups file|directory>... [--run inline|background|window] [--model M|cli-default] [--effort E|cli-default] [--agent <claude|codex>[:<command>]] [--parallel N] [--impl solo|subagents|direct] [--reviewer-run background|window] [--reviewer-model M|cli-default] [--reviewer-effort E|cli-default] [--reviewer-agent <claude|codex>[:<command>]] [--reviewer-dual] [--auto]`

The **fixer**, the session performing this skill, gives every finding one outcome: **fix** (fixed in the batch), **drop** (removed with no change), **brief** (moved into a task brief for the [chain](#chain)) or **keep** (left in its file because the user chose so or a blocker held). The fixes form one **batch**, made by the fixer itself on the main branch of the project checkout with no worktree, spec, plan or implementing subagent per finding: the checks run once after all fixes, one commit holds the batch and one `review-fix-loop` reviews it. Use a [researcher](#difficult-findings) when the cause or safe fix remains unclear. A brief of the class Brief goes to `delivering-task` as written; a brief of the class Plan goes through `planning-task-docs` and `refining-task-docs` first. The aim: the run ends with no finding left in the input files other than those kept by the user's choice or a blocker.

Keys:

- `--run` places the fixer: `inline`, the default, is this session; `background` or `window` moves the whole skill to one child ([Run elsewhere](#run-elsewhere)). Any other value, `subagent` included, stops before anything starts, naming it: the fixer starts subagents and a reviewer, which a subagent cannot hold on every host.
- `--model` and `--effort` set the fixer. Under `inline` they are refused before anything starts: "the fixer is this session". Elsewhere the launcher consumes them.
- `--review` (an older key) is refused before anything starts: the batch is always reviewed by `review-fix-loop`.
- `--reviewer-run`, `--reviewer-model`, `--reviewer-effort`, `--reviewer-agent <claude|codex>[:<command>]` and `--reviewer-dual`: to the batch's `review-fix-loop` (the last two as its `--claude`, `--codex` or `--dual`, a launch command as `=<command>`) and, as given, to every `refining-task-docs` and `delivering-task` call of the chain. `--reviewer-run subagent` is refused before anything starts, naming `background` and `window`: a native subagent has no native review command. Refused before anything starts too, naming the key and its value: `--reviewer-agent` with a value whose system part is other than `claude` or `codex`; `--reviewer-agent` together with `--reviewer-dual`; `--reviewer-dual` together with any `--reviewer-model`, `cli-default` included (under the dual review `review-fix-loop` asks which reviewer a `--reviewer-model` is for, and no key says which). These refusals belong to this key list, before anything starts: under [Run elsewhere](#run-elsewhere) the launcher applies them before launching. The user's words choosing a reviewer ("a dual review by Claude and Codex", "let Claude review it") count as these keys: map them at entry and announce the mapping, then carry the keys themselves, since neither a chain call nor a child sees the words: in the chain calls' arguments and, under Run elsewhere, in `Arguments:`.
- `--agent`: to every chain call. `--impl` and `--parallel`: to the chain's `delivering-task` call, `--impl` as [Deliver](#deliver) says for mixed documents. A key not given is not passed: each nested skill resolves its own defaults, validates what it receives and decides its implementation mode. The implementer runs in `delivering-task`'s default place unless the user's words set it ("implement without a window"): announce the mapping and pass that place as `--run` to the `delivering-task` call.

Under `--auto` read child-sessions' [auto.md](../child-sessions/references/auto.md): every question below that would go to the user is routed by its Deciding, every brief this skill writes says `Auto: yes`, and the Report lists `## Decisions`.

## Run elsewhere

For `--run window` or `background`, follow [Launch the fixer](references/launch-fixer.md).

## Preflight

1. **Checkout.** Find the project checkout as [Input](#input) 3 says. Require it, and its separate docs repository when there is one, each on its main branch, by a four-command boundary of [checkout state](../independent-review/references/checkout-state.md#direct-use-preflight) each, with process-local `GIT_OPTIONAL_LOCKS=0`; failed Git evidence stops. Uncommitted changes are allowed and stay untouched. Staged changes in the main checkout hold every merge of the chain (`delivering-task` merges only while the index equals HEAD): when there are any, name them to the user now, as information.
2. **Skills.** Locate the installed `review-fix-loop`, `planning-task-docs`, `refining-task-docs`, `delivering-task` and `child-sessions` SKILL.md files by absolute path, and read none of them yet. A missing one stops before anything runs, named for the user to install, so that no run stops for a missing skill after its batch commit.

## Input

1. Each argument is a follow-ups file (a name ending `-follow-ups.md`, or `-tails.md`, the older format of the same file) or a directory, which contributes every such file directly inside it (not recursive), in file-name order. Any other file is refused, naming it, before any work.
2. A file holds sections headed `## <branch> @ <sha7> (<YYYY-MM-DD>)` (an older file may have none); each line starting with `- ` is one finding, in the form `- <what> — <where> — <why>`. Keep older finding formats as written. With no finding in any file, report "nothing to settle" and stop.
3. The project checkout is the top level of the current repository. When that top level is itself a separate docs repository (a `docs/superpowers` directory with its own repository), the project checkout is `git -C <docs-top>/../.. rev-parse --show-toplevel`; when that fails, ask the user (under `--auto`, routed by [auto.md](../child-sessions/references/auto.md#deciding)). Every follow-ups file must lie in the project checkout or in its separate docs repository (`<project>/docs/superpowers`), and a tracked one must have no uncommitted changes (`git status --porcelain=v1 -z -- <file>` empty, with `GIT_OPTIONAL_LOCKS=0`); refuse any other file, naming it and the reason, before any work. Each finding's `<where>` resolves against the project checkout.
4. Read the project rules (`AGENTS.md`, `CLAUDE.md` and the like): they decide what a fix must satisfy and which checks [Verify](#verify) runs.

## Recheck

Investigate every finding against the code as it is now before choosing its route. Locate the current code even when the recorded location has moved. Use [Difficult findings](#difficult-findings) if initial investigation cannot establish the cause or a safe correction. Consult the adjacent plan and its spec only when needed to understand the finding. Answer three questions for every finding, in this order, each from evidence in the current code: is it current (does what it describes still exist), is it confirmed (a defect or a needed change, or the code stands as it should), and, for a current and confirmed finding, what is the best solution. Put each finding in one class (capitalised they are classes; in lower case a brief and a plan are documents):

- **Resolved**: the defect no longer exists (fixed later, the code removed, the point made moot). Evidence: the `path:line` or commit that shows it.
- **Declined**: current, but not to be changed. Three cases, each with its evidence: the recheck contradicts the finding and the described behavior is correct (the `path:line`, test or document that shows it); the spec, the plan or the project rules mandate the behavior and the finding names no harm beyond disagreeing with them (the quoted mandate); the finding's `<why>` records a decision already made to leave it, an owner's decision or an accepted risk, and a revisit condition recorded with it (`revisit only if …`) has not come (the quoted record, and for a revisit condition the `path:line` showing it has not come).
- **Fix**: investigation establishes a correction to the intended behavior or existing contract. This is the default for confirmed defects, including changes across several files or modules. The fixer chooses ordinary implementation details. Required checks never decide the class, since [Verify](#verify) runs them once for the whole batch.
- **Brief**: resolving the finding requires choosing new behavior, changing a public contract or substantially restructuring the architecture; the fixer has chosen the solution, and one brief can state it so that an implementer needs no further decision. It is delivered from its brief.
- **Plan**: a task that meets the same threshold (new behavior, a changed public contract or substantial restructuring) and that a brief cannot carry, for one of three reasons the fixer names. `rules`: the project rules require a spec or a plan for a change of this kind. `open decision`: a decision about what the result should do stays open after the investigation, since the code, the project's documents and the finding's record do not settle it, and it is the owner's to make. `structure`: the solution needs a design a brief cannot hold, such as new interfaces, data formats or a migration across modules, or work in stages whose later steps depend on the design of the earlier ones. Difficulty, file count and the amount of code alone do not qualify. Without one of the three reasons the class is Brief.

A reason to wait recorded in `<why>` is evidence to weigh, never a class. A decision already made gives Declined. A decision *left* to someone (`the owner's call`, `needs a decision on …`) is not a decision made: the fixer makes it when the code and documents settle it (Fix or Brief), otherwise the finding is Plan with `open decision`. A deferral for scope or time (`deferred minor`, `out of scope`, `deferred at the round limit`) is no reason to leave a defect: the finding takes Fix, Brief or Plan by its own content. A revisit condition that has come gives no Declined.

When `<why>` carries two positions, check both against the code and choose. The finding's position confirmed gives Fix, Brief or Plan; the other position confirmed gives Declined, its evidence naming the rejected position; a question code cannot settle, about what the result should do, gives Plan with `open decision`.

For Fix record the exact correction. For Brief and Plan record the chosen solution, rationale and rejected alternatives. For Plan with `open decision`, include the recommendation and the open question.

Put the Brief and Plan findings into groups, one group per future task. Findings that share a mechanism, a module boundary or a design decision go together, and findings whose fixes depend on each other always go together, so that every group is a task independent of the others. A Fix finding whose correction depends on a Brief or Plan finding's solution joins that group and takes its class. A group may hold a single finding. A group holding at least one Plan finding is a Plan group, carrying every reason of its Plan findings; every other group is a Brief group. Give each group a short title naming the change (`OAuth state hardening`).

Finish with current evidence and a supported class for every finding. If evidence or access is unavailable, request what is missing and continue independent findings. Keep a finding only by owner choice or a concrete blocker such as a needed dirty path, a check failure repaired by undoing the fix, or unavailable evidence.

### Difficult findings

If initial investigation leaves the cause or safe correction unclear, follow the [researcher procedure](references/research.md).

## Select

Show one table: `# | file | finding (short) | class | group | evidence or change`, followed by one line per group: its class, its title and its findings' numbers. For a Brief or Plan finding the last column holds the chosen solution in one line and, for Plan, the reason. Propose an outcome for each finding: Fix → **fix**; Resolved → **drop**; Declined → **drop**; Brief → **brief**, delivered as written; Plan → **brief**, planned first. Every finding has a proposal. Ask the user one question: confirm or change the outcomes and the groups (keep any finding; fix or brief a Declined one; move a finding, merge or split groups, retitle one; change a group between Brief and Plan, which plans a Brief group first or delivers a Plan group from its brief). A Plan group with the reason `rules` among its reasons is delivered from its brief only on the user's explicit choice, shown with the rule it sets aside; one with the reason `open decision` only when the answer settles that decision, after which the brief is rewritten with it in Solution and `None` under Open questions. Say in the question that, on confirmation, the fixes are made, checked, committed on the main branch and reviewed by `review-fix-loop`, whose fix commits land on the main branch too, and the briefs go through delivery, a Plan group's after planning: the answer is the consent to those commits, and no other question about them follows. No edit starts before the answer.

A finding the user moves changes the groups as the user says; a Fix or Declined finding the user chooses to brief joins the group the user names, or a group of its own. Apply the Plan reasons again to every changed group before accepting its route. A grouping that splits a dependency is not accepted: name the dependency and ask again. The exact-change requirement selects the direct batch route after investigation; findings meeting the Brief or Plan criterion take **brief** and the [chain](#chain). When the user disputes a Brief, Plan or Declined finding's class, recheck it. Under `--auto` the proposed outcomes and groups are the skill's recommended options and settle this question by [auto.md](../child-sessions/references/auto.md#deciding).

## Fix

1. Record the checkout's status (`git status --porcelain=v1 -z`, with `GIT_OPTIONAL_LOCKS=0`) before the first edit. A file with uncommitted changes holds another writer's work: never edit, revert, stage or commit it. A chosen finding whose fix needs such a file is not fixed: its outcome becomes keep, with the reason `uncommitted changes in <path>`.
2. Apply the smallest correction for each chosen fix within the project rules. Verify the batch together, with any required baseline run on the version at HEAD.
3. When an approved fix proves difficult, use [Difficult findings](#difficult-findings) if its cause or safe correction remains unclear, then continue the correction in this batch. Only evidence meeting the Brief or Plan criterion returns that finding to Recheck and Select: undo only your own edits for it, identify the solution or the open decision, and propose **brief** with its group and class. Reuse existing authorization when it covers this route; otherwise obtain the changed selection through Select (including its `--auto` routing). Continue independent findings, then carry the selected brief through the chain in this run.
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
2. Commit the owned paths on the current branch, with no further question: Select's answer is the consent. Stage and commit with `git --literal-pathspecs add -- <paths>` and `git --literal-pathspecs commit -m <message> -- <paths>`, each path and the message one literal shell argument, so that other staged changes stay out of the commit; `add` of a deleted follow-ups file stages its removal. The message follows the project rules; by default `follow-ups: settle <n> findings`, `<n>` the fixed, dropped, declined and briefed findings, with one body line per finding, `fixed: <what>`, `dropped: <what>` for a Resolved finding, `declined: <what> — <reason>` for a Declined one or `brief <brief file name>: <what>`; the body is the record of a finding closed without a change.
3. After the commit, require its changed paths (`git show --name-only --format= --no-renames <sha>`) to equal the owned paths; report a mismatch with the commit SHA.

## Review

When the batch commit holds at least one fixed finding, perform the installed `review-fix-loop` `inline` in this session, which is its loop owner, with `--reviewer-run`, `--reviewer-model`, `--reviewer-effort` and `--auto` as given and the system key the keys name (`--claude`, `--codex` or `--dual`, as `--<system>=<command>` when `--reviewer-agent` carries a [launch command](../child-sessions/references/run-contract.md#launch-command); none without `--reviewer-agent` and `--reviewer-dual`, so the reviewer is the system opposite to the fixer's). Select's answer is the request's authorization of its task-state and fix commits on the main branch, so it asks no branch confirmation. Its step 1 scope:

- **Task:** the project checkout and its main branch; the fixed task base is the full HEAD before the batch commit.
- **Requirements:** each fixed finding's line with the change made for it.
- **Task paths:** none; the uncommitted paths recorded in Fix 1 are unrelated work, excluded.
- **Checks:** the Verify checks that are commands form its suite, which it runs by its own rules. The agent-run checks are evidence, passed as completed results with their record paths and never part of the suite; its fixes start no new agent run. A required check Verify reported unavailable is passed as unavailable coverage, so the review cannot end clean; report that with its result.

Its fix commits land on the main branch. Its `clean except disputed` and `blocked` ends follow its own rules; a blocked review is reported and the chain still runs. Write its deferred, outside-scope and disputed findings by `delivering-task`'s [Write follow-ups](../delivering-task/references/follow-ups.md) with `--doc <dir>/<stem>-fixes.md`, where `<dir>` and `<stem>` are the directory and the stem without `-follow-ups` or `-tails` of the first follow-ups file Input took (no document needs to exist at that path), `--branch fixes-<batch commit sha7>`, `--head` the reviewed HEAD and `--checkout` the repository holding `<dir>`. Its Commit section decides whether the file is committed or written locally. With no such finding, write nothing.

## Chain

After Review, follow the [delivery chain](references/chain.md) when selected briefs exist. Otherwise go to Report.

### Plan and refine

[Plan and refine](references/chain.md#plan-and-refine) requires a plan review mark before delivery.

### Deliver

[Deliver](references/chain.md#deliver) passes eligible documents to delivery.

### Nested calls

[Chain calls](references/chain.md#nested-calls) use the shared phase contract.

## Report

Account for every input finding. A written brief is an intermediate result: report its chain's delivery result or the concrete stop and remaining work. Completing the direct batch alone does not complete the selected brief tasks.

- A table of every finding: `# | file | class | outcome` (fixed, `dropped: resolved`, `dropped: declined — <reason>`, brief `<brief file name>`, kept with reason, abandoned with reason). Below it, each declined finding's line verbatim with the reason in one clause: a follow-ups file the project ignores has no commit holding it.
- The files changed, each check with its command and exit (or its unavailable reason), run once, and the batch commit SHA or `not committed: <reason>`; each follow-ups file updated, deleted or left local.
- Each research assignment: finding numbers, agent identity, requested and effective model/effort with evidence or unavailable reason, result location, and how its findings were checked and used.
- The review: the batch review's reviewer system (the key passed, or the system opposite to the fixer's), `review-fix-loop`'s final verdict, rounds and commits, its deferred and disputed findings, and the follow-ups file they were written to with its count and commit (or where it was written locally); or `review skipped: no fixed finding`.
- The briefs, in the order Select listed the groups, and a table of their tasks: `task | class | brief | spec | plan | refine | delivery | merge SHA | follow-ups count`, each phase's outcome as its nested call's Report gave it, `-` for a phase the chain did not reach (`spec`, `plan` and `refine` always for a Brief task), and the reason where a chain ended.
- The settings lines of the delivery's Report, and for each call: phase agents: `subagent`, model and effort set as launch-settings' Nested agents says (Opus / Sol `high`); `<p>` Prepare and `<a>` Accept agents. Add this session's own `Wait:` line and dialog counts (answered, declined, escalated), each worker whose inline place ran as `subagent`, and each call that ran `inline` with the shared contract's reason.
- Under `--auto`, the `## Decisions` of [auto.md](../child-sessions/references/auto.md#decisions): this session's own and those of every nested call's status.
- What remains, as commands to run by hand:
  - each task whose chain ended, with the next skill for it (`planning-task-docs <brief>`, `refining-task-docs <plan>`, `delivering-task <plan>`, or `delivering-task <plan> --resume` when its delivery left a branch or worktree; for a Brief task `delivering-task <brief>`, or `delivering-task <brief> --resume` likewise), and where to look (the nested call's brief and status file, its last phase's handoff record including the queue record/state file for a queue, and the worker status file and window its Report names). After a stop inside a cycle, a rerun derives states from Git and the documents: a planner/refiner's live window is its skill's own refusal when that call runs again; a delivery branch/worktree takes resume or discard. Settle Earlier runs before another watcher on a possibly live child;
  - each follow-ups file still holding kept findings, with its count of `- ` lines, and anything noticed outside the chosen findings;
  - each follow-ups file the review or the delivered tasks left, for another `delivering-task-follow-ups` run. This run does not take them up itself.
