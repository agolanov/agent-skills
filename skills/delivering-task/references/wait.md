# Wait for delivery

## Wait

The holder is the single root, the queue root for its units, or the phase agents' caller. Follow child-sessions' [Wait](../../child-sessions/SKILL.md#wait) for `<name>`, using the rung it proves or its present loop with the host-specific duration, explicit tool timeout and same-command polling. Write its report line's value into `Wait:` when choosing the rung and set `State: waiting`. For `subagent` or `background`, wait by run-contract Launch and wait.

The holder handles these events without Accept:

- **`blocked`:** show Questions/options/recommendation and obtain the user's answer (under `--auto`, routed by auto.md's Deciding; without send the user only types it in, as Brief says). Archive to `<file>-blocked-<n>`, put the answer in one line or an absolute answer-file instruction, then apply Events **Before every send** for a window and wait for fresh status. A dead child before that send goes to Events **Reopen** with the line to send. For `subagent` or `background`, continue the same child by run-contract [Questions and continuation](../../child-sessions/references/run-contract.md#questions-and-continuation), or its fresh-child fallback, then wait again.
- **`124` or `4`:** `peek <name> 40` where supported; wait again for work in progress or handle a dialog per child-sessions Dialogs; on `4` apply its stall rule and re-arm as required. A timeout supplies no question or approval. Keep the rung and one-watcher rule.

Everything else goes to Events. Other errors stop with artifacts preserved. Keep changed facts, Report carries, Decisions and one-time notices in the record.
