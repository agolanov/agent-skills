# Window Reviewers

A window reviewer is an interactive Codex or Claude session in a visible window, opened through `child-sessions`, so the user can watch the review. Its brief is a short **driver brief**: the session runs the system's native review and saves the report. [CLI reviewers](cli-reviewers.md)' permission rules and independent-review **Validate** apply. The brief, answer and status file lie in the attempt directory, outside every checked tree.

## Prepare

1. **child-sessions.** Read the installed `child-sessions` SKILL.md with `platform-runtime.md`, `brief-writing.md` and `status-file.md`, and resolve its entrypoint. The backend must support owned `list`, `close` and `alive` besides launch and wait, else the place blocks before launch; retain each launch's `capabilities`. Process ownership and descendant limits follow [owned lifecycle](../../child-sessions/references/platform-runtime.md#owned-lifecycle).
2. **Run token.** `run_dir` is the absolute directory owning this run's attempts (`<dual dir>`, the caller's round directory, or a fresh direct-use directory). Allocate a random token once per run and persist it; continuation, reopen, retry and cross-check reuse it, and a missing or malformed saved token blocks:

   ```bash
   token_dir=$(mktemp -d "$run_dir/window-token.XXXXXXXX") || exit 2
   run_token=$(printf '%s' "${token_dir##*/}" | tr -cd 'A-Za-z0-9_-')
   [ -n "$run_token" ] || exit 2
   printf '%s\n' "$run_token" > "$run_dir/window-run-token"
   ```

   PowerShell uses `[Guid]::NewGuid().ToString('N')` and literal-path file APIs. Name each window `review-<codex|claude>-<token>-<phase>-<attempt basename>` (`[A-Za-z0-9_-]`, phase `review` in direct use). A name the owner's listing already holds allows a new token only before any window of the run started; otherwise it blocks. Reopen uses the saved name. Record names and each opening's `launch_id`.
3. **Brief.** Write `<attempt dir>/brief.md`: the driver brief of the reviewer's system, then the lines below with absolute paths. The attempt directory takes the place of child-sessions' `runtime-dir`. `context.md` is written as for any attempt.

   - **Claude:** "Run the built-in `/code-review` command once, in this checkout, with exactly these arguments: `<level> --max-findings all <target> <wrapper lines 2 to the end>`. It runs as a background agent: wait for its completion notification, then write the report it returns, complete and unchanged, to the answer file. Write no answer and no `STATUS: done` before that notification; if the command does not start (unknown, disabled or refused), write `STATUS: failed` with what it showed. Add no findings of your own and review nothing yourself." Level and target follow the [wrapper](review-wrapper.md#carrying-the-wrapper).
   - **Codex:** the controller writes the wrapper to `<attempt dir>/prompt.md`. "Run this one command in this checkout and wait for it: `<reviewer-process> codex --command <command> --checkout <tree> --prompt <attempt dir>/prompt.md --dir <attempt dir> --model <M> --effort <E> --native yes [--keep-feature F]...`, with the resolved keep-feature list ([CLI reviewers](cli-reviewers.md)). Add no findings of your own and review nothing yourself." `<reviewer-process>` is the installed [helper](cli-reviewers.md#launch), so the nested `codex review -` gets the lean Codex switches and writes `stderr.log`, `session-id`, `producer.exit` and `answer.md` into the attempt directory. Every path is one single-quoted shell word (`'` written `'\''`). A native PowerShell window names the [`Invoke-ReviewerLaunch`](cli-reviewers.md#native-powershell-io) call with the same values. The model cannot call the TUI's own `/review`, so the review runs nested and the window shows the driver.
   - **Cross-check window:** the brief is the filled [cross-check prompt](cross-check-prompt.md); the lines below follow it.

   ```text
   Answer file: <attempt dir>/answer.md
   Status file: <attempt dir>/status.md
   Status contract: <absolute path of the installed child-sessions references/status-file.md>
   Terminal controls: the root reads this window's controls after it opens and may be unable to see or answer it; a question or dialog here can wait for the user.
   Authority: review the recorded target without writing or committing in any monitored checkout. Write the answer, status and your own scratch/diagnostics in this attempt directory. Normal tool-owned external state (such as plugin-managed state and CLI runtime records) remains under the existing permissions; this grants no new authority to change configuration, permissions or folder trust.
   Read the status contract and use its reviewer interpretation: `STATUS: done` means the review tool finished, whatever it found; for a native review `## Review` names the saved report and says the verdict is derived by the caller, and you write no verdict (a cross-check keeps its caller-defined outcome); `## Commits` is `None`, `## Checks` lists what actually ran, and `## Artifacts` names the absolute answer file. For blocked/failed progress use the actual reason, with no invented final verdict. The controller owns dialog counts; do not invent them in the child report.
   Auto: <yes|no>. With yes, ask the user nothing; a question you cannot settle goes into the status as STATUS: blocked with the question, the options and your recommendation.
   ```

### Before every open

Before every opening, retries included, read the owner's validated `review-*` listing. Resolve each listed session's checkout (`git rev-parse --show-toplevel`, canonical paths) and its local clone source (a retained mapping, else a local absolute `origin`) and compare both with every monitored tree of the new review. A matching reviewer that is not a registered peer of this dual phase must have `alive` exit exactly 1 before launch; another exit, an unreadable checkout or a failed lookup blocks while it may be alive. An unrelated repository does not block; unrelated sessions are preserved. Continuation needs the saved run and attempt identities, phase baseline, ownership and clone mappings; a fresh invocation without them claims no continuation. Apply [phase recovery](checkout-state.md#phase-recovery-and-resume) before reopening an interrupted phase. This is a trusted-local guard, not a lock.

## Open

4. Open in the reviewed tree (the clone in clone mode) with `--agent <system>` (`<system>:<command>` with an assignment [command](../SKILL.md#assignment)) and `--model`/`--effort` from the resolved settings, omitting a `cli-default` field; a Claude window's effort equals the `/code-review` level. A Claude window adds the lean words `--cli-arg --strict-mcp-config --cli-arg --no-chrome --cli-arg --session-id --cli-arg <uuid>`, a fresh UUID on each opening, appended to `<attempt dir>/session-ids`; it keeps its plugins. Every `open` of the attempt, the reopen included, runs with `CHILD_SESSION_CLAUDE_ARGS=''` or `CHILD_SESSION_CODEX_ARGS=''`, so the reviewer keeps its normal permissions instead of child-sessions' writing defaults; the variable carries only already authorized sandbox or approval options, or with explicit unrestricted authority `--permission-mode bypassPermissions` / `--dangerously-bypass-approvals-and-sandbox`. An `open` error is a launch failure.

   ```bash
   # Claude; a Codex window drops the --cli-arg words and uses CHILD_SESSION_CODEX_ARGS=''.
   settings=()
   [ "$review_model" = cli-default ] || settings+=(--model "$review_model")
   [ "$review_effort" = cli-default ] || settings+=(--effort "$review_effort")
   uuid=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid) || exit 2
   printf '%s\n' "$uuid" >> "$attempt_dir/session-ids"
   CHILD_SESSION_CLAUDE_ARGS='' "$child_session" open --agent "$reviewer_agent" "${settings[@]}" \
     --cli-arg --strict-mcp-config --cli-arg --no-chrome --cli-arg --session-id --cli-arg "$uuid" \
     "$name" "$reviewed_tree" "$attempt_dir/brief.md"
   "$child_session" capabilities "$name"
   ```

   On native PowerShell save the variable's existence and value, set it to one space for the call (Windows PowerShell 5.1 deletes a variable assigned an empty string, and the helper reads whitespace as no arguments), and restore it in `finally`.

## Wait

5. Wait by child-sessions' [Wait](../../child-sessions/SKILL.md#wait), its Startup watch and single reopen after a silent exit included (step 4's `open`, a new UUID). A native Codex review window is never reopened: its nested review may outlive the driver, so a silent exit is that attempt's unsuccessful completion, gated by step 7, and a retry is a new attempt directory. When the dual review opens two windows, one watcher covers both in opening order and ends at the first event; a `done` or unsuccessful reviewer leaves the set, a `blocked` one rejoins after its answer; the wait ends when both have a terminal outcome.
6. Dialogs follow child-sessions [Dialogs](../../child-sessions/SKILL.md#dialogs), new folder trust included as its own user decision, also under `--auto`; the controller keeps the [dialog record](#dialogs). The nested `codex review` may raise approval dialogs: a limitation, not an invalid attempt. A `STATUS: blocked` goes to the caller as a question (direct use: the user; under `--auto` by [auto.md](../../child-sessions/references/auto.md#deciding)). `STATUS: failed`, or a second silent exit (the first for a native Codex window), is an unsuccessful completion; a dual peer still working keeps its wait.

## Stop, confirm, capture, validate

Status makes an answer ready; it does not prove the reviewer stopped. Order: terminal outcome → preserve reports and counters → owned close → every participant's `alive` exit 1 → final Git capture and compare in every monitored tree → validation → `result.md`.

7. **Barrier.** Close each owned reviewer and record the `close` exit. Then a fresh `alive` per participant: 0 live, 1 stopped, anything else unavailable. Only validated ownership plus exit 1 for every participant confirms shutdown; a close error after confirmed stop is a diagnostic. A native Codex window's nested review counts as stopped only with its `producer.exit`, or with evidence bound to this launch that it never started (a helper usage or setup error, exit 2, before launch). This **nested-producer gate** applies here and on every continuation. In a shared phase both participants pass before the shared capture; a retry alone has its own boundary. A retained shell or window with the reviewer gone is reported separately.
8. **Validate** by independent-review **Validate**, with this evidence:
   - **Completion:** `STATUS: done`, a non-empty answer and the barrier; never an invented producer exit. A cross-check window has no nested process and no `/code-review` call: its producer evidence is its own session.
   - **The native tool ran** (native attempts; a cross-check window's report is judged by its caller's report checks). Claude: the window session's transcript (bound by its `--session-id`) holds the `code-review` skill call with the brief's arguments, and the answer holds the final report of the agent record that call starts, written after its last message; else `invalid: answer is not the native report`. Codex: `producer.exit` 0, the delegate bound through `stderr.log`'s session ID exists, and the answer's findings are exactly its final review output; else the same reason. A driver that reviewed itself or used other arguments is `invalid: native tool not run`. Context and target reads come from the reviewing process: Claude's command agent records, Codex's nested `stderr.log` and delegate.
   - **Settings:** the [child settings check](launch-settings.md#child-settings-check) for the reviewer: Claude by each opening's session ID, main transcript and every command agent record; Codex by the nested delegate, the driver's own settings recorded beside it; a Codex cross-check window by its own session records. A nested review that never started has no nested records.
   - **State:** the saved before and the final after, with exits and limits.
9. **Unconfirmed shutdown.** Keep the attempt, ownership, baseline and diagnostics pending and return `blocked: reviewer shutdown unconfirmed` (`review-fix-loop` reports it as its unmet-completion `blocked: <reason>`); `result.md` says `invalid: reviewer shutdown unconfirmed`, or `checkout changed; otherwise invalid: reviewer shutdown unconfirmed` when a diagnostic capture proves a difference. No adjudication or overlapping attempt runs while a participant may live. Continuation runs [Phase recovery and resume](checkout-state.md#phase-recovery-and-resume): every participant's `alive` 1 and the nested-producer gate first, then a fresh Git comparison with the saved before; unchanged keeps the invalid outcome, charged once under the caller's budget.

## Dialogs

The controller counts each actual window dialog response once: `answered` includes approvals and declines, `declined` is its subset, `escalated` counts dialogs forwarded for a decision. Navigation keys and stale peeks do not count; reopening keeps the attempt's counts; the child never supplies them. Carry each attempt's record, invalid attempts and cross-checks included, through direct output and dual reports, deduplicated by attempt identity on resume; a total of observable counters names the nonobservable attempts beside it.
