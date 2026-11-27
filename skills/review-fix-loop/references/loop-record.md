# Loop Record

The one format of the loop record, kept outside the checkout (an existing task log is reused). A Markdown example, not a parser format: fill it with inspected facts.

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
Assignment: <background|window>/<codex|claude>[ via <command>], model <exact>, effort <exact>; engine native: codex review | native: /code-review <level | none (cli-default)>
<or> Assignment: dual (<background|window>): codex[ via <command>] <model>/<effort>; claude[ via <command>] <model>/<effort>
Settings evidence: <requested and observed model/effort, the record read, unverified fields; dual: per reviewer>
Round limit: 20 <or explicit user limit; raised to <n> at a checkpoint>
Reviewer settings by target: initial settings on every round; <explicit user final-pass settings, if any>
Completed rounds: 0
Checkpoints (round limit): <not reached | per checkpoint: limit reached; cause; recommendation; answer (stop | <n> more rounds[, reviewer settings]) and who gave it>
Final pass: not run <or round/commit>
Pending round: 1; invalid attempts: 0 of 2 <dual: spent attempts per reviewer per call in the round's state.md>
Next D: <dual: next free D<n>, starting at 1>

## Round 1
Effective reviewer settings: <per system: exact model/effort; dual loop's scoped round: the one reviewer, <system> <model>/<effort>; settings evidence; retained on retry>
Target: <review kind; range <base>..<head> | files <paths> at <head>; added wrapper line: security | none | decisions only>
Reviewed commit: <HEAD>
Context file: <absolute path of the attempt's context.md>
Findings file: <absolute path of the attempt's findings.md>
Last derived verdict: <none or the previous round's derived verdict>
Result validity/completion: <exit or native completion; metadata; monitored-state evidence; omissions; dual: the dual review's return>
Dual record: <dual dir>; derived codex <CLEAN|CHANGES>, claude <CLEAN|CHANGES>; cross-check: <D-ids confirmed / rejected / repeat> <or: not applicable (scoped round)>
Derived verdict: <CLEAN|CHANGES, derived by the session from the native report; dual: the report's derived verdict>
Findings/decisions:
- R1-F1 (source F1) native <P1 | important | ...>, <critical | important | minor | unrated>; <path:line>; <scenario/requirement/evidence>; <accepted | minor | rejected: quoted requirement or test | deferred: round limit | disputed | outside-scope | not re-raised>; <fix/verification or both disputed positions and human question>
- D2 <normalized severity>; <path:line>; raised by codex F2; <scenario/requirement/evidence as raised>; rejected by cross-check: claude, <verifier evidence>; closed <or: repeat, unchanged | re-raised with <evidence>; rejected again: <verifier evidence>>
- C1 outside-round candidate: <evidence; adjudicated at once by evidence; from a resumed record with the final pass pending: carried to it; dual, from a dual review's report: raised by <reviewer> <source ID>; round 1's carried in the final pass's ledger input, the final pass's carried to the first scoped round, or recorded for the user when none follows>
Fix commit: <single hash and finding IDs, or none>; next: <final pass | scoped round | no review: minor-only | disposition round>
Checks: <fresh commands/cwd/exits/tested states/checkout and affected coverage; immutable run paths; Git outputs/comparison; dependency/profile/environment facts and gaps>
Acceptance: <current committed target; original-run/acceptance links; intervening differences and disposition; unchanged coverage and fresh checks; pending broader coverage and phase/producer obligations>
State: <before/after Git output/exit/diagnostic paths; comparison result/exits/errors; retained recovery baseline>; ignored files and untracked-file contents not covered; Git flags/normalization may hide bytes; nested repositories/submodules not recursively covered; transient restored writes not detected
Verification: complete | incomplete: <checks/coverage gaps>
Pending-round retry count: <retained across reconciliation; dual: spent attempts per reviewer per call in the round's state.md>

## Finish
Status: <running | clean | clean except disputed | blocked: reason>
Final reviewed commit: <commit of the last valid review>; final HEAD: <HEAD, with "unreviewed minor-only fix commit" only when that commit took the `no review: minor-only` row>
Last derived verdict: <CLEAN|CHANGES, derived by the session from the native report; after a minor-only fix commit left without review: the last review's derived verdict as recorded, plus "minor fixes <IDs> in <commit> closed without review"; if dispute-only CHANGES closes, preserve it and explain why all other completion conditions hold; dual: derived <..>, derived codex <..>, claude <..>>
Final composed verification: <current committed target; original runs/tested states and acceptance links; retained/fresh passing coverage per required item; satisfied phase/producer obligations; actual full executions distinguished from composed coverage; pending/failed/unavailable checks>
Decisions/candidates: <disputed both positions and fix-or-dismiss question; minors deferred at the round limit; outside-scope; unresolved findings; dual: rejected by cross-check with both positions>
Squash command for the user (not executed): <command per `review-fix-loop` step 5>
```

## Dual rounds

Resolve both assignments by [dual settings](../../independent-review/references/dual.md#1-settings-and-target). Pass `--reviewer-effort` to both; for `--reviewer-model` ask which reviewer it selects. Prose may set one reviewer's model or effort using `--codex-model`, `--codex-effort`, `--claude-model` or `--claude-effort`.

- **Round 1, final pass and disposition.** Request [dual review](../../independent-review/references/dual.md) with the review kind, target, recorded place and settings, round directory, suite runs/acceptances and pending coverage. Pass the full [ledger input](../../independent-review/references/dual.md#4-matching), carried candidates and `Next D`. The dual review runs the suites and owns its attempt budgets.
- **Result.** A `report.md` completes the round. Keep its derived verdict and both reviewers' verdicts. Adjudicate confirmed findings, including unrated ones. Carry round 1 report candidates to the final pass; carry final or disposition candidates as prior findings to the first scoped round, or report them to the user. Do not fix a dual report candidate on the loop owner’s evidence alone.
- **Cross-check decisions.** Keep each rejected finding closed with its raiser, source ID, original claim and verifier evidence. Record a repeat without new evidence as `repeat, unchanged`; append new evidence to a renewed rejection. A confirmation returns to ordinary adjudication.
- **Scoped round.** Use one reviewer opposite the loop owner, with that reviewer's recorded command, place and settings. Apply ordinary single-attempt, candidate and retry rules. Assign new in-scope findings from `Next D`, recording `raised by <system> <source ID>; no cross-check`. If an older record already has a started scoped dual review (`state.md` exists), finish it as dual.
- **Interrupted round.** A system-qualified block keeps its reason. On `checkout changed: <state.md>`, apply step 4's ownership rule; an unattributable parallel write is invalidating unless demonstrably unrelated scratch. Continue by [State and resume](../../independent-review/references/dual.md#state-and-resume) with the recorded state and write decision.
