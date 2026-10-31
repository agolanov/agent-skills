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
Assignment: codex cli, model <exact>, effort <exact>; claude cli, model <exact>, effort <exact>
Settings evidence: <per reviewer: discovery and runtime records>
Complete suite: `<command>`, exit <n>, commit <full sha>, run by this session (state check under Phases) <or: the caller's run | no complete suite defined>
Ledger: none <or the caller's ledger input, below>; next D: 1
Phase: suite | review | cross-check | done | blocked: <codex|claude|codex and claude> invalid result
Interrupted: none <or: checkout changed after <phase> (<reviewers in it> | the suite); answer pending | scratch | invalidating; resume refused: not restored, porcelain <current>>

## Attempts
- codex review: spent 0 of 2
  - attempt-1: valid; <dual dir>/review/codex/attempt-1/result.md; commit <sha>
- claude review: spent 1 of 2
  - attempt-1: invalid: exit 1; <dual dir>/review/claude/attempt-1/result.md
  - attempt-2: valid; <dual dir>/review/claude/attempt-2/result.md; commit <sha>
- codex cross-check: spent 0 of 2
  - attempt-1: valid; <dual dir>/cross-check/codex/attempt-1/result.md; commit <sha>
- claude cross-check: spent 0 of 2
- voided by restart on <new sha> (spend nothing): <result.md paths with their commit>

## Phases
- suite, this session's run: HEAD <before> -> <after>; porcelain <identical | differs: <dual dir>/suite/<diff path>>
- review, codex attempt-1 + claude attempt-1 in parallel: HEAD <before> -> <after>; porcelain <identical | differs: <preserved diff paths>>
- review retry, claude attempt-2 alone: HEAD <before> -> <after>; porcelain identical
- cross-check, codex attempt-1 alone: HEAD <before> -> <after>; porcelain identical
```

## report.md

```markdown
# Dual review report
Checkout: /absolute/checkout; target <base>..<reviewed commit>; state <dual dir>/state.md

## Verdict
Derived: CHANGES
Raw (each reviewer's own, as given): codex CHANGES; claude CHANGES

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
`<command>` exit <n> on <full sha>, run by this session <or: no complete suite defined>

## Codex
- Settings and evidence: <model/effort and runtime records; result.md paths>
- Coverage: <as reported, with omissions>
- Checks run: <as reported; inherited evidence separate>

## Claude
- Settings and evidence: <...>
- Coverage: <...>
- Checks run: <...>
```

## Ledger input

A caller such as `review-fix-loop` passes its full finding ledger and `Next D` (dual-review step 4); direct use has none.

```markdown
Next D: 3
- D1 critical (codex minor, claude critical); module.py:5; raised by codex F1, claude R1; scenario <as stated>; requirement <as stated>; evidence <as stated>; accepted; fixed in <fix commit>
- D2; module.py:2; raised by claude R2; scenario <as stated>; requirement <as stated>; evidence <as stated>; rejected by cross-check: codex, <verifier evidence>; re-raised with <re-raised evidence>; rejected by cross-check again: codex, <verifier evidence>
- C1 (outside-round): <finding and evidence>; raised by claude R3; carried from round 2
```
