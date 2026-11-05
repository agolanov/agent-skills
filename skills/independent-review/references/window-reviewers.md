# Window Reviewers

A window reviewer is an interactive Codex or Claude session in a visible window, opened through `child-sessions`, so the user can watch the review. It reviews as the other places do: the filled [review prompt](review-prompt.md), the permission rules of [CLI reviewers](cli-reviewers.md), and independent-review **Validate**. Its brief, answer and status file lie in the attempt directory, outside every checked tree.

## Prepare

1. Locate the installed `child-sessions` SKILL.md and read it with its references `platform-runtime.md`, `brief-writing.md` and `status-file.md`; resolve and retain its entrypoint as they say. An unavailable `child-sessions` or window backend is a capability blocker: report it, keeping the place and settings.
2. Name the window `review-<codex|claude>-<run token>-<attempt dir basename>`, with the reviewer's system. The run token is the basename of the directory that holds this run's attempt directories: the `<dual dir>` under `--dual`, the caller's round directory for a loop caller, otherwise the direct-use run directory, one fresh directory (for example from `mktemp -d`) that holds the direct-use attempt directories. Remove from both basenames every character outside `[A-Za-z0-9_-]`, child-sessions' name pattern.
3. Write the brief to `<attempt dir>/brief.md`: the filled review prompt, its `Auto:` line included, followed by these lines with absolute paths. The attempt directory takes the place of child-sessions' `runtime-dir` for the brief and the status file.

   ```text
   Answer file: <attempt dir>/answer.md
   Status file: <attempt dir>/status.md
   Status contract: <absolute path of the installed child-sessions references/status-file.md>
   Terminal controls: the root reads this window's controls after it opens and may be unable to see or answer it; a question or dialog here can wait for the user.
   Write your whole report, in the form the review prompt requires, to the answer file. Then read the status contract and write the status file by it: `STATUS: done`, with `## Artifacts` naming the answer file.
   ```

## Open

4. Immediately before every `open` of this attempt, append the `Opened:` line of the [child settings check](launch-settings.md#child-settings-check) to the brief.
5. Open the window in the reviewed tree (the clone in clone mode) with `--agent <reviewer system>` and `--model`/`--effort` from the resolved settings, omitting a `cli-default` field. Give every `open` of this attempt, child-sessions' reopen after a silent exit included, and only those calls, the process-local environment `CHILD_SESSION_CLAUDE_ARGS=''` (Claude) or `CHILD_SESSION_CODEX_ARGS=''` (Codex): the reviewer keeps the normal permissions [CLI reviewers](cli-reviewers.md) require instead of child-sessions' writing defaults. The variable carries only what that guide permits: already authorized sandbox/approval options, and, with explicit unrestricted-execution authority, `--permission-mode bypassPermissions` (Claude) or `--dangerously-bypass-approvals-and-sandbox` (Codex). An `open` error is a launch failure, as for a CLI reviewer.

   ```bash
   settings=()
   [ "$review_model" = cli-default ] || settings+=(--model "$review_model")
   [ "$review_effort" = cli-default ] || settings+=(--effort "$review_effort")
   printf 'Opened: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$attempt_dir/brief.md"
   CHILD_SESSION_CODEX_ARGS='' "$child_session" open --agent codex "${settings[@]}" \
     "$name" "$reviewed_tree" "$attempt_dir/brief.md"
   "$child_session" capabilities "$name"
   ```

   On native PowerShell, set the variable to one space for the dispatch call and remove it afterwards: Windows PowerShell 5.1 deletes a variable assigned an empty string (pwsh 7.6.9 keeps it), which would bring back the writing defaults, and the helper reads a whitespace-only value as no arguments.

## Wait

6. Wait with child-sessions' foreground wait loop, its Startup watch included; its single reopen after a silent exit is this step 5's `open`, override and `Opened:` line included. When a caller opens two windows at once (the dual review), wait on them in turn, one bounded `wait` per window per turn, until both have a status.
7. Dialogs follow child-sessions **Dialogs**. For that rule the attempt directory is the reviewer's recorded runtime directory, where it writes its answer, status and scratch; a write inside the reviewed tree (in clone mode, also inside the user's checkout) is outside the reviewer's authority.
8. A `STATUS: blocked` goes to the caller as a question (in direct use, the user; under `--auto` the caller routes it by [auto.md](../../child-sessions/references/auto.md#deciding)); its answer returns through child-sessions' `blocked` row. A `STATUS: failed`, or a second silent exit, ends the wait as an unsuccessful completion.

## Validate and close

9. Capture the after Git evidence of independent-review **Launch** once the status is written (under a shared phase, once both windows have theirs). Then apply independent-review **Validate** with these window facts:
   - **Completion:** `STATUS: done` with a non-empty answer file; anything else is unsuccessful. `Completion:` records the status line, `Answer:` the answer file.
   - **Settings:** the child settings check over the record of each opening of this attempt, run once here, with these outcomes in place of its question to the user: a mismatch is invalid; a record missing, ambiguous or without the fields is `invalid: settings unverified: <reason>`. `Settings evidence:` names the record paths.
   - **State:** the Git evidence captured before `open` and after the status.
10. After Validate, `close "$name"` and confirm `alive` exits 1; report a window the backend retains.
