---
name: review-fix-loop
description: Runs a review/fix cycle over committed task work, the session that did the work fixing what an independent reviewer finds; the reviewer is the other system by default, or Codex, Claude or both under `--codex`, `--claude` or `--dual`. Use when work should be reviewed and fixed until clean; for a one-off review without fixes, use independent-review.
---

# Review Fix Loop

```text
review-fix-loop [--codex[=<command>] | --claude[=<command>] | --dual] [--run inline|subagent|background|window]
                [--model M] [--effort E] [--reviewer-run background|window] [--reviewer-model M] [--reviewer-effort E] [--auto]
```

The session that did the work owns the loop. An independent reviewer checks the committed target. The user's words count as keys.

| Setting | Role and default |
| --- | --- |
| `--run` | Loop owner: `inline` (this session). For `subagent`, `background` or `window`, follow [Run elsewhere](references/run-elsewhere.md) before starting the loop. Reject any other value. |
| `--model`, `--effort` | Non-inline owner: default to its [most demanding step](../independent-review/references/launch-settings.md#effort-by-task). Under `inline` refuse these keys and name the reviewer keys below. |
| `--reviewer-run` | Reviewer: `background` (default) or `window`. |
| `--reviewer-model`, `--reviewer-effort` | Reviewer: pass as independent-review's `--model`, `--effort`; default to its reviewer role. |

Under `--auto`, follow [auto.md](../child-sessions/references/auto.md) for decisions, briefs and the report. Apply matching skills throughout; style skills must preserve the required records and cross-check report.

## 1. Establish scope and reviewer

1. **Scope.** Resolve the absolute task checkout (a worktree included), branch, HEAD, fixed base, requirements and checks. The task is the branch's changes plus task-owned staged, unstaged and untracked files; unrelated work is preserved and listed as excluded. Select requirement files and sections by [Review coverage](../independent-review/SKILL.md#review-coverage). Resolve ambiguous scope first.
2. **Target form** ([target](../independent-review/references/review-wrapper.md#target)): `range` by default; `files: <paths>` when the caller names whole files with no single task range (`refining-task-docs` does). For a document review the task checkout is the docs repository and the project checkout is related code.
3. **Checks.** Resolve the ordered complete-suite and targeted commands with cwd, coverage and phase/producer obligations once, by the [suite contract](../independent-review/references/checkout-state.md#resolve-checks-and-bind-suite-evidence); inspect retained implementation runs before scheduling more. The loop owner runs the checks; reviewers get commands and results as data.
4. **Merge-candidate checks.** A [merge-candidate check](../independent-review/references/checkout-state.md#merge-candidate-checks) is recorded `pending: merge candidate` with its command in every context file, left unrun throughout the loop, and holds back neither clean mode. The session that merges runs it, else the user before merging.

### Reviewer

Read [independent-review](../independent-review/SKILL.md), using the installed catalog if the sibling is missing. Stop if unavailable. Before starting, apply its [Assignment](../independent-review/SKILL.md#assignment) to the reviewer keys above, passing system keys and launch commands unchanged. For an invalid reviewer place name the supported `--reviewer-run background|window` choices.

On resume keep the recorded system and command unless explicitly selected, and the recorded place unless a new `--reviewer-run` is announced and recorded. For an old `subagent` reviewer ask for a supported place. Before continuing an interrupted phase apply [recovery](../independent-review/references/checkout-state.md#phase-recovery-and-resume).

Under `--dual` follow [Dual rounds](references/loop-record.md#dual-rounds) for assignment, round inputs, IDs, cross-check decisions and returns.

**Record.** Keep one [loop record](references/loop-record.md) outside the checkout (reuse an existing task log) with the assignment. The round limit is the explicit one, else twenty completed rounds. Rounds report to the user once, in the final report, by child-sessions' [quiet wait](../child-sessions/SKILL.md#wait).

### Reviewer settings by target

Every review uses the resolved initial reviewer settings, passed explicitly each round. The user's explicit final-pass settings apply to the final pass and its retries only (per reviewer in a dual loop); later rounds return to the initial settings. A request for one setting on every round is an ordinary explicit setting. Retries and resumes keep the pending round's settings and budget; a running attempt is never replaced on resume. Announce and record each switch.

## 2. Commit the reviewed state

Invoking the loop requests a task-state commit and one fix commit per round on the task branch; that is all it authorizes. Push, merge, rebase, amend, squash, deploy, worktree creation, installation and persistent configuration changes each need their own authorization. A request forbidding commits withdraws it: stop and ask whether to allow these commits or end without review. Before the first commit, a detached HEAD or the default branch (`main`/`master` or configured) asks for confirmation unless already authorized.

1. Record the pre-loop HEAD for the squash command.
2. Commit task-owned changes, if any, as `review-fix-loop: task state before review`. Stage and commit exact task paths only (`git --literal-pathspecs commit --only -- <paths>` when unrelated work is staged): a plain commit of the whole index would absorb unrelated staged work. Unrelated staged and unstaged work stays as it was, its exclusion recorded. Fix commits follow the same rule.
3. Before each commit, require passing affected checks (applicable evidence or a run) and any explicit pre-commit gate; after each fix batch make exactly one commit naming the round and finding IDs. Apply the [suite contract](../independent-review/references/checkout-state.md#resolve-checks-and-bind-suite-evidence) and [handoff recipe](../independent-review/references/checkout-state.md#run-and-hand-off-a-suite); a new SHA alone needs no suite run.
4. Round 1 and the final pass need accepted complete coverage, merge-candidate checks and checks a requirement gives to the reviewer aside (step 3). A fix commit followed by a scoped round or by no review may have broader coverage pending until completion; one followed by the final pass meets the final-pass gate first.

A failed required check blocks dependent work and authorizes no amend, squash or unreviewed corrective commit. Every review targets a recorded stable commit.

## 3. Request independent review

Obtain each attempt from independent-review (`--auto` under `--auto`), passing the review kind, target form and target, and the [context file](../independent-review/references/review-wrapper.md#the-context-file) data: requirements, the full finding ledger with evidence and dispositions, carried candidates, check commands with results. Skip routine full-file readback after writing an attempt's context file. Each round gets a fresh round directory beside the loop record, with a random part (`mktemp -d "<record dir>/round-<n>-XXXXXX"`).

| Review | Target | Added [wrapper line](../independent-review/references/review-wrapper.md#added-lines) |
| --- | --- | --- |
| Round 1 | complete task: `<base>..HEAD`, or the files | security |
| Scoped round | `<fix commit>^..<fix commit>` | none |
| Final pass | complete task; accumulated outside-round candidates in `Candidates` | security |
| Disposition round | complete task, on the same HEAD | decisions only |

Scoped rounds run only after the final pass (step 5). A requirement that names the reviewer as the one who runs a check adds the reviewer-run line; that check does not hold back the launch, stays `pending` until the attempt's runtime records show it ran, and the loop cannot close before. Each finding's class (in scope, outside-round or outside-task) comes from the attempt's `findings.md`.

**Outside-round candidates** of a scoped round are adjudicated at once by evidence, without widening the review: accepted task defects and minor task findings go through a fix commit within the remaining limit; others get a recorded disposition. A record resumed with the final pass pending carries every such candidate to the final pass's `Candidates` unfixed. Pre-existing outside-task problems never block.

## 4. Validate and decide

Each attempt returns validated by independent-review as `valid`, `invalid: <reason>`, `checkout changed` or a shutdown `blocked`, with its `result.md` and, when valid, `findings.md` and derived verdict; record them in the round. A result not obtained from independent-review on a recorded commit is an invalid attempt, never a round.

- **Empty target:** `blocked: empty review target`.
- **Native tool unavailable:** not retried; `blocked: <reason>`.
- **Shutdown unconfirmed:** the round stays pending with its ownership records, baseline and budget; no reviewer, suite or fix starts until the barrier resolves; report the block and resume through the same recovery gates.
- **Recovery:** [Phase recovery and resume](../independent-review/references/checkout-state.md#phase-recovery-and-resume) governs suites, attempts and retries.
- **Checkout changed:** pause retries; with the write and its diff preserved, adjudicate within authority. A reviewer write to task state or a moved HEAD invalidates the attempt; a demonstrably unrelated scratch write with state and coverage intact is recorded without spending; never fold a reviewer's edit into a fix commit or reset unrelated work; unresolved ownership blocks.
- **Budget:** any other invalid attempt spends the round's budget, an initial attempt plus one retry with the same assignment, never reset by reconciliation; a second invalid attempt blocks.

For a dual round, use the [dual result and budget](references/loop-record.md#dual-rounds). For one system use `R<round>-F<n>` from the round and source ID, keeping the ledger ID of a repeat.

Adjudicate every finding in the record by its normalized severity ([severity map](../independent-review/references/review-wrapper.md#findings-and-derived-verdict)):

- **Accepted:** a critical or important defect or a spec-compliance gap requires a fix. A runnable reproduction demonstrating a violated requirement is accepted after verification, whatever the opinion.
- **Rejected:** needs a checkable quoted requirement or test showing correct behaviour; an unsupported opinion rejects nothing. An `unrated` finding is accepted or rejected on its evidence, never deferred.
- **Minor:** fixed in the round's fix commit; a round of only minor findings still makes that commit. A minor finding whose fix would change the spec or plan, or needs an open decision, is **Outside-scope**, its reason naming that. One unfixed at the round limit is `deferred: round limit` and holds back neither clean mode.
- **Disputed:** after a recorded rejection with basis, the reviewer re-raises the same scenario and requirement without new evidence (a reproduction, code reference or requirement quote the ledger entry lacks; a moved line alone keeps identity). Record both positions and the fix-or-dismiss question for the user, and spend no further rounds on it. Under `--auto` the question leaves with the report and is settled by auto.md's [`CLEAN EXCEPT DISPUTED`](../child-sessions/references/auto.md#deciding) rule, applied by the first session.
- **Outside-scope:** pre-existing or outside-task candidates, recorded once for the report.
- **Not re-raised:** an accepted finding fixed in the reviewed range and absent from the next report; never "verified by the reviewer".

## 5. Fix, repeat and finish

Fix the round's accepted and minor findings in one commit and run the affected required checks; a failed check (even PASS text with a nonzero exit) blocks dependent work until resolved within authority. A missing dependency needing broader authority is a reported blocker.

**After the fix commit:**

| State | Next |
| --- | --- |
| The final pass has not run | The final pass on the complete task |
| The final pass has run, and the commit fixes an accepted defect or the loop owner rejected a finding of the round | A scoped round on `<fix commit>^..<fix commit>` |
| The final pass has run, every fix is of a minor finding, the loop owner rejected none of the round's findings, and no reviewer-run check is pending | No review: go to completion (`no review: minor-only`) |

A commit mixing a defect fix with minor fixes takes the second row. A rejection beside minor fixes takes it too, so the reviewer can re-raise it; a finding closed as rejected by cross-check is no loop-owner rejection. A minor-only commit with a reviewer-run check pending (never run, or its inputs changed) takes the second row with the reviewer-run line. A resumed record with an unstarted scoped round decides it again by this table.

**Finishing.** A valid round-1 `CLEAN` with no minor finding to fix may finish at once when complete required verification applies to that commit. A round with no fix commit runs the **one final complete pass** if it has not run. Final-pass findings return through fix commits and scoped rounds; there is never a second complete pass or a budget reset. With no fix commit after the final pass, at most one disposition round per disposition set on the same HEAD: `CLEAN` confirms, an evidence-free repeat becomes disputed.

**No progress.** When successive rounds return the same finding set with no accepted fix, stop repeating the review: fix confirmed defects within the remaining rounds or mark eligible repeats disputed; an unresolved non-disputed defect blocks.

**Limit.** Every valid result counts as a round, final and disposition passes included; invalid attempts never do. At the limit (completed rounds equal it, loop unfinished) a last fix commit is allowed only when the review it requires still fits, or it requires none. When finishing needs one more review, pause at the checkpoint first. When the user stops there, adjudicate every open finding with a reason; an unresolved accepted defect reports `blocked: round limit` with the next action.

**Checkpoint.** Ask how to go on, giving each round's target and verdict in one line, the open findings and the cause the record shows (fixes failing their scoped review, findings rejected round after round, real defects closed per round, minor-only rounds). Offer: more rounds, as many as the user names; more rounds with named reviewer settings; stop with `blocked: round limit`, the record kept for a resume with a higher limit or a stronger loop owner (`--run` with `--model`/`--effort`). Recommend continuing, with a number, when each round closed real defects and the open set shrinks; stopping when fixes keep failing or the same kind of finding keeps being rejected. Record cause, recommendation, answer and new limit; reaching a raised limit brings the checkpoint again.

**Report** one of:

- `clean`: a valid derived `CLEAN` on final HEAD; or a dual scoped round's `CHANGES` held only by `repeat, unchanged` entries closed by cross-check; or a final HEAD that is a fix commit left without review by the table above, made directly on the last reviewed commit, with every finding of that review fixed, outside-scope, deferred minor or closed by cross-check, and its affected checks passed. In every case: the final pass completed when more than one round ran, complete applicable final verification with run/acceptance provenance and all obligations met, no unresolved accepted critical or important defect or compliance gap, no open minor finding, outside-round candidates adjudicated. Merge-candidate checks are listed `pending: merge candidate` with their commands. The last derived verdict stays as derived, never relabelled; a minor-only commit left without review is named with the IDs it closed.
- `clean except disputed`: the same conditions, plus disputed findings with both positions and the fix-or-dismiss question (a disputed finding of the last review counts as closed for a minor-only final commit). A derived `CHANGES` may close here when its only remaining blocking claims are disputed evidence-free repeats, possibly with cross-check repeats, every other finding resolved, deferred or outside-scope and no required review left; keep the `CHANGES` and explain. Deferred minors alone do not qualify.
- `blocked: <reason>`: exhausted invalid attempts, round limit, failed required checks, missing dependencies, unresolved edit ownership or unmet completion requirements.

Later task edits invalidate the reviewed result. The report gives rounds, targets and commits, assignment and evidence, checks, all decisions, deferred and disputed findings, outside-scope candidates, under a dual assignment the findings rejected by cross-check with both positions, and under `--auto` the [`## Decisions`](../child-sessions/references/auto.md#decisions). Print the squash command without running it, round history left unsquashed, with a subject and body you write summing up the folded commits in the project's conventions, each one quoted `-m` argument: `git reset --soft <pre-loop HEAD> && git commit -m '<subject>' -m '<body>'`; with unrelated staged changes left, `git reset --soft <pre-loop HEAD> && git --literal-pathspecs commit --only -m '<subject>' -m '<body>' -- <exact task paths>`, the paths quoted, so excluded staging survives.
