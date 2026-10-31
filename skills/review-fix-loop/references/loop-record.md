# Loop Record

Reuse an existing task log outside the checkout when possible. This is a short Markdown example, not a parser format. Fill it with inspected facts; do not copy illustrative status/evidence as a result.

With the `dual` assignment, findings carry dual-review's merged IDs `D<n>` with their raisers and source IDs, the record keeps `Next D`, and each round adds its `Dual record` line. A cross-check rejection keeps the raiser, source ID, the finding as raised and the verifier's evidence: each next round passes those entries and `Next D` to dual-review as its ledger input.

```markdown
# Review Fix Loop record
Status: running
Checkout: /absolute/task
Branch: feature/task
Base: <fixed base>
Pre-loop HEAD (squash anchor): <last task commit before the loop>
Requirements/rules/checks: <links or concise text>
Exclusions: <unrelated files and preserved index/worktree state>
Assignment: <cli|subagent>/<codex|claude>, model <exact>, effort <exact>
<or> Assignment: dual: codex <model>/<effort>; claude <model>/<effort>
Selection/runtime evidence: <catalog/schema and actual runtime/log evidence; dual: per reviewer>
Round limit: 5 <or explicit user limit>
Completed rounds: 0
Final pass: not run <or round/commit>
Pending round: 1; invalid attempts: 0 of 2 <dual: spent attempts per reviewer per call in the round's state.md>
Next D: <dual: next free D<n>, starting at 1>

## Round 1
Target: <range|fix commit|dispositions only>
Reviewed commit: <HEAD>
Previous verdict: <none or verdict>
Result validity/completion: <exit or native completion; metadata; unchanged-state evidence; omissions; dual: the dual-review return>
Dual record: <dual dir>; raw verdicts codex <CLEAN|CHANGES>, claude <CLEAN|CHANGES>; cross-check: <D-ids confirmed / rejected / repeat>
Verdict: <CLEAN|CHANGES; dual: the report's derived verdict>
Findings/decisions:
- F1 <severity>; <path:line>; <scenario/requirement/evidence>; <accepted | rejected: quoted requirement or test | deferred | disputed | outside-scope>; <fix/verification or both disputed positions and human question>
- D2 <severity>; <path:line>; raised by codex F2; <scenario/requirement/evidence as raised>; rejected by cross-check: claude, <verifier evidence>; closed <or: repeat, unchanged>
- C1 outside-round candidate: <evidence; pending final pass disposition, or immediate adjudication if it already ran>
Fix commit: <single hash and finding IDs, or none; next is final/disposition review>
Checks: <commands/results and commit>
Pending-round retry count: <retained across reconciliation>

## Finish
Status: <running | clean | clean except disputed | blocked: reason>
Final reviewed commit: <HEAD>
Raw last verdict: <CLEAN|CHANGES; if dispute-only CHANGES closes, preserve it and explain why all other completion conditions hold; dual: derived <..>, raw codex <..>, claude <..>>
Implementing-session complete suite: <command/exit/evidence on final commit>
Decisions/candidates: <disputed both positions and fix-or-dismiss question; deferred minors; outside-scope; unresolved findings; dual: rejected by cross-check with both positions>
Squash command for the user (not executed): <command per `review-fix-loop` step 5>
```
