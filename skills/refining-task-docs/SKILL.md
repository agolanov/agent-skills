---
name: refining-task-docs
description: Cross-reviews one task's spec and plan in a visible child agent session, fixes the findings and marks each document that ends the review clean with a Review line, leaving freshly marked documents as context. Use when task documents should be reviewed and fixed before execution, or when a document's Review mark is missing or stale.
---

# Refining Task Docs

For every checkout cleanliness or changed-path gate below and in child briefs/references, use [checkout-state Direct-use preflight](../independent-review/references/checkout-state.md#direct-use-preflight). Resolve its installed helper and retain fresh evidence. This skill's gates are own-paths gates whose owned paths are the run's documents: uncommitted changes to any other path, staged or not, pass and stay untouched, and a project checkout that is another repository than the docs repository owns no path. Unavailable verification stops the dependent action; raw status/diff is not a fallback. Gates compare the result's decoded exact `paths`. This applies separately to project, docs and child checkouts. Every read-only Git verification below and in references/child briefs (log, refs, roots, ancestry and diffs included) uses that reference's `git-read` command; displayed `git <read-command>` notation means this wrapper, never a raw invocation. Resolve paths relative to the containing checkout root. Mutating commands keep their explicit authorization.


`refining-task-docs <spec|plan> [<plan|spec>] [--agent claude|codex] [--model M|cli-default] [--effort E|cli-default] [--reviewer-model M|cli-default] [--reviewer-effort E|cli-default]`

One task per run. The child owns the review, its fixes and the review marks, and talks to the user in its own window. The root resolves the documents, opens one window in the project checkout, waits, verifies Git/status facts and reports paths. It writes no document or mark, never edits a child status, and invokes no other task skill: the user chooses what runs next.

## Input

1. The project checkout is the top level of the current repository. When that top level is a separate docs repository (a `docs/superpowers` directory with its own repository), the project checkout is `git -C <docs-top>/../.. rev-parse --show-toplevel`; when that fails, ask the user for the project checkout. Project-relative paths such as `**Spec:**` headers resolve against the project checkout, never the docs repository. Resolve applicable project rules. Resolve each given path to an absolute path, read it completely and recognise it:
   - **Plan**: it carries the superpowers plan header (`> **For agentic workers:** REQUIRED SUB-SKILL:`) or lies in a `plans/` directory of a superpowers docs dir (`docs/superpowers/plans/`) and is not a `*-follow-ups.md` or `*-tails.md` file.
   - **Spec**: named `*-design.md` or lying in a `specs/` directory.

   Anything else is refused before any window: only specs and plans are reviewed. Two plans or two specs are refused too.
2. A single plan: find its spec by the matching rules; a single spec is reviewed alone, its plans are not added. Matching rules, in order:
   1. Naming pair: `specs/YYYY-MM-DD-<slug>-design.md` with `plans/YYYY-MM-DD-<slug>.md` in the same docs dir.
   2. Else the plan's `**Spec:**` header line (path relative to the project checkout).
   3. Else ask the user which spec belongs to the plan. Never guess a pairing.
3. Docs repository = `git -C <document-dir> rev-parse --show-toplevel`; every document of the run must lie in the same one. Run the own-paths gate on the docs repository over every document of the run, those to review and the context documents alike; a hit stops, naming the path. Record the docs repository's full HEAD as `<base-sha>`.
4. Classify each document fresh or stale per [review-mark.md](references/review-mark.md#freshness), `rel` relative to the docs repository, and show each to the user: fresh with verdict, reviewer and date; stale with the failing condition. Stale documents are the documents to review; fresh ones are context only. None stale: report "nothing to review" with each document's mark and stop; no window opens.

## Preflight

1. Select `--agent`, otherwise identify the root's own system from session identity as `auto-cross-refine` does; unknown identity requires clarification. Never infer the agent from executable availability, environment, directory names or model.
2. Resolve the refiner's settings per [launch settings](../independent-review/references/launch-settings.md#precedence) for the selected agent: `--model`/`--effort` are explicit values, `cli-default` is a per-field [opt-out](../independent-review/references/launch-settings.md#cli-defaults-opt-out), and every other field takes the refiner role default. An unresolved or unsupported pair stops before any window. Validate explicit `--reviewer-model`/`--reviewer-effort` values for the reviewer system, the system opposite to the child's agent: a model of another system or an unsupported pair stops before any window, naming the value and the reviewer system; `cli-default` is accepted. These values fill the brief's Reviewer settings line; without them it says `reviewer policy`.
3. Locate the installed `child-sessions/SKILL.md`; read it, its `references/brief-writing.md` and `references/status-file.md`. Call `scripts/child-session` beside it by absolute path, never through PATH; its command/status contract governs every call. `<runtime>` is `${XDG_RUNTIME_DIR:-/tmp}/child-sessions`.
4. Check the selected child's actual installed catalogs (Claude: `~/.claude/skills`, enabled `~/.claude/plugins`; Codex: `~/.codex/skills`, `~/.agents/skills`, enabled `~/.codex/plugins`; plus the project's `.claude/skills` and `.agents/skills`). Resolve readable absolute SKILL.md paths for `auto-cross-refine`, the opposite launcher (`refine-with-codex` for a Claude child, `refine-with-claude` for Codex), `review-fix-loop` and `independent-review`. Executables or the root's catalog alone do not prove child skill availability. Missing ones stop before any window; report them for the user to install, without substitution.
5. Names: `<stem>` is the plan's stem when the run has a plan, else the spec's, with every character outside `[A-Za-z0-9_-]` replaced by `-`. Window `refine-<stem>`, brief `<runtime>/refine-<stem>-brief.md`, status `<runtime>/refine-<stem>-status.md`. A live window of that name (`alive refine-<stem>` returns 0) is refused, naming it. Leftover runtime files of that name from an earlier run (brief, status, and their archived `-blocked-<n>` and `-rejected-<n>` copies) are renamed to `<file>-old-<n>`, `n` the smallest unused number; no file exists at the status path when the brief is written.

## Brief

Fill [refiner-brief.md](references/refiner-brief.md) with absolute resolved paths, following child-sessions' brief checklist, and write it to the brief path.

## Open and wait

1. Append the `Opened:` line of the [child settings check](../independent-review/references/launch-settings.md#child-settings-check) to the brief, then call `open --agent <agent> [--model M] [--effort E] --split right refine-<stem> <project checkout> <brief>`, quoting paths, passing the brief's recorded Launch settings as `--model` and `--effort` and omitting a field that is `cli-default`. The user answers the child's questions in its window, so it asks for a pane right of the root; when `open` prints a fallback note (a tab or a tmux window instead), tell the user where the window opened. The child works in the project checkout: no worktree, no branch of its own. Tell the user that the run owns the task's documents: edit none of them while the window is open; other files stay theirs to change and commit, except that any edit in the docs repository while a reviewer runs makes the child's review loop report `checkout changed`.
2. Follow child-sessions' foreground loop: `wait refine-<stem> <status> 240` on Codex, `540` on Claude. A Codex tool yield is not a timeout: poll the same returned foreground session in intervals of at most 60 seconds until it exits. At the first `wait` return after each `open`, run the early [child settings check](../independent-review/references/launch-settings.md#child-settings-check) for that opening and keep the matched record path; only a mismatch stops the loop for the user's continue-or-stop question.
3. On exit `0`, read the exact first status line. `done` proceeds to Verify. `blocked` shows Questions, options and recommendation, obtains the user's answer, archives the status to `<file>-blocked-<n>`, sends one line or an absolute answer-file instruction, then waits for a fresh status. `failed` shows the failure and stops, keeping the window and status; go to Report.
4. Exit `3`: `peek refine-<stem> 40`, show diagnostics, append “Continue from the current state of the checkout: read git log and run the checkout-state preflight first. Uncommitted changes on your owned paths are your earlier session's work: inspect them and continue from them.” to the brief, close the stale window if present, append a new `Opened:` line and reopen once with the brief's recorded Launch settings; never re-resolve them. A second silent exit stops, keeping the window and status. Exit `124`: `peek refine-<stem> 40`; wait again for work in progress, or handle a dialog per child-sessions Dialogs. Other errors stop with artifacts preserved.
5. Before every `send` (a `blocked` answer here, a mismatch line in Verify), run `alive refine-<stem>`: a dead agent leaves a shell that would run the text. Dead: `close refine-<stem>`, append the continuation line of step 4 and then the line you meant to send to the brief, append a new `Opened:` line, and `open` again with the brief's recorded Launch settings, never re-resolved; this is the run's one reopen, shared with step 4. When that reopen was already used, stop and report, keeping the window and runtime files.

## Verify

On `done`, all of these must hold:

1. Full status format with `## Artifacts`; BRANCH, CHECKOUT and HEAD name the docs repository's current branch, top level and full HEAD.
2. Commits lists the child's own commits in the docs repository: each is in `<base-sha>..HEAD` and changes only Artifacts paths (`git show --name-only --format= --no-renames <sha>`, relative to the docs repository). Every other commit of that range is the user's parallel work and changes neither an Artifacts path nor any document of the run, context documents included; one that does stops Verify and goes to the user, naming the commit, never back to the child. A project checkout that is another repository may move freely.
3. A fresh own-paths gate on the docs repository over the Artifacts paths and the documents to review passes: no document of the run is left uncommitted.
4. Review gives final refine mode `CLEAN` or `CLEAN EXCEPT DISPUTED`, with the raw reviewer verdict reported separately; dispute-only closure can keep raw `CHANGES`, never relabelled CLEAN.
5. Every document to review is under Artifacts, and every Artifacts path lies in the docs repository and passes the freshness check of review-mark.md, run by the root.
6. The final [child settings check](../independent-review/references/launch-settings.md#child-settings-check) over every opening's record matches, or the user accepted its result.

A settings mismatch or `settings unverified: <reason>` never goes back to the child: show expected and observed values and the record paths, and ask the user to accept the result with the observed settings or stop with everything preserved. A user commit changing a document of the run goes to the user per Verify 2. Any other mismatch goes back to the child once: archive the status to `<file>-rejected-<n>`, `send` one line naming the mismatch and asking for a fresh report at the same path, wait and verify again. A repeated mismatch goes to the user, with window and status kept.

## Report

Report the final refine mode and the raw reviewer verdict; each document with its new `Review:` line, `fresh, context only` when untouched, or `not marked: <why>`; disputed findings with both positions; the commits; and every Out of scope line. When Verify 3's preflight listed paths other than the owned documents, add `unrelated uncommitted changes left untouched: <count>`, without listing them. Add one settings line: role `refiner`, effective model and effort, source of each, the settings check outcome, and the record paths or the user's acceptance; and the brief's Reviewer settings line. Without a clean verdict nothing is marked, and the report says what is left: the documents still unmarked and the open findings the status names. After a verified `done`, `close refine-<stem>`; otherwise the window and status stay for the user.
