# Window Reviewers

A window reviewer is an interactive Codex or Claude session in a visible window, opened through `child-sessions`, so the user can watch the review. It reviews as the other places do: the filled [review prompt](review-prompt.md), the permission rules of [CLI reviewers](cli-reviewers.md), and independent-review **Validate**. Its brief, answer and status file lie in the attempt directory, outside every checked tree.

## Prepare

1. Locate the installed `child-sessions` SKILL.md and read it with its references `platform-runtime.md`, `brief-writing.md` and `status-file.md`; resolve and retain its entrypoint as they say. Before opening, establish that the selected backend supports owned `list`, `close` and `alive` as well as launch/wait. Missing or unavailable lifecycle capabilities block before launch, keeping the place and settings. Retain the actual per-launch capabilities too. Use the existing [process ownership and descendant limits](../../child-sessions/references/platform-runtime.md#owned-lifecycle) throughout.
2. Bind `run_dir` to the absolute external directory owning this run's attempts: `<dual dir>`, the caller's run/round directory, or a fresh direct-use run directory. Allocate a random token once for a new run, independent of its directory basename, and retain the allocation directory as evidence:

   ```bash
   token_dir=$(mktemp -d "$run_dir/window-token.XXXXXXXX") || exit 2
   token_base=${token_dir##*/}
   run_token=$(printf '%s' "$token_base" | tr -cd 'A-Za-z0-9_-')
   [ -n "$run_token" ] || exit 2
   printf '%s\n' "$run_token" > "$run_dir/window-run-token"
   ```

   Native PowerShell uses `[Guid]::NewGuid().ToString('N')` and literal-path native file APIs to persist it. Continuation loads the saved token and validates a nonempty value containing only `[A-Za-z0-9_-]`; missing/malformed identity blocks until reconciled. Reopen, retry, cross-check and resume keep that token.

   Name each window `review-<codex|claude>-<token>-<phase>-<attempt basename>`, sanitizing the phase and attempt basename to `[A-Za-z0-9_-]`, each nonempty. Direct use has phase `review`; for example, `review-codex-<token>-review-attempt-1` and `review-codex-<token>-cross-check-attempt-1` are distinct. Before initial opening check every proposed name against the owner's validated listing. A collision permits a new token only before any window in the run starts; otherwise it blocks. Reopen the same owned attempt with its saved name. A continuation collision never authorizes reallocation or closing another run's session. Record allocation evidence, names and each opening's `launch_id`.
3. Write the brief to `<attempt dir>/brief.md`: the filled review prompt, its `Auto:` line included, followed by these lines with absolute paths. The attempt directory takes the place of child-sessions' `runtime-dir` for the brief and the status file.

   ```text
   Answer file: <attempt dir>/answer.md
   Status file: <attempt dir>/status.md
   Status contract: <absolute path of the installed child-sessions references/status-file.md>
   Terminal controls: the root reads this window's controls after it opens and may be unable to see or answer it; a question or dialog here can wait for the user.
   Authority: review the recorded target without writing or committing in any monitored checkout. Write the answer, status and your own scratch/diagnostics in this attempt directory. Normal tool-owned external state (such as plugin-managed state and CLI runtime records) remains under the review prompt's existing authority; this grants no new authority to change configuration, permissions or folder trust.
   Write your whole report, in the form the review prompt requires, to the answer file. Read the status contract and use its reviewer interpretation: `STATUS: done` means review finished, including a raw `VERDICT: CHANGES`; `## Review` keeps the answer's raw verdict (or the caller-defined cross-check outcome), `## Commits` is `None`, `## Checks` separates actual from inherited evidence, and `## Artifacts` names the absolute answer file. For blocked/failed progress use the actual reason, with no invented final verdict. The controller owns dialog counts; do not invent them in the child report.
   ```

### Before every open

Read the resolved owner's validated `review-*` listing before every opening, fresh calls and retries included. Keep its output, actual exit, ownership/launch records and canonical path comparisons. Compare each listed canonical checkout and any established disposable-clone source with **every monitored tree of the new review**, including its sole reviewed checkout when the new run has no clone.

Resolve a listed root with ordinary Git `rev-parse --show-toplevel` and canonicalize paths with installed native facilities. Prefer retained clone/source mappings. Otherwise a successful `git remote` listing establishes origin presence before `git remote get-url origin`: documented absence means an ordinary checkout compared by its own canonical path; a nonlocal origin supplies no local source. Without a retained mapping, a local absolute origin establishes the listed checkout's source identity; resolve/canonicalize it and compare it with every monitored tree too. This conservatively includes ordinary local clones of a monitored tree. Retain command exits and distinguish absence from failure.

Only deliberately registered peers of this current dual phase are exempt. Every matching reviewer requires `alive` exit exactly 1 before launch; another exit blocks with its name/evidence. An unreadable/missing checkout, lookup failure or unresolved recorded clone mapping also blocks while that reviewer may be alive. An identified unrelated ordinary repository, including one without origin, does not block. Preserve unrelated sessions.

Continuation requires the saved run/attempt identities, phase baseline, ownership/liveness and clone/source mapping, handed to a new controller if necessary. A fresh invocation without them cannot claim implicit continuation or replacement. Apply [pending-window recovery](checkout-state.md#phase-recovery-and-resume) before reopening/retrying an interrupted phase. This is a trusted-local discovery guard, with no global lock/registry or guarantee of discovering detached processes.

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

   On native PowerShell, first save whether the variable exists and its value, set it to one space for the dispatch call, and restore it in a `finally` block: put the saved value back, and remove the variable only when it did not exist before. Windows PowerShell 5.1 deletes a variable assigned an empty string (pwsh 7.6.9 keeps it), which would bring back the writing defaults, and the helper reads a whitespace-only value as no arguments; removing a value the caller had set would give its later workers in the same process the writing defaults instead of its own arguments.

## Wait

6. Wait with child-sessions' foreground wait loop, its Startup watch included; its single reopen after a silent exit is this step 5's `open`, override and `Opened:` line included. When a caller opens two windows at once (the dual review), wait on them in turn, one bounded `wait` per window per turn, until both have a status.
7. Dialogs follow child-sessions [Dialogs](../../child-sessions/SKILL.md#dialogs), including its separate user decision for new folder trust, also under `--auto`. The controller maintains independent-review's [dialog record](../SKILL.md#dialogs) across reopening. Record the pending or answered trust decision, exact folder and known persistent effect under launch coverage/limitations. For that rule the attempt directory is the reviewer's recorded runtime directory, where it writes its answer, status and scratch; a write inside the reviewed tree (in clone mode, also inside the user's checkout) is outside the reviewer's authority.
8. A `STATUS: blocked` goes to the caller as a question (in direct use, the user; under `--auto` the caller routes it by [auto.md](../../child-sessions/references/auto.md#deciding)); its answer returns through child-sessions' `blocked` row. A `STATUS: failed`, or a second silent exit, ends the wait as an unsuccessful completion.

## Stop, confirm, capture, validate

Status publication makes an answer ready; it does not prove the reviewer stopped. The required order is terminal status/unsuccessful completion → preserve reports and counters → owned close → every participant's `alive` exit 1 → final Git capture/compare in every monitored tree → final settings/report validation → `result.md`.

9. On `done`, `failed` or terminal unsuccessful completion, preserve answer/status, diagnostics and controller dialog counts. Close each proven owned reviewer through the resolved entrypoint and record actual `close` exits/diagnostics. Confirm retained validated ownership and record each fresh `alive` exit: 0 is still live, 1 is stopped, other exits or missing evidence are unavailable. Only validated ownership plus fresh `alive` exit 1 for every participant confirms shutdown. Missing ownership, unavailable/error liveness or any other `alive` exit blocks completion; a close error after confirmed process stop remains a terminal-cleanup diagnostic and does not by itself block. Under a shared phase close and check **both** participants before a shared final capture; a retry running alone has its own boundary. Report a retained shell/window separately: it does not fail completion when the recorded reviewer is gone.
10. Only after every participant's owned stopped state is confirmed capture independent-review **Launch**'s final four-command after evidence in every monitored tree and compare it to the saved before. Then apply independent-review **Validate**:
    - **Completion:** `STATUS: done`, a nonempty answer and the stopped-process barrier; otherwise unsuccessful. `Completion:` records the actual status, close/alive exits, ownership evidence and any retained window. Never invent an interactive producer exit.
    - **Settings:** run the [child settings check](launch-settings.md#child-settings-check) here over final records for every opening, with these outcomes replacing its user question: mismatch is invalid; missing/ambiguous/fieldless evidence is `invalid: settings unverified: <reason>`. Name record paths in `Settings evidence:`.
    - **State:** saved before and final stopped-process after evidence, with actual exits/comparisons and limits.
11. If shutdown is unconfirmed, keep the attempt, ownership/liveness, phase baseline, other completion/settings/coverage conditions and diagnostics pending. Return `blocked: reviewer shutdown unconfirmed` to every caller; `review-fix-loop` uses its existing unmet-completion `blocked: <reason>`. Write `invalid: reviewer shutdown unconfirmed` in `result.md`, or `checkout changed; otherwise invalid: reviewer shutdown unconfirmed` if diagnostic Git evidence proves a simultaneous difference. A live diagnostic capture is never a final unchanged boundary. No write adjudication or overlapping attempt proceeds while any participant may be alive, including when a difference is proven.

Continue that saved attempt through [Phase recovery and resume](checkout-state.md#phase-recovery-and-resume): first every participant's fresh `alive` exit 1, then fresh Git comparison against the saved before, before write adjudication or normal retry rules. Preserve prior diagnostics and any proven difference. If unchanged, retain the invalid-completion outcome and charge it once under the existing caller budget, preserving any already-recorded spend. A continuation never double-charges or resets/extends budgets. Non-window Git recovery is unchanged.
