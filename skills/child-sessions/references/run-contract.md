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
- A skill whose root is its worker (`review-fix-loop`, the triage, the orchestrators) moves as a whole: the calling session becomes a **thin launcher**, which writes the brief, waits, relays questions and reports the child's result.
- Any skill can be run as a whole outside `inline` by its caller, a parent skill or the user's words, through this contract; `--run` only names each skill's default target of that move.
- The user's words set places as keys do ("run the plan without a window", "let Codex review it in a window"): the session maps them to keys and announces the mapping.

**System.** `--agent claude|codex` chooses the worker's system. Without it the worker is the caller's own system, identified from session identity as independent-review's [Session system](../../independent-review/SKILL.md#session-system) says, and a window's `open` receives it as `--agent`; the helper's own default is not this rule. A reviewer is the opposite system unless `--codex`, `--claude` or `--dual` chooses it; with `subagent` and no system key it is the caller's own system. A `subagent` is always the caller's own system.

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
4. **Launch, wait and relay.** Append `Opened:` at the [Launch and wait](#launch-and-wait) boundary, then launch and wait there, preserving its failure and restart rules. A window uses `open --agent <this session's system>` with the pair, omitting a `cli-default` field; a subagent uses native setting controls; a background CLI uses the pair and [Permissions](#permissions). Run the early [child settings check](../../independent-review/references/launch-settings.md#child-settings-check) at the first status after each opening; only a mismatch stops for the user's continue-or-stop question. Show blocked Questions verbatim with their options and recommendation and obtain the user's answer. Under `--auto`, route mismatch and blocked questions by [auto.md](auto.md#deciding) instead. Archive blocked status and continue by [Questions and continuation](#questions-and-continuation), preserving the same-conversation and fresh-child rules.
5. **Verify and report.** After `done` or `failed`, run the final [child settings check](../../independent-review/references/launch-settings.md#child-settings-check). Report the local result and one settings line: role, effective model and effort with sources, check outcome and record paths, or the user's acceptance. For background, include each producer exit and session ID; under `--auto`, carry the status's `## Decisions` together with this session's own. Apply any local final decision before reporting completion. After `done`, close the owned window only when the calling skill's completion conditions pass; otherwise leave the window and status for the user. Preserve failures and their evidence.

## Earlier runs

A skill names a run's brief, status and run directories after its task (`plan-<slug>`, `loop-<slug>`), and every session of the user shares `runtime-dir`, so files of those names may belong to a run still in progress, started by this session or another, in this project or another. A live window of that name is refused, as each skill says. Before renaming the other files of those names as an earlier run's leftovers, check whether a `subagent` or `background` run may still use them: a brief whose `Place:` line names `subagent` or `background` while its status file is absent or its first line is neither `STATUS: done` nor `STATUS: failed`, or a run directory of those names whose recording is unfinished. A directory with `launch.time` or `wrapper.identity` is new-format: without a valid `wrapper.done` and completed records by [Background recording](#background-recording), it remains possibly live/incomplete even when `producer.exit` exists. A directory with neither new field retains the legacy rule: absence of `producer.exit` means possibly live. Nothing outside a window proves that such a run has ended, and renaming its files would hand its parent another run's status and session ID. Show those files and ask the user whether that run has ended: rename them only on the user's yes; otherwise stop, naming them. Under `--auto` this question reaches the user ([auto.md](auto.md#hard-to-undo)).

## Launch and wait

Every place starts the child with the window's prompt:

```text
Read the brief at <absolute brief> completely and carry it out.
```

Before every launch (each `open` of a window included) and every fresh child, append the brief's `Opened:` line ([Settings](#settings)); an answer or a restart that continues the same conversation never gets one.

- **`window`:** [SKILL.md](../SKILL.md) as today: `open`, Startup, the foreground wait loop, Dialogs and the single reopen after a silent exit.
- **`subagent`:** start a fresh agent with the host's agent tool ([Host mechanisms](#host-mechanisms)): the prompt above, no parent history, the host's normal tool set, and the pair of [Settings](#settings). It starts in the parent's working directory; the brief's `Checkout:` is where it works. Wait with the host's wait tools until it ends; it writes the status file before it ends.
- **`background`:** start the CLI in the checkout with the prompt on stdin and stdout/stderr in a fresh run directory under `runtime-dir`, one per start or resume. Claude: `claude --print --output-format stream-json --verbose <permission args> [--model M] [--effort E]`. Codex: `codex exec <permission args> [-c model="M"] [-c model_reasoning_effort="E"] -`. `<permission args>` come from [Permissions](#permissions); a `cli-default` field omits its flag. On Claude, start the top-level producer script **once** with Bash `run_in_background: true`, retain its host task identifier, and use `TaskOutput` with its actual installed schema (`block: true`, waits at most 60000 ms) only when exposed. On the inspected Claude 2.1.318 neither root nor native subagent exposed it: use the supported [Completion-marker fallback](#completion-marker-fallback) and keep this coordinator active. On Codex start with `exec_command` and continue that same returned `session_id` through `write_stdin`, with individual waits at most 60000 ms, until it exits. That host handle is separate from the CLI conversation ID in `session.id`. Refuse before launch only if neither a usable host execution/wait pair nor the fallback's shell/liveness capabilities exist; do not silently change places. Complete [Background recording](#background-recording) before reading terminal status.

Then read the status file's first line, as for a window: `done` and `failed` follow the window's status table ([Foreground wait loop](../SKILL.md#foreground-wait-loop)), `blocked` follows [Questions and continuation](#questions-and-continuation). A child that ends without a valid first line (a subagent's end, any producer exit) gets **one restart** by that section's continuation, the message being "Your turn ended without a status file. Continue from the current state of the checkout: read git log and git status first." A second ends the run, as a window's second silent exit: show the producer exit, stderr and the run directory, and preserve the checkout. A **launch failure** gets no restart and is reported with the CLI's message: a start exception (no producer exit), or the CLI refusing its arguments before any session starts (a usage error on stderr, no session ID).

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

POSIX recipe (Bash). Bind absolute `checkout` and `run_dir` holding `prompt.md` (the start prompt, or a resume's continuation message), `agent` (`claude` or `codex`), `model` and `effort` (each may be `cli-default`), and `session_id` (empty to start, the recorded ID to resume). The Linux parser adapts the owner's `process_identity` algorithm; lifecycle scripts remain unchanged. Every required command checks its real exit; no shell-wide errexit is assumed.

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
  vector=(claude --print --output-format stream-json --verbose "${perm[@]}")
  [ -z "$session_id" ] || vector+=(--resume "$session_id")
  [ "$model" = cli-default ] || vector+=(--model "$model")
  [ "$effort" = cli-default ] || vector+=(--effort "$effort")
  out=events.jsonl
else
  if [ -n "${CHILD_SESSION_CODEX_ARGS+x}" ]; then read -r -a perm <<< "$CHILD_SESSION_CODEX_ARGS"
  else perm=(--dangerously-bypass-approvals-and-sandbox); fi
  vector=(codex exec)
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

Native PowerShell recipe (PowerShell 7). Bind the same values as `$checkout`, `$runDir`, `$agent`, `$model`, `$effort` and `$sessionId`, plus `$exe` with `$lead`: the resolved installed `claude` or `codex` executable with `$lead = @()`, or for an npm shim its installed node with `$lead = @('<the shim's JavaScript target>')`; any other shim is unavailable, never evaluated. It uses `System.Diagnostics.Process` directly and depends on no other skill's script. Start/property, copy, extraction and literal .NET write errors stop the recipe without a marker; `$LASTEXITCODE` is not used for managed operations.

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

When no synchronous host-task wait is exposed, run one foreground watcher at a time, normally with a 60-second internal deadline and 1-second intervals. Bind absolute `run_dir`/`runDir` and `watch_seconds`/`watchSeconds` in **1..60** (normally 60; a synthetic deadline probe may use 1). Invoke with an explicit Bash tool `timeout: 75000` ms or a verified native tool equivalent with margin. Keep the nested coordinator active through the result. The raw OS-read function is the only fixture seam: disposable V2 runners may replace that leaf, then invoke the unchanged watcher entry. Production reads real proc/installed commands; parsing, record validation, identity comparison and the deadline body are never replaced. This adds no user key, installed helper or persistent configuration.

The startup observation lasts 30 seconds from the persisted `launch.time`, never from a later watcher's start. Validate the timestamp grammar on every loop pass, but apply calendar chronology and age checks only while identity is absent; a confirmed same live process waits to its bounded deadline even after a backward calendar-clock step. `0` means complete recording; `124` means the same live wrapper, or an identity still pending within the persisted startup grace, at the deadline; continue one bounded watcher without resetting `launch.time`. `2` means unavailable timestamp/identity/process evidence; `3` means incomplete recording. A gone, zombie or replaced wrapper gets one final marker/record recheck before `3`. Preserve logs and stop on `2`/`3`; do not launch another producer to repair recording. A malformed present marker or required record is `3`. A missing CLI ID still gives ready recording with a valid empty `session.id`, and is reported separately as launch failure.

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

A foreground watcher unexpectedly moved to background retains its original host task handle and diagnostics. Settle that waiter through a supported host mechanism before replacement, and report the capability failure; start no competing waiter or producer. The window's [foreground loop](../SKILL.md#foreground-wait-loop) stays unchanged by this fallback. Marker validation grants no signal or cleanup authority; keep existing ownership checks.

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

Initial catalog check on 2026-11-05 used Linux (WSL2), Claude Code 2.1.318 and codex-cli 0.166.0: installed CLI help, live Claude agent schemas, recorded Codex tool lists and existing runtime records; that reading launched nothing. Help means installed help, schema the live tool schema, observed actual retained runtime evidence. Later V2 executed the complete producer/watcher recipes through Bash and native PowerShell 7.6.9 with controlled fake CLIs; failure observations were synthetic. One V3 print-mode Claude coordinator foreground-joined one native agent on Linux/WSL2, which exercised the tmux window waits and the published background watcher over a real wrapper. Both test CLIs were fakes, so this verifies waiting/recording rather than real worker-model launches. Its retained report distinguishes the helper exits, an enclosing diagnostic-shell exit, recording completion and the later host notification, and separately records an unnecessary coordinator metadata-inspection deviation. Installed help and live schemas win over this table. The earlier real background planner used bounded record waits and supplies no acceptance for the new marker recipe. Other hosts/versions/platforms remain unverified. A run may use an `unverified` entry, names it unverified in its report, and falls back as [Questions and continuation](#questions-and-continuation) says.

| Mechanism | Claude Code 2.1.318 | Codex 0.166.0 |
|---|---|---|
| Subagent start | agent tool with `prompt`, `subagent_type`, `model`, `effort` (schema); a general-purpose type has the normal tools; the fork type inherits the parent's context and is not used | `spawn_agent` with `task_name`, `message`, `model`, `reasoning_effort`, and `fork_turns: "none"` for no parent history (tool list) |
| Subagent wait | the agent tool's result with `run_in_background: false` foreground-joined V3's one native agent through its final report (observed); completion notification for a background agent (schema) | `wait_agent` (`timeout_ms` up to 3600000) reports which agents have updates; the final answer arrives when the agent finishes (tool list) |
| Continue after it ends | `SendMessage` to the agent's ID or name, which "resumes it from its transcript" (schema); observed 2026-11-05: four finished subagents of one run continued this way, each transcript holding both prompts | `followup_task` (`target`, `message`) triggers a turn on an idle agent; `send_message` only queues (tool list); continuing a finished agent: unverified |
| Subagent model and effort | `model` takes the aliases `sonnet`, `opus`, `haiku`, `fable` (`opus` observed as `claude-opus-5-5`); `effort` takes `low` to `max` (schema); an omitted effort inherited the parent's (observed); explicit `model: opus`, `effort: high` resolved to `claude-opus-5-5`/`high` in V3's native agent record (observed); other explicit settings unverified | `model` and `reasoning_effort` per spawn; `reasoning_effort: high` under an `xhigh` parent showed `high` in the child's `turn_context` (observed 2026-11-03) |
| Subagent starts subagents | the agent tool is in a subagent's tool list and its `meta.json` records `spawnDepth` (observed); a nested start: unverified | the tool says spawned agents can spawn their own, and a depth-1 subagent lists `spawn_agent` (observed); `[agents] max_depth` in `config.toml` limits depth (this machine: `1`); a depth-2 spawn: unverified |
| Subagent holds child-sessions' foreground wait loop | V3 held a 150-second helper call with Bash `timeout: 175000`: helper exit 124 after 150.17 s; its enclosing diagnostic shell exited 2 only because a final `ls` of the absent status failed. After release the next 150-second helper call returned 0; neither call automatically backgrounded (observed Linux/WSL2, tmux, fake child). Other backends unverified; the schema's 600000 ms maximum alone proves no effective limit | use 240-second helper calls; a yielded `exec_command` continues through same-session `write_stdin` waits at most 60000 ms. Observed 2026-11-06 on Linux/WSL2 with herdr and real Codex: a native subagent held one wait through completion after 15.486 s; a background CLI coordinator held one uninterrupted 240-second-deadline wait for 150.138 s through the same tool handle, then close=0/alive=1. These are lifecycle mechanism probes, not complete refiner-workflow acceptance; other backends/platforms remain unverified |
| Subagent runtime record | `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/<parent project>/<parent session ID>/subagents/agent-<agent ID>.jsonl` beside its `.meta.json`, bound to the returned agent ID and parent identity/metadata; the first actual user prompt is string content or top-level text blocks. Use launch-settings' [typed settings fields](../../independent-review/references/launch-settings.md#typed-settings-fields) for assistant model and typed request effort, with assistant `effort` as corroboration; the assigned agent's sidechain marker is expected, its descendants excluded (observed record layout) | a rollout under `${CODEX_HOME:-$HOME/.codex}/sessions/` whose `session_meta.payload.source.subagent.thread_spawn.parent_thread_id` is the parent's thread, with the parent's cwd; the spawn message is a user message; `turn_context.payload.model` and `.effort` (observed) |
| Background CLI | `claude --print` reads the prompt on stdin; `--output-format stream-json --verbose`, `--model`, `--effort`, `--permission-mode`; print mode skips the workspace-trust dialog (help); a print-mode `init` event showed `permissionMode: bypassPermissions` (observed on 2.1.316) | `codex exec ... -` reads the prompt on stdin; `-c model=...`, `-c model_reasoning_effort=...`, `--dangerously-bypass-approvals-and-sandbox`, `-s`, but no `-a`/`--ask-for-approval`, which only top-level `codex` takes (help); `codex exec` sessions spawn subagents (observed 2026-11-01) |
| Host background execution and wait | Bash `run_in_background: true` returns the producer's host task identifier; use `TaskOutput` only if exposed, with `block: true` and waits at most 60000 ms. V3's coordinator/native agent schemas lacked it; the nested agent used the exact final-marker watcher with a 60-second deadline and Bash `timeout: 75000`. It returned 124 while the real wrapper was live with early `producer.exit=7` and no final records, then 0 after release/marker publication. A later host completion-0 notification was observed but not independently awaited. Failure branches have synthetic V2 coverage; other hosts unverified | `exec_command`, then `write_stdin` on the same yielded `session_id`, individual waits at most 60000 ms; this handle is not `session.id` |
| Background session ID | `session_id` of the stream's `system`/`init` event (observed on 2.1.316, 2026-10-31, and the native Windows 2.1.318 recipe run on 2026-11-06) | the stderr header line `session id: <uuid>` (observed in review mode on 0.165.0 and 0.166.0, and in the real native Windows `exec` recipe run on 2026-11-06); the rollout's `session_meta.payload.id` carries the same ID |
| Background resume | `claude --print --resume <id>` keeps the ID unless `--fork-session` (help); not exercised: unverified | `codex exec resume [OPTIONS] <id> -` reads the prompt on stdin; its options list `-c`, `-m` and `--dangerously-bypass-approvals-and-sandbox`, but no `--sandbox` or `--ask-for-approval` (help); not exercised: unverified |
| Background runtime record | the **Claude child** transcript of launch-settings' [child settings check](../../independent-review/references/launch-settings.md#child-settings-check) | the **Codex child** rollout of the same check |
| Native Windows | native PowerShell 7.6.9 executed ten producer/watcher cases with fake CLIs plus twelve watcher fixtures; process-failure observations were synthetic and the API exposes no zombie state. On 2026-11-06 the complete recipe and marker watcher also ran real native Claude and Codex CLIs: producer/watcher exits 0 and nonempty session IDs. Real interactive Windows terminal launches remain unverified. The recipe needs `ProcessStartInfo.ArgumentList`, absent in Windows PowerShell 5.1, where `background` is unavailable | the same fake coverage plus the real native Codex background recipe/watcher run above; interactive Windows terminal launches remain unverified |

## Permissions

A non-interactive child has nowhere to ask for a permission. A writing worker in `background` gets a window's permission arguments on every start and resume, built as `open` builds them: Claude `--permission-mode bypassPermissions`, Codex `--dangerously-bypass-approvals-and-sandbox`, or, when `CHILD_SESSION_CLAUDE_ARGS`/`CHILD_SESSION_CODEX_ARGS` is set, its whitespace-separated words without shell evaluation (a whitespace-only value means no arguments). Words the CLI refuses (for example `-a`, which `codex exec` does not take) make every start a launch failure ([Launch and wait](#launch-and-wait)). A `subagent` runs with its host session's permissions. In every place the brief's `Authority:` bounds what the child does with them. A reviewer keeps [CLI reviewers](../../independent-review/references/cli-reviewers.md)' permission rules in every place, a window included ([window reviewers](../../independent-review/references/window-reviewers.md) step 5).

## Settings

Every role keeps its launch-settings policy in every place: resolve, pass and check the pair as [launch settings Places](../../independent-review/references/launch-settings.md#places) says, the `Opened:` line before every launch and fresh child included.

## Refused combinations

Refused before anything starts, naming the combination:

- a `subagent` of a system other than the current session's, for example `--codex --reviewer-run subagent` from Claude Code;
- a `subagent` started by a session that is itself a subagent, where the host's subagents cannot start subagents ([Host mechanisms](#host-mechanisms)): the session checks its own agent tool and, on Codex, `[agents] max_depth` in the user's `config.toml` against its own depth (the segments of its canonical task name after `/root`). A spawn the host refuses at launch is reported as this combination, with no fallback to another place;
- `--dual` with `subagent`;
- a place that cannot select the role's model and effort ([Settings](#settings));
- `--model` or `--effort` with an `inline` worker, except in the orchestrators, where they set the implementer;
- an `inline` worker with `--agent` naming a system other than the current session's ([Session system](../../independent-review/SKILL.md#session-system)), refused before any edit.

## Nested calls

An orchestrator (`delivering-spec-stages`, `delivering-task-follow-ups`) runs each nested skill as a nested call in a `subagent`:

- **Brief:** the identity lines with `Skill:` the nested skill's absolute SKILL.md, `Arguments:` its arguments, `Checkout:`, `Authority:`, `Place: subagent`, `Auto:` and `Status file:`, and the instruction: "Run the skill completely, its windows included, and write its Report under a status section `## Report`, after the status contract's sections."
- **Run:** the subagent reads and runs the nested skill completely, its child-sessions windows included, and returns its status. The orchestrator reads the first line and `## Report`, and under `--auto` the status's `## Decisions`, which it carries into its own report; a `blocked` call continues by [Questions and continuation](#questions-and-continuation), the same subagent first.
- **Settings:** the host's default, the orchestrator session's model, neither set nor verified (launch-settings [Nested agents](../../independent-review/references/launch-settings.md#nested-agents)); the nested skill's own workers take their roles as usual.
- **Host that cannot hold the call:** when the host has no subagents, or its subagents cannot run child-sessions' foreground wait loop ([Host mechanisms](#host-mechanisms), or a nested subagent's status saying so), the orchestrator runs that call `inline` and reports why.
