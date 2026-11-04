---
name: resolving-task-follow-ups
description: Rechecks the findings of follow-ups files against the current code, fixes the ones the user selects directly in the current session and checkout, and removes resolved findings from the files, with no child session, worktree, spec or plan. Use when follow-ups left after a delivered task are small enough to fix by hand, or when accumulated follow-ups files need sorting out.
---

# Resolving Task Follow-ups

`resolving-task-follow-ups <follow-ups file|directory>... [--review]`

The current session does the work itself, on the current branch of the current checkout: it opens no window, creates no worktree or branch and writes no spec or plan. The user selects what is fixed and decides whether it is committed.

## Input

1. Each argument is a follow-ups file (a name ending `-follow-ups.md`, or `-tails.md`, the older format of the same file) or a directory, which contributes every such file directly inside it (not recursive), in file-name order. Any other file is refused, naming it, before any work.
2. A file holds sections headed `## <branch> @ <sha7> (<YYYY-MM-DD>)` (an older file may have none); each line starting with `- ` is one finding, in the form `- <what> — <where> — <why>`. Take a line in another form (older files) as written. With no finding in any file, report "nothing to resolve" and stop.
3. The project checkout is the top level of the current repository. When that top level is itself a separate docs repository (a `docs/superpowers` directory with its own repository), the project checkout is `git -C <docs-top>/../.. rev-parse --show-toplevel`; when that fails, ask the user. Every follow-ups file must lie in the project checkout or in its separate docs repository (`<project>/docs/superpowers`); refuse any other file, naming it, before any work. Each finding's `<where>` resolves against the project checkout. Read the project rules (`AGENTS.md`, `CLAUDE.md` and the like) before the recheck: they decide what a fix must satisfy.

## Recheck

Read every finding against the code as it is now. A finding was recorded at its section's commit, so its paths and line numbers may have moved: find the described code by its content. Read the plan beside the file (the same path without the `-follow-ups` or `-tails` suffix) and that plan's spec only when the finding cannot be understood without them. Put each finding in one class:

- **Resolved**: the defect no longer exists (fixed later, the code removed, the point made moot). Evidence: the `path:line` or commit that shows it.
- **Small**: a localized fix whose exact change you can state now, in one or a few files, with no behaviour to design, no open question, and every check the project rules require for that change runnable in this session.
- **Design**: anything larger: a behaviour to decide, many modules or skills touched, new tests or verification the project rules require beyond this session. It belongs in a task.
- **Disputed**: the finding's `<why>` carries two positions, or your recheck disagrees with the finding. The user decides.

The recheck is done when every finding has a class and its evidence or proposed change.

## Select

Show one table: `# | file | finding (short) | class | evidence or proposed change`. Propose an outcome for each: Small → **fix**, Resolved → **drop** (removed from the file with no change), Design → **keep**; a Disputed finding gets no proposal, the user chooses among fix, drop and keep. Ask the user to confirm or change the outcomes; no edit starts before the answer. A Design finding is kept or dropped, never fixed here; when the user disputes its class, recheck it, and only a finding whose exact change you can then state becomes Small.

## Fix

1. Record the checkout's status (`git status --porcelain=v1 -z`, with `GIT_OPTIONAL_LOCKS=0`). A file you are about to edit, a follow-ups file included, that already has uncommitted changes is another writer's work: tell the user and edit on top of it only after their answer, telling them that such a file stays out of the commit. Leave every uncommitted change as it is; never revert, stage or commit it.
2. Fix the chosen findings one at a time, each with the smallest change that removes the defect, following the project rules. Run the checks the project rules require for each change (the tests of the touched code, a validator) and keep each check's command and exit.
3. A fix that turns out larger than chosen (it needs a design decision, or breaks a check you cannot repair within the finding) is abandoned: undo your own edits for it, change its outcome to keep with the reason, and go on.
4. Anything you notice outside the chosen findings goes into the Report, unfixed.

## Update the files

In each follow-ups file, delete the lines of the fixed and dropped findings; every other line stays byte-identical, headings included (they record the original review). A section left with no `- ` line is removed, from its `## ` line to the next line starting with `## ` or the end of the file. A file left with no `- ` line is deleted. A written file has one blank line between sections and ends with exactly one newline.

## Commit

1. The owned paths are the files you changed for fixes, plus each changed or deleted follow-ups file tracked in this repository, except a file that had uncommitted changes before your edit (Fix 1). A follow-ups file the project ignores (`git check-ignore -q` exits 0) or one in the separate docs repository stays uncommitted; report where it is. With no owned path, ask nothing, commit nothing and report `not committed: nothing to commit`; run no commit command, since `commit --` with no path commits the whole index.
2. Show a summary: the fixed findings with the files each changed, the checks with their exits, the dropped and kept findings, the follow-ups files changed or deleted, and the owned paths. Ask whether to commit them. On no, leave everything uncommitted and go to Report.
3. On yes, commit the owned paths on the current branch. Stage and commit with `git --literal-pathspecs add -- <paths>` and `git --literal-pathspecs commit -m <message> -- <paths>`, each path and the message one literal shell argument, so that other staged changes stay out of the commit; `add` of a deleted follow-ups file stages its removal. The message follows the project rules; by default `follow-ups: resolve <n> findings`, `<n>` the fixed and dropped findings, with one body line per finding, `fixed: <what>` or `dropped: <what>`.
4. After the commit, require its changed paths (`git show --name-only --format= --no-renames <sha>`) to equal the owned paths; report a mismatch with the commit SHA.

## Review

Only with `--review`, and only after a commit; without a commit report `review skipped: nothing committed`. Identify your own system (Codex or Claude) from session identity, as `auto-cross-refine` does, and perform the installed `independent-review --reviewer <the opposite system> <commit sha>`, naming the fixed findings' lines as the requirements. Show its verdict and findings as given, not adjudicated, with the `result.md` path. Fix nothing on your own: the user decides what happens next.

## Report

- A table of every finding: `# | file | class | outcome` (fixed, dropped, kept with reason, abandoned with reason).
- Files changed, checks with their exits, the commit SHA or `not committed: <reason>`, each follow-ups file updated, deleted or left local.
- The review result when `--review` ran.
- What remains: each follow-ups file that still exists with its count of `- ` lines, for `planning-task-docs <follow-ups file>` when its findings need a task, and anything noticed outside the chosen findings.
