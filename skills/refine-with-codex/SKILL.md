---
name: refine-with-codex
description: Use when a review/fix cycle specifically requires a separate Codex CLI reviewer, including Codex reviewing work implemented in Codex.
---

# Refine with Codex

1. Locate and read the shared [refine](../refine/SKILL.md) skill, using the installed skill catalog if the sibling link is unavailable. If it is missing, report the missing dependency and stop before review or fixes. Tell the user that the complete refinement bundle is required; do not install it as part of this cycle.
2. Supply the reviewer assignment: **method `cli`, system `codex`**. This is a separate process, even when the parent is Codex. `--codex` and `--reviewer codex` are equivalent confirmations; a Claude or subagent selector conflicts with this entry point and requires clarification.
3. Forward task/worktree context, `--model`, `--effort`, natural-language overrides, limits, and existing permissions unchanged. Resolve missing model/effort through the common settings; retain explicit premium assignments when supported.
4. Execute `refine` in the implementing session using its CLI launch guide. Only the independent review runs in Codex; the implementing session keeps findings decisions and fixes. Reuse the common protocol rather than copying its loop here.
