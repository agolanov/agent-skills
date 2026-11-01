---
name: writing-task-follow-ups
description: Creates, replaces or clears one branch's section in the follow-ups file beside a task document, listing findings left outside the task (out-of-scope items, deferred and disputed review findings). Use when a task branch's review is done and its leftover findings must be recorded, or when another skill hands over follow-ups to write.
---

# Writing Task Follow-ups

For every checkout cleanliness or changed-path gate below and in child briefs/references, use [checkout-state Direct-use preflight](../independent-review/references/checkout-state.md#direct-use-preflight). Resolve its installed helper, retain fresh evidence, and require `uncommitted: false` for clean. Unavailable verification stops the dependent action; raw status/diff is not a fallback. Path allowlists use the result's decoded exact `paths`. This applies separately to project, docs and child checkouts. Every read-only Git verification below and in references/child briefs (log, refs, roots, ancestry and diffs included) uses that reference's `git-read` command; displayed `git <read-command>` notation means this wrapper, never a raw invocation. Resolve paths relative to the containing checkout root. Mutating commands keep their explicit authorization.


`writing-task-follow-ups --doc <task-document> --branch <branch> --head <full-sha> --checkout <checkout> [--findings <file>] [--no-commit]`

Runs in the session that invokes it, child or root; it opens no window. It behaves the same whoever calls it.

## Input

1. `--doc`: absolute path of the task document (for a plan, the plan) in the checkout where the file is to be written. `--branch`: the task branch. `--head`: full SHA of the last commit the review covered. `--checkout`: the checkout to commit in (the task worktree, or the docs main checkout). The date is today, `YYYY-MM-DD`.
2. Findings: one per line in the entry form `- <what> — <where> — <why>`, where `<where>` is a concrete `path:line` and `<why>` says why the finding is outside the task; a disputed finding's `<why>` carries both positions and the open question. They come from the file named by `--findings`, else from the lines the caller lists with the invocation. No findings is a valid input. A line not in the entry form goes back to the caller; never invent, merge or drop a finding.

## File

1. Path: `<doc-dir>/<doc-stem>-follow-ups.md`, beside the task document (`plans/2026-11-01-greet.md` → `plans/2026-11-01-greet-follow-ups.md`).
2. One section per branch:

   ```markdown
   ## <branch> @ <head-sha7> (<YYYY-MM-DD>)
   - <what> — <where> — <why>
   ```

   `<head-sha7>` is the first seven characters of `--head`.
3. A section starts at its `## ` line and runs to the next line starting with `## `, or the end of the file. The branch's section is the one whose heading starts with `## <branch> @ `.
4. With findings: replace the branch's section as a whole, in place, with the new heading and entries; when it has none, append the section at the end. Every other section stays byte-identical.
5. With no findings: remove the branch's section. When no section remains, remove the file. When the branch has no section, change nothing and create no file.
6. A written file ends with exactly one newline, with one blank line between sections.

## Commit

1. Decide the mode. Take the docs toplevel `git -C <doc-dir> rev-parse --show-toplevel`. **Local**: `--no-commit` was given, or `git -C <toplevel> check-ignore -q <doc-dir>` exits 0 (a directory the project ignores without its own repository). **Commit**: otherwise; the toplevel must equal `--checkout`, else stop and report the mismatch.
2. Local: write the file in place. No staging, no commit, no force-add. Report `not committed: <--no-commit | ignored by the project without its own repository>`.
3. Commit, before writing: a fresh checkout-state preflight of `--checkout` must be clean, or list in decoded `paths` only the follow-ups file; anything else stops before any write and is reported. Then write the file. When its content did not change, report `not committed: no change`. Otherwise stage only this path (`git add -- <file>`, or `git rm -q -- <file>` for a removed file) and commit it on the checkout's current branch as `follow-ups: <branch>`. The message ends with its own content, unsigned: no `Co-Authored-By` trailer and no "Generated with" line.
4. After a commit, require a clean checkout-state preflight of `--checkout`; a dirty or unavailable result is reported with the commit SHA.

## Report

The file's absolute path, the number of findings written (`0` after a removal or with nothing to write), and the full commit SHA or `not committed: <reason>`.
