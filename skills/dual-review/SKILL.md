---
name: dual-review
description: Runs Codex and Claude CLI reviewers in parallel over committed work, has each verify the findings only the other raised, and returns one severity-ranked list of confirmed findings without changing the checkout. Use when the user wants a two-model review to fix from, or when the review/fix loop runs with the dual assignment.
---

# Dual Review

Codex CLI and Claude CLI review one recorded commit target in parallel; a finding only one of them raised goes to the other for a cross-check; the confirmed findings come back as one severity-ranked report with a derived verdict. The pair is always these two CLI reviewers, in separate processes, whatever system runs this skill; both run every review. This skill changes nothing in the checkout, commits nothing, and returns one of: `<dual dir>/report.md`, `checkout changed: <state.md>`, `blocked: <codex|claude|codex and claude> invalid result`.

A caller (`review-fix-loop` with the `dual` assignment) supplies the absolute checkout, branch, fixed base, reviewed commit, target row and review order, requirements/rules/checks, both reviewers' settings, its round directory as `<dual dir>`, its complete-suite run, and the ledger input of step 4. Direct use resolves them in step 1.

## Dependency

Read [checkout state and suite evidence](../independent-review/references/checkout-state.md) and [independent-review](../independent-review/SKILL.md), using the installed catalog if its sibling is unavailable. Missing dependency: report that the complete refinement bundle is required and stop before any launch; never install it or invent its rules. This skill is independent-review's caller: every review or cross-check attempt is one independent-review attempt under its **Assignment**, **Review prompt**, **Launch**, **Validate** and **Result** sections, and its **Direct use** applies only where this skill points to it.

## 1. Settings and target

`dual-review [--codex-model M] [--codex-effort E] [--claude-model M] [--claude-effort E] [--effort E] [<range|commit>]`

The assignments are `cli/codex` and `cli/claude`. `--effort` sets both efforts unless a per-reviewer flag sets that reviewer's; a `--model` without a reviewer prefix asks which reviewer it is for; equivalent prose counts as the flag. Everything else follows independent-review's [reviewer settings](../independent-review/references/reviewer-settings.md) per reviewer; announce and record both resolved assignments.

Direct use takes the target, the uncommitted-change stop and the requirement sources from independent-review **Direct use**; the uncommitted-change question comes before the suite run and any launch. It reviews with the final-pass row (complete target, security-focused review), prior findings `None`, and numbers from `D1`.

`<dual dir>` lies outside the checkout: the caller's round directory, else `${TMPDIR:-/tmp}/dual-review-<repo basename>-<short reviewed sha>-<YYYYmmddHHMMSS>`. It holds `state.md`, one independent-review attempt directory per attempt at `review/<codex|claude>/attempt-<n>/` and `cross-check/<codex|claude>/attempt-<n>/`, and `report.md`. When **Direct use** calls for a clone of the reviewed commit, make one the same way at `<dual dir>/tree` for both reviewers and every phase on that commit, the suite phase included: it is every prompt's `Checkout:`, and every state check covers it and the user's checkout. Write `state.md` per [dual record](references/dual-record.md) now and update it after every attempt and phase.

Resolve and record exact ordered complete-suite and targeted commands with cwd/source using the shared [suite contract](../independent-review/references/checkout-state.md#resolve-checks-and-bind-suite-evidence), accepting the caller’s already resolved set. Forward it unchanged to every prompt.

## 2. Complete suite

The reviewers never run the project's complete test suite: this session runs the resolved commands on the reviewed commit in the reviewed tree before review. Use caller evidence only under the shared [suite reuse contract](../independent-review/references/checkout-state.md#resolve-checks-and-bind-suite-evidence): same commit/checkout, successful state comparisons through reuse, no known dependency/environment change. Record commands/cwd/exits/commit, snapshots/comparison and limits; unavailable state prevents reuse. If none is defined, record `no complete suite defined`.

Capture/compare every suite phase under the shared contract, covering both trees in clone mode. A suite write is attributed to the suite, preserved externally and returned as `checkout changed: <state.md>` before any reviewer launches; **State and resume** owns reconciliation. A new commit requires a new suite run even for generated-only content. Capture failure blocks before reviewers without spending their attempts; recover a failed post-capture against that phase's saved baseline before rerunning. A failed suite itself goes to direct-use reviewers as-is and makes Verification incomplete; a loop caller retains its stricter required-check gate.

Every review and cross-check prompt carries exact resolved commands and this evidence in the dual suite slot. Reviewers retain targeted reproduction capabilities. An answer citing inherited suite evidence without rerunning it satisfies that slot; preserve actual failed/unrun checks and gaps in Verification.

## 3. Review phase

Fill independent-review's review prompt for both reviewers with the same target row, order, requirements, prior findings and dual suite slot; the two prompts differ only in their `Assignment:` line, and round 1 and final-pass rows keep the security-focus instruction. Each reviewer numbers its own findings; those numbers stay its source IDs.

A phase runs both reviewers' calls in parallel, as background jobs in one shell command run with the host's background execution. Each job runs its reviewer's launch subshell from independent-review's [CLI guide](../independent-review/references/cli-reviewers.md), with the guide's variables `task_checkout`, `review_model`, `review_effort`, `round_prompt` and `round_dir` bound inside the job to that reviewer's settings and attempt directory. The guide's `review_exit=$?` line is left out: `wait` on the job's PID gives that reviewer's exit instead.

```bash
# Obtain valid shared before snapshots under the checkout-state contract.
# Clone mode captures the original tree too; failure here launches no job.
( task_checkout="<checkout>"; review_model="<codex model>"; review_effort="<codex effort>"
  round_dir="<dual dir>/review/codex/attempt-<n>"; round_prompt="$round_dir/prompt.md"
  <the guide's Codex launch subshell> ) & codex_pid=$!
( task_checkout="<checkout>"; review_model="<claude model>"; review_effort="<claude effort>"
  round_dir="<dual dir>/review/claude/attempt-<n>"; round_prompt="$round_dir/prompt.md"
  <the guide's Claude launch subshell> ) & claude_pid=$!
wait "$codex_pid"; codex_exit=$?
wait "$claude_pid"; claude_exit=$?
# Capture shared after snapshots for all monitored trees, then compare.
# Inspect records and exits even when capture fails; retain the phase baseline.
```

The shared before/after captures and comparison implement independent-review **Launch**; use the exact helper commands in its [state contract](../independent-review/references/checkout-state.md#capture-and-compare). A failed pre-capture launches nothing/spends nothing; a shared unavailable post-capture requires recording both attempts’ other conditions before spending each reviewer’s own budget. Recovery compares the next successful capture against this phase’s retained pre-snapshot before any retry/rebaseline. This applies equally to cross-checks and single retries. Monitored coverage: ignored untracked paths not monitored; submodule/nested-repository content not recursively monitored; special-file contents not monitored. Run the guide's post-processing (Claude's answer extraction) after the waits; for that step `round_dir` is the phase's Claude attempt directory (`<dual dir>/review/claude/attempt-<n>` or `<dual dir>/cross-check/claude/attempt-<n>`). Where the host cannot run one such command, start each job as its own background command and wait for both before the state check.

Validate each answer by independent-review **Validate**. A phase with any `checkout changed` stops per **State and resume**. Otherwise keep each valid result and handle each invalid one per **Budget**: a retry of one reviewer runs alone, with its own state check, so its state is attributable; reruns of both reviewers form a parallel phase. The review phase is done when both reviewers hold a valid result for the reviewed commit.

## 4. Matching

Match only in-scope findings; outside-round and outside-task candidates go to `Candidates`, deduplicated and attributed to their raisers. Two findings are the same finding when they describe the same defect: the same failure scenario (triggering condition and wrong outcome) against the same requirement. A shared violated requirement alone does not merge them (two different failures of one requirement are two findings, each cross-checked); a shared path:line alone does not merge them; a moved line or a different source ID alone does not split them; unsure → two findings. Each match, and each non-match of findings that share a location or a requirement, goes into `Matching decisions` with a one-line reason.

The ledger input is the caller's full finding ledger: every earlier `D<n>` with its raiser, source IDs, scenario, requirement, evidence and disposition (a cross-check rejection carrying the verifier's evidence and, after a re-raise, the re-raised evidence), the caller's carried candidates, and `Next D`; direct use has none. It fills the Prior findings slot of both review prompts in step 3. A finding that matches one of its `D<n>` entries keeps that ID; one that matches a carried candidate takes the next `D<n>` and names the candidate's ID (`C<n>`) as its provenance, in its report entry and in its matching decision.

Number the findings `D<n>` from `Next D`: a matched pair takes one ID; new IDs follow Codex's findings in its order, then Claude's unmatched ones in its order. A finding raised by both reviewers is confirmed (`confirmed by: both`) without a cross-check. A confirmed finding's final severity is the highest scale rating (`critical`, `important`, `minor`) among the ratings of the reviewers that raised or confirmed it, both shown when they differ; a rating outside the scale is shown as given and counts as no rating, and a confirmed finding with no scale rating is `unrated`.

A unique finding that matches a ledger cross-check rejection and is raised again by the same reviewer without new evidence is a `repeat`: it gets no cross-check and goes under `Rejected by cross-check` marked `repeat`, with the earlier verifier evidence. Raised again with new evidence it is cross-checked again; raised by both reviewers, the former verifier included, it is confirmed.

## 5. Cross-check

Each unique in-scope finding that is not a `repeat` goes to the reviewer that did not raise it: one cross-check call per verifier, in a fresh process, carrying all of the other reviewer's unique findings. When both reviewers verify, the two calls form a parallel phase run as in step 3; a single direction runs alone. No unique finding means no cross-check phase.

Fill the [cross-check prompt](references/cross-check-prompt.md) for each verifier and launch it through independent-review with that prompt in place of the review prompt, in `cross-check/<verifier>/attempt-<n>/`. Validate each answer by independent-review **Validate**, with these as the caller's report checks: a `CROSS-CHECK REPORT` block, read wherever it appears in the answer, gives every listed source ID `confirmed` or `rejected`, a severity and checkable evidence (code read, quoted with path:line; a reproduction or check run, with command and result; or a quoted requirement); a rejection of a finding that supplies a runnable reproduction (a command or test it gives to run) also gives that run's command and result and shows, against a quoted requirement, that the result demonstrates no violation. A cross-check requires only the checks its verdicts need: a supplied runnable reproduction always, the project's complete suite never; another required check carried in its requirements is not missing coverage. A listed ID without a verdict or evidence, or a runnable reproduction rejected without being run, makes the attempt `invalid: evidence-free cross-check of <ID>`: it neither confirms nor rejects anything, and the retry sends the same list. `checkout changed`, invalid attempts and retries follow step 3.

A `confirmed` verdict confirms the finding (`confirmed by: cross-check by <verifier>`), with the final severity of step 4. A `rejected` verdict puts it under `Rejected by cross-check` with both positions. Only the two reviewers confirm or reject: this session's own reading or checks decide no finding. Items under `Noticed, not verified` go to `Candidates`, attributed to the verifier.

## 6. Report and verdict

Write `<dual dir>/report.md` per [dual record](references/dual-record.md), sections in order: `Verdict`, `Confirmed findings`, `Rejected by cross-check`, `Candidates`, `Matching decisions`, `Complete suite`, and per reviewer `Settings and evidence`, `Coverage`, `Checks run`. Every finding from either reviewer appears in exactly one of confirmed, rejected or candidates. Rank confirmed findings `unrated` → critical → important → minor, ties by `D<n>`; each carries its final severity (both ratings when they differ), path:line, scenario, violated requirement, evidence, proposed fix, `raised by`, `confirmed by` and its source IDs qualified by reviewer (`codex F1`, `claude R1`). The report states the reviewers' findings, positions and evidence as they gave them, with no assessment of this session's own.

The derived verdict is `CHANGES` when a confirmed finding is critical, important or `unrated`, or is a spec-compliance gap, otherwise `CLEAN`. A confirmed finding is a spec-compliance gap when the finding as raised names the violated requirement and its confirmation (the matching finding, or the cross-check verdict) names one too; nothing else makes it one, and this session judges none. Place `Verification: complete | incomplete: <specific checks/coverage gaps>` immediately beside the derived/raw verdicts using the shared [Verification marker](../independent-review/references/checkout-state.md#verification-marker). Aggregate the suite and retained current-commit review/cross-check gaps, excluding superseded invalid attempts; record exact failed/unrun commands and reasons. Keep `no complete suite defined` visible when applicable. CLEAN describes findings even when Verification is incomplete; it does not waive the loop check gate. Each reviewer's raw verdict stands beside it as given; a derived `CLEAN` is never presented as either reviewer's own verdict. Set phase `done` and return the report path. Direct use shows the user the report and its path as the reviewers' confirmed findings, not adjudicated by this session; nothing is fixed or committed.

## State and resume

`state.md` holds the reviewed commit; the phase (`suite`, `review`, `cross-check`, `done` or `blocked`); per reviewer per call (`review`, `cross-check`) its spent attempts and every attempt's `result.md` with its result; the valid results kept, each with its reviewed commit; and the suite evidence with its commit and its state check.

Any `checkout changed` stops the dual review once every attempt of the phase is validated: record the interruption in `state.md` (the diff stays preserved in the attempt directories, or in `<dual dir>/suite/`, per **Validate**) and return `checkout changed: <state.md>`. After a parallel phase the write is unattributable; after a call that ran alone it is that reviewer's; after the suite phase it is the suite's. This skill never adjudicates or keeps a write, and outside direct use it never restores one. The caller answers `scratch` (demonstrably unrelated, the checkout restored by the caller) or `invalidating` (any other write) and resumes with `dual-review --resume <state.md> --write scratch|invalidating`. The resume call carries the caller's inputs of the first call (settings, requirements, target row for the reviewed commit, suite run, ledger) as the first call did, so the target row for a new commit arrives with it. In direct use the caller is the user: show the preserved diff and ask which answer applies, for a suite write as for a reviewer's; the resume below requires the checkout restored first, so on the user's answer restore it with targeted commands on the changed paths (a user who keeps the write uncommitted cannot resume; one who commits it, the suite's output included, gets the restart below).

Use the shared [Phase recovery and resume](../independent-review/references/checkout-state.md#phase-recovery-and-resume) contract for every interrupted suite/review/cross-check. Preserve its pre-phase snapshot and pending recovery obligations in `state.md`. Failed pre-capture has no attempt or earlier-phase attribution; post-capture unavailability is not itself a write. Correct capture failures before another launch; persistent failure blocks.

On **same-HEAD** resume, both answers require successful content equality to the pre-interruption monitored state for every monitored tree. Otherwise leave the answer unapplied and return `checkout changed` again; equal porcelain is insufficient. Once restored, `invalidating` spends one attempt per reviewer in that phase (none for suite); `scratch` reuses otherwise-valid answers without spending, but otherwise-invalid answers spend and rerun. Resume an interrupted reviewer phase with retained valid results. After a completed suite phase on unchanged HEAD, with either `scratch` or `invalidating` and restoration equality proved, retain both the original changed comparison and restoration proof and advance to the review phase using that run, without rerunning the writing suite. Neither answer spends reviewer attempts for a suite phase. Keep its actual exits/coverage; step 2's other reuse conditions still apply. New-HEAD reconciliation requires fresh suite evidence.

For caller-authorized reconciliation at **new HEAD**, require the supplied new target, an explicitly recorded reconciled baseline and no unexplained residual changes. Resolve any pending post-failure recovery comparison/adjudication first. Apply the write answer's attempt spending, void earlier results, refresh suite evidence and restart review on the new commit. Do not demand old committed content equality. Direct use retains its final-pass target on `<base>..<new commit>`. Neither path resets spent attempts, ledger history or Next D.

## Budget

Each reviewer has, per call (`review`, `cross-check`), an initial attempt plus one retry, counted as spent attempts. An attempt is spent only when it is invalid, including what a write answer spends per **State and resume**; a valid result voided by a restart spends nothing. After `invalid` only that reviewer's call is retried; the other reviewer's valid result is reused. A reviewer whose call reaches two spent attempts ends the dual review: set phase `blocked` and return `blocked: <codex|claude> invalid result`, or `blocked: codex and claude invalid result` when both reach it at once, with `state.md`, which lists both reviewers' attempts, `result.md` files and answers. There is no merged list, and the other reviewer's findings are never returned as the review's findings.
