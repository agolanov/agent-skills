---
name: review-fix-loop
description: Use when an independent review/fix cycle is requested with an assigned reviewer, or another refine skill supplies that assignment. For a one-off review without fixes, use independent-review.
---

# Review Fix Loop

The implementing session owns decisions, fixes and the loop. An independent reviewer checks the task; launchers supply the assignment.

## Skill composition

Keep normal skill discovery and automatic invocation active in both sessions; read and apply matching skills at each stage. Compose their methods and style with review-fix-loop's role, scope, verdict, finding evidence, prior dispositions, coverage and checks.

## 1. Establish scope and reviewer

Resolve the absolute task checkout (including a worktree used by the implementation), branch, HEAD, fixed task base, requirements and checks. Include branch changes, staged/unstaged task changes and task-owned untracked files; preserve unrelated work and list exclusions. Resolve ambiguous scope first.

### Launch assigned reviewer

Read [independent-review](../independent-review/SKILL.md), using the installed catalog if its sibling is unavailable. Missing dependency: report that the complete bundle is required and stop before review/fixes; do not install or invent the protocol. Require the assignment per its **Assignment** section.

Keep one [loop record](references/loop-record.md) outside the checkout; reuse an existing task log. Record the resolved assignment there. Use the explicit round limit, otherwise five completed rounds.

## 2. Commit the reviewed state

Invoking review-fix-loop or a launcher explicitly requests a task-state commit and one fix commit per round on the task branch, satisfying "commit only when asked" rules. Before the first commit, stop on detached HEAD or the default branch (`main`/`master` or configured default) and ask for branch/commit confirmation unless already authorized in the request. This authority covers exactly those commits on the task branch; anything else (push, merge, rebase, amend, squash, deploy, worktree creation, installation, persistent configuration changes) needs its own authorization.

Record the pre-loop HEAD for the user's squash command. Commit task-owned staged/unstaged and untracked changes as `review-fix-loop: task state before review` if present. Select exact task paths and commit only them; an ordinary commit of the whole index could absorb unrelated staged work. Preserve unrelated index/worktree changes and record their exclusions and existing status. After each fix batch, run affected checks and make exactly one commit naming the round and finding IDs. Run the complete suite before creating any commit that may become the final reviewed HEAD; when its role is unknown, assume it may. The final-pass reviewer runs the suite again independently. Every review targets a recorded commit; keep it stable during review.

## 3. Request independent review

Obtain each attempt from independent-review with the round's target row and order. Carry requirements/rules/checks, previous verdict, and the full finding ledger with evidence and disposition basis. Select the target and order:

| Review | Target and order |
| --- | --- |
| Round 1 | Complete task `<base>..HEAD` against original requirements. |
| Scoped round | Previous round's single fix commit; verify each accepted fix and its regressions first, then defects introduced by that commit. Keep required prior-finding dispositions. |
| Final pass | Complete task `<base>..HEAD`, prior fixes first; include accumulated outside-round candidates, complete test suite and security-focused review. |
| Disposition round | Same HEAD, ledger dispositions only; confirm them or re-raise with evidence. |

In scoped rounds, defects noticed outside the fix commit are outside-round candidates: without widening this review, record them for the final pass if it is still pending. After that sole pass has run, adjudicate new candidates immediately by evidence; accepted task defects get a fix commit and scoped verification within the remaining limit, other candidates get a recorded disposition. Pre-existing outside-task problems stay separate and never block.

## 4. Validate and decide

Each attempt comes back validated by independent-review (its **Validate** section) as `valid`, `invalid: <reason>` or `checkout changed`, with its `result.md`; copy those facts into the round's "Result validity/completion" field.

Any new or changed checkout file (`checkout changed`) requires adjudication. With the unexpected work and its diff preserved and its source identified by independent-review, pause retries for implementing-session adjudication/reconciliation and affected checks within authority. Unresolved ownership/scope blocks. Do not silently incorporate a reviewer's edit in the fix commit or reset unrelated work. Outcomes:

- A reviewer write to task state, or a moved HEAD, invalidates the attempt.
- A demonstrably unrelated scratch write with required state and coverage intact is recorded without spending a retry.
- Any other invalid attempt spends the shared budget: initial attempt plus one retry per pending round, same assignment; reconciliation or new commits do not reset it. A second invalid attempt blocks.

Adjudicate every finding in the [record](references/loop-record.md):

- **Accepted:** a critical/important defect or spec-compliance gap requires a fix. A runnable reproduction that demonstrates a violated requirement is accepted after verification, regardless of opinion.
- **Rejected:** give a checkable quoted requirement or test demonstrating correct behavior. An unsupported opinion cannot reject a finding.
- **Deferred:** minor/style findings are fixed cheaply alongside defects or listed for the user. They never start a fix round alone and are not open blocking defects.
- **Disputed:** after a recorded rejection with basis, a reviewer re-raises the same scenario/violated requirement without new evidence. A moved line alone preserves identity; new evidence instead requires fresh evaluation. Record both positions and the fix-or-dismiss question for the user, continue other work and spend no further rounds on that finding.
- **Outside-scope:** record pre-existing/outside-task candidates once for the final report; outside-round candidates follow step 3.

## 5. Fix, repeat and finish

Fix accepted defects in one round commit, including cheap minor fixes, run affected required checks and request its scoped review. A failed required check (even PASS text with nonzero exit) blocks dependent work; use matching debugging skills, resolve within authority and rerun. Missing dependencies needing broader authority are reported blockers.

A valid round-1 CLEAN can finish immediately if the full suite passes on that commit. Otherwise, after a scoped CLEAN or a round with no fix commit (all findings rejected/deferred/outside-scope), run the **one final complete pass** if it has not run. Final-pass findings return through ordinary fix-commit/scoped rounds; there is never a second complete pass. If no fix commit exists after the final pass, use at most one disposition round per disposition set on the same HEAD: CLEAN confirms, an evidence-free repeat becomes disputed.

**No progress:** if successive rounds return the same finding set with no accepted fix, stop repeating that unchanged review. Fix confirmed defects now and verify within remaining rounds, or mark eligible evidence-free repeats disputed; an unresolved non-disputed defect blocks rather than silently disappearing.

**Limit:** every valid result counts, including final/disposition passes; invalid attempts never do. At the cap, adjudicate every open finding with a recorded reason. A last small unambiguous fix commit is allowed only when its scoped verification still fits within the limit. Otherwise report `blocked: round limit` with unresolved findings and next action.

Report:

- `clean`: valid CLEAN on final HEAD, required final pass completed when more than one round ran, implementing-session full suite passing on that commit, no unresolved accepted critical/important defects or compliance gaps, and outside-round candidates adjudicated.
- `clean except disputed`: the same coverage, final-pass, commit and check conditions, plus disputed findings with both positions and the fix-or-dismiss question. A substantive final/scoped/disposition `CHANGES` may close in this status when its only remaining blocking claims are evidence-free repeats now adjudicated `disputed`, every other finding is resolved/deferred/outside-scope, and no further required review remains. Preserve the raw `CHANGES` verdict and explain this disposition-based closure; never relabel the reviewer result CLEAN. Deferred minors alone do not qualify for this exception.
- `blocked: <reason>`: exhausted invalid attempts or round limit, failed required checks, missing dependencies, unresolved edit ownership, or unmet completion requirements.

Later task edits invalidate the reviewed result. Report rounds/targets/commits, assignment/evidence, checks, all decisions, deferred/disputed findings and outside-scope candidates. Print the user's squash command without executing it; leave round history unsquashed. With no excluded staged work: `git reset --soft <pre-loop HEAD> && git commit`. If unrelated staged changes remain, print `git reset --soft <pre-loop HEAD> && git commit --only -- <exact task paths>` instead, binding and quoting the task paths so the commit preserves excluded staging.
