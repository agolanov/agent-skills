# CLI Reviewers

Use a separate CLI session for the assigned system. Start a fresh reviewer each round with the prompt and finding ledger supplied by `refine`. Keep prompts, answers, and logs outside the task checkout. The implementing session stays responsible for fixes.

Check installed `codex exec --help` or `claude --help` when constructing a launch. Use absolute paths, quote variables, and capture the real exit status separately from the answer. Wait for the process to finish using the host's background execution and wait tools; keep the controlling session active until the loop finishes or blocks.

Preserve the CLI's normal tools, installed skills, plugins, and MCP configuration. Unless the user explicitly requests capability limits, add no `--tools` whitelist, `--disallowedTools` denylist, skill/plugin disabling, or empty/restricted MCP configuration. Review-only is a task contract, not a reduced tool set; skills may use editing tools for authorized scratch artifacts outside the reviewed files. Existing user/project permissions still apply. Configure session permissions for already authorized checks when needed, without changing persistent settings or silently broadening authority.

## Codex reviewer

Set `task_checkout`, `review_model`, `review_effort`, `round_prompt`, and `round_dir` from the resolved task. Example with explicitly selected model and effort:

```bash
codex exec -C "$task_checkout" \
  --model "$review_model" \
  -c "model_reasoning_effort=\"$review_effort\"" \
  --json --output-last-message "$round_dir/answer.md" - \
  < "$round_prompt" > "$round_dir/events.jsonl" 2> "$round_dir/stderr.log"
review_exit=$?
```

If the user explicitly authorized unrestricted reviewer execution, add `--dangerously-bypass-approvals-and-sandbox`. Otherwise use the authorized sandbox/approval settings. Prompt-level review-only authority still applies under unrestricted execution.

## Claude reviewer

Use a subshell so the implementing session keeps its working directory:

```bash
(
  cd "$task_checkout" || exit
  claude --print --model "$review_model" --effort "$review_effort" \
    --output-format stream-json --verbose \
    < "$round_prompt" > "$round_dir/events.jsonl" 2> "$round_dir/stderr.log"
)
review_exit=$?
jq -r 'select(.type == "result") | .result // empty' \
  "$round_dir/events.jsonl" > "$round_dir/answer.md"
```

Explicit unrestricted execution maps to `--permission-mode bypassPermissions`; otherwise retain authorized settings. Pass the prompt through stdin and preserve the full normal capability set. The reviewer follows the common protocol's reviewed-state contract even when editing tools are available.

## Result handling

Keep the reviewer exit status even after extracting the answer. Read answer, coverage, runtime model/effort metadata, and errors together. A model/effort rejection, capacity error, startup/account permission failure, or missing executable is a launch failure. A denied tool call inside an otherwise running session is a coverage limitation, not automatically a failed launch: require disclosure and judge whether required review coverage and checks were completed. A denied optional lookup replaced by sufficient evidence does not invalidate a complete review; missing essential coverage or checks does. A CLI fallback or settings coercion is not the assigned review. Follow the common protocol's result and retry rules; do not substitute model, effort, system, or permissions.

If the user explicitly requested CLI defaults, omit the corresponding overrides and record the effective settings rather than claiming the automatic defaults were used. Otherwise pass both resolved settings explicitly.

Sources for command semantics: [Codex non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode), [Claude Code CLI](https://code.claude.com/docs/en/cli-reference). Installed help takes precedence for version-specific flags.
