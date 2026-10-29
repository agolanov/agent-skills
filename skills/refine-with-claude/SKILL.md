---
name: refine-with-claude
description: Use when a review/fix cycle specifically requires a separate Claude CLI reviewer, including Claude reviewing work implemented in Claude Code.
---

# Refine with Claude

1. Locate and read the shared [refine](../refine/SKILL.md) skill, using the installed skill catalog if the sibling link is unavailable. If it is missing, report the missing dependency and stop before review or fixes. Tell the user that the complete refinement bundle is required; do not install it as part of this cycle.
2. Supply the reviewer assignment: **method `cli`, system `claude`**. This is a separate process, even when the parent is Claude Code. `--claude` and `--reviewer claude` are equivalent confirmations; a Codex or subagent selector conflicts with this entry point and requires clarification.
3. Forward task/worktree context, `--model`, `--effort`, natural-language overrides, limits, and existing permissions unchanged. Resolve missing model/effort through the common settings; retain explicit premium assignments when supported.
4. Execute `refine` in the implementing session using its CLI launch guide. Only the independent review runs in Claude; the implementing session keeps findings decisions and fixes. Reuse the common protocol rather than copying its loop here.
