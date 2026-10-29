---
name: refine-with-a-subagent
description: Use when a review/fix cycle is requested with a built-in subagent of the implementing system instead of a separate CLI reviewer process.
---

# Refine with a Subagent

1. Read shared [refine](../refine/SKILL.md), using the installed catalog if its sibling is unavailable. Missing dependency: report that the complete bundle is required and stop before review/fixes; do not install or invent the protocol.
2. Assign **method `subagent`, system matching the implementing host** (Codex or Claude Code); unknown host requires clarification. `--subagent` confirms; CLI selectors conflict and require clarification.
3. Forward task/worktree context, explicit model/effort, limits and permissions to refine's **Launch assigned reviewer** section and native guide. The implementing session keeps the loop and fixes. Delegate only review with normal capabilities and verified settings; unavailable native controls block without CLI substitution or persistent configuration edits.
