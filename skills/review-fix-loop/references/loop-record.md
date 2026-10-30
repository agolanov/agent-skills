# Loop Record

Reuse an existing task log outside the checkout when possible. This is a short Markdown example, not a parser format. Fill it with inspected facts; do not copy illustrative status/evidence as a result.

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
Selection/runtime evidence: <catalog/schema and actual runtime/log evidence>
Round limit: 5 <or explicit user limit>
Completed rounds: 0
Final pass: not run <or round/commit>
Pending round: 1; invalid attempts: 0 of 2

## Round 1
Target: <range|fix commit|dispositions only>
Reviewed commit: <HEAD>
Previous verdict: <none or verdict>
Result validity/completion: <exit or native completion; metadata; unchanged-state evidence; omissions>
Verdict: <CLEAN|CHANGES>
Findings/decisions:
- F1 <severity>; <path:line>; <scenario/requirement/evidence>; <accepted | rejected: quoted requirement or test | deferred | disputed | outside-scope>; <fix/verification or both disputed positions and human question>
- C1 outside-round candidate: <evidence; pending final pass disposition, or immediate adjudication if it already ran>
Fix commit: <single hash and finding IDs, or none; next is final/disposition review>
Checks: <commands/results and commit>
Pending-round retry count: <retained across reconciliation>

## Finish
Status: <running | clean | clean except disputed | blocked: reason>
Final reviewed commit: <HEAD>
Raw last verdict: <CLEAN|CHANGES; if dispute-only CHANGES closes, preserve it and explain why all other completion conditions hold>
Implementing-session complete suite: <command/exit/evidence on final commit>
Decisions/candidates: <disputed both positions and fix-or-dismiss question; deferred minors; outside-scope; unresolved findings>
Squash command for the user (not executed): <command per `review-fix-loop` step 5>
```
