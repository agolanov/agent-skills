---
name: dual-review
description: Runs Codex and Claude CLI reviewers in parallel over committed work, has each verify the findings only the other raised, and returns one severity-ranked list of confirmed findings without changing the checkout. Use when the user wants a two-model review to fix from, or when the review/fix loop runs with the dual assignment.
metadata:
  internal: true
---

# Dual Review

Codex CLI and Claude CLI review one recorded commit target in parallel; a finding only one of them raised goes to the other for a cross-check; the confirmed findings come back as one severity-ranked report with a derived verdict. The pair is always these two CLI reviewers, in separate processes, whatever system runs this skill; both run every review. This skill changes nothing in the checkout, commits nothing, and returns one of: `<dual dir>/report.md`, `checkout changed: <state.md>`, `blocked: <codex|claude|codex and claude> invalid result`.

A caller (`review-fix-loop` with the `dual` assignment) supplies the absolute checkout, branch, fixed base, reviewed commit, target row and review order, requirements/rules/checks, both reviewers' settings, its round directory as `<dual dir>`, its complete-suite run, and its finding ledger with the next `D<n>`. Direct use resolves them in step 1.

## Dependency

Read [independent-review](../independent-review/SKILL.md), using the installed catalog if its sibling is unavailable. Missing dependency: report that the complete refinement bundle is required and stop before any launch; never install it or invent its rules. This skill is independent-review's caller: every review or cross-check attempt is one independent-review attempt under its **Assignment**, **Review prompt**, **Launch**, **Validate** and **Result** sections, and its **Direct use** applies only where this skill points to it.

## 1. Settings and target

`dual-review [--codex-model M] [--codex-effort E] [--claude-model M] [--claude-effort E] [--effort E] [<range|commit>]`

The assignments are `cli/codex` and `cli/claude`. `--effort` sets both efforts unless a per-reviewer flag sets that reviewer's; a `--model` without a reviewer prefix asks which reviewer it is for; equivalent prose counts as the flag. Everything else follows independent-review's [reviewer settings](../independent-review/references/reviewer-settings.md) per reviewer; announce and record both resolved assignments.

Direct use takes the target, the uncommitted-change stop and the requirement sources from independent-review **Direct use**; the uncommitted-change question comes before the suite run and any launch. It reviews with the final-pass row (complete target, security-focused review), prior findings `None`, and numbers from `D1`.

`<dual dir>` lies outside the checkout: the caller's round directory, else `${TMPDIR:-/tmp}/dual-review-<repo basename>-<short reviewed sha>-<YYYYmmddHHMMSS>`. It holds `state.md`, one independent-review attempt directory per attempt at `review/<codex|claude>/attempt-<n>/` and `cross-check/<codex|claude>/attempt-<n>/`, and `report.md`. When **Direct use** calls for a clone of the reviewed commit, make one the same way at `<dual dir>/tree` for both reviewers and every phase on that commit: it is every prompt's `Checkout:`, and every state check covers it and the user's checkout. Write `state.md` per [dual record](references/dual-record.md) now and update it after every attempt and phase.

## 2. Complete suite

The reviewers never run the project's complete test suite: this session runs it on the reviewed commit, in the tree the reviewers review, before the review phase. A caller's own run on the reviewed commit is used instead when HEAD has not moved since. Direct use takes the command from the project rules or README; with none identifiable the evidence is `no complete suite defined`. Record command, exit and commit in `state.md`; a failing run goes to the reviewers as it is. Every review prompt carries this evidence in the dual complete-suite slot of independent-review's [review prompt](../independent-review/references/review-prompt.md), and every cross-check prompt carries the same slot. A reviewer answer that runs no complete suite and cites the supplied run as inherited evidence has the suite coverage **Validate** requires.

## 3. Review phase

Fill independent-review's review prompt for both reviewers with the same target row, order, requirements, prior findings and dual suite slot; the two prompts differ only in their `Assignment:` line, and a final-pass row keeps its security-focus instruction. Each reviewer numbers its own findings; those numbers stay its source IDs.

A phase runs both reviewers' calls in parallel, as background jobs in one shell command run with the host's background execution. Each job runs its reviewer's launch subshell from independent-review's [CLI guide](../independent-review/references/cli-reviewers.md), with the guide's variables `task_checkout`, `review_model`, `review_effort`, `round_prompt` and `round_dir` bound inside the job to that reviewer's settings and attempt directory. The guide's `review_exit=$?` line is left out: `wait` on the job's PID gives that reviewer's exit instead.

```bash
head_before=$(git -C "<checkout>" rev-parse HEAD); status_before=$(git -C "<checkout>" status --porcelain)
( task_checkout="<checkout>"; review_model="<codex model>"; review_effort="<codex effort>"
  round_dir="<dual dir>/review/codex/attempt-<n>"; round_prompt="$round_dir/prompt.md"
  <the guide's Codex launch subshell> ) & codex_pid=$!
( task_checkout="<checkout>"; review_model="<claude model>"; review_effort="<claude effort>"
  round_dir="<dual dir>/review/claude/attempt-<n>"; round_prompt="$round_dir/prompt.md"
  <the guide's Claude launch subshell> ) & claude_pid=$!
wait "$codex_pid"; codex_exit=$?
wait "$claude_pid"; claude_exit=$?
head_after=$(git -C "<checkout>" rev-parse HEAD); status_after=$(git -C "<checkout>" status --porcelain)
```

The two state records are the phase-level comparison of independent-review **Launch**. Run the guide's post-processing (Claude's answer extraction) after the waits. Where the host cannot run one such command, start each job as its own background command and wait for both before the state check.

Validate each answer by independent-review **Validate**. A phase with any `checkout changed` stops per **State and resume**. Otherwise keep each valid result and handle each invalid one per **Budget**: a retry of one reviewer runs alone, with its own state check, so its state is attributable; reruns of both reviewers form a parallel phase. The review phase is done when both reviewers hold a valid result for the reviewed commit.

## 4. Matching

Match only in-scope findings; outside-round and outside-task candidates go to `Candidates`, deduplicated and attributed to their raisers. Two findings are the same finding when they describe the same defect: the same failure scenario (triggering condition and wrong outcome) against the same requirement. A shared violated requirement alone does not merge them (two different failures of one requirement are two findings, each cross-checked); a shared path:line alone does not merge them; a moved line or a different source ID alone does not split them; unsure → two findings. Each match, and each non-match of findings that share a location or a requirement, goes into `Matching decisions` with a one-line reason.

Number the findings `D<n>` from the caller's next number: a matched pair takes one ID, new IDs follow Codex's findings in its order, then Claude's unmatched ones in its order, and a finding that matches an entry of the caller's ledger keeps that entry's ID. A finding raised by both reviewers is confirmed (`confirmed by: both`) without a cross-check; its final severity is the higher rating, with both shown when they differ.

A caller's ledger lists, for each earlier cross-check rejection, the finding as its raiser stated it (raiser, source ID, `D<n>`, scenario, requirement, evidence) and the verifier's evidence, plus the next free `D<n>`; direct use has none. A unique finding that matches a ledger cross-check rejection and is raised again by the same reviewer without new evidence is a `repeat`: it gets no cross-check and goes under `Rejected by cross-check` marked `repeat`, with the earlier verifier evidence. Raised again with new evidence it is cross-checked again; raised by both reviewers, the former verifier included, it is confirmed.

## 5. Cross-check

Each unique in-scope finding that is not a `repeat` goes to the reviewer that did not raise it: one cross-check call per verifier, in a fresh process, carrying all of the other reviewer's unique findings. When both reviewers verify, the two calls form a parallel phase run as in step 3; a single direction runs alone. No unique finding means no cross-check phase.

Fill the [cross-check prompt](references/cross-check-prompt.md) for each verifier and launch it through independent-review with that prompt in place of the review prompt, in `cross-check/<verifier>/attempt-<n>/`. Validate each answer by independent-review **Validate**, with these as the caller's report checks: a `CROSS-CHECK REPORT` gives every listed source ID `confirmed` or `rejected`, a severity and checkable evidence (code read, quoted with path:line; a reproduction or check run, with command and result; or a quoted requirement); a rejection of a finding that supplies a runnable reproduction (a command or test it gives to run) also gives that run's command and result and shows, against a quoted requirement, that the result demonstrates no violation. A cross-check requires only the checks its verdicts need: a supplied runnable reproduction always, the project's complete suite never; another required check carried in its requirements is not missing coverage. A listed ID without a verdict or evidence, or a runnable reproduction rejected without being run, makes the attempt `invalid: evidence-free cross-check of <ID>`: it neither confirms nor rejects anything, and the retry sends the same list. `checkout changed`, invalid attempts and retries follow step 3.

A `confirmed` verdict confirms the finding (`confirmed by: cross-check by <verifier>`), with the higher of the raiser's and the verifier's severities, both shown when they differ. A `rejected` verdict puts it under `Rejected by cross-check` with both positions. Only the two reviewers confirm or reject: this session's own reading or checks decide no finding. Items under `Noticed, not verified` go to `Candidates`, attributed to the verifier.

## 6. Report and verdict

Write `<dual dir>/report.md` per [dual record](references/dual-record.md), sections in order: `Verdict`, `Confirmed findings`, `Rejected by cross-check`, `Candidates`, `Matching decisions`, `Complete suite`, and per reviewer `Settings and evidence`, `Coverage`, `Checks run`. Every finding from either reviewer appears in exactly one of confirmed, rejected or candidates. Rank confirmed findings critical → important → minor, ties by `D<n>`; each carries its final severity (both ratings when they differ), path:line, scenario, violated requirement, evidence, proposed fix, `raised by`, `confirmed by` and its source IDs qualified by reviewer (`codex F1`, `claude R1`). The report states the reviewers' findings, positions and evidence as they gave them, with no assessment of this session's own.

The derived verdict is `CHANGES` when a confirmed finding is critical or important or is a spec-compliance gap, otherwise `CLEAN`. Each reviewer's raw verdict stands beside it as given; a derived `CLEAN` is never presented as either reviewer's own verdict. Set phase `done` and return the report path. Direct use shows the user the report and its path as the reviewers' confirmed findings, not adjudicated by this session; nothing is fixed or committed.

## State and resume

`state.md` holds the reviewed commit; the phase (`review`, `cross-check`, `done` or `blocked`); per reviewer per call (`review`, `cross-check`) its spent attempts and every attempt's `result.md` with its result; the valid results kept, each with its reviewed commit; and the suite evidence with its commit.

Any `checkout changed` stops the dual review once every attempt of the phase is validated: record the interruption in `state.md` (the diff stays preserved in the attempt directories per **Validate**) and return `checkout changed: <state.md>`. After a parallel phase the write is unattributable; after a call that ran alone it is that reviewer's. This skill never adjudicates or keeps a write, and outside direct use it never restores one. The caller answers `scratch` (demonstrably unrelated, the checkout restored by the caller) or `invalidating` (any other write) and resumes with `dual-review --resume <state.md> --write scratch|invalidating`. In direct use the caller is the user: show the preserved diff and ask which answer applies and whether to restore the checkout; restore only on the user's answer, with targeted commands on the changed paths.

On resume, first require the porcelain to be back to its state before the interrupted phase; otherwise record the reason in `state.md` (not restored, with the current porcelain), leave the answer unapplied and return `checkout changed: <state.md>` again for the caller to adjudicate. Then apply the answer. `invalidating` spends one attempt for each reviewer in that phase, and the phase reruns. Under `scratch` an attempt recorded `checkout changed; otherwise valid` spends nothing and its result is reused, while one recorded `checkout changed; otherwise invalid: <reason>` still spends an attempt and its answer is not reused. Then compare `git rev-parse HEAD` of the reviewed tree with the recorded reviewed commit. Unchanged: continue at the interrupted phase, reusing that commit's valid results. Changed (reconciliation made a commit): record the new reviewed commit, void every earlier result, refresh the suite evidence for it per step 2, and restart at the review phase with the target row the caller supplies for the new commit (in direct use the same final-pass row on `<base>..<new commit>`). Spent attempts are never reset, by either path.

## Budget

Each reviewer has, per call (`review`, `cross-check`), an initial attempt plus one retry, counted as spent attempts. An attempt is spent only when it is invalid, including what a write answer spends per **State and resume**; a valid result voided by a restart spends nothing. After `invalid` only that reviewer's call is retried; the other reviewer's valid result is reused. A reviewer whose call reaches two spent attempts ends the dual review: set phase `blocked` and return `blocked: <codex|claude> invalid result`, or `blocked: codex and claude invalid result` when both reach it at once, with `state.md`, which lists both reviewers' attempts, `result.md` files and answers. There is no merged list, and the other reviewer's findings are never returned as the review's findings.
