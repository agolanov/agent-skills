# Loop Record

Reuse an existing task log outside the checkout when possible. This is a short Markdown example, not a parser format. Fill it with inspected facts; do not copy illustrative status/evidence as a result.

With the `dual` assignment, findings carry the merged IDs `D<n>` of the [dual review](../../independent-review/references/dual.md) with their raisers and source IDs, the record keeps `Next D`, and each round adds its `Dual record` line. Each next round passes the full finding ledger (every `D<n>` line with its disposition, the carried candidates) and `Next D` to the dual review as its [ledger input](../../independent-review/references/dual.md#4-matching); a cross-check rejection keeps the raiser, source ID, the finding as raised, the verifier's evidence and each re-raise's evidence.

```markdown
# Review Fix Loop record
Status: running
Checkout: /absolute/task
Branch: feature/task
Base: <fixed base>
Pre-loop HEAD (squash anchor): <last task commit before the loop>
Target form: range | files: <repository-relative paths>
Related code: <absolute project checkout for a document review | None>
Requirements/rules/checks: <links or concise text>
Resolved complete suite: <ordered exact commands; cwd/source | no complete suite defined>
Targeted checks: <commands; cwd/source and intended coverage>
Required phase/producer: <per check, source and obligation; None when absent>
Original runs: <immutable absolute records, original tested checkout/HEAD/dirty state>
Current acceptance: <absolute record; current committed target and inspected differences>
Coverage: <per required item: retained | fresh | pending | failed/unavailable>
Unavailable coverage: <None | checks/reasons>
Exclusions: <unrelated files and preserved index/worktree state>
Assignment: <background|window>/<codex|claude>, model <exact>, effort <exact>; engine native: codex review | native: /code-review <level | none (cli-default)>
<or> Assignment: dual (<background|window>): codex <model>/<effort>; claude <model>/<effort>
Selection/runtime evidence: <catalog/schema and actual runtime/log evidence; dual: per reviewer>
Round limit: 10 <or explicit user limit>
Reviewer settings by target: round 1, scoped and disposition rounds initial settings; final pass Claude Fable 5.2/xhigh and/or GPT-6.2 Astra/xhigh; <explicit user exception, if any>
Flagship pair: <not needed: round 1 finished | exact identifiers/effort and selection evidence, resolved after round 1 | blocked: unavailable or unverified pair>
Completed rounds: 0
Checkpoint (five completed rounds): <not reached | cause; recommendation; answer and who gave it>
Final pass: not run <or round/commit>
Pending round: 1; invalid attempts: 0 of 2 <dual: spent attempts per reviewer per call in the round's state.md>
Next D: <dual: next free D<n>, starting at 1>

## Round 1
Effective reviewer settings: <per system: exact model/effort; selection/runtime evidence; retained on retry>
Target: <review kind; range <base>..<head> | files <paths> at <head>; added wrapper line: security | none | decisions only>
Reviewed commit: <HEAD>
Context file: <absolute path of the attempt's context.md>
Findings file: <absolute path of the attempt's findings.md>
Last derived verdict: <none or the previous round's derived verdict>
Result validity/completion: <exit or native completion; metadata; monitored-state evidence; omissions; dual: the dual review's return>
Dual record: <dual dir>; derived codex <CLEAN|CHANGES>, claude <CLEAN|CHANGES>; cross-check: <D-ids confirmed / rejected / repeat>
Derived verdict: <CLEAN|CHANGES, derived by the session from the native report; dual: the report's derived verdict>
Findings/decisions:
- F1 native <P1 | important | ...>, <critical | important | minor | unrated>; <path:line>; <scenario/requirement/evidence>; <accepted | rejected: quoted requirement or test | deferred | disputed | outside-scope | not re-raised>; <fix/verification or both disputed positions and human question>
- D2 <normalized severity>; <path:line>; raised by codex F2; <scenario/requirement/evidence as raised>; rejected by cross-check: claude, <verifier evidence>; closed <or: repeat, unchanged | re-raised with <evidence>; rejected again: <verifier evidence>>
- C1 outside-round candidate: <evidence; pending final pass disposition, or immediate adjudication if it already ran; dual: raised by <reviewer> <source ID>; carried in the next ledger input, or recorded for the user after the final pass>
Fix commit: <single hash and finding IDs, or none; next is final/disposition review>
Checks: <fresh commands/cwd/exits/tested states/checkout and affected coverage; immutable run paths; Git outputs/comparison; dependency/profile/environment facts and gaps>
Acceptance: <current committed target; original-run/acceptance links; intervening differences and disposition; unchanged coverage and fresh checks; pending broader coverage and phase/producer obligations>
State: <before/after Git output/exit/diagnostic paths; comparison result/exits/errors; retained recovery baseline>; ignored files and untracked-file contents not covered; Git flags/normalization may hide bytes; nested repositories/submodules not recursively covered; transient restored writes not detected
Verification: complete | incomplete: <checks/coverage gaps>
Pending-round retry count: <retained across reconciliation; dual: spent attempts per reviewer per call in the round's state.md>

## Finish
Status: <running | clean | clean except disputed | blocked: reason>
Final reviewed commit: <HEAD>
Last derived verdict: <CLEAN|CHANGES, derived by the session from the native report; if dispute-only CHANGES closes, preserve it and explain why all other completion conditions hold; dual: derived <..>, derived codex <..>, claude <..>>
Final composed verification: <current committed target; original runs/tested states and acceptance links; retained/fresh passing coverage per required item; satisfied phase/producer obligations; actual full executions distinguished from composed coverage; pending/failed/unavailable checks>
Decisions/candidates: <disputed both positions and fix-or-dismiss question; deferred minors; outside-scope; unresolved findings; dual: rejected by cross-check with both positions>
Squash command for the user (not executed): <command per `review-fix-loop` step 5>
```
