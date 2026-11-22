# CLI Reviewers

Use a separate CLI session for the assigned system. Start a fresh reviewer for each attempt. A native attempt carries the [wrapper](review-wrapper.md#the-wrapper), with the task's data in the attempt's `context.md`; a caller-supplied prompt (the dual review's cross-check) is carried unchanged instead.
Check installed `codex review --help` or `claude --help` when constructing a launch. On native Windows inspect the resolved executable/npm shim and its help in the installed PowerShell; use a verified `.exe` or its `.ps1` shim, never evaluate a constructed command string. Use absolute paths, quote variables, and capture the real exit status separately from the answer. Wait for the process to finish using the host's background execution and wait tools; keep the controlling session active until the caller's review finishes or blocks.

The reviewer keeps the user's normal configuration: permissions, tools, skills/plugins and MCP. No flag disables any of them. Configure process-local permissions only for already authorized checks; persistent settings and silent authority expansion remain excluded.

## Codex reviewer

The Codex launch uses `codex review -` as an independent session carrying the attempt's prompt through stdin: the wrapper for a native attempt, the caller-supplied prompt otherwise. The target is in the wrapper's first line: installed review mode accepts a custom prompt or a scope flag, never both. Do not combine stdin instructions with `--base`, `--commit` or `--uncommitted`.

**Native attempt:** the native report is the process's stdout. After the process ends the launcher copies `stdout.log` to a temporary sibling and renames it to `<round_dir>/answer.md`, so an interrupted copy never leaves a partial answer (`answer.md.tmp` is never an answer); the reviewer writes no file.

**Caller-supplied prompt:** before launch, fill the prompt's report-delivery slot with an absent absolute `<round_dir>/answer.md` outside every monitored checkout. Require the reviewer to write the complete required report there atomically (temporary sibling, then rename), before returning its native review result. This authorized report write is separate from the unchanged-checkout rule. Preserve stdout separately as `stdout.log`: review mode's native final schema can reduce it to findings and a short explanation, even when a complete report was produced in commentary.

Set `review_command` to the assignment's [command](../SKILL.md#assignment), `codex` when it has none. Set `task_checkout`, `review_model` and `review_effort` from the caller (the loop record, or the direct-use request; a field may be `cli-default`), `round_prompt` and `round_dir` to the attempt's prompt file and directory per independent-review **Launch**, and `native_attempt` to `yes` for the wrapper or `no` for a caller-supplied prompt:

```bash
settings=()
[ "$review_model" = cli-default ] || settings+=(-c "model=\"$review_model\"")
[ "$review_effort" = cli-default ] || settings+=(-c "model_reasoning_effort=\"$review_effort\"")
review_exit=0
[ ! -e "$round_dir/answer.md" ] && [ ! -L "$round_dir/answer.md" ] || exit 2
(
  cd "$task_checkout" || exit
  "$review_command" review "${settings[@]}" - \
    < "$round_prompt" > "$round_dir/stdout.log" 2> "$round_dir/stderr.log"
) || review_exit=$?
printf '%s\n' "$review_exit" > "$round_dir/producer.exit"
# A native attempt's report is its stdout.
# Publish it whole: copy to a temporary sibling, then rename.
[ "$native_attempt" != yes ] || { cp "$round_dir/stdout.log" "$round_dir/answer.md.tmp" &&
  mv "$round_dir/answer.md.tmp" "$round_dir/answer.md"; }
```

Review mode has no `--json` or `--output-last-message` in the tested CLI. Read the answer, stdout, stderr and producer exit together; for a caller-supplied prompt stdout alone is not report completeness evidence. Stderr contains runtime/command evidence and the producer session ID. Pass already authorized sandbox/approval options as global options **before** `review` (check installed top-level help); only explicit unrestricted-execution authority permits `codex --dangerously-bypass-approvals-and-sandbox review ...`. If review mode cannot apply an authorized option, report a blocker.

**Recover before retrying** (caller-supplied prompt only; a native attempt's report is its stdout). For an already completed run whose answer file is missing or incomplete, bind its unique review execution delegate by [record selection](launch-settings.md#child-settings-check). Inspect that delegate's assistant messages for a complete Required report, including `commentary`; its final message may instead be the short native JSON. Recover only one unambiguous complete report for this target, verbatim to the answer file, retaining the original files and the source record/message phase. Validate required fields, target, completion, effective settings, unchanged state and consistency with the native verdict as usual. A short stdout does not itself spend a retry. Missing, ambiguous, contradictory or incomplete evidence remains invalid; never substitute another session, combine progress fragments into a report or synthesize one.

**Why native review mode:** two throwaway checks on 2026-11-21 (codex-cli 0.171.0, Claude Code 2.1.330) sent the wrapper and a context file to `codex review -` and to `/code-review` inside `claude --print`. Both tools read the context file and reported the planted requirement deviations in code, in a plan checked against its spec and in skill text; `codex review -` found every planted defect of a scoped round, starting each repeat with its prior ID, and did not repeat a rejected finding; `/code-review low` read the diff only and found none of the scoped round's defects. Both tools also take whole files as the target. The comparison of Verification 1 of the native-review spec (2026-11-21, same versions, `gpt-6.2-sol` and `claude-opus-5-5` at `high`, `claude-fable-5-2` at `xhigh`) found every planted defect in every wrapper cell, as the long review prompt it replaced did. This is evidence for the tested versions only: rerun the comparison after relevant runtime/launch changes. Raw artifacts live in ignored `tests/independent-review/native-comparison-notes.md`, not in a fresh clone.

## Claude reviewer

For a native attempt `round_prompt` holds one line, the `/code-review` command of the [wrapper](review-wrapper.md#carrying-the-wrapper):

```text
/code-review <level> --max-findings all <target> <wrapper lines 2 to the end, joined by single spaces>
```

The level is the review's effort: `medium`, `high` or `xhigh`, equal to the resolved reviewer effort; `max` only when the user set the reviewer effort to `max` explicitly; none under the effort opt-out (`cli-default`), where the command keeps the level it remembers. Effort `low` is refused before launch. `--max-findings all` is always explicit. The target is `<base>..<head>` or the repository-relative paths; a path containing whitespace is untested: quote it inside the line (`"docs/my plan.md"`), and if the reviewer's records show it did not read that file, report the files target as unavailable coverage for that path. `--model` and `--effort` are passed as for any Claude launch. Every Claude reviewer launch also passes `--settings '{"language":"English"}'`, so that a `language` setting of the user does not put the report into another language; it holds for this process only and changes no other setting. A caller-supplied prompt goes on stdin as it is, without `/code-review`.

Set `review_command` to the assignment's [command](../SKILL.md#assignment), `claude` when it has none. Use a subshell so the implementing session keeps its working directory:

```bash
settings=(--settings '{"language":"English"}')
[ "$review_model" = cli-default ] || settings+=(--model "$review_model")
[ "$review_effort" = cli-default ] || settings+=(--effort "$review_effort")
review_exit=0
(
  cd "$task_checkout" || exit
  "$review_command" --print "${settings[@]}" \
    --output-format stream-json --verbose \
    < "$round_prompt" > "$round_dir/events.jsonl" 2> "$round_dir/stderr.log"
) || review_exit=$?
printf '%s\n' "$review_exit" > "$round_dir/producer.exit"
# Run after the producer finishes. Use an already installed parser; install none.
if command -v jq >/dev/null 2>&1; then
  extraction_exit=0
  jq -ej -s 'map(select(.type == "result")) | last | if .is_error != true and (.result | type == "string" and test("\\S")) then .result else error("missing/invalid final result") end' \
    "$round_dir/events.jsonl" > "$round_dir/answer.md" 2> "$round_dir/extraction-error.txt" || extraction_exit=$?
elif command -v node >/dev/null 2>&1; then
  extraction_exit=0
  node -e 'const fs=require("fs");const rows=fs.readFileSync(process.argv[1],"utf8").split(/\r?\n/).filter(x=>x.trim()).map(JSON.parse).filter(x=>x.type==="result");const result=rows[rows.length-1];if(!result||result.is_error===true||typeof result.result!=="string"||!result.result.trim())throw Error("missing/invalid final result");process.stdout.write(result.result);' \
    "$round_dir/events.jsonl" > "$round_dir/answer.md" 2> "$round_dir/extraction-error.txt" || extraction_exit=$?
else
  extraction_exit=127
  printf '%s\n' 'No installed JSON parser: extraction unavailable.' > "$round_dir/extraction-error.txt"
fi
printf '%s\n' "$extraction_exit" > "$round_dir/extraction.exit"
```

After the producer completes, use the last result event: background notifications can start further turns. A malformed stream, missing/blank final result or final error is invalid; never fall back to an earlier result. See [Claude Code background tasks and streaming](https://code.claude.com/docs/en/headless#stream-responses).

Explicit unrestricted execution maps to `--permission-mode bypassPermissions`.

## Native PowerShell I/O

Use installed PowerShell 7 (verified here: pwsh 7.6.9), literal arrays and the small owner-local [reviewer-process.ps1](../scripts/reviewer-process.ps1). The vectors below are unchanged for native attempts; only the prompt file's content differs (the wrapper for Codex, the one `/code-review` line for Claude). After a native Codex attempt publish `stdout.log` as `answer.md` with literal-path file APIs, through a temporary sibling renamed on success (below); a failed publication is recorded in `copy.exit`, apart from the producer exit. Dot-source it by its resolved absolute installed path. It uses ordinary Process/File APIs, preserves prompt/stdout/stderr bytes, and records `producer.exit`. It accepts an executable or installed PowerShell script. For an npm shim it resolves the single existing JavaScript target and installed node executable, avoiding the shim's text stdin pipeline; an ambiguous/missing target is unavailable launch coverage. Verify the actual installed shim/help, rather than assuming every script has npm's shape. Keep normal caller configuration/permissions and pass already authorized flags explicitly. No jq or Python is needed.

Bind absolute `$task_checkout`, `$round_prompt`, `$round_dir`, the recorded model/effort, `$codex` or `$claude` as the resolved installed assignment [command](../SKILL.md#assignment) (the system's own executable when it has none), and `$native_attempt`: `'yes'` for the wrapper (a native window driver included), `'no'` for a caller-supplied prompt. Codex:

```powershell
. $reviewer_io  # absolute installed independent-review/scripts/reviewer-process.ps1
$vector = @('review')
if ($review_model -cne 'cli-default') { $vector += @('-c', ('model="' + $review_model + '"')) }
if ($review_effort -cne 'cli-default') { $vector += @('-c', ('model_reasoning_effort="' + $review_effort + '"')) }
$vector += '-'
if (Test-Path -LiteralPath (Join-Path $round_dir 'answer.md')) { throw 'The answer path must be absent before launch.' }
$result = Invoke-ReviewerProcess -Executable $codex -Vector $vector -Checkout $task_checkout -PromptPath $round_prompt -OutputDirectory $round_dir -OutputName stdout.log
$review_exit = $result.ProducerExit
# Retain IOFailure too: an I/O error invalidates the answer even with producer exit 0.
# A native attempt's report is its stdout: publish it whole through a temporary sibling.
if ($native_attempt -ceq 'yes') {
  $answer = Join-Path $round_dir 'answer.md'; $staged = Join-Path $round_dir 'answer.md.tmp'
  try {
    [System.IO.File]::Copy((Join-Path $round_dir 'stdout.log'), $staged, $true)
    [System.IO.File]::Move($staged, $answer)
  } catch {
    [System.IO.File]::WriteAllText((Join-Path $round_dir 'copy.exit'), "1`n")
  }
}
```

`$codex`/`$claude` are the resolved installed command paths. Put Codex global permission options before `review`, per installed help and existing authority. Claude uses the same helper:

```powershell
$vector = @('--print', '--output-format', 'stream-json', '--verbose', '--settings', '{"language":"English"}')
if ($review_model -cne 'cli-default') { $vector += @('--model', $review_model) }
if ($review_effort -cne 'cli-default') { $vector += @('--effort', $review_effort) }
$result = Invoke-ReviewerProcess -Executable $claude -Vector $vector -Checkout $task_checkout -PromptPath $round_prompt -OutputDirectory $round_dir -OutputName events.jsonl
$review_exit = $result.ProducerExit
$extraction_exit = Export-ClaudeReviewAnswer -OutputDirectory $round_dir
```

Keep producer exit, launch/I/O errors and extraction exit separate. A missing executable or launch exception has no producer success; a JSON/result error cannot overwrite `producer.exit`. Extraction success never rescues a nonzero producer exit or a final Claude error-result event. Validate runtime settings and the report only after inspecting all these records. For parallel calls, each job returns its producer result; extract after both producers complete.

## Result handling

Read answer, runtime records, model/effort metadata, errors and exit status together, then apply the validation rules of `independent-review` **Validate**; the caller owns the retry budget:

- **Native tool, context and target evidence.** Claude: the last result event's `local_command` is `code_review` (Claude Code 2.1.330), or the stream holds the expanded command; the stream's `assistant` events of the command (`parent_tool_use_id` of the forked command) and its agent records hold the tool calls that read `<round_dir>/context.md` and the range's diff or the target files. Codex: stderr holds the producer session ID, the prompt and every command the review ran, including the reads of `context.md` and of the diff or files; the bound review execution delegate (below) is the review-mode session record.

- Bind runtime records to the actual reviewer before comparing settings, using launch-settings' [record selection](launch-settings.md#child-settings-check) and [typed settings fields](launch-settings.md#typed-settings-fields), not invocation flags or self-report. Keep the runtime-produced ID anchor: Codex's stderr session ID must match the producer's `session_meta.payload.id`; Claude's stream `system`/`init` session ID binds its main transcript and launch checkout. The actual stdin prompt need not contain a brief path.
- For `codex review -`, retain producer startup/header and persisted `thread_settings_applied.thread_settings` as launch corroboration, then validate its uniquely bound mandatory review execution delegate's own `turn_context` and thread settings. The delegate is distinct from arbitrary helper descendants; a missing/ambiguous delegate is unverified. Inspect every concrete delegate model/effort value for non-opted-out assignment fields: a `review_model` override that mismatches the assignment invalidates execution settings even when the producer matches. Producer evidence cannot replace execution evidence. Ordinary Codex TUI/exec sessions keep their bound `turn_context` model/effort fields.
- For a background Claude native attempt, the main transcript holds no assistant record: `/code-review` runs in agent records of its own under `<project dir>/<session id>/subagents/`, bound through the stream's `system`/`init` session ID. Validate the model and effort of **every** agent record of that session through the [typed settings fields](launch-settings.md#typed-settings-fields); one conflicting value in any of them is a mismatch, and an observed effort `low` is `invalid: /code-review ran at low`. For a caller-supplied prompt, validate the bound main transcript's assistant model and typed request effort through the same map; initialization/model usage and assistant effort may corroborate. Inspect all concrete values, including continuations and mid-session changes, without tool-result text or sidechains. Conflicting concrete evidence invalidates the result; missing/null in one record alone is not a mismatch. Required effective settings with no evidence remain unverified and invalidate the result. Verify only the fields not opted out; for an opted-out field record the observed value, or `unavailable`. Keep producer/extraction/I/O failures and report validation separate; settings evidence never rescues them.
- A model/effort rejection, capacity error, startup/account permission failure, or missing executable is a launch failure.
- A denied tool call inside an otherwise running session is a coverage limitation, not automatically a failed launch: require disclosure and judge whether required review coverage and checks were completed.

With a [CLI-defaults opt-out](launch-settings.md#cli-defaults-opt-out) for a field, omit that field's override and pass the other; otherwise pass both resolved settings explicitly.

Sources for command semantics: [Codex non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode), [Claude Code CLI](https://code.claude.com/docs/en/cli-reference). Installed help takes precedence for version-specific flags.
