# CLI Reviewers

Use a separate CLI session for the assigned system. Start a fresh reviewer each round with the filled [round prompt](round-prompt.md) and finding ledger supplied by `refine`. Keep prompts, answers, and logs outside the task checkout. The implementing session stays responsible for fixes.

Check installed `codex review --help` or `claude --help` when constructing a launch. Use absolute paths, quote variables, and capture the real exit status separately from the answer. Wait for the process to finish using the host's background execution and wait tools; keep the controlling session active until the loop finishes or blocks.

Carry the [round-prompt capability contract](round-prompt.md) unchanged into the independent session. Retain normal permissions, tools, skills/plugins and MCP configuration. Configure process-local permissions only for already authorized checks; persistent settings and silent authority expansion remain excluded.

## Codex reviewer

The Codex launch uses `codex review -` as an independent session carrying the complete round prompt through stdin. Put the target in that prompt: installed review mode accepts a custom prompt or a scope flag, never both. Do not combine stdin instructions with `--base`, `--commit` or `--uncommitted`.

Set `task_checkout`, `review_model`, `review_effort`, `round_prompt`, and `round_dir` from the loop record:

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

Review mode has no `--json` or `--output-last-message` in the tested CLI. Its stdout is the report; stderr contains runtime/command evidence and its session ID. Retain normal authorized configuration. Where a session needs already authorized sandbox/approval options, pass supported global options **before** `review` (check installed top-level help). Only explicit unrestricted-execution authority permits `codex --dangerously-bypass-approvals-and-sandbox review ...`; otherwise retain the authorized settings. If this mode cannot apply them, report a blocker instead of broadening authority or changing persistent configuration.

**Experiment, 2026-10-29, codex-cli 0.165.0:** identical round-1 prompts sent to `codex exec` and `codex review -` both read the requirements file, reproduced the seeded inclusive-endpoint defect despite passing tests, and retained the required verdict/findings/coverage/check report. Identical round-2 prompts made both verify the single fix commit first; review mode's command trace ran F1 regressions and a parent-versus-HEAD probe before other checks. All four exits were 0, with HEAD and porcelain unchanged; runtime records showed the assigned model/high effort. Therefore the launch switches to stdin review mode. This is evidence for the tested version, not every future CLI; rerun the comparison after relevant runtime/launch changes.

Local raw experiment artifacts live in ignored `tests/refine/e2e-notes.md` and its referenced temporary directory; they are not shipped with a fresh clone.

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

Keep the reviewer exit status even after extracting the answer. Verify effective settings from runtime records, not invocation flags or self-report: Codex review startup headers expose model/effort, corroborated by persisted `thread_settings_applied.thread_settings` (model/reasoning_effort); exec sessions may instead expose `turn_context` (model/effort); Claude initialization/model usage plus the matching persisted session transcript's `output_config.effort` expose the pair where supported. If that evidence is unavailable, record unverified settings and invalidate the result. Read answer, coverage, runtime model/effort metadata, and errors together. A model/effort rejection, capacity error, startup/account permission failure, or missing executable is a launch failure. A denied tool call inside an otherwise running session is a coverage limitation, not automatically a failed launch: require disclosure and judge whether required review coverage and checks were completed. A denied optional lookup replaced by sufficient evidence does not invalidate a complete review; missing essential coverage or checks does. A CLI fallback or settings coercion is not the assigned review. Follow the common protocol's result and retry rules; do not substitute model, effort, system, or permissions.

If the user explicitly requested CLI defaults, omit the corresponding overrides and record the effective settings rather than claiming the automatic defaults were used. Otherwise pass both resolved settings explicitly.

Sources for command semantics: [Codex non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode), [Claude Code CLI](https://code.claude.com/docs/en/cli-reference). Installed help takes precedence for version-specific flags.

The [round prompt](round-prompt.md) owns the full reviewer capability and unchanged-state contract; carry it into every independent session. Vendor review commands are tools within that session, not replacements for its requirements, finding ledger or stage order.
