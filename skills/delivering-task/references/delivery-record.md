# Delivery record

Use child-sessions' [handoff record](../../child-sessions/references/handoff-record.md) for its format, life and authority.

## Facts

```text
Invocation: <UTC ISO 8601 to the second when this record was created> <new|resume>
Main checkout: <absolute path>
Main branch: <name>
Layout: <tracked|separate docs|ignored>
Merge: <merge|no-merge>
Queue: <None|absolute state file>
Project rules: <absolute paths, comma-separated|None>
Pending return: <none|verify mismatch|follow-ups correction|main moved to <full SHA>|merge candidate <full SHA>>
```

The record's `Run:` is the brief's `Branch:` exactly (under `--checkout main`, the derived name: [Checkout mode](checkout-modes.md#checkout-mode) 2), `Checkout:` the task worktree. Keep root Git boundary outputs in a fresh directory outside Git: `Root evidence:` names that directory, where Accept adds its own outputs. `Reopen:` holds the one reopen shared by silent exit and dead-before-send, or the run contract's one non-window restart. Returns are not limited to one: `Return to worker:` holds the latest archived status path and `Pending return:` its reason. Keep Report carries (announced non-window place, Worktree 2's nonzero count lines, open fallback, missing send, dialog counts or `dialogs not observable`, reopen and reason), Decisions and Told the user current as facts change.
