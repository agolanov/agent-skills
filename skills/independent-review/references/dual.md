# Dual Review

Codex and Claude review one recorded commit target in parallel, in separate CLI processes in the assigned place, whatever system runs the dual review. A finding only one of them raised goes to the other for a cross-check, and the confirmed findings come back as one severity-ranked report with a derived verdict. The dual review changes nothing in the checkout, commits nothing, and returns one of:

- `<dual dir>/report.md`;
- `checkout changed: <state.md>`;
- `blocked: <codex|claude|codex and claude> invalid result` (budget exhausted);
- `blocked: <codex|claude|codex and claude> reviewer shutdown unconfirmed` with `<state.md>` (completion recovery pending).

A caller (`review-fix-loop` with the `dual` assignment) supplies the absolute checkout, branch, fixed base, reviewed commit, review kind with target form and target, requirements and checks, both reviewers' settings, its round directory as `<dual dir>`, its resolved checks with run/acceptance evidence and pending coverage, and the ledger of step 4. Direct use resolves them in step 1.

## Dependency

Read [checkout state](checkout-state.md), and [independent-review](../SKILL.md) if not yet read. Every review or cross-check attempt is one independent-review attempt under its **Assignment**, **Review wrapper**, **Launch**, **Validate** and **Result**; its **Direct use** applies only where this guide points to it.

## 1. Settings and target

`independent-review --dual [--run background|window] [--codex=<command>] [--claude=<command>] [--codex-model M] [--codex-effort E] [--claude-model M] [--claude-effort E] [--effort E] [--auto] [<range|commit>]`

The assignments are `<place>/codex` and `<place>/claude`, each with its [command](../SKILL.md#assignment) when given, one place for both (`background` by default, or `window`). `--effort` sets both efforts unless a per-reviewer key sets one; a `--model` without a reviewer prefix asks which reviewer it is for. Everything else follows [launch settings](launch-settings.md) for the reviewer role per reviewer; cross-checks keep each reviewer's recorded settings. Announce and record both assignments.

Direct use takes target, preflight and requirements from independent-review **Direct use**, running its preflight before the suite and any launch; it reviews with the final-pass kind, prior findings `None`, numbering from `D1`.

`<dual dir>` lies outside the checkout: the caller's round directory, else a fresh temporary directory. It holds `state.md`, one attempt directory per attempt at `review/<codex|claude>/attempt-<n>/` and `cross-check/<codex|claude>/attempt-<n>/`, and `report.md`. When **Direct use** calls for a clone, make one at `<dual dir>/tree` for both reviewers and every phase on that commit; every state check covers it and the user's checkout. Write `state.md` per [dual record](dual-record.md) now and update it after every attempt and phase.

Resolve the checks by the [suite contract](checkout-state.md#resolve-checks-and-bind-suite-evidence), accepting the caller's resolved set. The commands, their results and the remaining obligations reach the reviewers as data in the context files and cross-check prompts.

## 2. Complete suite

This session runs required complete suites in the reviewed tree, one at a time, before any reviewer: it accepts applicable retained coverage or runs the missing checks under the [suite contract](checkout-state.md#resolve-checks-and-bind-suite-evidence), keeping original runs and current-target acceptances. When a requirement names the reviewer as the one who runs a check, that phase runs the two reviewers one after the other, without the dual line and with the reviewer-run line, so no two complete suites run at once. Scoped loop rounds may carry passing affected checks with broader coverage pending; the final review needs complete applicable coverage or the missing runs.

Every suite phase has before/after Git evidence (both trees in clone mode). A suite write is preserved and returned as `checkout changed: <state.md>` before any reviewer launches. A capture failure blocks before reviewers and spends no attempt. A failed suite goes to direct-use reviewers as it is and makes Verification incomplete; a loop caller keeps its stricter gate.

## 3. Review phase

Both reviewers get the [wrapper](review-wrapper.md#the-wrapper) of the review kind with the dual line, and context files with the same content; round 1, the final pass and direct use keep the security line. Native reports carry no IDs: this session assigns each reviewer's source IDs in report order in its `findings.md` (`codex F1`, `claude F1`).

The phase runs both reviewers in parallel inside one shared Git boundary of every monitored tree; under a reviewer-run obligation they run one after the other, each on its own boundary, and a write found after the first stops the phase before the second starts:

- **`--run window`:** each call is one [window reviewer](window-reviewers.md); register both as current-phase peers, open both before either wait, and stop and confirm **both** before the shared after capture.
- **`--run background`:** two background jobs in one host background command, each one [CLI launch](cli-reviewers.md#launch) with `--native yes` and its own attempt directory, then wait for both:

  ```bash
  # The shared before boundary succeeded; a failed one launches no job.
  # keep_features: the resolved --keep-feature words for Codex (CLI reviewers), usually none.
  "$reviewer_process" codex --command "$codex_command" --checkout "$tree" --prompt "$codex_dir/prompt.md" \
    --dir "$codex_dir" --model "$codex_model" --effort "$codex_effort" --native yes "${keep_features[@]}" & codex_pid=$!
  "$reviewer_process" claude --command "$claude_command" --checkout "$tree" --prompt "$claude_dir/prompt.md" \
    --dir "$claude_dir" --model "$claude_model" --effort "$claude_effort" --native yes & claude_pid=$!
  wait "$codex_pid"; wait "$claude_pid"
  # Then the shared after boundary and comparison.
  ```

  On native PowerShell run two `Start-Job` calls, each dot-sourcing the helper and calling [`Invoke-ReviewerLaunch`](cli-reviewers.md#native-powershell-io) with literal arguments (Codex with its `-KeepFeature` list); `Receive-Job` returns each result. Where job control is unavailable, use two host background commands and wait for both. The producer exit is each directory's `producer.exit`, never a job's exit.

A failed before capture launches nothing; a failed shared after capture records both attempts' other conditions before spending each reviewer's budget. Validate each answer by **Validate**, then write each valid answer's `findings.md` and derived verdict. An unconfirmed window shutdown first returns the system-qualified shutdown block, even beside a diagnostic `checkout changed`, until [pending-window recovery](checkout-state.md#phase-recovery-and-resume) passes. After that, any `checkout changed` stops per **State and resume**. An invalid result is handled per **Budget**: a retry of one reviewer runs alone on its own boundary; reruns of both form a parallel phase. The phase is done when both hold a valid result for the reviewed commit.

## 4. Matching

Match only in-scope findings; outside-round and outside-task candidates go to `Candidates`, deduplicated and attributed. Two findings are the same finding when they describe the same failure scenario (triggering condition and wrong outcome) against the same requirement. A shared requirement alone, a shared path:line alone, a moved line or a different source ID decides nothing; unsure means two findings. Each match, and each non-match of findings sharing a location or requirement, goes into `Matching decisions` with a one-line reason.

The ledger input is the caller's full ledger: every earlier `D<n>` with raiser, source IDs, scenario, requirement, evidence and disposition (a cross-check rejection with the verifier's evidence and any re-raised evidence), the carried candidates, and `Next D`; direct use has none. It fills `Prior findings` and `Candidates` of both context files. A finding matching a `D<n>` keeps that ID; one matching a carried candidate takes the next `D<n>` and names the candidate's `C<n>` as provenance.

Number new findings `D<n>` from `Next D`: a matched pair takes one ID; Codex's findings first in its order, then Claude's unmatched ones in its order. A finding raised by both is confirmed (`confirmed by: both`) without a cross-check. A raiser's rating is its normalized severity ([severity map](review-wrapper.md#findings-and-derived-verdict)); a verifier rates `critical`, `important` or `minor` itself. A confirmed finding's final severity is the highest scale rating among its raisers and confirmers, both shown when they differ; a rating outside the scale counts as none, and a finding with none is `unrated`.

A unique finding that repeats a ledger cross-check rejection by the same reviewer without new evidence is a `repeat`: no cross-check, listed under `Rejected by cross-check` marked `repeat` with the earlier verifier evidence. With new evidence it is cross-checked again; raised by both, it is confirmed.

## 5. Cross-check

Each unique in-scope finding that is not a `repeat` goes to the other reviewer: one cross-check call per verifier, in a fresh process, carrying all the other reviewer's unique findings. Two verifiers form a parallel phase as in step 3; one direction runs alone; an explicitly assigned complete-check obligation makes them run one after the other without the concurrency line, each on its own boundary, a write after the first stopping the phase before the second. No unique finding, no cross-check.

Fill the [cross-check prompt](cross-check-prompt.md) per verifier and launch it through independent-review in place of the wrapper (`--native no`), in `cross-check/<verifier>/attempt-<n>/`. Its report checks: a `CROSS-CHECK REPORT` block, wherever it appears, gives every listed source ID `confirmed` or `rejected`, a severity and checkable evidence (code quoted with path:line, a run with command and result, or a quoted requirement); a rejection of a finding with a runnable reproduction gives that run's command and result and shows against a quoted requirement that it demonstrates no violation. A listed ID without verdict or evidence, or a reproduction rejected unrun, makes the attempt `invalid: evidence-free cross-check of <ID>`; the retry sends the same list. The prompt's check commands add no blanket suite run.

`confirmed` confirms the finding (`confirmed by: cross-check by <verifier>`) with step 4's final severity; `rejected` puts it under `Rejected by cross-check` with both positions. Only the two reviewers confirm or reject; this session's own reading decides nothing. `Noticed, not verified` items go to `Candidates`, attributed to the verifier.

## 6. Report and verdict

Write `<dual dir>/report.md` per [dual record](dual-record.md). Every finding from either reviewer appears in exactly one of confirmed, rejected or candidates. Rank confirmed findings `unrated`, critical, important, minor, ties by `D<n>`. The report states the reviewers' findings, positions and evidence as given, with no assessment of this session's own. `Dialogs` keeps the per-attempt [records](../SKILL.md#dialogs), background ones `not applicable (background)`.

The derived verdict is `CHANGES` when a confirmed finding is critical, important or `unrated`, or is a spec-compliance gap (the finding as raised and its confirmation both name the violated requirement), otherwise `CLEAN`. Place the [Verification marker](checkout-state.md#verification-marker) beside it, and each reviewer's derived verdict, named as derived by this session from its native report. Set phase `done` and return the report path. Direct use shows the report as the reviewers' confirmed findings, not adjudicated, with `Not reviewed (uncommitted): <paths>` when the preflight found them; nothing is fixed or committed.

## State and resume

`state.md` holds the reviewed commit, the phase (`suite`, `review`, `cross-check`, `done` or `blocked`), per reviewer per call its spent attempts and each attempt's `result.md` and dialog record, the valid results kept with their commit, suite runs and acceptances, and for windows the run token, names, launch IDs, owner, clone mappings and close/alive evidence. A recorded place `subagent` cannot continue: ask for `background` or `window`.

**Unconfirmed shutdown.** Record the block apart from budget exhaustion, with affected attempts, ownership, the saved baseline and spend, and return the shutdown block with `state.md`. Continue with `independent-review --dual --resume <state.md>`; `--write` applies only after every participant has `alive` 1 and a fresh comparison with the saved before. A fresh invocation never infers replacement authority, and a changed place never bypasses this.

**Checkout changed.** After the barrier, any `checkout changed` stops the dual review once the phase's attempts are validated: record it in `state.md` (the diff stays preserved) and return `checkout changed: <state.md>`. After a parallel phase the write is unattributable; after a lone call it is that reviewer's; after the suite it is the suite's. The dual review never adjudicates, keeps or (outside direct use) restores a write. The caller answers `scratch` (demonstrably unrelated, the checkout restored) or `invalidating` and resumes with `independent-review --dual --resume <state.md> --write scratch|invalidating`, carrying the first call's inputs (and for a new commit its review kind and target). The resume keeps the recorded place unless `--run` is given, announced and recorded. In direct use the user is the caller: show the diff and ask, under `--auto` too, since restoring discards changes ([hard to undo](../../child-sessions/references/auto.md#hard-to-undo)); on the answer restore the changed paths with targeted commands.

Every interrupted phase follows [Phase recovery and resume](checkout-state.md#phase-recovery-and-resume), pending windows first.

- **Same HEAD:** both answers need unchanged evidence against the pre-interruption baseline in every monitored tree, else `checkout changed` again. Then `invalidating` spends one attempt per reviewer in the phase (none for the suite) and `scratch` reuses otherwise-valid answers without spending. A completed writing suite with restoration proven is kept, not rerun.
- **New HEAD:** with the caller's new target, a recorded reconciled baseline and no unexplained residue, apply the answer's spending, void earlier review answers, refresh suite applicability and restart review on the new commit (direct use: `<base>..<new commit>`). Spent attempts, ledger and `Next D` are never reset.

## Budget

Each reviewer has, per call (`review`, `cross-check`), an initial attempt plus one retry. An attempt is spent only when invalid, or by a write answer above; a valid result voided by a restart spends nothing. After `invalid` only that reviewer's call is retried; the other's valid result is reused. A reviewer reaching two spent attempts ends the dual review: phase `blocked`, return `blocked: <codex|claude> invalid result` (`codex and claude` when both reach it at once) with `state.md`. There is no merged list, and one reviewer's findings are never returned as the review's.

`invalid: native review tool unavailable: <system>, <evidence>` ends that reviewer's call at once, without a retry: `blocked: <system> invalid result`, the reason in `state.md`.
