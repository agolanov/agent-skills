---
name: planning-task-docs
description: Turns one task (a task text, a brief, a spec without a plan, or a follow-ups file) into a superpowers spec and plan written in a visible child agent session, where the user answers the brainstorming questions. Use when a task needs its spec or plan written before review or execution, or when delivery follow-ups should become a new task.
---

# Planning Task Docs

For every checkout cleanliness or changed-path gate below and in child briefs/references, use [checkout-state Direct-use preflight](../independent-review/references/checkout-state.md#direct-use-preflight). Resolve its installed helper, retain fresh evidence, and require `uncommitted: false` for clean. Unavailable verification stops the dependent action; raw status/diff is not a fallback. Path allowlists use the result's decoded exact `paths`. This applies separately to project, docs and child checkouts. Every read-only Git verification below and in references/child briefs (log, refs, roots, ancestry and diffs included) uses that reference's `git-read` command; displayed `git <read-command>` notation means this wrapper, never a raw invocation. Resolve paths relative to the containing checkout root. Mutating commands keep their explicit authorization.


`planning-task-docs <"task text"|brief|spec|follow-ups file> [--agent claude|codex] [--model M|cli-default] [--effort E|cli-default]`

One task per run. The child writes the documents with superpowers `brainstorming` and `writing-plans` and talks to the user in its own window; the user answers its questions there, never through the root. The root classifies the input, opens one window in the project checkout, waits, verifies Git/status facts and reports paths. It writes no document, mark or commit, never edits a child status, and invokes no other task skill: the user chooses what runs next.

## Input

The project checkout is the top level of the current repository. When that top level is a separate docs repository (a `docs/superpowers` directory with its own repository), the project checkout is `git -C <docs-top>/../.. rev-parse --show-toplevel`; when that fails, ask the user for the project checkout. Project-relative paths such as `**Spec:**` headers resolve against the project checkout, never the docs repository. Resolve the input; read a given file completely. Classify it by the first rule that matches; every stop happens before any window:

1. **Follow-ups file**: a file whose name ends `-follow-ups.md`, or `-tails.md` (the older format of the same file). Each line starting with `- ` is one finding. With none, report "nothing to plan" and stop.
2. **Plan**: it carries the superpowers plan header (`> **For agentic workers:** REQUIRED SUB-SKILL:`) or lies in a `plans/` directory of a superpowers docs dir (`docs/superpowers/plans/`). Refuse: "already planned; review it with `refining-task-docs` or execute it with `executing-task-docs`".
3. **Spec**: named `*-design.md` or lying in a `specs/` directory. Find its plans in the sibling `plans/` directory, with no question: the naming pair (`specs/YYYY-MM-DD-<slug>-design.md` with `plans/YYYY-MM-DD-<slug>.md`), and every plan whose `**Spec:**` header (path relative to the project checkout) names this spec. Any found: report "already planned", naming each plan, with the same pointer to `refining-task-docs` or `executing-task-docs`, and stop. None: the child writes the plan only.
4. **Brief**: any other existing file.
5. **Task text**: a quoted text that is not an existing path.

`<slug>` is the input file's stem; for a task text, `<today>-<slug>` with `<slug>` made of `[a-z0-9-]` from its key words (`Add a --version flag` → `2026-11-01-version-flag`). Replace every character outside `[A-Za-z0-9_-]` with `-`.

## Preflight

1. Resolve applicable project rules. Docs repository = `git -C <project>/docs/superpowers rev-parse --show-toplevel` when that directory exists, else the project checkout. Require the project checkout and the docs repository clean (one check when they are the same repository) and record each full HEAD. For a brief, spec or follow-ups input, record the input file's SHA-256.
2. Select `--agent`, otherwise identify the root's own system from session identity as `auto-cross-refine` does; unknown identity requires clarification. Never infer the agent from executable availability, environment, directory names or model.
3. Resolve the planner's settings per [launch settings](../independent-review/references/launch-settings.md#precedence) for the selected agent: `--model`/`--effort` are explicit values, `cli-default` is a per-field [opt-out](../independent-review/references/launch-settings.md#cli-defaults-opt-out), and every other field takes the planner role default. An unresolved or unsupported pair stops before any window.
4. Locate the installed `child-sessions/SKILL.md`; read it, its `references/brief-writing.md` and `references/status-file.md`. Call `scripts/child-session` beside it by absolute path, never through PATH; its command/status contract governs every call. `<runtime>` is `${XDG_RUNTIME_DIR:-/tmp}/child-sessions`.
5. Check the selected child's actual installed catalogs (Claude: `~/.claude/skills`, enabled `~/.claude/plugins`; Codex: `~/.codex/skills`, `~/.agents/skills`, enabled `~/.codex/plugins`; plus the project's `.claude/skills` and `.agents/skills`). Resolve readable absolute SKILL.md paths for superpowers `brainstorming` (not needed for a spec input) and `writing-plans`. Executables or the root's catalog alone do not prove child skill availability. A missing one stops before any window: ask the user to install superpowers for that agent. No other skill substitutes for them.
6. Window `plan-<slug>`, brief `<runtime>/plan-<slug>-brief.md`, status `<runtime>/plan-<slug>-status.md`. A live window of that name (`alive plan-<slug>` returns 0) is refused, naming it. Leftover runtime files of that name from an earlier run (brief, status, and their archived `-blocked-<n>` and `-rejected-<n>` copies) are renamed to `<file>-old-<n>`, `n` the smallest unused number; no file exists at the status path when the brief is written.

## Brief

Fill [planner-brief.md](references/planner-brief.md) with absolute resolved paths, following child-sessions' brief checklist, and write it to the brief path.

## Open and wait

1. Append the `Opened:` line of the [child settings check](../independent-review/references/launch-settings.md#child-settings-check) to the brief, then call `open --agent <agent> [--model M] [--effort E] --split right plan-<slug> <project checkout> <brief>`, quoting paths, passing the brief's recorded Launch settings as `--model` and `--effort` and omitting a field that is `cli-default`. The user answers the child's questions in its window, so it asks for a pane right of the root; when `open` prints a fallback note (a tab or a tmux window instead), tell the user where the window opened. The child works in the project checkout: no worktree, no branch of its own.
2. Follow child-sessions' foreground loop: `wait plan-<slug> <status> 240` on Codex, `540` on Claude. A Codex tool yield is not a timeout: poll the same returned foreground session in intervals of at most 60 seconds until it exits. Brainstorming with the user can take long: keep waiting. At the first `wait` return after each `open`, run the early [child settings check](../independent-review/references/launch-settings.md#child-settings-check) for that opening and keep the matched record path; only a mismatch stops the loop for the user's continue-or-stop question.
3. On exit `0`, read the exact first status line. `done` proceeds to Verify. `blocked` shows Questions, options and recommendation, obtains the user's answer, archives the status to `<file>-blocked-<n>`, sends one line or an absolute answer-file instruction, then waits for a fresh status. `failed` shows the failure and stops, keeping the window and status; the report says no spec and plan were produced and lists any commits the status names.
4. Exit `3`: `peek plan-<slug> 40`, show diagnostics, append “Continue from the current state of the checkout: read git log and run the checkout-state preflight first.” to the brief, close the stale window if present, append a new `Opened:` line and reopen once with the brief's recorded Launch settings; never re-resolve them. A second silent exit stops, keeping the window and status. Exit `124`: `peek plan-<slug> 40`; wait again for work in progress, or handle a dialog per child-sessions Dialogs. Other errors stop with artifacts preserved.
5. Before every `send` (a `blocked` answer here, a mismatch line in Verify), run `alive plan-<slug>`: a dead agent leaves a shell that would run the text. Dead: `close plan-<slug>`, append the continuation line of step 4 and then the line you meant to send to the brief, append a new `Opened:` line, and `open` again with the brief's recorded Launch settings, never re-resolved; this is the run's one reopen, shared with step 4. When that reopen was already used, stop and report, keeping the window and runtime files.

## Verify

On `done`, all of these must hold:

1. Full status format with `## Artifacts`, listing the spec and plan written (only the plan for a spec input); every Artifacts path exists.
2. The repository holding the documents (`git -C <document-dir> rev-parse --show-toplevel`) is the docs repository or the project checkout. Commits equal `git log --oneline <recorded HEAD>..HEAD` there; every other repository of the run still has its recorded HEAD.
3. The project checkout and the docs repository are clean.
4. No Artifacts document ends with a line matching `^Review: `.
5. For a brief, spec or follow-ups input, the input file's SHA-256 equals the recorded one.
6. The final [child settings check](../independent-review/references/launch-settings.md#child-settings-check) over every opening's record matches, or the user accepted its result.

A settings mismatch or `settings unverified: <reason>` never goes back to the child: show expected and observed values and the record paths, and ask the user to accept the result with the observed settings or stop with everything preserved. Any other mismatch goes back to the child once: archive the status to `<file>-rejected-<n>`, `send` one line naming the mismatch and asking for a fresh report at the same path, wait and verify again. A repeated mismatch goes to the user, with window and status kept.

## Report

Report the spec and plan paths, the repository and commits that hold them, and every Out of scope line. Add one settings line: role `planner`, effective model and effort, source of each, the settings check outcome, and the record paths or the user's acceptance. After a verified `done`, `close plan-<slug>`; otherwise the window and status stay for the user. Nothing is merged, reviewed or executed here: review is `refining-task-docs`, execution `executing-task-docs`.
