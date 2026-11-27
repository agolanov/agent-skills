---
name: review-fix-loop
description: Runs a review/fix cycle over committed task work, the session that did the work fixing what an independent reviewer finds; the reviewer is the other system by default, or Codex, Claude or both under `--codex`, `--claude` or `--dual`. Use when work should be reviewed and fixed until clean; for a one-off review without fixes, use independent-review.
---

# Review Fix Loop

```text
review-fix-loop [--codex[=<command>] | --claude[=<command>] | --dual] [--run inline|subagent|background|window]
                [--model M] [--effort E] [--reviewer-run background|window] [--reviewer-model M] [--reviewer-effort E] [--auto]
```

The loop owner, the session that did the work, owns decisions, fixes and the loop; an independent reviewer checks the task through [independent-review](../independent-review/SKILL.md). `--run` places the loop owner: `inline` (default) is this session; `subagent`, `background` or `window` move the loop to a child ([Run elsewhere](#run-elsewhere)). The user's words count as the keys.

| Who | Model / effort |
| --- | --- |
| Reviewer | [launch settings](../independent-review/references/launch-settings.md#roles) review row, or `--reviewer-model`/`--reviewer-effort` |
| Loop owner outside `inline` | `--model`/`--effort`, else the row of its most demanding step ([Effort by task](../independent-review/references/launch-settings.md#effort-by-task)) |

Under `--auto` read child-sessions' [auto.md](../child-sessions/references/auto.md): a question that would go to the user is routed by its Deciding, every brief, driver brief and cross-check prompt says `Auto: yes`, and the report lists `## Decisions`.

Keep normal skill discovery active and apply matching skills at each stage; skills that set output style or compress text never change the format or completeness of the loop's records or a cross-check report. A native review report has its tool's form, read as independent-review [Validate](../independent-review/SKILL.md#validate) says.

## Run elsewhere

Under `--run subagent`, `background` or `window` this session is a thin launcher ([Thin launchers](../child-sessions/references/run-contract.md#thin-launchers)) and runs none of steps 1–5: a child of this session's system performs this skill `inline`, and this session briefs it, waits, relays its questions and reports its result. Another `--run` value stops before anything starts.

- **Inputs.** Resolve step 1's scope: absolute task checkout and branch, full fixed base, target form and related-code checkout, requirements, task-owned uncommitted paths and excluded ones, exact checks. Apply step 1's refusals for the child.
- **Worker.** Role `implementer`, the effort of [Effort by task](../independent-review/references/launch-settings.md#effort-by-task) from step 1's requirements, recorded on `Launch settings:` with source `policy` and its `effort step:`; `--run`, `--model` and `--effort` are consumed, every other key goes to `Arguments:` as given. Name `loop-<slug>` from the branch (or short HEAD), every character outside `[A-Za-z0-9_-]` replaced by `-`.
- **Brief.** `Checkout:` the task checkout; `Authority:` the task-state commit and one fix commit per round on the task branch, nothing more; `Base SHA:`; `Target:` `range` or `files: <paths>`, plus `Related code:` for a document review; `Requirements:` paths or the task text verbatim; `Task paths:` or `None`; `Checks:` resolved commands with cwd and source, or `no complete suite defined`, and unavailable coverage; `Suite evidence:` the [suite handoff reference](../independent-review/references/checkout-state.md#run-and-hand-off-a-suite), an external records directory and retained records (`None`). The child verifies these against the checkout as step 1 does.
- **Result.** `STATUS: done` for `clean` or `clean except disputed`, `STATUS: failed` for `blocked: <reason>`. Review holds step 5's report; Checks its checks, merge-candidate ones pending; Commits its commits; Out of scope its candidates. Report them as this skill's report, with the launch evidence.
- **Disputed completion.** Under `--auto`, when the child ends `clean except disputed` and this session is the first session, apply auto.md's [`CLEAN EXCEPT DISPUTED`](../child-sessions/references/auto.md#deciding) rule before reporting; a launcher that is itself a child leaves the question in its report.

## 1. Establish scope and reviewer

1. **Scope.** Resolve the absolute task checkout (a worktree included), branch, HEAD, fixed base, requirements and checks. The task is the branch's changes plus task-owned staged, unstaged and untracked files; unrelated work is preserved and listed as excluded. Select requirement files and sections by [Review coverage](../independent-review/SKILL.md#review-coverage). Resolve ambiguous scope first.
2. **Target form** ([target](../independent-review/references/review-wrapper.md#target)): `range` by default; `files: <paths>` when the caller names whole files with no single task range (`refining-task-docs` does). For a document review the task checkout is the docs repository and the project checkout is related code.
3. **Checks.** Resolve the ordered complete-suite and targeted commands with cwd, coverage and phase/producer obligations once, by the [suite contract](../independent-review/references/checkout-state.md#resolve-checks-and-bind-suite-evidence); inspect retained implementation runs before scheduling more. The loop owner runs the checks; reviewers get commands and results as data.
4. **Merge-candidate checks.** A [merge-candidate check](../independent-review/references/checkout-state.md#merge-candidate-checks) is recorded `pending: merge candidate` with its command in every context file, left unrun throughout the loop, and holds back neither clean mode. The session that merges runs it, else the user before merging.

### Reviewer

Read [independent-review](../independent-review/SKILL.md) (the installed catalog if the sibling is missing; missing entirely, report that it is required and stop). Resolve the assignment before anything starts:

- **System:** `--codex`, `--claude` or `--dual`; `--codex=<command>`/`--claude=<command>` also give the launch command, passed unchanged. With none, a resumed loop keeps its recorded system and command; otherwise the system opposite to the loop owner's ([Session system](../independent-review/SKILL.md#session-system)).
- **Place:** `--reviewer-run background` (default) or `window`. A resume keeps the recorded place unless `--reviewer-run` is given now, announced and recorded. A resumed record holding `subagent` asks for `background` or `window` before its next review.
- **Reviewer settings:** `--reviewer-model`/`--reviewer-effort`, passed as independent-review's `--model`/`--effort`. Under `--dual`, `--reviewer-effort` sets both, a `--reviewer-model` asks which reviewer it is for, and prose may set one reviewer's value (`--codex-model`, `--codex-effort`, `--claude-model`, `--claude-effort`).
- **Loop owner settings:** `--model`/`--effort` set the loop owner outside `inline`.

Refused before anything starts, each naming its replacement: `--model`/`--effort` under `inline` ("the loop owner is this session; use --reviewer-model/--reviewer-effort for the reviewer"); `--reviewer-run subagent` and `--subagent` (`background` or `window`: a native subagent has no native review command); `--reviewer-run inline` (reviewing one's own work is not independent); `--reviewer codex|claude` (`--codex` or `--claude`); reviewer effort `low` for Claude (`medium`).

**Dual.** Codex and Claude review round 1, the final pass and every disposition round through [the dual review](../independent-review/references/dual.md), both settings resolved by its [step 1](../independent-review/references/dual.md#1-settings-and-target). A scoped round of a dual loop is a single-system round by the system opposite to the loop owner's, with that reviewer's recorded command, settings and place.

**Record.** Keep one [loop record](references/loop-record.md) outside the checkout (reuse an existing task log) with the assignment. The round limit is the explicit one, else twenty completed rounds. Rounds report to the user once, in the final report, by child-sessions' [quiet wait](../child-sessions/SKILL.md#wait).

### Reviewer settings by target

Every review uses the resolved initial reviewer settings, passed explicitly each round. The user's explicit final-pass settings apply to the final pass and its retries only (per reviewer in a dual loop); later rounds return to the initial settings. A request for one setting on every round is an ordinary explicit setting. Retries and resumes keep the pending round's settings and budget; a running attempt is never replaced on resume. Announce and record each switch.

## 2. Commit the reviewed state

Invoking the loop requests a task-state commit and one fix commit per round on the task branch; that is all it authorizes. Push, merge, rebase, amend, squash, deploy, worktree creation, installation and persistent configuration changes each need their own authorization. A request forbidding commits withdraws it: stop and ask whether to allow these commits or end without review. Before the first commit, a detached HEAD or the default branch (`main`/`master` or configured) asks for confirmation unless already authorized.

1. Record the pre-loop HEAD for the squash command.
2. Commit task-owned changes, if any, as `review-fix-loop: task state before review`. Stage and commit exact task paths only (`git --literal-pathspecs commit --only -- <paths>` when unrelated work is staged): a plain commit of the whole index would absorb unrelated staged work. Unrelated staged and unstaged work stays as it was, its exclusion recorded. Fix commits follow the same rule.
3. Before each commit, require passing affected checks (applicable evidence or a run) and any explicit pre-commit gate; after each fix batch make exactly one commit naming the round and finding IDs. Apply the [suite contract](../independent-review/references/checkout-state.md#resolve-checks-and-bind-suite-evidence) and [handoff recipe](../independent-review/references/checkout-state.md#run-and-hand-off-a-suite); a new SHA alone needs no suite run.
4. Round 1 and the final pass need accepted complete coverage, merge-candidate checks and checks a requirement gives to the reviewer aside (step 3). A fix commit followed by a scoped round or by no review may have broader coverage pending until completion; one followed by the final pass meets the final-pass gate first.

A failed required check blocks dependent work and authorizes no amend, squash or unreviewed corrective commit. Every review targets a recorded stable commit. Under the dual assignment the dual review's [Complete suite](../independent-review/references/dual.md#2-complete-suite) runs the suites.

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

**Dual.** A scoped round follows the single-system text: one attempt directory, an initial attempt plus one retry, `checkout changed` adjudicated by the loop owner, candidates adjudicated at once; its derived verdict is the round's. Every other review is one dual review, resumes included, given its recorded place, both settings, the review kind and target, the full ledger with `Next D` as the [ledger input](../independent-review/references/dual.md#4-matching), the step 2 run/acceptance records and pending coverage, and the round directory as `<dual dir>`.

## 4. Validate and decide

Each attempt returns validated by independent-review as `valid`, `invalid: <reason>`, `checkout changed` or a shutdown `blocked`, with its `result.md` and, when valid, `findings.md` and derived verdict; record them in the round. A result not obtained from independent-review on a recorded commit is an invalid attempt, never a round.

- **Empty target:** `blocked: empty review target`.
- **Native tool unavailable:** not retried; `blocked: <reason>`.
- **Shutdown unconfirmed:** the round stays pending with its ownership records, baseline and budget; no reviewer, suite or fix starts until the barrier resolves; report the block and resume through the same recovery gates.
- **Recovery:** [Phase recovery and resume](../independent-review/references/checkout-state.md#phase-recovery-and-resume) governs suites, attempts and retries.
- **Checkout changed:** pause retries; with the write and its diff preserved, adjudicate within authority. A reviewer write to task state or a moved HEAD invalidates the attempt; a demonstrably unrelated scratch write with state and coverage intact is recorded without spending; never fold a reviewer's edit into a fix commit or reset unrelated work; unresolved ownership blocks.
- **Budget:** any other invalid attempt spends the round's budget, an initial attempt plus one retry with the same assignment, never reset by reconciliation; a second invalid attempt blocks.

**Dual round result.** The dual review's return replaces the loop's budget:

- `report.md` completes the round. Its derived verdict is the round's, reported with both reviewers' derived verdicts, never relabelled. Adjudicate its confirmed findings below (an `unrated` one as accepted or rejected, never deferred) and take its cross-check results as given. No report candidate is fixed on this session's own evidence: round 1's candidates are carried in the final pass's ledger input; the final pass's or a disposition round's go as prior-finding context to the first scoped round, else are recorded for the user.
- `checkout changed: <state.md>`: adjudicate as above; an unattributable parallel write is a reviewer write (`invalidating` unless demonstrably unrelated scratch). Resume with `independent-review --dual --resume <state.md> --write scratch|invalidating` ([State and resume](../independent-review/references/dual.md#state-and-resume)).
- `blocked: <system> invalid result` blocks the round.

**Ledger IDs.** Single-system: `R<round>-F<n>` from the round and source ID, or the ID of the ledger finding it repeats ([source and ledger IDs](../independent-review/references/review-wrapper.md#findings-and-derived-verdict)). Dual: the dual review assigns `D<n>`; in a scoped round the loop owner numbers new in-scope findings from `Next D`, recorded `raised by <system> <source ID>`, with no cross-check. A scoped-round repeat of a cross-check rejection without new evidence stays `repeat, unchanged`; when such repeats alone make the scoped verdict `CHANGES`, step 5's `clean` counts that verdict as met. A resumed dual record whose scoped dual review already started (`state.md` exists) finishes it as a dual review.

Adjudicate every finding in the record by its normalized severity ([severity map](../independent-review/references/review-wrapper.md#findings-and-derived-verdict)):

- **Accepted:** a critical or important defect or a spec-compliance gap requires a fix. A runnable reproduction demonstrating a violated requirement is accepted after verification, whatever the opinion.
- **Rejected:** needs a checkable quoted requirement or test showing correct behaviour; an unsupported opinion rejects nothing. An `unrated` finding is accepted or rejected on its evidence, never deferred.
- **Minor:** fixed in the round's fix commit; a round of only minor findings still makes that commit. A minor finding whose fix would change the spec or plan, or needs an open decision, is **Outside-scope**, its reason naming that. One unfixed at the round limit is `deferred: round limit` and holds back neither clean mode.
- **Disputed:** after a recorded rejection with basis, the reviewer re-raises the same scenario and requirement without new evidence (a reproduction, code reference or requirement quote the ledger entry lacks; a moved line alone keeps identity). Record both positions and the fix-or-dismiss question for the user, and spend no further rounds on it. Under `--auto` the question leaves with the report and is settled by auto.md's [`CLEAN EXCEPT DISPUTED`](../child-sessions/references/auto.md#deciding) rule, applied by the first session.
- **Outside-scope:** pre-existing or outside-task candidates, recorded once for the report.
- **Not re-raised:** an accepted finding fixed in the reviewed range and absent from the next report; never "verified by the reviewer".
- **Rejected by cross-check** (dual): recorded with raiser, source ID and verifier evidence, and closed: not fixed, not disputed, never blocking `clean`. A later repeat changes nothing; a renewed rejection adds the re-raise's evidence; a confirmation brings it under the rules above.

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
