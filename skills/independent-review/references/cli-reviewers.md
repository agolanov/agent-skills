# CLI Reviewers

Use a separate CLI session for the assigned system. Start a fresh reviewer for each attempt with the filled [review prompt](review-prompt.md) and finding ledger from the caller (the loop record, or the direct-use request).
Check installed `codex review --help` or `claude --help` when constructing a launch. On native Windows inspect the resolved executable/npm shim and its help in the installed PowerShell; use a verified `.exe` or its `.ps1` shim, never evaluate a constructed command string. Use absolute paths, quote variables, and capture the real exit status separately from the answer. Wait for the process to finish using the host's background execution and wait tools; keep the controlling session active until the caller's review finishes or blocks.

Carry the [review prompt](review-prompt.md) unchanged into the independent session; it owns the reviewer's capability and unchanged-state contract, and vendor review commands are tools inside it. Retain normal permissions, tools, skills/plugins and MCP configuration. Configure process-local permissions only for already authorized checks; persistent settings and silent authority expansion remain excluded.

## Codex reviewer

The Codex launch uses `codex review -` as an independent session carrying the complete review prompt through stdin. Put the target in that prompt: installed review mode accepts a custom prompt or a scope flag, never both. Do not combine stdin instructions with `--base`, `--commit` or `--uncommitted`.

Before launch, fill the review prompt's report-delivery slot with an absent absolute `<round_dir>/answer.md` outside every monitored checkout. Require the reviewer to write the complete Required report there atomically (temporary sibling, then rename), before returning its native review result. This authorized report write is separate from the unchanged-checkout rule. Preserve stdout separately as `stdout.log`: review mode's native final schema can reduce it to findings and a short explanation, even when a complete report was produced in commentary.

Set `task_checkout`, `review_model` and `review_effort` from the caller (the loop record, or the direct-use request; a field may be `cli-default`), and `round_prompt` and `round_dir` to the attempt's prompt file and directory per independent-review **Launch**:

```bash
settings=()
[ "$review_model" = cli-default ] || settings+=(-c "model=\"$review_model\"")
[ "$review_effort" = cli-default ] || settings+=(-c "model_reasoning_effort=\"$review_effort\"")
review_exit=0
[ ! -e "$round_dir/answer.md" ] && [ ! -L "$round_dir/answer.md" ] || exit 2
(
  cd "$task_checkout" || exit
  codex review "${settings[@]}" - \
    < "$round_prompt" > "$round_dir/stdout.log" 2> "$round_dir/stderr.log"
) || review_exit=$?
printf '%s\n' "$review_exit" > "$round_dir/producer.exit"
```

Review mode has no `--json` or `--output-last-message` in the tested CLI. Read the complete answer file, stdout, stderr and producer exit together; stdout alone is not report completeness evidence. Stderr contains runtime/command evidence and the producer session ID. Pass already authorized sandbox/approval options as global options **before** `review` (check installed top-level help); only explicit unrestricted-execution authority permits `codex --dangerously-bypass-approvals-and-sandbox review ...`. If review mode cannot apply an authorized option, report a blocker.

**Recover before retrying.** For an already completed run whose answer file is missing or incomplete, bind its unique review execution delegate by [record selection](launch-settings.md#child-settings-check). Inspect that delegate's assistant messages for a complete Required report, including `commentary`; its final message may instead be the short native JSON. Recover only one unambiguous complete report for this target, verbatim to the answer file, retaining the original files and the source record/message phase. Validate required fields, target, completion, effective settings, unchanged state and consistency with the native verdict as usual. A short stdout does not itself spend a retry. Missing, ambiguous, contradictory or incomplete evidence remains invalid; never substitute another session, combine progress fragments into a report or synthesize a CLEAN verdict.

**Why stdin review mode:** on codex-cli 0.165.0 (2026-10-29) identical round prompts sent to `codex exec` and `codex review -` produced the same findings, verdicts and coverage, with exit 0, HEAD and porcelain unchanged and the assigned model/effort in the runtime records; in round 2 both verified the fix commit first. This is evidence for the tested version only: rerun the comparison after relevant runtime/launch changes. On codex-cli 0.166.0 (2026-10-31) review mode completed the real run of the dual review (`independent-review --dual`) and the three review rounds of its delivery; the `exec`/`review` comparison was not rerun on that version. Raw artifacts live in ignored `tests/refine/e2e-notes.md` and in the e2e notes of the dual review (`independent-review --dual`) under `tests/`, not in a fresh clone.

## Claude reviewer

Use a subshell so the implementing session keeps its working directory:

```bash
settings=()
[ "$review_model" = cli-default ] || settings+=(--model "$review_model")
[ "$review_effort" = cli-default ] || settings+=(--effort "$review_effort")
review_exit=0
(
  cd "$task_checkout" || exit
  claude --print "${settings[@]}" \
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

After the producer completes, use the last result event: background notifications can start further turns. A malformed stream, missing/blank final result or final error is invalid; never fall back to an earlier CLEAN. See [Claude Code background tasks and streaming](https://code.claude.com/docs/en/headless#stream-responses).

Explicit unrestricted execution maps to `--permission-mode bypassPermissions`.

## Native PowerShell I/O

Use installed PowerShell 7 (verified here: pwsh 7.6.9), literal arrays and the small owner-local [reviewer-process.ps1](../scripts/reviewer-process.ps1). Dot-source it by its resolved absolute installed path. It uses ordinary Process/File APIs, preserves prompt/stdout/stderr bytes, and records `producer.exit`. It accepts an executable or installed PowerShell script. For an npm shim it resolves the single existing JavaScript target and installed node executable, avoiding the shim's text stdin pipeline; an ambiguous/missing target is unavailable launch coverage. Verify the actual installed shim/help, rather than assuming every script has npm's shape. Keep normal caller configuration/permissions and pass already authorized flags explicitly. No jq or Python is needed.

Bind absolute `$task_checkout`, `$round_prompt`, `$round_dir`, and the recorded model/effort. Codex:

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
```

`$codex`/`$claude` are the resolved installed command paths. Put Codex global permission options before `review`, per installed help and existing authority. Claude uses the same helper:

```powershell
$vector = @('--print', '--output-format', 'stream-json', '--verbose')
if ($review_model -cne 'cli-default') { $vector += @('--model', $review_model) }
if ($review_effort -cne 'cli-default') { $vector += @('--effort', $review_effort) }
$result = Invoke-ReviewerProcess -Executable $claude -Vector $vector -Checkout $task_checkout -PromptPath $round_prompt -OutputDirectory $round_dir -OutputName events.jsonl
$review_exit = $result.ProducerExit
$extraction_exit = Export-ClaudeReviewAnswer -OutputDirectory $round_dir
```

Keep producer exit, launch/I/O errors and extraction exit separate. A missing executable or launch exception has no producer success; a JSON/result error cannot overwrite `producer.exit`. Extraction success never rescues a nonzero producer exit or a final Claude error-result event. Validate runtime settings and the report only after inspecting all these records. For parallel calls, each job returns its producer result; extract after both producers complete.

## Result handling

Read answer, coverage, runtime model/effort metadata, errors and exit status together, then apply the validation rules of `independent-review` **Validate**; the caller owns the retry budget:

- Bind runtime records to the actual reviewer before comparing settings, using launch-settings' [record selection](launch-settings.md#child-settings-check) and [typed settings fields](launch-settings.md#typed-settings-fields), not invocation flags or self-report. Keep the runtime-produced ID anchor: Codex's stderr session ID must match the producer's `session_meta.payload.id`; Claude's stream `system`/`init` session ID binds its main transcript and launch checkout. The actual stdin prompt need not contain a brief path.
- For `codex review -`, retain producer startup/header and persisted `thread_settings_applied.thread_settings` as launch corroboration, then validate its uniquely bound mandatory review execution delegate's own `turn_context` and thread settings. The delegate is distinct from arbitrary helper descendants; a missing/ambiguous delegate is unverified. Inspect every concrete delegate model/effort value for non-opted-out assignment fields: a `review_model` override that mismatches the assignment invalidates execution settings even when the producer matches. Producer evidence cannot replace execution evidence. Ordinary Codex TUI/exec sessions keep their bound `turn_context` model/effort fields.
- For Claude, validate the bound main transcript's assistant model and typed request effort through the same map; initialization/model usage and assistant effort may corroborate. Inspect all concrete values, including continuations and mid-session changes, without tool-result text or sidechains. Conflicting concrete evidence invalidates the result; missing/null in one record alone is not a mismatch. Required effective settings with no evidence remain unverified and invalidate the result. Verify only the fields not opted out; for an opted-out field record the observed value, or `unavailable`. Keep producer/extraction/I/O failures and report validation separate; settings evidence never rescues them.
- A model/effort rejection, capacity error, startup/account permission failure, or missing executable is a launch failure.
- A denied tool call inside an otherwise running session is a coverage limitation, not automatically a failed launch: require disclosure and judge whether required review coverage and checks were completed.

With a [CLI-defaults opt-out](launch-settings.md#cli-defaults-opt-out) for a field, omit that field's override and pass the other; otherwise pass both resolved settings explicitly.

Sources for command semantics: [Codex non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode), [Claude Code CLI](https://code.claude.com/docs/en/cli-reference). Installed help takes precedence for version-specific flags.
