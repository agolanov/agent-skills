# Dual Record

`state.md` and `report.md` live in `<dual dir>`, outside the checkout; a caller's ledger input comes with the call. These are short Markdown examples, not parser formats. Fill them with inspected facts; do not copy illustrative results.

## state.md

```markdown
# Dual review state
Checkout: /absolute/checkout <or clone <dual dir>/tree of /absolute/checkout>
Branch: feature/task
Fixed base: <full sha>
Reviewed commit: <full sha>
Target row and order: <final pass, direct use | caller's row and order>
Requirements/rules/checks: <links or concise text>
Resolved complete suite: <ordered exact commands; cwd/source | no complete suite defined>
Targeted checks: <commands; cwd/source>
Unavailable coverage: <None | checks/reasons>
Assignment: dual (<background|window>): codex <model>/<effort>; claude <model>/<effort>
Settings evidence: <per reviewer: discovery and runtime records>
Window identity: <not applicable (background) | persisted token path/allocation; owner entrypoint; per-attempt names/launch IDs/capabilities; clone/source mappings>
Complete suite: `<ordered commands/cwd>`, exits <n>, commit <full sha>, checkout <absolute>, known environment changes <None|details>, run by this session (Git outputs/comparison under Phases) <or: the caller's run | no complete suite defined>
Ledger: none <or the caller's ledger input, below>; next D: 1
Phase: suite | review | cross-check | done | blocked
Block reason: None | <codex|claude|codex and claude> invalid result (budget exhausted) | <codex|claude|codex and claude> reviewer shutdown unconfirmed (completion recovery pending)
Interrupted: none <or: checkout changed after <phase> (<reviewers in it> | the suite); answer pending | scratch | invalidating; resume refused: monitored content not restored, comparison <path>; retained recovery baseline <path>>
Completion recovery: <None | affected phase/attempts; every participant's owner/name/launch and actual close/alive exits/diagnostics; pending before baseline in every tree; retained spend; saved attempt results; resume via --resume <state.md>, fresh alive 1 for all before final Git comparison/adjudication/retry; --write only for proven-write adjudication after that boundary>

## Attempts
- codex review: spent 0 of 2
  - attempt-1: valid; <dual dir>/review/codex/attempt-1/result.md; commit <sha>
    Dialogs: answered 3; declined 1; escalated 1
- claude review: spent 1 of 2
  - attempt-1: invalid: unsuccessful completion; <dual dir>/review/claude/attempt-1/result.md
    Dialogs: answered 0; declined 0; escalated 0
  - attempt-2: valid; <dual dir>/review/claude/attempt-2/result.md; commit <sha>
    Dialogs: answered 0; declined 0; escalated 0
- codex cross-check: spent 0 of 2
  - attempt-1: valid; <dual dir>/cross-check/codex/attempt-1/result.md; commit <sha>
    Dialogs: not observable: <unsupported observation capability>
- claude cross-check: spent 0 of 2
- voided by restart on <new sha> (spend nothing): <result.md paths with their commit>
- completion-pending example: <system/phase/attempt>; invalid: reviewer shutdown unconfirmed <or checkout changed; otherwise invalid: reviewer shutdown unconfirmed>; <result.md>; spend <already charged once | pending existing caller rule>; Dialogs: <saved record>

## Phases
- <suite | review | cross-check | retry>; attempts <identifiers>; owned shutdown <not applicable | per-participant owner/name/launch, close/alive exits and retained-window diagnostics>; tree <clone/original/checkout>: before/after <Git output/exit/diagnostic paths; final after only once every participant is stopped>; comparison <result path and exit>; errors <None|details>; preserved diff <path>; pending recovery baseline <path|None>; ignored files and untracked-file contents not covered; Git flags/normalization may hide bytes; nested repositories/submodules not recursively covered; transient restored writes not detected
- Reconciled new-commit baseline: <explicit caller target/authorization, Git outputs, unexplained residual changes check | None>
```

## report.md

```markdown
# Dual review report
Checkout: /absolute/checkout; target <base>..<reviewed commit>; state <dual dir>/state.md

## Verdict
Derived: CHANGES
Raw (each reviewer's own, as given): codex CHANGES; claude CHANGES
Verification: complete | incomplete: <specific required commands/cwd/exits/reasons and coverage gaps; no complete suite defined when applicable>

## Confirmed findings
### D1 critical (codex minor, claude critical)
- Location: module.py:5 (codex), module.py:4 (claude)
- Scenario: <triggering condition and wrong outcome>
- Violated requirement: "<quoted>"
- Evidence: <raiser's evidence; verifier's evidence when cross-checked>
- Proposed fix: <...>
- Raised by: codex, claude; confirmed by: both <or, for a unique finding: raised by codex; confirmed by: cross-check by claude>
- Sources: codex F1, claude R1

## Rejected by cross-check
### D2 (claude R2)
- Finding: <as raised>
- Raiser's position: <claude's scenario, requirement and evidence>
- Verifier's evidence: <codex's quoted requirement, code read or run>
- Repeat: no <or: repeat, raised again without new evidence; not cross-checked>

## Candidates
- outside-task: <finding and evidence>; raised by codex F2

## Matching decisions
- codex F1 + claude R1: one finding; same scenario (value equal to the limit rejected) and requirement, different lines.
- claude R2: no match; no codex finding shares its location or requirement.

## Complete suite
`<ordered commands/cwd/source>` exits <n> on <full sha>, checkout <absolute>, Git outputs/comparison <paths>, environment changes <None|details>, coverage limits <details>, run by this session <or: no complete suite defined>
Per-attempt Suite evidence: inherited: <records | None: caller supplied no suite evidence>; independently executed: <records | None: not required in this phase | missing: commands/reasons | no complete suite defined>
Targeted checks: <separate actual reproductions/checks with commands/results/evidence | None>

## Dialogs
- review/codex/attempt-1: answered 3; declined 1; escalated 1
- review/claude/attempt-1 (invalid): answered 0; declined 0; escalated 0
- review/claude/attempt-2 (retry): answered 0; declined 0; escalated 0
- cross-check/codex/attempt-1: not observable: <unsupported observation capability>
- Observable counters (partial): answered 3; declined 1; escalated 1; not observable: cross-check/codex/attempt-1

## Codex
- Settings and evidence: <model/effort and runtime records; result.md paths>
- Coverage: <as reported, with omissions>
- Checks run: <as reported; inherited evidence separate>

## Claude
- Settings and evidence: <...>
- Coverage: <...>
- Checks run: <...>
```

The dialog examples show window records; a background run instead uses `not applicable (background)` for every attempt. Retain one record per saved attempt across review, retries and cross-checks, including invalid attempts; resume deduplicates those identities. Aggregates name nonobservable attempts alongside observable totals; `declined` is a subset of `answered`, and escalations can later be answered. Keep raw verdicts as given beside the derived verdict. Direct output carries these records; a shutdown block points to `state.md` and its retained attempt records.

## Ledger input

A caller such as `review-fix-loop` passes its full finding ledger and `Next D` ([dual review](dual.md#4-matching) step 4); direct use has none.

```markdown
Next D: 3
- D1 critical (codex minor, claude critical); module.py:5; raised by codex F1, claude R1; scenario <as stated>; requirement <as stated>; evidence <as stated>; accepted; fixed in <fix commit>
- D2; module.py:2; raised by claude R2; scenario <as stated>; requirement <as stated>; evidence <as stated>; rejected by cross-check: codex, <verifier evidence>; re-raised with <re-raised evidence>; rejected by cross-check again: codex, <verifier evidence>
- C1 (outside-round): <finding and evidence>; raised by claude R3; carried from round 2
```
