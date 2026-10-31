---
name: refine-with-codex
description: Use when a review/fix cycle specifically requires a separate Codex CLI reviewer, including Codex reviewing work implemented in Codex.
---

# Refine with Codex

1. Read shared [review-fix-loop](../review-fix-loop/SKILL.md), locating it in the installed catalog if the sibling is unavailable. Missing dependency: report that the complete bundle is required and stop before review/fixes; do not install or invent the protocol.
2. Assign **method `cli`, system `codex`**: a separate process even on the same host. `--codex` and `--reviewer codex` confirm; a Claude, subagent or `--dual` selector conflicts and requires clarification.
3. Forward task/worktree context, explicit model/effort (including premium assignments), limits and permissions unchanged to review-fix-loop's **Launch assigned reviewer** section. The implementing session runs its loop and fixes; only independent review goes to the CLI.
