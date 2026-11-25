# Run contract

One contract for every child outside `inline`: the parent writes a brief, starts the child in its place, waits for the status file, answers or relays the child's questions and reads its report. A `window` runs through [SKILL.md](../SKILL.md) unchanged; this file adds `subagent` and `background` and the rules all three places share.

## Places

| Value | Place |
|---|---|
| `inline` | the current session does the work itself |
| `subagent` | a native subagent of the current session's host (Claude Code's agent tool, Codex subagents); always the same system as the session that starts it |
| `background` | a separate non-interactive CLI process (`claude --print`, `codex exec`, `codex review -`) started by the current session; not visible; either system |
| `window` | a visible interactive session through `child-sessions` (herdr, else tmux, else the native terminal); either system |

`--run <place>` places a skill's **worker**, the agent that does the work the skill exists for; each skill names its default.

- A skill whose root only prepares, waits and verifies (the planner's, the implementer's) keeps its root in the calling session and moves only the worker.
- A skill whose root is its worker (`review-fix-loop`, `delivering-task-follow-ups`, the orchestrators) moves as a whole: the calling session becomes a **thin launcher**, which writes the brief, waits, relays questions and reports the child's result.
- Any skill can be run as a whole outside `inline` by its caller, a parent skill or the user's words, through this contract; `--run` only names each skill's default target of that move.
- The user's words set places as keys do ("run the plan without a window", "let Codex review it in a window"): the session maps them to keys and announces the mapping.

**System.** `--agent claude|codex`, optionally with a [launch command](#launch-command), chooses the worker's system. Without it the worker is the caller's own system, identified from session identity as independent-review's [Session system](../../independent-review/SKILL.md#session-system) says, and a window's `open` receives it as `--agent`; the helper's own default is not this rule. A reviewer is the opposite system unless `--codex`, `--claude` or `--dual` chooses it; with `subagent` and no system key it is the caller's own system. A `subagent` is always the caller's own system.

### Launch command

An agent value is `<system>` or `<system>:<command>`, for example `codex:codex-avc`. The system (`claude` or `codex`) decides everything a system decides: CLI flags, native review tool, runtime records, the opposite system, review marks and window names. A reviewer's command comes from its own key ([independent-review Assignment](../../independent-review/SKILL.md#assignment)). The command is the executable a `window` or `background` launch starts in place of the system's own `claude` or `codex`: one word of `[A-Za-z0-9._/+-]` (also `\` and `:` on native Windows), found on `PATH` or given as a path, taking the system's CLI arguments unchanged. Without a command the system's own executable runs; an `inline` or `subagent` worker starts no CLI and refuses a command ([Refused combinations](#refused-combinations)). Carry the value whole wherever the agent travels: `--agent` to `open` (the helper splits it), the brief's `Agent:` line, nested calls and state records; compare and choose systems by its system part only.

## Brief

Write the brief by [brief-writing.md](brief-writing.md), outside the checkout under child-sessions' `runtime-dir` ([platform-runtime.md](platform-runtime.md)), with an absent status path beside it; its `Terminal controls:` item belongs to `window` only. A run-contract brief opens with these identity lines, paths absolute:

```text
Skill: <absolute SKILL.md>
Arguments: <the caller's keys and values, verbatim, except those the launcher consumes>
Checkout: <absolute>
Authority: <what the child may write, commit and decide>
Place: <window|subagent|background>
Auto: <yes|no>
Status file: <absolute>
```

- A thin launcher consumes `--run` and the keys that set the worker it launches (`--model`, `--effort`) and writes every other key into `Arguments:`. In the orchestrators `--model` and `--effort` set the implementer, so they stay in `Arguments:`.
- The child reads `Skill:` completely and performs that skill `inline` in its own session with `Arguments:`, adding `--auto` when `Auto: yes` (the parent writes `yes` when its own run has `--auto`), and then follows [auto.md](auto.md) as a child; with `Auto: no` it asks as the skill says. `Authority:` bounds what it writes, commits and decides. It writes the status file by [status-file.md](status-file.md).
- A skill's own brief template is a run-contract brief too. Its identity block carries `Place:` and `Auto:`; its Work replaces `Skill:` and `Arguments:`. Its explicit `Authority:` line, or its explicit Work, Ownership and boundary instructions together, supplies the authority bound. These instructions must agree. An omitted label grants no additional authority.
- A subagent's last message lands in the parent's context: the brief tells it to end with the status file's first line only.

## Thin launchers

When a whole skill moves outside `inline`, follow these steps with its local `Run elsewhere` parameters. The child performs the skill's inline task steps; the thin parent only prepares, waits, relays questions and reports. Local authority remains an upper bound: permissions, `--auto`, this procedure and an orchestration fallback grant no additional authority.

1. **Prepare.** Read the installed child-sessions [SKILL.md](../SKILL.md), [brief-writing.md](brief-writing.md), [status-file.md](status-file.md) and this contract. Resolve its installed platform entrypoint by absolute path and set `<runtime>` from `runtime-dir` as [platform-runtime.md](platform-runtime.md) says. Check the caller's accepted [Places](#places), [Refused combinations](#refused-combinations) and extra local refusals before anything starts, naming a refused combination. Resolve the local checkout, inputs and scope; the child has none of this session's history.
2. **Resolve settings.** Use the local worker role and [launch settings precedence](../../independent-review/references/launch-settings.md#precedence): consumed `--model`/`--effort` are explicit values, `cli-default` is a per-field [opt-out](../../independent-review/references/launch-settings.md#cli-defaults-opt-out), and other fields take the role default. Orchestrators forward implementer settings and take their own role defaults. Resolve and pass the pair by [Settings](#settings); an unresolved or unsupported pair, or one the place cannot select and verify, stops before launch, naming the place and pair.
3. **Write the brief.** Use the local run name `<name>` for the window, `<runtime>/<name>-brief.md` for the brief, `<runtime>/<name>-status.md` for the initially absent status and `<runtime>/<name>-run-<n>` for each fresh background run directory. Refuse a live window of that name, naming it. A fresh worktree or reviewer clone may pause even an auto chain for the user's separate [folder-trust decision](../SKILL.md#dialogs); keep its consent boundary and selected place. Check [Earlier runs](#earlier-runs) before renaming leftovers `<file>-old-<n>`, with the smallest unused `n`. Write the [Brief](#brief) identity block, with `Skill:` this caller's absolute SKILL.md, its local `Arguments:`, `Checkout:` and `Authority:`, `Place:`, `Auto: yes` under `--auto` (else `no`), and `Status file:`; add the [Launch settings record](../../independent-review/references/launch-settings.md#record), local inputs and report instructions. Tell the child to read the Skill completely and perform it `inline` with the Arguments within the Authority, and write the status by [status-file.md](status-file.md). Apply the local completion mapping and question payload: in a window the child asks the user the local questions there, except under `--auto`; in subagent/background, and in a window under `--auto`, each question ends its turn with `STATUS: blocked`, Questions holding the question, options and recommendation plus the local content. Every turn ends with the status file written and its exact first line as the child's last message.
4. **Launch, wait and relay.** Append `Opened:` at the [Launch and wait](#launch-and-wait) boundary, then launch and wait there, preserving its failure and restart rules. A window uses `open --agent <this session's system>` with the pair, omitting a `cli-default` field; a subagent uses native setting controls; a background CLI uses the pair and [Permissions](#permissions). Run the early [child settings check](../../independent-review/references/launch-settings.md#child-settings-check) when that section's Early check says; only a mismatch stops for the user's continue-or-stop question. Show blocked Questions verbatim with their options and recommendation and obtain the user's answer. Under `--auto`, route mismatch and blocked questions by [auto.md](auto.md#deciding) instead. Archive blocked status and continue by [Questions and continuation](#questions-and-continuation), preserving the same-conversation and fresh-child rules.
5. **Verify and report.** After `done` or `failed`, run the final [child settings check](../../independent-review/references/launch-settings.md#child-settings-check). Report the local result and one settings line: role, effective model and effort with sources, check outcome and record paths, or the user's acceptance. For background, include each producer exit and session ID; under `--auto`, carry the status's `## Decisions` together with this session's own. Apply any local final decision before reporting completion. After `done`, close the owned window only when the calling skill's completion conditions pass; otherwise leave the window and status for the user. Preserve failures and their evidence.

## Earlier runs

A skill names a run's brief, status and run directories after its task (`plan-<slug>`, `loop-<slug>`), and every session of the user shares `runtime-dir`, so files of those names may belong to a run still in progress, started by this session or another, in this project or another. A live window of that name is refused, as each skill says. Before renaming the other files of those names as an earlier run's leftovers, check whether a `subagent` or `background` run may still use them: a brief whose `Place:` line names `subagent` or `background` while its status file is absent or its first line is neither `STATUS: done` nor `STATUS: failed`, or a run directory of those names whose recording is unfinished. A directory with `launch.time` or `wrapper.identity` is new-format: without a valid `wrapper.done` and completed records by [Background recording](#background-recording), it remains possibly live/incomplete even when `producer.exit` exists. A directory with neither new field retains the legacy rule: absence of `producer.exit` means possibly live. Nothing outside a window proves that such a run has ended, and renaming its files would hand its parent another run's status and session ID. Show those files and ask the user whether that run has ended: rename them only on the user's yes; otherwise stop, naming them. Under `--auto` this question reaches the user ([auto.md](auto.md#hard-to-undo)).

## Launch and wait

Every place starts the child with the window's prompt:

```text
Read the brief at <absolute brief> completely and carry it out.
```

Before every launch (each `open` of a window included) and every fresh child, append the brief's `Opened:` line ([Settings](#settings)); an answer or a restart that continues the same conversation never gets one.

- **`window`:** [SKILL.md](../SKILL.md) as today: `open`, Startup, [Wait](../SKILL.md#wait), Dialogs and the single reopen after a silent exit.
- **`subagent`:** start a fresh agent with the host's agent tool ([Host mechanisms](#host-mechanisms)): the prompt above, no parent history, the host's normal tool set, and the pair of [Settings](#settings). For an orchestrator's phase agent, use its whole phase brief from [Nested calls](#nested-calls) instead of that prompt and set no model or effort. It starts in the parent's working directory; the brief's `Checkout:` is where it works. Wait with the host's wait tools until it ends; it writes the status file before it ends.
- **`background`:** start the CLI in the checkout with the prompt on stdin and stdout/stderr in a fresh run directory under `runtime-dir`, one per start or resume. Claude: `claude --print --output-format stream-json --verbose <permission args> [--model M] [--effort E]`. Codex: `codex exec <permission args> [-c model="M"] [-c model_reasoning_effort="E"] -`. `<permission args>` come from [Permissions](#permissions); a `cli-default` field omits its flag. On Claude, start the top-level producer script **once** with Bash `run_in_background: true` and retain its host task identifier. After each start run the early [child settings check](../../independent-review/references/launch-settings.md#child-settings-check), before waiting. A background child has rung 1 only where [Host mechanisms](#host-mechanisms)' `Free wait: host notification` row says `observed` for the waiting session's host and kind; it has no rung 2. On rung 1 print [Wait](../SKILL.md#wait)'s waiting notice with the host task identifier as handle and end the turn. On every re-invocation apply the [Completion-marker fallback](#completion-marker-fallback)'s rung 1 recording check before reading status; pending recording returns to the same free wait. Else keep today's waiting: `TaskOutput` with its actual installed schema (`block: true`, waits at most 60000 ms) only when exposed, otherwise the 60-second completion-marker polling. Codex starts with `exec_command` and continues that same returned `session_id` through `write_stdin`, individual waits at most 60000 ms, until it exits. That host handle is separate from the CLI conversation ID in `session.id`. The report includes the `Wait:` line of [Wait](../SKILL.md#wait), naming why the present loop applies (including native subagent or print session). Refuse before launch only if neither a usable host execution/wait pair nor the fallback's shell/liveness capabilities exist; do not silently change places. Complete [Background recording](#background-recording) before reading terminal status.

While a child works, in every place, the parent keeps the [quiet wait](../SKILL.md#wait).

Then read the status file's first line, as for a window: `done` and `failed` follow the window's status table ([Wait](../SKILL.md#wait)), `blocked` follows [Questions and continuation](#questions-and-continuation). A child that ends without a valid first line (a subagent's end, any producer exit) gets **one restart** by that section's continuation, the message being "Your turn ended without a status file. Continue from the current state of the checkout: read git log and git status first." A second ends the run, as a window's second silent exit: show the producer exit, stderr and the run directory, and preserve the checkout. A **launch failure** gets no restart and is reported with the CLI's message: a start exception (no producer exit), or the CLI refusing its arguments before any session starts (a usage error on stderr, no session ID).

### Background recording

Before each start or resume, allocate a fresh owned run directory. Bind only literal resolved absolute paths. In preflight, load the appropriate completion watcher's function definitions below and query the coordinator's own PID with `inspect_process "$$"` (Bash) or `Inspect-Process $PID` (PowerShell); require a live identity. This validates the actual Linux proc read/parser, other POSIX `ps` syntax, or native process properties **before** starting a producer. Preserve observations, errors and exits. Missing inspection capabilities refuse before launch. Each complete watcher repeats that self-check at entry. On Linux a missing process directory means gone; a still-present directory with an unreadable/malformed stat means unavailable, with an existence and marker recheck for a concurrent exit. Other POSIX `ps` is queried by name through PATH; only validated syntax, exit 1 and empty stdout/stderr establishes gone. Native PowerShell recognizes only the exact absent-process error identifier below as gone.

The coordinator executes its platform timestamp fragment once before starting that run's producer. Check the actual command/write exit or exception and stop before CLI launch on failure; an old `$LASTEXITCODE` proves no .NET write. The absolute run directory is already bound and fresh.

POSIX launch timestamp (Bash).

```bash
date +%s > "$run_dir/launch.time"
```

Native PowerShell launch timestamp (PowerShell 7).

```powershell
[IO.File]::WriteAllText((Join-Path $runDir 'launch.time'),
  ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString([Globalization.CultureInfo]::InvariantCulture) + "`n"),
  [Text.UTF8Encoding]::new($false))
```

Write the complete producer recipe, with its bindings, to an owned runtime script and run it as its own top-level Bash/PowerShell process. An inline subshell or a function in a longer-lived caller does not identify the wrapper. The final successful operation atomically publishes `wrapper.done`; after it the wrapper performs no more work. Never publish from an unconditional trap/finally. A new directory and marker are required on every resume.

**Record format.** All five coordination records use UTF-8 without BOM and LF only. `launch.time` is nonnegative decimal Unix epoch seconds plus one LF; `wrapper.identity` is positive decimal PID plus LF, then the start identity plus LF; `producer.exit` is signed decimal exit plus one LF; `session.id` is the extracted single-line CLI ID plus LF (an empty line records missing ID/launch failure, not a successful session); `wrapper.done` is exactly the bytes `complete\n`. Linux/WSL start identity is positive decimal kernel start ticks from field 22 of `/proc/PID/stat`; parse after the final `) ` so spaces/parentheses in comm do not shift fields. State is the first field of that suffix and start ticks its twentieth. Do not use calendar lstart as the Linux identity: procps derives it from a boot wall-clock timestamp. On other POSIX hosts trim only outer ASCII spaces from LC_ALL=C ps lstart; those platforms remain unverified unless exercised. Native start identity is invariant decimal `StartTime.ToUniversalTime().Ticks`. Writer and reader use that same canonical form. Change the recipe's default PowerShell Set-Content writes for these records to explicit no-BOM LF writes; stdout/stderr log bytes remain untouched. Marker readers compare exact bytes/text including the single LF, not arbitrary trimming. Missing/malformed launch.time or identity is unavailable (2); malformed completed producer records are incomplete (3).

POSIX recipe (Bash). Bind absolute `checkout` and `run_dir` holding `prompt.md` (the start prompt, or a resume's continuation message), `agent` (`claude` or `codex`, the system part of the agent value), `command` (the [launch command](#launch-command), else the system's name), `model` and `effort` (each may be `cli-default`), and `session_id` (empty to start, the recorded ID to resume). The Linux parser adapts the owner's `process_identity` algorithm; lifecycle scripts remain unchanged. Every required command checks its real exit; no shell-wide errexit is assumed.

```bash
wrapper_pid=$$
if [[ ${OSTYPE:-} == linux* ]]; then
  IFS= read -r wrapper_stat < "/proc/$wrapper_pid/stat" || exit 2
  [[ $wrapper_stat == *") "* ]] || exit 2
  wrapper_suffix=${wrapper_stat##*) }
  read -r -a wrapper_fields <<< "$wrapper_suffix"
  (( ${#wrapper_fields[@]} >= 20 )) || exit 2
  [[ ${wrapper_fields[0]} =~ ^[A-Za-z]$ && ${wrapper_fields[0]} != [ZX] &&
     ${wrapper_fields[19]} =~ ^[1-9][0-9]*$ ]] || exit 2
  wrapper_start=${wrapper_fields[19]}
else
  LC_ALL=C ps -p "$wrapper_pid" -o lstart= > "$run_dir/wrapper-start.stdout" 2> "$run_dir/wrapper-start.stderr"
  identity_exit=$?
  (( identity_exit == 0 )) && [[ ! -s "$run_dir/wrapper-start.stderr" ]] || exit 2
  IFS= read -r wrapper_start < "$run_dir/wrapper-start.stdout" || exit 2
  while [[ $wrapper_start == ' '* ]]; do wrapper_start=${wrapper_start# }; done
  while [[ $wrapper_start == *' ' ]]; do wrapper_start=${wrapper_start% }; done
  [[ -n $wrapper_start && $wrapper_start != *$'\r'* ]] || exit 2
fi
printf '%s\n%s\n' "$wrapper_pid" "$wrapper_start" > "$run_dir/wrapper.identity.tmp" || exit $?
mv -- "$run_dir/wrapper.identity.tmp" "$run_dir/wrapper.identity" || exit $?
if [ "$agent" = claude ]; then
  if [ -n "${CHILD_SESSION_CLAUDE_ARGS+x}" ]; then read -r -a perm <<< "$CHILD_SESSION_CLAUDE_ARGS"
  else perm=(--permission-mode bypassPermissions); fi
  vector=("$command" --print --output-format stream-json --verbose "${perm[@]}")
  [ -z "$session_id" ] || vector+=(--resume "$session_id")
  [ "$model" = cli-default ] || vector+=(--model "$model")
  [ "$effort" = cli-default ] || vector+=(--effort "$effort")
  out=events.jsonl
else
  if [ -n "${CHILD_SESSION_CODEX_ARGS+x}" ]; then read -r -a perm <<< "$CHILD_SESSION_CODEX_ARGS"
  else perm=(--dangerously-bypass-approvals-and-sandbox); fi
  vector=("$command" exec)
  [ -z "$session_id" ] || vector+=(resume)
  vector+=("${perm[@]}")
  [ "$model" = cli-default ] || vector+=(-c "model=\"$model\"")
  [ "$effort" = cli-default ] || vector+=(-c "model_reasoning_effort=\"$effort\"")
  [ -z "$session_id" ] || vector+=("$session_id")
  vector+=(-)
  out=stdout.log
fi
producer_exit=0
(
  cd "$checkout" || exit
  for child_variable in CLAUDECODE CLAUDE_CODE_SESSION_ID \
    CLAUDE_CODE_CHILD_SESSION CLAUDE_CODE_MESSAGING_SOCKET \
    CLAUDE_CODE_MESSAGING_TOKEN CLAUDE_EFFORT CODEX_THREAD_ID \
    CODEX_COMPANION_SESSION_ID CODEX_COMPANION_TRANSCRIPT_PATH \
    CODEX_SESSION_ID CODEX_TOOL_CALL_ID CLAUDE_PID \
    CLAUDE_CODE_SESSION_ATTENDED CLAUDE_CODE_ENTRYPOINT; do
    unset "$child_variable" || exit $?
  done
  "${vector[@]}" < "$run_dir/prompt.md" > "$run_dir/$out" 2> "$run_dir/stderr.log"
) || producer_exit=$?
printf '%s\n' "$producer_exit" > "$run_dir/producer.exit" || exit $?
if [ "$agent" = claude ]; then
  sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$run_dir/events.jsonl" > "$run_dir/session.matches" || exit $?
else
  sed -n 's/^session id: //p' "$run_dir/stderr.log" > "$run_dir/session.matches" || exit $?
fi
recorded_id=$(sed -n '1p' "$run_dir/session.matches") || exit $?
[[ $recorded_id != *$'\r'* && $recorded_id != *$'\n'* && $recorded_id != $'\xef\xbb\xbf'* ]] || exit 2
printf '%s\n' "$recorded_id" > "$run_dir/session.id" || exit $?
printf 'complete\n' > "$run_dir/wrapper.done.tmp" || exit $?
mv -- "$run_dir/wrapper.done.tmp" "$run_dir/wrapper.done" || exit $?
```

Native PowerShell recipe (PowerShell 7). Bind the same values as `$checkout`, `$runDir`, `$agent`, `$model`, `$effort` and `$sessionId`, plus `$exe` with `$lead`: the resolved installed [launch command](#launch-command) (`claude` or `codex` by default) with `$lead = @()`, or for an npm shim its installed node with `$lead = @('<the shim's JavaScript target>')`; any other shim is unavailable, never evaluated. It uses `System.Diagnostics.Process` directly and depends on no other skill's script. Start/property, copy, extraction and literal .NET write errors stop the recipe without a marker; `$LASTEXITCODE` is not used for managed operations.

```powershell
$ErrorActionPreference = 'Stop'
$utf8 = [Text.UTF8Encoding]::new($false, $true)
$wrapperProcess = Get-Process -Id $PID -ErrorAction Stop
$wrapperStart = $wrapperProcess.StartTime.ToUniversalTime().Ticks.ToString([Globalization.CultureInfo]::InvariantCulture)
if ($wrapperStart -cnotmatch '\A[1-9][0-9]*\z') { throw 'Wrapper start identity unavailable' }
[IO.File]::WriteAllText((Join-Path $runDir 'wrapper.identity.tmp'),
  ($PID.ToString([Globalization.CultureInfo]::InvariantCulture) + "`n" + $wrapperStart + "`n"), $utf8)
[IO.File]::Move((Join-Path $runDir 'wrapper.identity.tmp'), (Join-Path $runDir 'wrapper.identity'))
if ($agent -ceq 'claude') {
  $perm = if (Test-Path Env:CHILD_SESSION_CLAUDE_ARGS) { @($env:CHILD_SESSION_CLAUDE_ARGS -split '\s+' | Where-Object { $_ -ne '' }) } else { @('--permission-mode', 'bypassPermissions') }
  $vector = $lead + @('--print', '--output-format', 'stream-json', '--verbose') + $perm
  if ($sessionId) { $vector += @('--resume', $sessionId) }
  if ($model -cne 'cli-default') { $vector += @('--model', $model) }
  if ($effort -cne 'cli-default') { $vector += @('--effort', $effort) }
  $outName = 'events.jsonl'; $idSource = 'events.jsonl'; $idPattern = '"session_id"\s*:\s*"([^"]+)"'
} else {
  $perm = if (Test-Path Env:CHILD_SESSION_CODEX_ARGS) { @($env:CHILD_SESSION_CODEX_ARGS -split '\s+' | Where-Object { $_ -ne '' }) } else { @('--dangerously-bypass-approvals-and-sandbox') }
  $vector = $lead + @('exec')
  if ($sessionId) { $vector += 'resume' }
  $vector += $perm
  if ($model -cne 'cli-default') { $vector += @('-c', ('model="' + $model + '"')) }
  if ($effort -cne 'cli-default') { $vector += @('-c', ('model_reasoning_effort="' + $effort + '"')) }
  if ($sessionId) { $vector += $sessionId }
  $vector += '-'
  $outName = 'stdout.log'; $idSource = 'stderr.log'; $idPattern = '^session id: (\S+)'
}
$psi = [Diagnostics.ProcessStartInfo]::new($exe)
foreach ($word in $vector) { $psi.ArgumentList.Add($word) }
$psi.WorkingDirectory = $checkout
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$parentMetadata = @('CLAUDECODE','CLAUDE_CODE_SESSION_ID',
  'CLAUDE_CODE_CHILD_SESSION','CLAUDE_CODE_MESSAGING_SOCKET',
  'CLAUDE_CODE_MESSAGING_TOKEN','CLAUDE_EFFORT','CODEX_THREAD_ID',
  'CODEX_COMPANION_SESSION_ID','CODEX_COMPANION_TRANSCRIPT_PATH',
  'CODEX_SESSION_ID','CODEX_TOOL_CALL_ID','CLAUDE_PID',
  'CLAUDE_CODE_SESSION_ATTENDED','CLAUDE_CODE_ENTRYPOINT')
foreach ($childVariable in @($psi.Environment.Keys)) {
  if ($parentMetadata -icontains $childVariable) {
    [void]$psi.Environment.Remove($childVariable)
  }
}
$outFile = $null; $errFile = $null; $process = $null
try {
  $outFile = [IO.File]::Create((Join-Path $runDir $outName))
  $errFile = [IO.File]::Create((Join-Path $runDir 'stderr.log'))
  $process = [Diagnostics.Process]::Start($psi)
  $outCopy = $process.StandardOutput.BaseStream.CopyToAsync($outFile)
  $errCopy = $process.StandardError.BaseStream.CopyToAsync($errFile)
  $promptFile = [IO.File]::OpenRead((Join-Path $runDir 'prompt.md'))
  try { $promptFile.CopyTo($process.StandardInput.BaseStream) } finally { $promptFile.Dispose(); $process.StandardInput.Close() }
  $process.WaitForExit(); $outCopy.Wait(); $errCopy.Wait()
  $producerExit = $process.ExitCode
} finally {
  if ($null -ne $outFile) { $outFile.Dispose() }
  if ($null -ne $errFile) { $errFile.Dispose() }
  if ($null -ne $process) { $process.Dispose() }
}
[IO.File]::WriteAllText((Join-Path $runDir 'producer.exit'),
  ($producerExit.ToString([Globalization.CultureInfo]::InvariantCulture) + "`n"), $utf8)
$found = Select-String -LiteralPath (Join-Path $runDir $idSource) -Pattern $idPattern -ErrorAction Stop | Select-Object -First 1
$recordedId = if ($found) { $found.Matches[0].Groups[1].Value } else { '' }
if ($recordedId.Contains("`r") -or $recordedId.Contains("`n") -or $recordedId.StartsWith([string][char]0xFEFF, [StringComparison]::Ordinal)) { throw 'Malformed CLI session ID' }
[IO.File]::WriteAllText((Join-Path $runDir 'session.id'), ($recordedId + "`n"), $utf8)
[IO.File]::WriteAllText((Join-Path $runDir 'wrapper.done.tmp'), "complete`n", $utf8)
[IO.File]::Move((Join-Path $runDir 'wrapper.done.tmp'), (Join-Path $runDir 'wrapper.done'))
```

### Completion-marker fallback

For a waiting session without rung 1 for its host and kind and without a synchronous host-task wait, run one foreground watcher at a time, normally with a 60-second internal deadline and 1-second intervals. Bind absolute `run_dir`/`runDir` and `watch_seconds`/`watchSeconds` in **1..60** (normally 60). Invoke with an explicit Bash tool `timeout: 75000` ms or a verified native tool equivalent with margin. Keep the nested coordinator active through the result in that case. The raw OS-read function is the only fixture seam: disposable V2 runners may replace that leaf, then invoke the unchanged watcher entry. Production reads real proc/installed commands; parsing, record validation, identity comparison and the deadline body are never replaced. This adds no user key, installed helper or persistent configuration.

**Rung 1 re-invocation, including user input:** keep the original host task identifier and run this watcher exactly once against its retained run directory, with `watch_seconds`/`watchSeconds` set to `1`. It validates the stored wrapper identity and recording rather than trusting notification text. Exit `0` means the recording barrier passed: read the status first line and dispatch it. Exit `124` means recording is still pending under the live-wrapper/startup rules below: answer any input, print the same waiting notice with the original host task identifier and end the turn. Keep rung 1 and start no further watcher or producer. Exits `2`/`3` preserve diagnostics and stop as below. The repeated bounded polling below belongs only to the present loop.

The startup observation lasts 30 seconds from the persisted `launch.time`, never from a later watcher's start. Validate the timestamp grammar on every loop pass, but apply calendar chronology and age checks only while identity is absent; a confirmed same live process waits to its bounded deadline even after a backward calendar-clock step. `0` means complete recording; `124` means the same live wrapper, or an identity still pending within the persisted startup grace, at the deadline; on the present loop continue one bounded watcher without resetting `launch.time`, on rung 1 take the no-event branch above. `2` means unavailable timestamp/identity/process evidence; `3` means incomplete recording. A gone, zombie or replaced wrapper gets one final marker/record recheck before `3`. Preserve logs and stop on `2`/`3`; do not launch another producer to repair recording. A malformed present marker or required record is `3`. A missing CLI ID still gives ready recording with a valid empty `session.id`, and is reported separately as launch failure.

POSIX completion watcher (Bash).

```bash
# Reads keep exact LF counts by byte-comparing the reconstructed record.
# Bash cannot retain NUL; cmp rejects it rather than silently normalizing it.
load_record() {
  local path=$1
  record=$(cat -- "$path") || return 2
  printf '%s\n' "$record" | cmp - "$path" > "$run_dir/watch-compare.stdout" 2> "$run_dir/watch-compare.stderr"
  local -a compare_exits=("${PIPESTATUS[@]}")
  (( compare_exits[0] == 0 && compare_exits[1] == 0 )) || return 2
  [[ $record != $'\xef\xbb\xbf'* && $record != *$'\r'* ]] && valid_utf8 "$record" || return 2
}
valid_utf8() {
  local LC_ALL=C text=$1 i=0 byte low high count continuation
  while (( i < ${#text} )); do
    printf -v byte '%d' "'${text:i:1}"
    (( i += 1 ))
    if (( byte < 128 )); then continue; fi
    low=128; high=191
    if (( byte >= 194 && byte <= 223 )); then count=1
    elif (( byte >= 224 && byte <= 239 )); then
      count=2
      (( byte != 224 )) || low=160
      (( byte != 237 )) || high=159
    elif (( byte >= 240 && byte <= 244 )); then
      count=3
      (( byte != 240 )) || low=144
      (( byte != 244 )) || high=143
    else return 2; fi
    while (( count > 0 )); do
      (( i < ${#text} )) || return 2
      printf -v continuation '%d' "'${text:i:1}"
      (( continuation >= low && continuation <= high )) || return 2
      (( i += 1 )); (( count -= 1 )); low=128; high=191
    done
  done
  return 0
}
check_complete() {
  [[ -e "$run_dir/wrapper.done" ]] || return 1
  load_record "$run_dir/wrapper.done" && [[ $record == complete ]] || return 3
  load_record "$run_dir/producer.exit" && [[ $record =~ ^[+-]?[0-9]+$ ]] || return 3
  load_record "$run_dir/session.id" && [[ $record != *$'\n'* ]] && valid_utf8 "$record" || return 3
  return 0
}
# OS-read leaf only: keep raw text/files, exit and existence observations.
read_process_observation() {
  local process_pid=$1 read_exit
  observation_count=$(( ${observation_count:-0} + 1 ))
  observation_stdout="$run_dir/watch-process-$observation_count.stdout"
  observation_stderr="$run_dir/watch-process-$observation_count.stderr"
  observed_present=0; observed_present_after=0; observed_exit=0; observed_text=''
  if [[ ${OSTYPE:-} == linux* ]]; then
    [[ ! -d /proc/$process_pid ]] || observed_present=1
    cat -- "/proc/$process_pid/stat" > "$observation_stdout" 2> "$observation_stderr"
    observed_exit=$?
    [[ ! -d /proc/$process_pid ]] || observed_present_after=1
  else
    LC_ALL=C ps -p "$process_pid" -o stat= -o lstart= > "$observation_stdout" 2> "$observation_stderr"
    observed_exit=$?
  fi
  printf '%s\n' "$observed_exit" > "$run_dir/watch-process-$observation_count.exit" || return 2
  if (( observed_exit == 0 )); then
    observed_text=$(cat -- "$observation_stdout"); read_exit=$?
    (( read_exit == 0 )) || return 2
  fi
}
inspect_process() {
  local process_pid=$1 suffix state
  local -a fields
  read_process_observation "$process_pid" || return 2
  process_start=''; process_state=''
  if [[ ${OSTYPE:-} == linux* ]]; then
    (( observed_present_after != 0 )) || return 1
    (( observed_present != 0 && observed_exit == 0 )) || return 2
    [[ $observed_text == *") "* ]] || return 2
    suffix=${observed_text##*) }
    read -r -a fields <<< "$suffix"
    (( ${#fields[@]} >= 20 )) || return 2
    state=${fields[0]}; process_start=${fields[19]}
    [[ $state =~ ^[A-Za-z]$ && $process_start =~ ^[1-9][0-9]*$ ]] || return 2
  else
    if (( observed_exit == 1 )) && [[ ! -s "$observation_stdout" && ! -s "$observation_stderr" ]]; then return 1; fi
    (( observed_exit == 0 )) && [[ ! -s "$observation_stderr" ]] || return 2
    load_record "$observation_stdout" || return 2
    [[ $record != *$'\n'* ]] || return 2
    while [[ $record == ' '* ]]; do record=${record# }; done
    state=${record%% *}; process_start=${record#"$state"}
    while [[ $process_start == ' '* ]]; do process_start=${process_start# }; done
    while [[ $process_start == *' ' ]]; do process_start=${process_start% }; done
    [[ $state =~ ^[A-Za-z][A-Za-z0-9+\<\>NsLl]*$ && -n $process_start ]] || return 2
  fi
  process_state=$state
  [[ $state != [ZX]* ]] || return 1
  return 0
}
watch_main() {
  local complete_exit inspect_exit launch_time now deadline wrapper_pid wrapper_start
  [[ $watch_seconds =~ ^([1-9]|[1-5][0-9]|60)$ && $run_dir == /* ]] || return 2
  check_complete; complete_exit=$?
  (( complete_exit == 1 )) || return "$complete_exit"
  inspect_process "$$" || return 2
  deadline=$((SECONDS + watch_seconds))
  while :; do
    check_complete; complete_exit=$?
    (( complete_exit == 1 )) || return "$complete_exit"
    load_record "$run_dir/launch.time" && [[ $record =~ ^[0-9]+$ && ${#record} -le 18 ]] || return 2
    launch_time=$((10#$record))
    if [[ ! -e "$run_dir/wrapper.identity" ]]; then
      now=$(date +%s) || return 2
      [[ $now =~ ^[0-9]+$ && ${#now} -le 18 ]] || return 2
      now=$((10#$now))
      (( now >= launch_time && now - launch_time < 30 )) || return 2
    else
      load_record "$run_dir/wrapper.identity" || return 2
      [[ $record == *$'\n'* ]] || return 2
      wrapper_pid=${record%%$'\n'*}; wrapper_start=${record#*$'\n'}
      [[ $wrapper_pid =~ ^[1-9][0-9]*$ && -n $wrapper_start && $wrapper_start != *$'\n'* ]] || return 2
      if [[ ${OSTYPE:-} == linux* ]]; then
        [[ $wrapper_start =~ ^[1-9][0-9]*$ ]] || return 2
      else
        [[ $wrapper_start != ' '* && $wrapper_start != *' ' ]] || return 2
      fi
      inspect_process "$wrapper_pid"; inspect_exit=$?
      if (( inspect_exit == 2 )); then
        # Reobserve directory existence after a failed Linux read/parse.
        if [[ ${OSTYPE:-} == linux* ]]; then
          read_process_observation "$wrapper_pid" || return 2
          (( observed_present_after != 0 )) || inspect_exit=1
        fi
        check_complete; complete_exit=$?
        (( complete_exit == 1 )) || return "$complete_exit"
        (( inspect_exit != 1 )) || return 3
        return 2
      fi
      if (( inspect_exit == 1 )) || [[ $process_start != "$wrapper_start" ]]; then
        check_complete; complete_exit=$?
        (( complete_exit == 1 )) || return "$complete_exit"
        return 3
      fi
    fi
    if (( SECONDS >= deadline )); then return 124; fi
    sleep 1 || return 2
  done
}
watch_main
exit $?
```

Native PowerShell completion watcher (PowerShell 7).

```powershell
$ErrorActionPreference = 'Stop'
$utf8 = [Text.UTF8Encoding]::new($false, $true)
function Read-Record([string]$Name) {
  $value = $utf8.GetString([IO.File]::ReadAllBytes((Join-Path $runDir $Name)))
  if ($value.StartsWith([string][char]0xFEFF, [StringComparison]::Ordinal) -or $value.Contains("`r") -or $value.Contains([string][char]0)) {
    throw ('Malformed record: ' + $Name)
  }
  return $value
}
function Test-Complete {
  try {
    if (-not (Test-Path -LiteralPath (Join-Path $runDir 'wrapper.done') -ErrorAction Stop)) { return 1 }
    if ((Read-Record 'wrapper.done') -cne "complete`n" -or
        (Read-Record 'producer.exit') -cnotmatch '\A[+-]?[0-9]+\n\z' -or
        (Read-Record 'session.id') -cnotmatch '\A[^\r\n]*\n\z') { return 3 }
    return 0
  } catch { [Console]::Error.WriteLine($_); return 3 }
}
# OS-read leaf only; the caller interprets the raw error and properties.
function Read-ProcessObservation([int]$ProcessId) {
  try { return @{ Process = (Get-Process -Id $ProcessId -ErrorAction Stop); Error = $null } }
  catch { return @{ Process = $null; Error = $_ } }
}
function Inspect-Process([int]$ProcessId) {
  $observation = Read-ProcessObservation $ProcessId
  if ($null -ne $observation.Error) {
    [Console]::Error.WriteLine($observation.Error)
    if ($observation.Error.FullyQualifiedErrorId -ceq 'NoProcessFoundForGivenId,Microsoft.PowerShell.Commands.GetProcessCommand') {
      return @{ Code = 1; Start = '' }
    }
    return @{ Code = 2; Start = '' }
  }
  try {
    $start = $observation.Process.StartTime.ToUniversalTime().Ticks.ToString([Globalization.CultureInfo]::InvariantCulture)
    if ($start -cnotmatch '\A[1-9][0-9]*\z') { throw 'Malformed process start identity' }
    if ($observation.Process.HasExited) { return @{ Code = 1; Start = $start } }
    return @{ Code = 0; Start = $start }
  } catch { [Console]::Error.WriteLine($_); return @{ Code = 2; Start = '' } }
}
function Watch-Main {
  try {
    if ($watchSeconds -lt 1 -or $watchSeconds -gt 60 -or -not [IO.Path]::IsPathFullyQualified($runDir)) { return 2 }
    $complete = Test-Complete
    if ($complete -ne 1) { return $complete }
    if ((Inspect-Process $PID).Code -ne 0) { return 2 }
    $clock = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
      $complete = Test-Complete
      if ($complete -ne 1) { return $complete }
      $launch = Read-Record 'launch.time'
      if ($launch -cnotmatch '\A[0-9]+\n\z') { return 2 }
      [long]$launchTime = 0
      if (-not [long]::TryParse($launch.Substring(0, $launch.Length - 1), [Globalization.NumberStyles]::None,
          [Globalization.CultureInfo]::InvariantCulture, [ref]$launchTime)) { return 2 }
      if (-not (Test-Path -LiteralPath (Join-Path $runDir 'wrapper.identity') -ErrorAction Stop)) {
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        if ($now -lt $launchTime -or $now - $launchTime -ge 30) { return 2 }
      } else {
        $identity = Read-Record 'wrapper.identity'
        if ($identity -cnotmatch '\A([1-9][0-9]*)\n([1-9][0-9]*)\n\z') { return 2 }
        [int]$wrapperPid = 0
        if (-not [int]::TryParse($Matches[1], [ref]$wrapperPid)) { return 2 }
        $wrapperStart = $Matches[2]
        $observed = Inspect-Process $wrapperPid
        if ($observed.Code -eq 2) {
          $complete = Test-Complete
          if ($complete -ne 1) { return $complete }
          return 2
        }
        if ($observed.Code -eq 1 -or $observed.Start -cne $wrapperStart) {
          $complete = Test-Complete
          if ($complete -ne 1) { return $complete }
          return 3
        }
      }
      if ($clock.Elapsed.TotalSeconds -ge $watchSeconds) { return 124 }
      Start-Sleep -Seconds 1
    }
  } catch { [Console]::Error.WriteLine($_); return 2 }
}
exit (Watch-Main)
```

A foreground watcher unexpectedly moved to background retains its original host task handle and diagnostics. Settle that waiter through a supported host mechanism before replacement, and report the capability failure; start no competing waiter or producer. The window's [Wait](../SKILL.md#wait) stays unchanged by this fallback. Marker validation grants no signal or cleanup authority; keep existing ownership checks.

Read child terminal status only after the recording barrier or successful native host completion. Keep host task handle, wrapper recording outcome, actual CLI exit, CLI conversation ID and child status separate. With this fallback disclose that the outer host task-exit notification was not independently awaited. An early `producer.exit` or `STATUS:` alone permits no status consumption. A missing ID records launch failure, never a fabricated conversation; exceptions or incomplete recording remain unavailable evidence. Preserve settings-record selection, permission vectors, continuation/restart budgets and the same-conversation rules below.

## Child environment

On every background start/resume, remove exactly the fourteen parent-session metadata names in the recipes, case-sensitive on POSIX and case-insensitive in the native Windows environment dictionary. The POSIX scrub happens inside the producer subshell after `cd`, immediately before the CLI; native PowerShell removes only from `$psi.Environment`. Vector construction and the parent's environment remain intact. Preserve every other variable, including provider/auth/platform names, config locators (`CLAUDE_CONFIG_DIR`, `CODEX_HOME`), `CLAUDE_CODE_EXECPATH`, `CLAUDE_CODE_TASK_LIST_ID`, permission overrides and unknown names with the same prefixes. Never evaluate or print real values. This bounded denylist does not classify future metadata automatically.

Window scripts use the same fourteen exact names ([Other operations and environment](../SKILL.md#other-operations-and-environment)); no prefix-wide removal is permitted. PowerShell background support requires installed PowerShell 7 and `ProcessStartInfo.ArgumentList`; Windows PowerShell 5.1, runtime installation, profile changes and authentication redesign remain outside scope.

## Questions and continuation

- A `subagent` or `background` child asks nobody directly: a question ends its turn with `STATUS: blocked`, its Questions holding the question, the options and its recommendation. In a `window` an interactive skill (brainstorming) may still ask the user in the window, except under `--auto`; any other question takes the same status.
- Without `--auto`, the parent answers within its authority or asks the user, showing the question, options and recommendation as written.
- Under `--auto`, [auto.md](auto.md) governs both sides: the child asks nobody, in a window either, and the parent routes the question by its [Deciding](auto.md#deciding) and records an answer given without the user under `## Decisions`.
- Before continuing, archive the status: rename it to `<file>-blocked-<n>` with an unused number, as for a window ([status-file.md](status-file.md)); the child writes a fresh status at the original path.
- Continue **the same child conversation** by the host mechanism of [Host mechanisms](#host-mechanisms), the answer as one message (multiline content in a file, the message naming its absolute path), then wait as at launch:
  - `subagent`: the host's message tool to the same agent;
  - `background`: the recipe of [Launch and wait](#launch-and-wait) with the recorded `session_id`, the message as `prompt.md`, the same permission arguments and the recorded settings;
  - `window`: child-sessions' `blocked` row.
- Otherwise start a **fresh child**: the original brief, followed by every question and answer so far and the line "Continue from the current state of the checkout: read git log and git status first.", with a new `Opened:` line. Otherwise means no mechanism for the host, no recorded session ID, or a continuation the host refuses (its message tool returns an error, or the resume exits nonzero without a status); that fallback belongs to the same answer or restart.

## Host mechanisms

Initial catalog check on 2026-11-05 used Linux (WSL2), Claude Code 2.1.318 and codex-cli 0.166.0: installed CLI help, live Claude agent schemas, recorded Codex tool lists and existing runtime records; that reading launched nothing. Help means installed help, schema the live tool schema, observed actual retained runtime evidence. Later V2 executed the complete producer/watcher recipes through Bash and native PowerShell 7.6.9 with controlled fake CLIs; failure observations were synthetic. One V3 print-mode Claude coordinator foreground-joined one native agent on Linux/WSL2, which exercised the tmux window waits and the published background watcher over a real wrapper. Both test CLIs were fakes, so this verifies waiting/recording rather than real worker-model launches. Its retained report distinguishes the helper exits, an enclosing diagnostic-shell exit, recording completion and the later host notification, and separately records an unnecessary coordinator metadata-inspection deviation. Installed help and live schemas win over this table. The earlier real background planner used bounded record waits and supplies no acceptance for the new marker recipe. Other hosts/versions/platforms remain unverified. A run may use an `unverified` entry, names it unverified in its report, and falls back as [Questions and continuation](#questions-and-continuation) says. The free-wait rows were observed on 2026-11-11 on Linux/WSL2 with Claude Code 2.1.322 and codex-cli 0.167.0. Unlike other entries, an `unverified` or unlisted host notification gives no rung 1.

| Mechanism | Claude Code 2.1.318 | Codex 0.166.0 |
|---|---|---|
| Subagent start | agent tool with `prompt`, `subagent_type`, `model`, `effort` (schema); a general-purpose type has the normal tools; the fork type inherits the parent's context and is not used | `spawn_agent` with `task_name`, `message`, `model`, `reasoning_effort`, and `fork_turns: "none"` for no parent history (tool list) |
| Subagent wait | the agent tool's result with `run_in_background: false` foreground-joined V3's one native agent through its final report (observed); completion notification for a background agent (schema) | `wait_agent` (`timeout_ms` up to 3600000) reports which agents have updates; the final answer arrives when the agent finishes (tool list) |
| Continue after it ends | `SendMessage` to the agent's ID or name, which "resumes it from its transcript" (schema); observed 2026-11-05: four finished subagents of one run continued this way, each transcript holding both prompts | `followup_task` (`target`, `message`) triggers a turn on an idle agent; `send_message` only queues (tool list); continuing a finished agent: unverified |
| Subagent model and effort | `model` takes the aliases `sonnet`, `opus`, `haiku`, `fable` (`opus` observed as `claude-opus-5-5`); `effort` takes `low` to `max` (schema); an omitted effort inherited the parent's (observed); explicit `model: opus`, `effort: high` resolved to `claude-opus-5-5`/`high` in V3's native agent record (observed); other explicit settings unverified | `model` and `reasoning_effort` per spawn; `reasoning_effort: high` under an `xhigh` parent showed `high` in the child's `turn_context` (observed 2026-11-03) |
| Subagent starts subagents | the agent tool is in a subagent's tool list and its `meta.json` records `spawnDepth` (observed); a nested start: unverified | the tool says spawned agents can spawn their own, and a depth-1 subagent lists `spawn_agent` (observed); `[agents] max_depth` in `config.toml` limits depth (this machine: `1`); a depth-2 spawn: unverified |
| Subagent holds the present loop | V3 held a 150-second helper call with Bash `timeout: 175000`: helper exit 124 after 150.17 s; its enclosing diagnostic shell exited 2 only because a final `ls` of the absent status failed. After release the next 150-second helper call returned 0; neither call automatically backgrounded (observed Linux/WSL2, tmux, fake child). Other backends unverified; the schema's 600000 ms maximum alone proves no effective limit | use 240-second helper calls; a yielded `exec_command` continues through same-session `write_stdin` waits at most 60000 ms. Observed 2026-11-06 on Linux/WSL2 with herdr and real Codex: a native subagent held one wait through completion after 15.486 s; a background CLI coordinator held one uninterrupted 240-second-deadline wait for 150.138 s through the same tool handle, then close=0/alive=1. These are lifecycle mechanism probes, not complete refiner-workflow acceptance; other backends/platforms remain unverified |
| Subagent runtime record | `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/<parent project>/<parent session ID>/subagents/agent-<agent ID>.jsonl` beside its `.meta.json`, bound to the returned agent ID and parent identity/metadata; the first actual user prompt is string content or top-level text blocks. Use launch-settings' [typed settings fields](../../independent-review/references/launch-settings.md#typed-settings-fields) for assistant model and typed request effort, with assistant `effort` as corroboration; the assigned agent's sidechain marker is expected, its descendants excluded (observed record layout) | a rollout under `${CODEX_HOME:-$HOME/.codex}/sessions/` whose `session_meta.payload.source.subagent.thread_spawn.parent_thread_id` is the parent's thread, with the parent's cwd; the spawn message is a user message; `turn_context.payload.model` and `.effort` (observed) |
| Background CLI | `claude --print` reads the prompt on stdin; `--output-format stream-json --verbose`, `--model`, `--effort`, `--permission-mode`; print mode skips the workspace-trust dialog (help); a print-mode `init` event showed `permissionMode: bypassPermissions` (observed on 2.1.316) | `codex exec ... -` reads the prompt on stdin; `-c model=...`, `-c model_reasoning_effort=...`, `--dangerously-bypass-approvals-and-sandbox`, `-s`, but no `-a`/`--ask-for-approval`, which only top-level `codex` takes (help); `codex exec` sessions spawn subagents (observed 2026-11-01) |
| Host background execution and wait | Bash `run_in_background: true` returns the producer's host task identifier; use `TaskOutput` only if exposed, with `block: true` and waits at most 60000 ms. V3's coordinator/native agent schemas lacked it; the nested agent used the exact final-marker watcher with a 60-second deadline and Bash `timeout: 75000`. It returned 124 while the real wrapper was live with early `producer.exit=7` and no final records, then 0 after release/marker publication. A later host completion-0 notification was observed but not independently awaited. Failure branches have synthetic V2 coverage; other hosts unverified | `exec_command`, then `write_stdin` on the same yielded `session_id`, individual waits at most 60000 ms; this handle is not `session.id` |
| Background session ID | `session_id` of the stream's `system`/`init` event (observed on 2.1.316, 2026-10-31, and the native Windows 2.1.318 recipe run on 2026-11-06) | the stderr header line `session id: <uuid>` (observed in review mode on 0.165.0 and 0.166.0, and in the real native Windows `exec` recipe run on 2026-11-06); the rollout's `session_meta.payload.id` carries the same ID |
| Background resume | `claude --print --resume <id>` keeps the ID unless `--fork-session` (help); not exercised: unverified | `codex exec resume [OPTIONS] <id> -` reads the prompt on stdin; its options list `-c`, `-m` and `--dangerously-bypass-approvals-and-sandbox`, but no `--sandbox` or `--ask-for-approval` (help); not exercised: unverified |
| Background runtime record | the **Claude child** transcript of launch-settings' [child settings check](../../independent-review/references/launch-settings.md#child-settings-check) | the **Codex child** rollout of the same check |
| Native Windows | native PowerShell 7.6.9 executed ten producer/watcher cases with fake CLIs plus twelve watcher fixtures; process-failure observations were synthetic and the API exposes no zombie state. On 2026-11-06 the complete recipe and marker watcher also ran real native Claude and Codex CLIs: producer/watcher exits 0 and nonempty session IDs. Real interactive Windows terminal launches remain unverified. The recipe needs `ProcessStartInfo.ArgumentList`, absent in Windows PowerShell 5.1, where `background` is unavailable | the same fake coverage plus the real native Codex background recipe/watcher run above; interactive Windows terminal launches remain unverified |
| Free wait: host notification | Interactive session: `observed` on 2.1.322 (40 s background command; the session ended its turn and the completion notification carrying exit code 0 re-invoked it). On 2026-11-12, a real tmux orchestrator parked for 3908.302 s with zero assistant records before its next notification; the next request wrote 153091 cache tokens and read 16165 after the observed one-hour cache lifetime. Two stall notifications caused separate work turns during the complete delivery. Native subagent: observed unusable (35 s command exiting 7: the run returned to the parent after 7 s marked waiting on its own background work; 39 s after start the host re-invoked it with "failed with exit code 7" and notified the parent again at its end). Print session: `unverified` | `unverified` on 0.167.0 and on the 2026-11-12 interactive 0.167.2 run; no host-notification rung was used |
| Free wait: wake line | On 2.1.322, a line typed by `send` into an idle window woke the session within 2–6 s on herdr and tmux. While it worked the line was taken into the current turn (once between tool calls, once with the work's end). An idle input box's suggested prompt nobody typed did not enter the line sent afterwards (observed). The 2026-11-12 orchestrator used host notifications; its own-pane `wake` remains `unverified` | On 0.167.0, the same wake within 2–6 s on herdr and tmux; a line typed while it worked was handled after the running command (observed). An initial 2026-11-12 0.167.2 tmux run refused own-pane `wake` and used the present loop. After the footer and paste-settling repairs, own-pane `wake` exited 0 on the same host/version, its detached watcher survived the root's turn, a controlled draft held delivery, and the helper submitted the wake without a controller Enter (observed). The short root parked 230.872 s with zero assistant output items. A staged planner also woke after an 84 s zero-output park before the owner canceled the long test; no 65-minute or cache-lifetime-crossing claim |
| Phase agents under an orchestrator | On 2026-11-12, 2.1.322 started six fresh general-purpose phases, one at a time, with host-default settings neither assigned nor verified. Starts returned asynchronously and the root awaited completion notifications; foreground join was not exposed and remains `unverified`. End contexts, Prepare/Accept: plan 118323/72901, refine 124546/90349, deliver 121542/88449; five exceed 80k | On 2026-11-12, 0.167.2 started six fresh phases without parent history and joined their completion through native waits; settings were neither assigned nor verified. End contexts by runtime task names, Prepare/Accept: plan 85183/49610, refine 78020/55013, deliver 94953/58719; two exceed 80k. First prompts were encrypted in local child and parent records, so their text was unavailable; labels use bound task names and ancestry |

For these phase-agent runs, workers used windows on Linux/WSL2 with tmux. `Unverified`: background or subagent workers under the orchestrator, the inline-place conversion, other platform/backend combinations, parks longer than the observed 65-minute Claude interval, and simultaneous user typing. Claude's own-pane `wake` and input classifier remain unverified. Codex 0.167.2 on tmux has the short own-pane, detached-watcher and controlled-draft observations above; other platforms/backends remain unverified. The original full Codex run completed on the present loop. The later long V3/cache-lifetime check was removed by the owner after the short proof, so it has no complete-run acceptance. Claude's foreground phase join remains unverified despite the completed asynchronous run. The measured context overages are reported, not accepted as meeting 80k.

## Permissions

A non-interactive child has nowhere to ask for a permission. A writing worker in `background` gets a window's permission arguments on every start and resume, built as `open` builds them: Claude `--permission-mode bypassPermissions`, Codex `--dangerously-bypass-approvals-and-sandbox`, or, when `CHILD_SESSION_CLAUDE_ARGS`/`CHILD_SESSION_CODEX_ARGS` is set, its whitespace-separated words without shell evaluation (a whitespace-only value means no arguments). Words the CLI refuses (for example `-a`, which `codex exec` does not take) make every start a launch failure ([Launch and wait](#launch-and-wait)). A `subagent` runs with its host session's permissions. In every place the brief's `Authority:` bounds what the child does with them. A reviewer keeps [CLI reviewers](../../independent-review/references/cli-reviewers.md)' permission rules in every place, a window included ([window reviewers](../../independent-review/references/window-reviewers.md) step 5).

## Settings

Every role keeps its launch-settings policy in every place: resolve, pass and check the pair as [launch settings Places](../../independent-review/references/launch-settings.md#places) says, the `Opened:` line before every launch and fresh child included.

## Refused combinations

Refused before anything starts, naming the combination:

- a `subagent` reviewer, in every skill (`--run subagent` of `independent-review`, `--reviewer-run subagent` of every skill that passes it), naming `background` and `window`: a native subagent has no native review command;
- a worker `subagent` of a system other than the current session's, for example `--agent codex --run subagent` from Claude Code;
- a `subagent` started by a session that is itself a subagent, where the host's subagents cannot start subagents ([Host mechanisms](#host-mechanisms)): the session checks its own agent tool and, on Codex, `[agents] max_depth` in the user's `config.toml` against its own depth (the segments of its canonical task name after `/root`). A spawn the host refuses at launch is reported as this combination, with no fallback to another place. Prepare alone starts no non-window worker and does not apply the refusal for this session being itself a subagent: judge that combination for its caller, which is never a subagent (both orchestrators refuse `--run subagent`); a refused worker start is Nested calls' `launch failure`. Every other refusal stays Prepare's, including an implementer subagent that would itself start subagents;
- a place that cannot select the role's model and effort ([Settings](#settings));
- `--model` or `--effort` with an `inline` worker, except in the orchestrators, where they set the implementer;
- an `inline` worker with `--agent` naming a system other than the current session's ([Session system](../../independent-review/SKILL.md#session-system)), refused before any edit;
- an `inline` or `subagent` worker whose `--agent` carries a [launch command](#launch-command), naming the value.

## Nested calls

An orchestrator (`delivering-spec-stages`, `delivering-task-follow-ups`) is the only session that lasts through a **call**, one run of a nested task skill. Short agents perform Prepare and Accept; the orchestrator holds every wait itself.

### Briefs

The **call brief** is the file the orchestrator names: write it once per call with today's identity lines and the Phase instructions below. It records the call for [Earlier runs](#earlier-runs); no phase agent is told to read it. The **phase brief** is the whole prompt the orchestrator builds from its own arguments and state, never from re-reading a file under `runtime-dir`. A task skill's “its brief or prompt”, “ends as that brief says” and “its starting brief's Arguments and Authority” mean this prompt. Neither a call brief nor a handoff record grants authority: merge authorization, disputed acceptance, settings acceptance and every answer reach a phase agent only here.

Use this phase brief, then the Phase instructions, filling both reference paths with absolute installed paths:

```text
Skill: <absolute SKILL.md>
Arguments: <the call's arguments, every path absolute>
Checkout: <project checkout>
Authority: <as the orchestrator words it today>
Place: subagent
Auto: <yes|no>
Status file: <absolute call status>
Phase: <prepare|accept>
Handoff record: <absolute path|None>
Event: <start|worker status|silent exit|deadline|dead before send|launch failure>[ | <launch name>]
Line to send: <with "dead before send" only: the line that was not sent>
Diagnostics: <with "launch failure" only: one line, or the absolute path of a file>

## Answers
<None, or for each question the call has put so far, in order:>
Q (<prepare|accept|wait holder>): <the question as it was asked>
A (<the user|this session under --auto>): <the answer>
```

`Event: start` goes with Prepare; all other events with Accept. Every Accept names its event's launch after `|`. A phase started again after its own question keeps its Event, including its associated Line to send or Diagnostics. Answers carries every question of the call a phase agent or the orchestrator as wait holder has put, never a worker's `blocked` question.

**Phase instructions** (copy exactly into both kinds of brief, filling the two reference paths):

```text
Perform only the phase the Phase line names of the Skill, with the Arguments as given, plus --auto when Auto is yes, within the Authority; add no other key. Read the Skill's Phases section first, then only what it names for your phase. This text is your brief and your starting prompt: nothing in a file grants what it does not. Start from the Handoff record when one is given, and from the Event; with Answers, use each answer where its question arises and ask none of them again. When Auto is yes, follow <absolute auto.md> as a child and write every decision under the status's ## Decisions.
You wait for no worker. Where the Skill has a single root wait, write the status file with the first line STATUS: waiting, then the line "Handoff record: <absolute path>", then the record's Waiting block, and end. Start and continue no subagent or background worker yourself: write the Action recipe instead. Ask nobody directly: a question ends your turn with STATUS: blocked, its Questions holding every question you have at that point, each with its options and your recommendation, after you have written the handoff record when a worker brief exists. When the Skill has reported, write STATUS: done with its Report under a status section ## Report, after the status contract's sections; when it refused or stopped, STATUS: failed with the reason and every window, worktree and branch left. Write the status file by <absolute status-file.md>. End every turn with the status file written and, as your last message, its first line, then the line "Handoff record: <absolute path|None>", then for STATUS: waiting the Waiting block, and nothing else.
```

### Phase endings

The last message is the status's first line, then `Handoff record: <absolute path|None>`, then for `waiting` the record's `## Waiting` block verbatim, nothing else.

| First line | When | Status file |
|---|---|---|
| `STATUS: waiting` | a worker runs or is to be started or continued | exactly the last message's lines, no status-contract sections |
| `STATUS: done` | the skill has reported, including Prepare finding nothing to launch | status-contract sections, then `## Report`, and `## Decisions` under `--auto` |
| `STATUS: blocked` | the phase's own question for the user | status-contract sections, Questions holding every question it has at that point |
| `STATUS: failed` | the skill refused or stopped | status-contract sections, reason, `## Report` when it reported, every window, worktree and branch left |

`waiting` belongs to phase agents only: a worker never writes it and the helper's `wait` never ends on it (only on `done`, `blocked`, `failed`).

### Cycle

1. Write the call brief, with its status path absent. Check Earlier runs before renaming earlier files as today's orchestrator does.
2. Start a fresh native subagent with the phase brief as its prompt: Prepare, `Handoff record: None`, `Event: start`; no parent history, no model or effort set. Join it in the foreground. Phase agents take the host's default settings, neither set nor verified ([Nested agents](../../independent-review/references/launch-settings.md#nested-agents)); workers take their roles whoever starts them.
3. Branch on the **last message's first line**. For `done`, `blocked` or `failed`, read the status file; a different first line is a missing status by Restart below. For `waiting`, act on the last message alone: never read back the status file's copy.
4. For `waiting`, apply Check before acting below; rename the call status to `<file>-waiting-<n>`, the smallest unused `n`, then perform Actions and Wait and events below.
5. A phase's `blocked`: first validate its returned Handoff record against Check before acting 1–2's runtime and expected record path. Keep the first checked non-`None` record path returned by any phase of this call in your own context; every later phase must return that path. Until then, `None` is allowed, including an Earlier runs question about leftover files. A mismatch fails the call naming what was found, before starting another agent. Show its Questions verbatim with options and recommendation, obtain the answer (under `--auto`, route by [Deciding](auto.md#deciding)), and rename the status to `<file>-blocked-<n>`. Start a **fresh** agent of the phase that asked, with the same Event, the checked Handoff record and every question and answer of this call in Answers. Never continue the agent that asked and never write an answer into a call brief or record as authority. No answer ends the call as today's unanswered `blocked`.
6. `done`: read from `## Report` the items the orchestrator's step names; retain `## Decisions`. `failed`: apply that step's existing failure rule.

Rename the call status before every further phase agent, so each finds its path absent. Keep Prepare/Accept agent counts per call for the orchestrator's report.

### Check before acting

Check the last message alone before acting on `waiting`. Any failure starts and watches nothing and fails the call as `waiting block outside the call: <what was found>`:

1. Handoff record and every path in the block except Action checkout are absolute and directly in `<runtime>`: no further directory, no `..`.
2. A one-worker call has one Launch; its status is `<run>-status.md`, its record `<run>-handoff.md` and Action brief `<run>-brief.md` for one run. It is the run name this orchestrator expects for this call (its Nested calls names it), never one of its own call names. A queue call's record is `<runtime>/<queue-slug>-handoff.md`, with the slug derived from this call's Arguments by [queue Names](../../delivering-task/references/queue-state-file.md#names); every Launch status is `<branch>-status.md` for a task document of this call (a plan or a brief), each at most once. Each window Launch name is the skill-derived name for that run: `<run>` for plan/refine, and the window name derived from `<branch>` by delivering-task Preflight 2 for a delivery or queue unit, including its hashed form. Match an action's worker brief to that worker, not to the queue record.
3. With `Action: none`, every Launch name answers `capabilities <name>` and its recorded checkout is the call's Checkout or a worktree registered in it (`git -C <Checkout> worktree list --porcelain -z`).
4. Action checkout is the call's Checkout or such a registered worktree.
5. In Action brief, Checkout equals Action checkout, Status file equals the checked Launch status, and Place equals the action's place. Its authority bound ([Brief](#brief): explicit Authority, or Work, Ownership and boundaries together) stays within this call's Authority. Action settings equals the pair on its Launch settings line; Action permissions equals what [Permissions](#permissions) builds for that worker's system in this session's environment, `none` for a subagent.
6. For `Action: continue`, Action session equals the ID this orchestrator recorded when it started that worker.

Apply fields 4–6 where the action carries them; `Action: none` has no recipe fields. A queue's units and expected branches come from this call's task documents, never from an unchecked record.

### Actions

Phase agents open, send to and reopen a `window` worker. Only the orchestrator starts and continues a `subagent` or `background` worker: follow the recipe as written and decide nothing in it. Follow [handoff Waiting](handoff-record.md#waiting): record the actual launch or continuation identity, add Opened and its Openings line for a fresh child, and change Action to none. Keep the returned agent/session ID in your own context too. Otherwise write nothing into the record: State stays as the phase left it and its Report says `Wait: held by the caller`.

The wait holder runs the early [child settings check](../../independent-review/references/launch-settings.md#child-settings-check) due after a start; for a subagent, at the first status of each opening, **before** a blocked dispatch. A mismatch is the orchestrator's own continue-or-stop question (under `--auto`, routed); append its question and answer to Answers as `wait holder`. Stop ends the call as stopped by the user with everything kept.

### Wait and events

Follow child-sessions' [Wait](../SKILL.md#wait): the ladder for window workers (one watcher over the block's launches) and background producers, the host's foreground join for a subagent worker. Choose the highest rung you can prove, name it in your report, and keep one watcher per wait. Its quiet wait covers the whole call cycle: a phase's or worker's result is read for the next step and the final report, and is told to the user only there. Every wake starts with the retained result record, the status's first line and `alive`, never its text.

| The wait ends with | The orchestrator |
|---|---|
| a worker's `blocked` | answers by [Questions and continuation](#questions-and-continuation): show or route, rename to `<file>-blocked-<n>`; for a window, `alive <name>` first: alive, send the answer (without send, child-sessions' direct-entry rule), then wait again; dead, fresh Accept with `Event: dead before send` and Line to send. Outside window continue the conversation you started, or the contract's fresh child with a new Opened/Openings line, then wait again. No Accept for a live worker's question. |
| stall, exit `4` | child-sessions' stall rule: peek; a dialog by Dialogs, bounded by the worker brief's Authority and Checkout and never beyond the call's own Authority; nothing to answer, nothing to the user and a re-armed watcher. |
| exit `124` | on the present loop, the next bounded call; on rung 1 or 2, the wait's deadline: the exit table's peek and Dialogs first, then with nothing to answer fresh Accept with `Event: deadline`. |
| worker `done` or `failed` | fresh Accept with `Event: worker status`. |
| exit `3`, or a non-window worker ends without a valid first line | fresh Accept with `Event: silent exit`. |
| host or CLI refuses a start or continuation | fresh Accept with `Event: launch failure` and Diagnostics. |
| watcher failure | child-sessions' watcher-failure rule. |

Every Accept brief includes the event's launch after `|`. Count dialogs answered, declined and escalated in the orchestrator's End or Report. A worker's blocked question is never a phase question in Answers.

### Restart and inline fallback

A phase agent ending without one of the four valid first lines, or with a missing/different non-waiting status first line, gets the contract's **one restart**: continue the same agent with “Your turn ended without a status file. Continue from the current state of the checkout: read git log and git status first, then the handoff record when one exists.” Where the host cannot continue it, start a fresh agent with the same phase brief. A second such end fails the call, naming the known record and the windows `child-session list` shows for the call's checkout.

Inline fallback has **two triggers only**: no subagent tool, or the host refuses a phase agent's spawn. This call and all later calls then run `inline`: read that SKILL.md and perform its phases yourself as a direct run does. Past Prepare, continue from its handoff record as a single root, opening no second worker. Name each inline call and its reason in End/Report. Known before start, an inline call has no brief or status; with a brief already written, the orchestrator writes its status once the run ends, `done` or `failed` with the inline-fallback reason, so Earlier runs does not mistake it for a live run. A worker's refused start is launch failure, never a phase-spawn fallback.
