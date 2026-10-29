---
name: refine-with-a-subagent
description: Use when a review/fix cycle is requested with a built-in subagent of the implementing system instead of a separate CLI reviewer process.
---

# Refine with a Subagent

1. Locate and read [refine](../refine/SKILL.md), through its sibling path or the installed skill catalog. If missing, report the dependency and stop before review or fixes. Tell the user that the complete refinement bundle is required; do not install it as part of this cycle.
2. Identify the implementing system from the current session: Codex or Claude Code. Supply **method `subagent`, system matching that host**. Unknown host requires clarification. `--subagent` confirms this method; CLI selectors conflict with this entry point.
3. Forward the task checkout, scope, explicit model/effort, limits, and permissions. Resolve missing settings through `refine`; use its native subagent guide. Require native controls or an existing definition that can select and verify those settings. Missing controls are a blocker, not permission to start a CLI process or rewrite persistent configuration.
4. The implementing session executes the common loop and makes fixes. Delegate only the independent review role, preserving normal tools, skills and plugins, with the complete round prompt and task worktree path. Return its completed review to `refine` for validation and the next action.
