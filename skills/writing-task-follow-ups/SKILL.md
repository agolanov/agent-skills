---
name: writing-task-follow-ups
description: Creates, replaces or clears one branch's section in the follow-ups file beside a task document, listing findings left outside the task (out-of-scope items, deferred and disputed review findings). Use when a task branch's review is done and its leftover findings must be recorded, or when another skill hands over follow-ups to write.
---

# Writing Task Follow-ups

For each clean/path gate and continuation below and in child briefs, use the four ordinary Git commands and identity checks in [checkout state](../independent-review/references/checkout-state.md#direct-use-preflight), with process-local `GIT_OPTIONAL_LOCKS=0`, actual exits and raw output files. Only the follow-ups file is owned. Other staged or unstaged paths pass and stay untouched; the post-commit own-paths gate requires that file to have no pending change. A clean gate requires successful commands and empty status and diffs; path gates parse NUL-delimited status and compare exact repository-relative paths, including both rename paths. Failed or unavailable Git evidence stops the dependent action. Use ordinary Git for other read-only checks, retaining real exits. Evidence has the reference's ignored/untracked-content, Git flags/normalization, nested-repository and transient-write limits. Stage/commit only owned paths; write, merge and push authority stays explicit.


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
3. Commit, before writing: record fresh ordinary Git evidence and checkout identity for `--checkout`; an unavailable one stops before any write and is reported. Every exact affected path passes: another path is unrelated work, counted for the Report and left as it is, staged or not; a pending change to the follow-ups file is left by an earlier interrupted run and is committed like a new one. Then write the file and stage only this path (`git --literal-pathspecs add -- <file>`, or `git --literal-pathspecs rm -q --ignore-unmatch -- <file>` for a removed file; --literal-pathspecs keeps Git from reading a file name such as `:(glob)…` as pathspec magic). When the staged path then equals its version in the checkout's HEAD (`git --literal-pathspecs diff --cached --quiet HEAD -- <file>` exits 0; both absent counts as equal), report `not committed: no change`. Otherwise commit only this path on the checkout's current branch, `git --literal-pathspecs commit -m "follow-ups: <branch>" -- <file>`: the pathspec keeps other staged changes staged and out of the commit. The message ends with its own content, unsigned: no `Co-Authored-By` trailer and no "Generated with" line.
4. After a commit, require both: an own-paths gate on a fresh preflight of `--checkout` passes (the follow-ups file is not among the exact affected paths), and the commit's changed paths (`git show --name-only --format= --no-renames <sha>`) are exactly the follow-ups file. A failed or unavailable check is reported with the commit SHA.

## Report

The file's absolute path, the number of findings written (`0` after a removal or with nothing to write), and the full commit SHA or `not committed: <reason>`. When the pre-write preflight listed paths other than the follow-ups file, add `unrelated uncommitted changes left untouched: <count>`, without listing them.
