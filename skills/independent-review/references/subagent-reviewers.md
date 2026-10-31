# Native Subagent Reviewer

Use the implementing system's built-in subagent tool, not a separate `codex` or `claude` CLI process.

1. Inspect the actual native tool schema and available agent settings. Resolve model and effort through [reviewer settings](reviewer-settings.md). Require controls or an existing agent definition that can select and verify the pair. Do not choose an artificially restricted agent type/definition merely to obtain model/effort.
2. Start a fresh independent reviewer with a self-contained [review prompt](review-prompt.md) from the caller (the loop record, or the direct-use request). Use a clean context where supported. Supply the absolute task checkout and require inspection there; native helpers may inherit the primary checkout instead. Do not request a new worktree or a writing implementer. Preserve the host's normal tool, skill, plugin and MCP access, including skill discovery and automatic invocation, rather than selecting a reduced tool set to enforce the review role. Inherent runtime restrictions still apply and must be disclosed when they limit coverage.
3. Set both model and effort explicitly using the current tool's supported controls. In Codex this can be `model` plus `reasoning_effort` with `fork_turns: "none"`; actual tool/schema limits apply. In Claude use supported per-invocation controls or an existing definition. Verify the actual model and effort from runtime metadata.
4. Wait for the native agent's completed review, using the host's wait/result tools. A spawn ID, acknowledgement, or intermediate question is not a review result. Save the final answer and completion evidence outside the checkout and return them to `independent-review` **Validate**; the caller owns the retry budget. Native completion has no shell exit code.

If spawning is unavailable, the exact requested pair cannot be selected/verified, or an inherited setting overrides it, report the capability blocker. Preserve the requested method and settings: do not silently switch to CLI, downgrade, or edit persistent agent/configuration files. The user can explicitly choose another assignment.

Sources: [Codex subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents), [Claude subagent models and effort](https://code.claude.com/docs/en/sub-agents).
