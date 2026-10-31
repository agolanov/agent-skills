---
name: refine-with-dual-review
description: Use when a review/fix cycle should have two independent reviewers, Codex and Claude CLI, in every round, with each finding confirmed by both before it is fixed.
---

# Refine with Dual Review

1. Read shared [review-fix-loop](../review-fix-loop/SKILL.md), locating it in the installed catalog if the sibling is unavailable. Missing dependency: report that the complete bundle is required and stop before review/fixes; do not install or invent the protocol.
2. Assign **`dual`**: Codex CLI and Claude CLI review every round through `dual-review`, separate processes even on the same host. `--dual` confirms; `--codex`, `--claude`, `--subagent` or `--reviewer` conflicts and requires clarification.
3. Forward task/worktree context, per-reviewer model/effort (including premium assignments), limits and permissions unchanged to review-fix-loop's **Launch assigned reviewer** section. The implementing session runs its loop and fixes; only the reviews go to the two CLIs.
