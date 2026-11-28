---
name: child-sessions
description: Coordinates a separate Claude Code or Codex session when a task needs a child in a window, a native subagent or a background process.
---

# Child Sessions

The caller sets the task, permissions and completion checks. The child gets a brief and writes its result to a status file.

## Run places

For a window, follow this file. For a native subagent or background CLI, follow the [run contract](references/run-contract.md#launch-and-wait). All three share its [place selection](references/run-contract.md#places), [brief fields](references/run-contract.md#brief), [permissions](references/run-contract.md#permissions) and [refusals](references/run-contract.md#refused-combinations). If the caller chose no system, pass its own system as `--agent`.

Under `--auto`, put `Auto: yes` in the brief. The child asks nobody directly. Route questions through [Deciding](references/auto.md#deciding).

## Locate and open

1. Resolve the installed skill's absolute path. Use its [native entrypoint](references/platform-runtime.md): `scripts/child-session` on POSIX (including WSL), or `scripts/child-session.ps1` through `Invoke-ChildSessionDispatch` on native Windows. Keep that invocation for the run. MSYS/Cygwin is unsupported.
2. Call `runtime-dir`. Under that private directory, outside monitored repositories, write the [brief](references/brief-writing.md) and choose an absent absolute [status path](references/status-file.md). Choose a unique name matching `[A-Za-z0-9_-]+`.
3. Build `open_args` as `--agent <system> [options] -- <name> <absolute checkout> <absolute brief>`, one literal word per element. Pass the caller's model, effort and [launch settings](references/run-contract.md#launch-and-wait), with one `--cli-arg WORD` per extra word. Omitted model and effort use CLI defaults.
4. For each open, reopen or resume, submit the following sequence in **one shell tool call**. Honor any caller check at the step it guards. Keep the output and exit code. If the tool yields, collect the same call. On native Windows use the [PowerShell sequence](references/platform-runtime.md#native-windows-invocation).

   ```bash
   "$child_session" open "${open_args[@]}" &&
     "$child_session" capabilities "$name" &&
     "$child_session" startup "$name" "$status_file"
   ```

Keep the capability JSON, launch ID, checkout, backend IDs and PID/start evidence. Check the launch identity before using its controls. On a plain terminal, tell the user at launch that questions and dialogs need direct attention in the window and counts are **not observable**. Repeat only when ending or escalating the wait. Report the unverified native macOS launch/process coverage where applicable.

**Startup.** Handle the result already returned by `startup`, which checks status, liveness and the visible window for up to 60 seconds. On `WORKING` or `UNOBSERVABLE`, proceed to wait. On `INSPECT`, read the returned screen. If it shows work, proceed to wait. Handle any [dialog](#dialogs) before waiting. If it is still starting, pause five seconds between checks within the original 60-second budget. Dispatch an exact status line or a startup exit 3 immediately. Report command errors.

## Wait

**Quiet wait.** Every parent records progress for the final report. Until then, send only the caller's launch lines, the waiting notice, decisions needed from the user, declined or escalated dialogs, and stops or failures. Answer direct user questions.

### Rungs

For a window, choose the wait once. An interactive CLI uses a verified host notification first, otherwise tries `wake` once in its own pane. A native subagent, print session or interactive CLI without a proven watcher uses the foreground loop. See [rung selection and the final Wait line](references/window-wait.md#rungs).

### Free wait

Start one watcher over the active children, print the waiting notice and end the turn. On every wake, call `event <name> <status-file> [<name> <status-file>]...` with the retained pairs. Dispatch a valid child status first. See [Free wait](references/window-wait.md#free-wait) for commands, the notice and watcher events.

### Present loop

Use a foreground `wait` for 150 seconds on Claude Code or 240 seconds on Codex. Check the [host timeout and foreground wait rules](references/window-wait.md#present-loop) before opening the window.

### Exits and statuses

| Wait exit | Action |
|---|---|
| 0 | Use the exact current status (`event` already checked it on a wake). Read only the sections needed below. Completion requires a valid status. |
| 124 | If supported, `peek <name> 40` for a dialog. Otherwise continue file-based waiting. |
| 3 | Peek if supported, otherwise show recorded launch/exit diagnostics. [Recover once](#recover-a-silent-exit). |
| 4 | Apply the [stall rule](references/window-wait.md#free-wait). |
| Other | Report the error. Preserve the session and checkout. |

| First line | Action |
|---|---|
| `STATUS: done` | Read the requested result sections and perform the caller's completion checks. |
| `STATUS: blocked` | Read Questions. Get the user's answer or route it under `--auto`. Before sending, rename the report to an unused `<file>-blocked-<n>`. Send one line or an instruction to read a file. Without `send`, give the user the actual answer or file to enter in the visible window. Keep the child open and wait for a fresh report at the original path. |
| `STATUS: failed` | Report the failure and stop for the user's decision. Preserve the status, window and checkout. |

## Dialogs

When a screen asks for input, follow [Handling a window dialog](references/dialogs.md) before sending any key. Keep ambiguous requests unanswered. A new folder-trust decision always goes to the user. Without terminal controls the user handles dialogs directly.

## Recover a silent exit

Append this exact line to the original brief:

> Continue from the current state of the checkout: read git log and git status first.

Close proven owned processes if supported, report any retained window and confirm `alive` exits 1. Reopen with the same agent, options, name, checkout and amended brief. On a second silent exit, show diagnostics, preserve the window and checkout, and stop.

## Other operations and environment

`list` shows owned launches. `alive <name>` checks the recorded process. `send <name> <text>` sends one line and Enter. Put multiline content in a file. After completion checks, `close <name>` stops owned processes and closes the window when supported. Keep the checkout and branch.

For backend selection, runtime storage, terminal capabilities and native Windows invocation, see [Platform runtime](references/platform-runtime.md). PowerShell stalls and wakes through herdr only. For CLI overrides and the exact parent metadata removed from a child's environment, see [Launch command](references/run-contract.md#launch-command) and [Child environment](references/run-contract.md#child-environment).
