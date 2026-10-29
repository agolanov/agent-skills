---
name: refine
description: Use when an independent review/fix cycle is requested with an assigned reviewer, or another refine skill supplies that assignment. Not for a read-only review alone.
---

# Refine

The implementing session owns finding decisions, fixes, and this loop. An independent reviewer checks the result. Launch skills supply the reviewer assignment; this protocol does not choose a coding system automatically.

## Prepare

1. Require an assignment: launch method (`cli` or `subagent`), system (`codex` or `claude`), and any explicit model/effort/permissions. A caller supplies it; direct use can specify `--codex`, `--claude`, or `--subagent`, or equivalent prose. The long CLI forms `--reviewer codex|claude` also work. With no assignment, ask how to run the reviewer before proceeding. Resolve conflicting selections rather than guessing.
2. Resolve the task checkout from the request and implementation context; verify its absolute path, branch, HEAD, fixed base, and status. A parent started in the primary checkout may have worked in a worktree: review that worktree. Include branch changes since the base, staged/unstaged task changes, and task-owned untracked files. Preserve unrelated work and list exclusions. Resolve ambiguous checkout or scope first.
3. Read [reviewer settings](references/reviewer-settings.md). Accept independent `--model MODEL` and `--effort LEVEL` overrides; default effort is `high`. Announce and record the resolved assignment. Use the assigned launch guide: [CLI](references/cli-reviewers.md) or [native subagent](references/subagent-reviewers.md). Missing runtime capabilities block that method; another method needs explicit authorization.
4. Use the user's round limit; default to 10 completed rounds. Keep one compact record outside reviewed files: scope/base, assignment, snapshots, results, pending-round retry count, and finding IDs/decisions. Reuse the task log when available.

## Repeat until clean

1. **Freeze a snapshot.** Record HEAD and save task diffs and untracked contents outside the checkout. Keep reviewed material stable while the reviewer works. HEAD alone cannot identify uncommitted fixes.
2. **Request independent review.** Supply the scope, snapshot, requirements/plan, project rules, checks, and finding ledger. The first round covers the complete task. Every later round requires this order:
   1. Verify every previously accepted fix and its regressions against the preceding reviewed snapshot; reconsider rejected findings only with new evidence.
   2. Review the complete current task again against the original requirements, including branch changes and uncommitted task files.

   Request `VERDICT: CLEAN` or `VERDICT: CHANGES`, prior-finding dispositions, concrete in-scope findings (severity, `path:line`, failure scenario, proposed fix), coverage/omissions, and checks actually run. Outside-scope candidates are reported separately. Include this capability contract in every round prompt: use any available tools, installed skills and plugins that improve the review, including shell commands, checks, browsers, MCP, and diagnostic artifacts outside the reviewed files. Keep existing user/project permissions; add no tool filters or skill/plugin disabling merely to enforce a review role. Leave reviewed files, index, HEAD, and branches unchanged. Only the implementing session fixes code.
3. **Validate the result.** Require successful completion (CLI exit 0 or native tool completion), a substantive answer covering the required scope/stages, the assigned model/effort, and an unchanged snapshot. Failed, partial, empty, stale, or substituted results are invalid. If a writer changed the snapshot, preserve the work, save the unexpected diff and identify its source; pause automatic retries. The implementing session must adjudicate and reconcile those edits within its authority and rerun affected checks before a new snapshot; unresolved ownership/scope blocks the loop. Never adopt unexpected edits by simply freezing the changed state, or reset unrelated work. Every invalid attempt, including a changed snapshot, uses the same pending-round budget: one initial attempt and at most one retry with the same assignment. Reconciliation or a new snapshot does not reset this budget; a second invalid attempt blocks. Invalid attempts do not consume completed rounds.
4. **Decide and fix.** Verify findings against code and requirements. Record accepted, rejected-with-reason, or outside-scope decisions. Fix confirmed in-scope issues, run affected required checks, then repeat. If all findings are rejected, send those decisions into another complete review. Outside-scope candidates stay in the report. An unexpected failed check, including a nonzero exit after PASS text, or a dependency needing broader authority blocks dependent work.

## Finish

Report clean only with a valid complete `VERDICT: CLEAN`, no unresolved accepted in-scope findings, and passing required checks on the final unchanged snapshot. A later task edit invalidates review. Report rounds, assignment, reviewed state, checks, decisions, and remaining candidates.

At the round limit or a blocker, report incomplete with the reason and next action. Continue within existing authority; this protocol grants no additional commit, merge, push, deploy, or scope permissions.
