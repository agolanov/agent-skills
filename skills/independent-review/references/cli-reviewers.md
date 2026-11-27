# CLI Reviewers

A background attempt is one fresh CLI process of the assigned system, started by the skill's helper: [`scripts/reviewer-process`](../scripts/reviewer-process) on POSIX, `Invoke-ReviewerLaunch` in [`scripts/reviewer-process.ps1`](../scripts/reviewer-process.ps1) on native PowerShell. The helper builds the lean argument vector, runs the reviewer in the checkout with the attempt's prompt on stdin, and records everything in the attempt directory. Wait for it with the host's background execution; the controlling session stays active until the caller's review finishes or blocks.

The reviewer keeps the user's settings, permission mode, deny rules and hooks. The lean switches below remove only what a review does not use, for this launch only.

| System | Lean launch | Kept on |
| --- | --- | --- |
| Claude | `--print --output-format stream-json --verbose --strict-mcp-config --no-chrome --session-id <uuid> --settings <json>`; the JSON carries `"language": "English"` and switches off every enabled plugin without hooks | plugins with hooks (`hooks/hooks.json` in the install path or `hooks` in `.claude-plugin/plugin.json`), plugins whose install path cannot be read, and every plugin when `plugin list --json` cannot be read |
| Codex | `--disable plugins --disable memories -c skills.include_instructions=false` before `review`; `-c model="M" -c review_model="M"` and `-c model_reasoning_effort="E"` after it | a feature the review's requirements name as one the reviewer must use: pass `--keep-feature plugins|memories|skills` and say so in `Assignment:` |

Per-server MCP overrides are added only for a named need. A `cli-default` field omits its flags ([opt-out](launch-settings.md#cli-defaults-opt-out)); `review_model` goes with the model only. Already authorized sandbox or approval options go through `--permission-arg WORD` (repeatable, literal); only explicit unrestricted-execution authority permits `--dangerously-bypass-approvals-and-sandbox` (Codex) or `--permission-mode bypassPermissions` (Claude). An option review mode cannot apply is a blocker.

## Codex reviewer

`codex review -` takes the prompt on stdin: the wrapper for a native attempt, the caller-supplied prompt otherwise. The target is in the wrapper's first line, so never add `--base`, `--commit` or `--uncommitted`.

- **Native attempt:** the report is stdout; the helper publishes it as `answer.md` through `answer.md.tmp` and a rename.
- **Caller-supplied prompt:** fill its report-delivery slot with the absent absolute `<attempt dir>/answer.md`; the reviewer writes the complete report there atomically before returning. Stdout stays `stdout.log`: review mode can reduce its final output to a short summary.
- **Recover before retrying** (caller-supplied prompt only): when a completed run's answer is missing or incomplete, look in the bound review delegate's assistant messages for one unambiguous complete report for this target and copy it verbatim, keeping the originals and naming the source. Never combine fragments or write one.

## Claude reviewer

For a native attempt the prompt file holds the one `/code-review` line of the [wrapper](review-wrapper.md#carrying-the-wrapper); a caller-supplied prompt goes as it is. The answer is the stream's last result event, extracted after the producer ends (background notifications can start further turns); a malformed stream, a blank or error final result is invalid, never replaced by an earlier result. A path with whitespace in a files target is quoted inside the line; if the records show it was not read, that path is unavailable coverage.

## Launch

Bind the assignment's [command](../SKILL.md#assignment) (else `codex` or `claude`), the absolute checkout, prompt file and attempt directory, the recorded model and effort (`cli-default` allowed), and `--native yes` for the wrapper or `no` for a caller-supplied prompt.

```bash
"$reviewer_process" codex --command "$review_command" --checkout "$task_checkout" \
  --prompt "$round_prompt" --dir "$round_dir" --model "$review_model" --effort "$review_effort" \
  --native "$native_attempt"   # [--keep-feature F]... [--permission-arg WORD]...
```

The same call with `claude` launches a Claude reviewer. The helper exits 2 on a usage or setup error before launch (no attempt ran) and 0 once the producer ran, whatever its exit.

### Native PowerShell I/O

Dot-source the installed `reviewer-process.ps1` by its absolute path and call:

```powershell
. $reviewer_io
$result = Invoke-ReviewerLaunch -System codex -Command $codex -Checkout $task_checkout -Prompt $round_prompt `
  -Directory $round_dir -Model $review_model -Effort $review_effort -Native $native_attempt
# optional: -KeepFeature plugins,memories,skills  -PermissionArg <words>
```

It returns `ProducerExit`, `IOFailure`, `ExtractionExit` and `SessionId`, and writes the same files. It accepts an executable or an installed PowerShell script; for an npm shim it runs the single JavaScript target with the installed node, and an ambiguous target is unavailable launch coverage.

## Result handling

The attempt directory holds `argv.txt` (the command and its words), `session-id`, `producer.exit`, `events.jsonl` (Claude) or `stdout.log` (Codex), `stderr.log`, `answer.md`, `extraction.exit` and `extraction-error.txt` (Claude) and `plugins.txt` (Claude: `off <id>`, `on <id> <reason>`, or `unavailable: <reason>`). Keep producer, extraction and I/O failures separate: extraction never rescues a nonzero producer exit or an error result.

Read these with **Validate**; the caller owns the retry budget.

- **Native tool, context and target.** Claude: the last result event names the command (`local_command: code_review`) or the stream holds the expanded command, and the command's agent records under `<project dir>/<session id>/subagents/` hold the reads of `context.md` and of the diff or files. Codex: `stderr.log` holds the session ID, the prompt and every command the review ran; the review delegate whose `parent_thread_id` is that ID is the review-mode record.
- **Settings.** One lookup by the session ID ([child settings check](launch-settings.md#child-settings-check), [typed settings fields](launch-settings.md#typed-settings-fields)). Codex: the delegate ran the review, so its values decide; the producer's header corroborates. Claude: every agent record of the command counts.
- **Launch failure.** A model or effort rejection, a capacity, account or permission failure at startup, or a missing executable.
- **Coverage limitation.** A denied tool call inside a running session: disclosed, and judged against the required coverage.

Installed help decides version-specific flags: [Codex non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode), [Claude Code CLI](https://code.claude.com/docs/en/cli-reference).
