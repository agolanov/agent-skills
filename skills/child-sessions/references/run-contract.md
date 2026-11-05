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

**System.** `--agent claude|codex` chooses the worker's system. Without it the worker is the caller's own system, identified from session identity as independent-review's [Session system](../../independent-review/SKILL.md#session-system) says, and a window's `open` receives it as `--agent`; the helper's own default is not this rule. A reviewer is the opposite system unless `--codex`, `--claude` or `--dual` chooses it. A `subagent` is always the caller's own system.

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
- The child reads `Skill:` completely and performs that skill `inline` in its own session with `Arguments:`, adding `--auto` when `Auto: yes` (the parent writes `yes` when its own run has `--auto`). `Authority:` bounds what it writes, commits and decides. It writes the status file by [status-file.md](status-file.md).
- A skill's own brief template (planner, splitter, refiner, implementer) is a run-contract brief too: its identity block carries `Place:` and `Auto:`, and its Work stands in for `Skill:` and `Arguments:`.
- A subagent's last message lands in the parent's context: the brief tells it to end with the status file's first line only.

## Launch and wait

Every place starts the child with the window's prompt:

```text
Read the brief at <absolute brief> completely and carry it out.
```

Before every start, append the brief's `Opened:` line ([Settings](#settings)).

- **`window`:** [SKILL.md](../SKILL.md) as today: `open`, Startup, the foreground wait loop, Dialogs and the single reopen after a silent exit.
- **`subagent`:** start a fresh agent with the host's agent tool ([Host mechanisms](#host-mechanisms)): the prompt above, no parent history, the host's normal tool set, and the pair of [Settings](#settings). It starts in the parent's working directory; the brief's `Checkout:` is where it works. Wait with the host's wait tools until it ends; it writes the status file before it ends.
- **`background`:** start the CLI in the checkout with the prompt on stdin and stdout/stderr in a fresh run directory under `runtime-dir`, one per start or resume. Claude: `claude --print --output-format stream-json --verbose <permission args> [--model M] [--effort E]`. Codex: `codex exec <permission args> [-c model="M"] [-c model_reasoning_effort="E"] -`. `<permission args>` come from [Permissions](#permissions); a `cli-default` field omits its flag. Run the recipe through the host's background execution and wait for the process to exit with the host's wait tools (a Codex `exec_command` that yields a `session_id` is polled with `write_stdin` until it exits), keeping this session active. Record the producer exit and the session ID in the run directory; the report names both.

Then read the status file's first line, as for a window: `done` and `failed` follow the window's status table ([Foreground wait loop](../SKILL.md#foreground-wait-loop)), `blocked` follows [Questions and continuation](#questions-and-continuation). A child that ends without a valid first line (a subagent's end, any producer exit) gets **one restart** by that section's continuation, the message being "Your turn ended without a status file. Continue from the current state of the checkout: read git log and git status first." A second ends the run, as a window's second silent exit: show the producer exit, stderr and the run directory, and preserve the checkout.

POSIX recipe (Bash). Bind absolute `checkout` and `run_dir` holding `prompt.md` (the start prompt, or a resume's continuation message), `agent` (`claude` or `codex`), `model` and `effort` (each may be `cli-default`), and `session_id` (empty to start, the recorded ID to resume):

```bash
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
  "${vector[@]}" < "$run_dir/prompt.md" > "$run_dir/$out" 2> "$run_dir/stderr.log"
) || producer_exit=$?
printf '%s\n' "$producer_exit" > "$run_dir/producer.exit"
if [ "$agent" = claude ]; then
  sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$run_dir/events.jsonl" | head -n 1
else
  sed -n 's/^session id: //p' "$run_dir/stderr.log" | head -n 1
fi > "$run_dir/session.id"
```

Native PowerShell recipe (PowerShell 7). Bind the same values as `$checkout`, `$runDir`, `$agent`, `$model`, `$effort` and `$sessionId`, plus `$exe` with `$lead`: the resolved installed `claude` or `codex` executable with `$lead = @()`, or for an npm shim its installed node with `$lead = @('<the shim's JavaScript target>')`; any other shim is unavailable, never evaluated. It uses `System.Diagnostics.Process` directly and depends on no other skill's script:

```powershell
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
$outFile = [IO.File]::Create((Join-Path $runDir $outName))
$errFile = [IO.File]::Create((Join-Path $runDir 'stderr.log'))
try {
  $process = [Diagnostics.Process]::Start($psi)
  $outCopy = $process.StandardOutput.BaseStream.CopyToAsync($outFile)
  $errCopy = $process.StandardError.BaseStream.CopyToAsync($errFile)
  $promptFile = [IO.File]::OpenRead((Join-Path $runDir 'prompt.md'))
  try { $promptFile.CopyTo($process.StandardInput.BaseStream) } finally { $promptFile.Dispose(); $process.StandardInput.Close() }
  $process.WaitForExit(); $outCopy.Wait(); $errCopy.Wait()
  Set-Content -LiteralPath (Join-Path $runDir 'producer.exit') -Value $process.ExitCode
} finally { $outFile.Dispose(); $errFile.Dispose() }
$found = Select-String -LiteralPath (Join-Path $runDir $idSource) -Pattern $idPattern | Select-Object -First 1
Set-Content -LiteralPath (Join-Path $runDir 'session.id') -Value $(if ($found) { $found.Matches[0].Groups[1].Value } else { '' })
```

A start exception is a launch failure with no producer exit; keep it apart from a nonzero exit.

## Questions and continuation

- A `subagent` or `background` child asks nobody directly: a question ends its turn with `STATUS: blocked`, its Questions holding the question, the options and its recommendation. In a `window` an interactive skill (brainstorming) may still ask the user in the window; any other question takes the same status.
- Without `--auto`, the parent answers within its authority or asks the user, showing the question, options and recommendation as written.
- Before continuing, archive the status: rename it to `<file>-blocked-<n>` with an unused number, as for a window ([status-file.md](status-file.md)); the child writes a fresh status at the original path.
- Continue **the same child conversation** by the host mechanism of [Host mechanisms](#host-mechanisms), the answer as one message (multiline content in a file, the message naming its absolute path), then wait as at launch:
  - `subagent`: the host's message tool to the same agent;
  - `background`: the recipe of [Launch and wait](#launch-and-wait) with the recorded `session_id`, the message as `prompt.md`, the same permission arguments and the recorded settings;
  - `window`: child-sessions' `blocked` row.
- Otherwise start a **fresh child**: the original brief, followed by every question and answer so far and the line "Continue from the current state of the checkout: read git log and git status first.", with a new `Opened:` line. Otherwise means no mechanism for the host, no recorded session ID, or a continuation the host refuses (its message tool returns an error, or the resume exits nonzero without a status); that fallback belongs to the same answer or restart.

## Host mechanisms

Checked 2026-11-05 on Linux (WSL2) with Claude Code 2.1.318 and codex-cli 0.166.0 by reading `claude --help`, `codex --help`, `codex exec --help`, `codex exec resume --help`, the agent tool schemas of a Claude Code subagent session, the Codex tool lists recorded in rollouts, and existing runtime records; nothing was launched for this check. Help means installed help, schema the live tool schema, observed an existing runtime record; `unverified` is what this reading could not confirm. Installed help and live schemas win over this table. A run may use an `unverified` entry, names it unverified in its report, and falls back as [Questions and continuation](#questions-and-continuation) says.

| Mechanism | Claude Code 2.1.318 | Codex 0.166.0 |
|---|---|---|
| Subagent start | agent tool with `prompt`, `subagent_type`, `model`, `effort` (schema); a general-purpose type has the normal tools; the fork type inherits the parent's context and is not used | `spawn_agent` with `task_name`, `message`, `model`, `reasoning_effort`, and `fork_turns: "none"` for no parent history (tool list) |
| Subagent wait | the agent tool's result, or its completion notification for a background agent (schema) | `wait_agent` (`timeout_ms` up to 3600000) reports which agents have updates; the final answer arrives when the agent finishes (tool list) |
| Continue after it ends | `SendMessage` to the agent's ID or name, which "resumes it from its transcript" (schema); observed 2026-11-05: four finished subagents of one run continued this way, each transcript holding both prompts | `followup_task` (`target`, `message`) triggers a turn on an idle agent; `send_message` only queues (tool list); continuing a finished agent: unverified |
| Subagent model and effort | `model` takes the aliases `sonnet`, `opus`, `haiku`, `fable` (`opus` observed as `claude-opus-5-5`); `effort` takes `low` to `max` (schema); an omitted effort inherited the parent's (observed); an explicit `effort`: unverified | `model` and `reasoning_effort` per spawn; `reasoning_effort: high` under an `xhigh` parent showed `high` in the child's `turn_context` (observed 2026-11-03) |
| Subagent starts subagents | the agent tool is in a subagent's tool list and its `meta.json` records `spawnDepth` (observed); a nested start: unverified | the tool says spawned agents can spawn their own, and a depth-1 subagent lists `spawn_agent` (observed); `[agents] max_depth` in `config.toml` limits depth (this machine: `1`); a depth-2 spawn: unverified |
| Subagent holds child-sessions' foreground wait loop | its shell tool takes foreground calls up to 600000 ms (schema); not exercised: unverified | spawned agents have the parent's tools (tool list); not exercised: unverified |
| Subagent runtime record | `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/<parent project>/<parent session ID>/subagents/agent-<agent ID>.jsonl` beside its `.meta.json`; the first user message is the prompt; model `message.model` of assistant records, effort `message.output_config.effort` of request records and `effort` of assistant records (observed) | a rollout under `${CODEX_HOME:-$HOME/.codex}/sessions/` whose `session_meta.payload.source.subagent.thread_spawn.parent_thread_id` is the parent's thread, with the parent's cwd; the spawn message is a user message; `turn_context.payload.model` and `.effort` (observed) |
| Background start | `claude --print` reads the prompt on stdin; `--output-format stream-json --verbose`, `--model`, `--effort`, `--permission-mode`; print mode skips the workspace-trust dialog (help); a print-mode `init` event showed `permissionMode: bypassPermissions` (observed on 2.1.316) | `codex exec ... -` reads the prompt on stdin; `-c model=...`, `-c model_reasoning_effort=...`, `--dangerously-bypass-approvals-and-sandbox` (help); `codex exec` sessions spawn subagents (observed 2026-11-01) |
| Background session ID | `session_id` of the stream's `system`/`init` event (observed on 2.1.316, 2026-10-31; on 2.1.318 unverified) | the stderr header line `session id: <uuid>` (observed in review mode on 0.165.0 and 0.166.0; for `exec` unverified); the rollout's `session_meta.payload.id` carries the same ID |
| Background resume | `claude --print --resume <id>` keeps the ID unless `--fork-session` (help); not exercised: unverified | `codex exec resume [OPTIONS] <id> -` reads the prompt on stdin; its options list `-c`, `-m` and `--dangerously-bypass-approvals-and-sandbox`, but no `--sandbox` or `--ask-for-approval` (help); not exercised: unverified |
| Background runtime record | the **Claude child** transcript of launch-settings' [child settings check](../../independent-review/references/launch-settings.md#child-settings-check) | the **Codex child** rollout of the same check |
| Native Windows | the PowerShell recipe is written, never exercised: unverified on every Windows shell; it needs `ProcessStartInfo.ArgumentList`, which Windows PowerShell 5.1 lacks, so there `background` is unavailable | the same |

## Permissions

A non-interactive child has nowhere to ask for a permission. A writing worker in `background` gets a window's permission arguments on every start and resume, built as `open` builds them: Claude `--permission-mode bypassPermissions`, Codex `--dangerously-bypass-approvals-and-sandbox`, or, when `CHILD_SESSION_CLAUDE_ARGS`/`CHILD_SESSION_CODEX_ARGS` is set, its whitespace-separated words without shell evaluation (a whitespace-only value means no arguments). A `subagent` runs with its host session's permissions. In every place the brief's `Authority:` bounds what the child does with them. A reviewer keeps [CLI reviewers](../../independent-review/references/cli-reviewers.md)' permission rules in every place, a window included ([window reviewers](../../independent-review/references/window-reviewers.md) step 5).

## Settings

Every role keeps its launch-settings policy in every place: resolve, pass and check the pair as [launch settings Places](../../independent-review/references/launch-settings.md#places) says, the `Opened:` line before every start included.

## Refused combinations

Refused before anything starts, naming the combination:

- a `subagent` of a system other than the current session's, for example `--codex --reviewer-run subagent` from Claude Code;
- a `subagent` started by a session that is itself a subagent, where the host's subagents cannot start subagents ([Host mechanisms](#host-mechanisms); the session checks its own agent tool);
- `--dual` with `subagent`;
- a place that cannot select the role's model and effort ([Settings](#settings));
- `--model` or `--effort` with an `inline` worker, except in the orchestrators, where they set the implementer;
- an `inline` worker with `--agent` naming a system other than the current session's ([Session system](../../independent-review/SKILL.md#session-system)), refused before any edit.

## Nested calls

An orchestrator (`delivering-spec-stages`, `delivering-task-follow-ups`) runs each nested skill as a nested call in a `subagent`:

- **Brief:** the identity lines with `Skill:` the nested skill's absolute SKILL.md, `Arguments:` its arguments, `Checkout:`, `Authority:`, `Place: subagent`, `Auto:` and `Status file:`, and the instruction: "Run the skill completely, its windows included, and write its Report under a status section `## Report`, after the status contract's sections."
- **Run:** the subagent reads and runs the nested skill completely, its child-sessions windows included, and returns its status. The orchestrator reads the first line and `## Report`; a `blocked` call continues by [Questions and continuation](#questions-and-continuation), the same subagent first.
- **Settings:** the host's default, the orchestrator session's model, neither set nor verified (launch-settings [Nested agents](../../independent-review/references/launch-settings.md#nested-agents)); the nested skill's own workers take their roles as usual.
- **Host that cannot hold the call:** when the host has no subagents, or its subagents cannot run child-sessions' foreground wait loop ([Host mechanisms](#host-mechanisms), or a nested subagent's status saying so), the orchestrator runs that call `inline` and reports why.
