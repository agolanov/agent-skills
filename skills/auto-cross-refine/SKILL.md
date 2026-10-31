---
name: auto-cross-refine
description: Use when the user requests a review/fix cycle with automatic selection of the other coding system, Codex versus Claude, as the reviewer.
---

# Auto Cross Refine

Choose the reviewer system, then delegate to its launcher. The launcher supplies the assignment to `review-fix-loop`; the implementing session continues to own the loop and fixes.

1. Honor an explicit `--codex`, `--claude`, `--reviewer codex|claude`, or equivalent reviewer instruction first. Otherwise retain the recorded single CLI assignment when resuming the same loop. With neither, identify the current implementing host from session identity, not executable availability, inherited environment variables, directory names, or model guesses:

   | Implementing host | Reviewer | Required launcher |
   | --- | --- | --- |
   | Codex | Claude | [refine-with-claude](../refine-with-claude/SKILL.md) |
   | Claude Code | Codex | [refine-with-codex](../refine-with-codex/SKILL.md) |

2. Unknown host without an explicit reviewer, conflicting CLI selectors, a subagent selector, a `--dual` selector, or a recorded `dual` assignment requires clarification. Announce the chosen system and any explicit override of opposite-system selection.
3. Locate and read the selected launcher through its sibling path or installed skill catalog. If unavailable, report the missing dependency and stop before review or fixes. Tell the user that the complete refinement bundle is required; do not install it as part of this cycle. Preserve an unavailable selected system rather than substitute the parent's CLI.
4. Forward all task/worktree context, explicit model/effort, limits, and permissions unchanged to that launcher. It forwards the assignment to review-fix-loop's **Launch assigned reviewer** section and executes the shared protocol. This skill adds no separate review loop, fixes, or integration authority.
