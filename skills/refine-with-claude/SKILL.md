---
name: refine-with-claude
description: Use when a review/fix cycle specifically requires a separate Claude CLI reviewer, including Claude reviewing work implemented in Claude Code.
---

# Refine with Claude

1. Read shared [review-fix-loop](../review-fix-loop/SKILL.md), locating it in the installed catalog if the sibling is unavailable. Missing dependency: report that the complete bundle is required and stop before review/fixes; do not install or invent the protocol.
2. Assign **method `cli`, system `claude`**: a separate process even on the same host. `--claude` and `--reviewer claude` confirm; a Codex or subagent selector conflicts and requires clarification.
3. Forward task/worktree context, explicit model/effort (including premium assignments), limits and permissions unchanged to review-fix-loop's **Launch assigned reviewer** section. The implementing session runs its loop and fixes; only independent review goes to the CLI.
