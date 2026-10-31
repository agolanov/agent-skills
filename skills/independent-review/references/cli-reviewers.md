# CLI Reviewers

Use a separate CLI session for the assigned system. Start a fresh reviewer each round with the filled [review prompt](review-prompt.md) and finding ledger from the caller (the loop record, or the direct-use request). 
Check installed `codex review --help` or `claude --help` when constructing a launch. Use absolute paths, quote variables, and capture the real exit status separately from the answer. Wait for the process to finish using the host's background execution and wait tools; keep the controlling session active until the caller's review finishes or blocks.

Carry the [review prompt](review-prompt.md) unchanged into the independent session; it owns the reviewer's capability and unchanged-state contract, and vendor review commands are tools inside it. Retain normal permissions, tools, skills/plugins and MCP configuration. Configure process-local permissions only for already authorized checks; persistent settings and silent authority expansion remain excluded.

## Codex reviewer

The Codex launch uses `codex review -` as an independent session carrying the complete review prompt through stdin. Put the target in that prompt: installed review mode accepts a custom prompt or a scope flag, never both. Do not combine stdin instructions with `--base`, `--commit` or `--uncommitted`.

Set `task_checkout`, `review_model`, `review_effort`, `round_prompt`, and `round_dir` from the caller (the loop record, or the direct-use request):

```bash
(
  cd "$task_checkout" || exit
  codex review \
    -c "model=\"$review_model\"" \
    -c "model_reasoning_effort=\"$review_effort\"" - \
    < "$round_prompt" > "$round_dir/answer.md" 2> "$round_dir/stderr.log"
)
review_exit=$?
```

Review mode has no `--json` or `--output-last-message` in the tested CLI. Its stdout is the report; stderr contains runtime/command evidence and its session ID. Pass already authorized sandbox/approval options as global options **before** `review` (check installed top-level help); only explicit unrestricted-execution authority permits `codex --dangerously-bypass-approvals-and-sandbox review ...`. If review mode cannot apply an authorized option, report a blocker.

**Why stdin review mode:** on codex-cli 0.165.0 (2026-10-29) identical round prompts sent to `codex exec` and `codex review -` produced the same findings, verdicts and coverage, with exit 0, HEAD and porcelain unchanged and the assigned model/effort in the runtime records; in round 2 both verified the fix commit first. This is evidence for the tested version only: rerun the comparison after relevant runtime/launch changes. Raw artifacts live in ignored `tests/refine/e2e-notes.md`, not in a fresh clone.

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

Explicit unrestricted execution maps to `--permission-mode bypassPermissions`.

## Result handling

Read answer, coverage, runtime model/effort metadata, errors and exit status together, then apply the validation rules of `independent-review` **Validate**; the caller owns the retry budget:

- Verify effective settings from runtime records, not invocation flags or self-report. Codex review startup headers expose model/effort, corroborated by persisted `thread_settings_applied.thread_settings` (model/reasoning_effort); exec sessions may instead expose `turn_context` (model/effort). Claude initialization/model usage plus the matching persisted session transcript's `output_config.effort` expose the pair where supported. Unavailable evidence means unverified settings: invalidate the result.
- A model/effort rejection, capacity error, startup/account permission failure, or missing executable is a launch failure.
- A denied tool call inside an otherwise running session is a coverage limitation, not automatically a failed launch: require disclosure and judge whether required review coverage and checks were completed.

With a CLI-defaults opt-out ([reviewer settings](reviewer-settings.md)), omit the model and effort overrides; otherwise pass both resolved settings explicitly.

Sources for command semantics: [Codex non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode), [Claude Code CLI](https://code.claude.com/docs/en/cli-reference). Installed help takes precedence for version-specific flags.
