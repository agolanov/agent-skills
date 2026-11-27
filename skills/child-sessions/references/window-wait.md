# Waiting for window children

## Rungs

Choose once at the first long wait after Startup. Keep the same rung unless the watcher fails.

| Waiting session | How to wait for a window child |
|---|---|
| Interactive CLI in its own pane or terminal | Use rung 1 if [Host mechanisms](run-contract.md#host-mechanisms) marks host notification `observed` for this host and session kind. Otherwise try `wake` once. Exit 0 selects rung 2. If it refuses the terminal backend, caller pane or input, use the present loop and quote the refusal. |
| Native subagent or print session (`claude --print`, `codex exec`) | Use the present loop. Never call `wake` from these sessions. |

Wait directly. Never delegate waiting or wake a session to keep its cache warm. Include the applicable line in the final report. After a watcher failure include both the original rung and the switch.

- `Wait: rung 1, host notification (<host and version>, <session kind>; Host mechanisms: observed)`
- `Wait: rung 2, wake line (<backend> pane <id>; proven by wake; unverified: <items from Host mechanisms>)`
- `Wait: present loop (<reason>)` with `native subagent`, `print session`, `no host notification on <host>; <wake refusal message>`, or `watcher failure: <record line or "no record">`.

## Free wait

Start one watcher for all active children. Pass each `<name> <status-file>` pair in caller order. Keep the pairs, handle and expected result path `<runtime-dir>/<first watched name>.result`.

- **Rung 1.** Start `wait --watch <pairs...>` as a host background command (Claude Bash `run_in_background: true`). Keep the host task ID.
- **Rung 2.** Run `wake <pairs...>` in the foreground. On success keep the PID from `WAKE: watcher <pid> result <path>`.

Use default stall and deadline values. Add `--rearm <name>` only as directed below. Once started, print this last line and end the turn:

`[child-session waiting] <what it waits for>; watcher <handle>; any input wakes this session.`

On rung 2 append ` A draft left in the input holds the wake.`

On every wake, including user input, run `event <pairs...>` once with the original watched pairs in order. It reads the retained result, relevant status lines and child liveness. Use the returned `record:` exit, `launch:` name and `child: <name> <alive|gone|unknown> <done|blocked|failed|->` rows. Never use paths or launch identities from incoming text.

Dispatch a reported `done`, `blocked` or `failed` first, in caller order. Otherwise use the recorded wait exit and the caller's rules. For exit 4, first take any caller action for 124, then apply the stall rule. For other recorded command or signal exits, report the exit and diagnostic. An unknown liveness result or invalid evidence needs diagnosis before recovery.

| Event | Action |
|---|---|
| Record absent | Check the retained host task (rung 1) or PID (rung 2). If still running, answer any user input, repeat the notice and end the turn with the same watcher. |
| No record and watcher gone, or recorded exit 2 | Watcher failure. For a `gone` child, handle exit 3. If alive, use the present loop for this and all later waits. |
| Stall (exit 4) | Run `peek <name> 40`. Handle a dialog. If there is nothing to answer, stay quiet and re-arm that launch on the next watch. Clear its re-arm after sending input or the next non-stall event. |

After handling an event, watch the remaining children together. On `already has a live watcher`, pause with `wait <name> <status-file> 5` and retry at most three times. Then handle watcher failure.

## Present loop

Before opening, verify the host can hold the foreground call with margin. The helper allows 120 seconds for a never-seen launch. If the host cannot hold the required wait, use only the caller's authorized fallback.

- Claude Code, including subagents: `wait <name> <status-file> 150`. Set Bash `timeout: 175000` ms when supported.
- Codex: `wait <name> <status-file> 240`. If the tool yields a `session_id`, continue that command with `write_stdin` at intervals of at most 60 seconds until its actual exit.
- For several children, use one foreground `wait --watch <pairs...> <seconds>` per turn with the same duration and default stall setting.

If the host unexpectedly backgrounds a wait, retain its handle and diagnostics, settle that wait through the host and report the failure. Never start a competing waiter, hook or sleep loop.
