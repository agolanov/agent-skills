---
name: refining-task-docs
description: Cross-reviews one task's spec and plan in a visible child agent session, fixes the findings and marks each document that ends the review clean with a Review line, leaving freshly marked documents as context. Use when task documents should be reviewed and fixed before execution, or when a document's Review mark is missing or stale.
---

# Refining Task Docs

For every checkout cleanliness or changed-path gate below and in child briefs/references, use [checkout-state Direct-use preflight](../independent-review/references/checkout-state.md#direct-use-preflight). Resolve its installed helper, retain fresh evidence, and require `uncommitted: false` for clean. Unavailable verification stops the dependent action; raw status/diff is not a fallback. Path allowlists use the result's decoded exact `paths`. This applies separately to project, docs and child checkouts. Every read-only Git verification below and in references/child briefs (log, refs, roots, ancestry and diffs included) uses that reference's `git-read` command; displayed `git <read-command>` notation means this wrapper, never a raw invocation. Resolve paths relative to the containing checkout root. Mutating commands keep their explicit authorization.


`refining-task-docs <spec|plan> [<plan|spec>] [--agent claude|codex] [--model M] [--effort E]`

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
3. Docs repository = `git -C <document-dir> rev-parse --show-toplevel`; every document of the run must lie in the same one. Require the project checkout and the docs repository clean (one check when they are the same repository). Record the docs repository's full HEAD as `<base-sha>` and, when the project checkout is another repository, its full HEAD.
4. Classify each document fresh or stale per [review-mark.md](references/review-mark.md#freshness), `rel` relative to the docs repository, and show each to the user: fresh with verdict, reviewer and date; stale with the failing condition. Stale documents are the documents to review; fresh ones are context only. None stale: report "nothing to review" with each document's mark and stop; no window opens.

## Preflight

1. Select `--agent`, otherwise identify the root's own system from session identity as `auto-cross-refine` does; unknown identity requires clarification. Never infer the agent from executable availability, environment, directory names or model.
2. Locate the installed `child-sessions/SKILL.md`; read it, its `references/brief-writing.md` and `references/status-file.md`. Call `scripts/child-session` beside it by absolute path, never through PATH; its command/status contract governs every call. `<runtime>` is `${XDG_RUNTIME_DIR:-/tmp}/child-sessions`.
3. Check the selected child's actual installed catalogs (Claude: `~/.claude/skills`, enabled `~/.claude/plugins`; Codex: `~/.codex/skills`, `~/.agents/skills`, enabled `~/.codex/plugins`; plus the project's `.claude/skills` and `.agents/skills`). Resolve readable absolute SKILL.md paths for `auto-cross-refine`, the opposite launcher (`refine-with-codex` for a Claude child, `refine-with-claude` for Codex), `review-fix-loop` and `independent-review`. Executables or the root's catalog alone do not prove child skill availability. Missing ones stop before any window; report them for the user to install, without substitution.
4. Names: `<stem>` is the plan's stem when the run has a plan, else the spec's, with every character outside `[A-Za-z0-9_-]` replaced by `-`. Window `refine-<stem>`, brief `<runtime>/refine-<stem>-brief.md`, status `<runtime>/refine-<stem>-status.md`. A live window of that name (`alive refine-<stem>` returns 0) is refused, naming it. Leftover runtime files of that name from an earlier run (brief, status, and their archived `-blocked-<n>` and `-rejected-<n>` copies) are renamed to `<file>-old-<n>`, `n` the smallest unused number; no file exists at the status path when the brief is written.

## Brief

Fill [refiner-brief.md](references/refiner-brief.md) with absolute resolved paths, following child-sessions' brief checklist, and write it to the brief path.

## Open and wait

1. Call `open --agent <agent> [--model M] [--effort E] refine-<stem> <project checkout> <brief>`, quoting paths. The child works in the project checkout: no worktree, no branch of its own.
2. Follow child-sessions' foreground loop: `wait refine-<stem> <status> 240` on Codex, `540` on Claude. A Codex tool yield is not a timeout: poll the same returned foreground session in intervals of at most 60 seconds until it exits.
3. On exit `0`, read the exact first status line. `done` proceeds to Verify. `blocked` shows Questions, options and recommendation, obtains the user's answer, archives the status to `<file>-blocked-<n>`, sends one line or an absolute answer-file instruction, then waits for a fresh status. `failed` shows the failure and stops, keeping the window and status; go to Report.
4. Exit `3`: `peek refine-<stem> 40`, show diagnostics, append “Continue from the current state of the checkout: read git log and run the checkout-state preflight first.” to the brief, close the stale window if present and reopen once with the same options. A second silent exit stops, keeping the window and status. Exit `124`: `peek refine-<stem> 40`; wait again for work in progress, or handle a dialog per child-sessions Dialogs. Other errors stop with artifacts preserved.
5. Before every `send` (a `blocked` answer here, a mismatch line in Verify), run `alive refine-<stem>`: a dead agent leaves a shell that would run the text. Dead: `close refine-<stem>`, append the continuation line of step 4 and then the line you meant to send to the brief, and `open` again with the same options; this is the run's one reopen, shared with step 4. When that reopen was already used, stop and report, keeping the window and runtime files.

## Verify

On `done`, all of these must hold:

1. Full status format with `## Artifacts`; BRANCH, CHECKOUT and HEAD name the docs repository's current branch, top level and full HEAD.
2. Commits equal `git log --oneline <base-sha>..HEAD` in the docs repository. When the project checkout is another repository, its HEAD is still the recorded one.
3. The project checkout and the docs repository are clean.
4. Review gives final refine mode `CLEAN` or `CLEAN EXCEPT DISPUTED`, with the raw reviewer verdict reported separately; dispute-only closure can keep raw `CHANGES`, never relabelled CLEAN.
5. Every document to review is under Artifacts, and every Artifacts path lies in the docs repository and passes the freshness check of review-mark.md, run by the root.
6. Every path of `git diff --name-only --no-renames <base-sha> HEAD` in the docs repository is an Artifacts path (relative to the docs repository): nothing but the reviewed documents and the context documents the child changed has changed.

A mismatch goes back to the child once: archive the status to `<file>-rejected-<n>`, `send` one line naming the mismatch and asking for a fresh report at the same path, wait and verify again. A repeated mismatch goes to the user, with window and status kept.

## Report

Report the final refine mode and the raw reviewer verdict; each document with its new `Review:` line, `fresh, context only` when untouched, or `not marked: <why>`; disputed findings with both positions; the commits; and every Out of scope line. Without a clean verdict nothing is marked, and the report says what is left: the documents still unmarked and the open findings the status names. After a verified `done`, `close refine-<stem>`; otherwise the window and status stay for the user.
