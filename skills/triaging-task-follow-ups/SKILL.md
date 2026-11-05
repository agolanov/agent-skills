---
name: triaging-task-follow-ups
description: Rechecks the findings of follow-ups files against the current code, fixes the small ones the user selects directly in the checkout, drops resolved ones, groups those that need design into task briefs for planning, and removes every settled finding from the files, by default in the current session, with no worktree, spec or plan. Use when follow-ups left after a delivered task need sorting out, or when another skill must triage follow-ups before their tasks are planned.
---

# Triaging Task Follow-ups

`triaging-task-follow-ups <follow-ups file|directory>... [--run inline|subagent|background|window] [--model M|cli-default] [--effort E|cli-default] [--review] [--reviewer-run background|subagent|window] [--reviewer-model M] [--reviewer-effort E] [--auto]`

`--run` places the triage. By default (`inline`) the current session does the work itself, on the current branch of the current checkout, and `--model` and `--effort` are refused before anything starts: the triager is this session. `subagent`, `background` or `window` move the whole triage to a child that works the same way ([Run elsewhere](#run-elsewhere)). The triage creates no worktree or branch and writes no spec or plan; the only windows are a `--run window` triage and a `--reviewer-run window` reviewer of **Review**. Every finding ends with one outcome: **fix** (fixed here), **drop** (removed with no change), **brief** (moved into a task brief for `planning-task-docs`) or **keep** (left in its file). The user selects the outcomes and decides whether the result is committed.

Under `--auto` read child-sessions' [auto.md](../child-sessions/references/auto.md): every question below that would go to the user is routed by its Deciding, every brief and prompt this skill writes says `Auto: yes`, and the Report lists `## Decisions`.

## Run elsewhere

Under `--run subagent`, `background` or `window` this session is a thin launcher (run contract [Places](../child-sessions/references/run-contract.md#places)) and performs none of the sections below: a child of this session's system performs this skill `inline`, and this session writes its brief, launches it, waits, relays its questions and reports its result. A `--run` value other than the four places stops before anything starts.

Follow child-sessions' [Thin launchers](../child-sessions/references/run-contract.md#thin-launchers) with these local parameters.

- **Inputs and refusals.** Resolve the project checkout as Input 3 does and each argument to an absolute path. Under `subagent`, refuse `--reviewer-run subagent` when the host's subagents cannot start subagents, since the child would start it.
- **Worker and arguments.** Role `triager`; consume `--run`, `--model` and `--effort`. `Arguments:` holds the absolute arguments and every other key as given. `Checkout:` is the project checkout.
- **Name.** `triage-<slug>`, where `<slug>` is the first argument's file stem or directory name, with every character outside `[A-Za-z0-9_-]` replaced by `-`.
- **Authority.** The fixes, briefs and follow-ups file updates of this skill, respecting the fix/drop/brief/keep selection; the commit of the owned paths on the current branch only after the user's yes (under `--auto`, the yes [auto.md](../child-sessions/references/auto.md#deciding) routes), nothing more.
- **Questions and result.** Input 3, Select and Commit questions follow the shared window/blocked routing. Blocked Questions include Select's table with its groups or Commit's summary, as applicable, with the question, options and recommendation. The child writes `STATUS: done` once it has reported, or `STATUS: failed` with the reason when it stopped, and its Report under `## Report` after the status contract's sections. Report that `## Report` as this skill's Report (after `failed`, the failure and what the status lists), with the shared launch evidence.

## Input

1. Each argument is a follow-ups file (a name ending `-follow-ups.md`, or `-tails.md`, the older format of the same file) or a directory, which contributes every such file directly inside it (not recursive), in file-name order. Any other file is refused, naming it, before any work.
2. A file holds sections headed `## <branch> @ <sha7> (<YYYY-MM-DD>)` (an older file may have none); each line starting with `- ` is one finding, in the form `- <what> — <where> — <why>`. Take a line in another form (older files) as written. With no finding in any file, report "nothing to triage" and stop.
3. The project checkout is the top level of the current repository. When that top level is itself a separate docs repository (a `docs/superpowers` directory with its own repository), the project checkout is `git -C <docs-top>/../.. rev-parse --show-toplevel`; when that fails, ask the user (under `--auto`, routed by [auto.md](../child-sessions/references/auto.md#deciding)). Every follow-ups file must lie in the project checkout or in its separate docs repository (`<project>/docs/superpowers`), and a tracked one must have no uncommitted changes (`git status --porcelain=v1 -z -- <file>` empty, with `GIT_OPTIONAL_LOCKS=0`); refuse any other file, naming it and the reason, before any work. Each finding's `<where>` resolves against the project checkout. Read the project rules (`AGENTS.md`, `CLAUDE.md` and the like) before the recheck: they decide what a fix must satisfy.

`delivering-task-follow-ups/references/checkout.md` holds a display copy of Input 3's project-checkout rule; keep them equal.

## Recheck

Read every finding against the code as it is now. A finding was recorded at its section's commit, so its paths and line numbers may have moved: find the described code by its content. Read the plan beside the file (the same path without the `-follow-ups` or `-tails` suffix) and that plan's spec only when the finding cannot be understood without them. Put each finding in one class:

- **Resolved**: the defect no longer exists (fixed later, the code removed, the point made moot). Evidence: the `path:line` or commit that shows it.
- **Small**: a localized fix whose exact change you can state now, in one or a few files, with no behaviour to design, no open question, and every check the project rules require for that change runnable in this session.
- **Design**: anything larger: a behaviour to decide, many modules or skills touched, new tests or verification the project rules require beyond this session. It belongs in a task.
- **Disputed**: the finding's `<why>` carries two positions, or your recheck disagrees with the finding. The user decides (under `--auto`, routed by [auto.md](../child-sessions/references/auto.md#deciding)).

The recheck is done when every finding has a class and its evidence, proposed change or current `path:line`.

## Group

Put the Design findings into groups, one group per future task. Findings that share a mechanism, a module boundary or a design decision go together, and findings whose fixes depend on each other always go together, so that every group is a task independent of the others. A group may hold a single finding. Give each group a short title naming the change (`OAuth state hardening`).

## Select

Show one table: `# | file | finding (short) | class | group | evidence or proposed change`, followed by one line per group: its title and its findings' numbers. Propose an outcome for each finding: Small → **fix**, Resolved → **drop**, Design → **brief** in its group; a Disputed finding gets no proposal, the user chooses among fix, drop, brief and keep. Ask the user to confirm or change the outcomes and the groups (move a finding, merge or split groups, retitle one, keep a finding instead of briefing it); no edit starts before the answer. A finding the user moves changes the groups as the user says; a Disputed or Small finding the user chooses to brief joins the group the user names, or a group of its own. The independence rule of Group still holds: a grouping that splits a dependency is not accepted; name the dependency and ask again. **fix** is chosen only for a Small finding; when the user disputes a Design finding's class, recheck it, and only a finding whose exact change you can then state becomes Small. Under `--auto` the proposed outcomes and groups are the skill's recommended options and settle this question by [auto.md](../child-sessions/references/auto.md#deciding); a Disputed finding, which has no proposal, is routed by it.

## Fix

1. Record the checkout's status (`git status --porcelain=v1 -z`, with `GIT_OPTIONAL_LOCKS=0`) before the first edit. A file with uncommitted changes holds another writer's work: never edit, revert, stage or commit it. A chosen finding whose fix needs such a file is not fixed: its outcome becomes keep, with the reason `uncommitted changes in <path>`. So every file you change was clean before, and the commit holds whole fixes.
2. Fix the chosen findings one at a time, each with the smallest change that removes the defect, following the project rules. Run the checks the project rules require for each change (the tests of the touched code, a validator) and keep each check's command and exit.
3. A fix that turns out larger than chosen (it needs a design decision, or breaks a check you cannot repair within the finding) is abandoned: undo your own edits for it, change its outcome to keep with the reason, and go on.
4. Anything you notice outside the chosen findings goes into the Report, unfixed.

## Briefs

Write one brief per group that holds at least one finding with the outcome brief, from [task-brief.md](references/task-brief.md): its path, name and content rules are there. The step is done when every finding with the outcome brief stands, verbatim, in exactly one written brief.

## Update the files

In each follow-ups file, delete the lines of the fixed, dropped and briefed findings; every other line stays byte-identical, headings included (they record the original review). A section left with no `- ` line is removed, from its `## ` line to the next line starting with `## ` or the end of the file. A file left with no `- ` line is deleted. A written file has one blank line between sections and ends with exactly one newline.

## Commit

1. The owned paths are the files you changed for fixes, each written brief that lies in this repository (new, so not yet tracked), plus each changed or deleted follow-ups file tracked in this repository. A follow-ups file or brief the project ignores (`git check-ignore -q` exits 0) or one in the separate docs repository stays uncommitted; report where it is. With no owned path, ask nothing, commit nothing and report `not committed: nothing to commit`; run no commit command, since `commit --` with no path commits the whole index.
2. Show a summary: the fixed findings with the files each changed, the checks with their exits, the briefs with their findings, the dropped and kept findings, the follow-ups files changed or deleted, and the owned paths. Ask whether to commit them (under `--auto`, a commit consent routed by [auto.md](../child-sessions/references/auto.md#deciding)). On no, leave everything uncommitted and go to Report.
3. On yes, commit the owned paths on the current branch. Stage and commit with `git --literal-pathspecs add -- <paths>` and `git --literal-pathspecs commit -m <message> -- <paths>`, each path and the message one literal shell argument, so that other staged changes stay out of the commit; `add` of a deleted follow-ups file stages its removal. The message follows the project rules; by default `follow-ups: triage <n> findings`, `<n>` the fixed, dropped and briefed findings, with one body line per finding, `fixed: <what>`, `dropped: <what>` or `brief <brief file name>: <what>`.
4. After the commit, require its changed paths (`git show --name-only --format= --no-renames <sha>`) to equal the owned paths; report a mismatch with the commit SHA.

## Review

Only with `--review`, and only after a commit; without a commit report `review skipped: nothing committed`. `--reviewer-run`, `--reviewer-model` and `--reviewer-effort` set this reviewer and mean nothing without `--review`. Perform the installed `independent-review [--run <--reviewer-run>] [--model <--reviewer-model>] [--effort <--reviewer-effort>] [--auto] <commit sha>`, passing only the keys given (`--auto` under `--auto`), with no system key: independent-review chooses the reviewer system by its default. Name the fixed findings' lines as the requirements. Show its verdict and findings as given, not adjudicated, with the `result.md` path. Fix nothing on your own, under `--auto` too: the user decides what happens next.

## Report

- A table of every finding: `# | file | class | outcome` (fixed, dropped, brief `<brief file name>`, kept with reason, abandoned with reason).
- The briefs: one line each, in the order Select listed the groups, its absolute path, title and number of findings.
- Files changed, checks with their exits, the commit SHA or `not committed: <reason>`, each follow-ups file updated, deleted or left local.
- The review result when `--review` ran.
- Under `--auto`, the `## Decisions` of [auto.md](../child-sessions/references/auto.md#decisions).
- What remains: each brief, for `planning-task-docs <brief>`; each follow-ups file that still exists with its count of `- ` lines; and anything noticed outside the chosen findings.
