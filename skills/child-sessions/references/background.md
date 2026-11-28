# Background workers

## Background recording

Use the installed [Bash helper](../scripts/background) or native [PowerShell 7 helper](../scripts/background.ps1) with literal arguments. Start the PowerShell producer in its own process with `pwsh -NoProfile -File <absolute background.ps1>`. Windows PowerShell 5.1 does not support this background path.

Use rung 1 for a background child only when [Host mechanisms](run-contract.md#host-mechanisms) verifies notifications for the waiting host and session kind. Print the usual waiting notice with the host handle and end the turn. Background children have no rung 2. In the foreground, use the host wait when available (Claude `TaskOutput` with `block: true`, up to 60000 ms), otherwise the [completion check](#completion-marker-fallback). Report the applicable `Wait:` line. If neither a host execution/wait pair nor the shell/liveness fallback is usable, refuse before launch.

1. Write the prompt outside the checkout. Before scheduling a producer, run `prepare --run-dir <fresh absolute directory> --prompt <absolute prompt file>`. This copies the prompt, verifies process inspection and records the launch time. Use a fresh directory for every start or resume.
2. Launch `run --run-dir <directory> --checkout <absolute checkout> --agent <system[:command]> [--model M] [--effort E] [--resume ID] [--cli-arg WORD]...` once through the host. The helper supplies the [permission arguments](run-contract.md#permissions). Pass each extra Claude [lean launch](run-contract.md#launch-and-wait) word as one literal `--cli-arg`. Keep the run directory and host handle.
   On Claude, start the producer once with Bash `run_in_background: true` and retain the host task ID. On Codex use `exec_command` and continue the same yielded `session_id` with `write_stdin` at intervals of at most 60 seconds. A host task handle and a CLI conversation ID serve different purposes.
3. Run `wait --run-dir <directory> [--seconds N]` to verify publication before reading the child status. On success the helper prints `producer_exit:` and `session_id:` from the completed recording. Keep the wrapper result, actual CLI exit and child status distinct. A missing ID is a launch failure. Retain logs on error.

## Completion-marker fallback

On each rung 1 wake, including user input, run the background helper's `wait --run-dir <directory> --seconds 1`. On the foreground fallback use 60 seconds with a host timeout that allows the command to finish (Claude Bash `timeout: 75000` ms).

| Exit | Action |
|---|---|
| 0 | Record the printed producer exit and conversation ID, then dispatch status. |
| 124 | Still pending. On rung 1, answer any input, repeat the notice with the original handle and end the turn. In the foreground, wait again on the same directory. |
| 2 or 3 | Process or timestamp evidence is unavailable (2) or recording is incomplete (3). Preserve diagnostics and stop. |

If the host unexpectedly backgrounds the foreground wait, settle its retained handle and report the failure. Start no competing waiter or producer. When relying on the marker, report that the outer host exit notification was not independently awaited. The marker grants no process cleanup authority.
