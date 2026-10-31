# Dual Record

`state.md` and `report.md` live in `<dual dir>`, outside the checkout. These are short Markdown examples, not parser formats. Fill them with inspected facts; do not copy illustrative results.

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
Complete suite: `<command>`, exit <n>, commit <full sha> <or: no complete suite defined>
Ledger: none <or caller's ledger path>; next D: 1
Phase: review | cross-check | done | blocked
Interrupted: none <or: checkout changed after <phase> (<reviewers in it>); answer pending | scratch | invalidating>

## Attempts
- codex review: spent 0 of 2
  - attempt-1: valid; <dual dir>/review/codex/attempt-1/result.md; commit <sha>
- claude review: spent 1 of 2
  - attempt-1: invalid: exit 1; <dual dir>/review/claude/attempt-1/result.md
  - attempt-2: valid; <dual dir>/review/claude/attempt-2/result.md; commit <sha>
- codex cross-check: spent 0 of 2
- claude cross-check: spent 0 of 2
  - attempt-1: valid; <dual dir>/cross-check/claude/attempt-1/result.md; commit <sha>
- voided by restart on <new sha> (spend nothing): <result.md paths with their commit>

## Phases
- review, codex attempt-1 + claude attempt-1 in parallel: HEAD <before> -> <after>; porcelain <identical | differs: <preserved diff paths>>
- review retry, claude attempt-2 alone: HEAD <before> -> <after>; porcelain identical
- cross-check, claude attempt-1 alone: HEAD <before> -> <after>; porcelain identical
```

## report.md

```markdown
# Dual review report
Checkout: /absolute/checkout; target <base>..<reviewed commit>; state <dual dir>/state.md

## Verdict
Derived: CHANGES <or CLEAN>
Raw (each reviewer's own, as given): codex CHANGES; claude CLEAN

## Confirmed findings
### D1 critical (codex minor, claude critical)
- Location: module.py:5
- Scenario: <triggering condition and wrong outcome>
- Violated requirement: "<quoted>"
- Evidence: <raiser's evidence; verifier's evidence when cross-checked>
- Proposed fix: <...>
- Raised by: codex, claude <or one reviewer>; confirmed by: both <or cross-check by claude>
- Sources: codex F1, claude R1

## Rejected by cross-check
### D2 (claude R1)
- Finding: <as raised>
- Raiser's position: <claude's scenario, requirement and evidence>
- Verifier's evidence: <codex's quoted requirement, code read or run>
- Repeat: no <or: repeat, raised again without new evidence; not cross-checked>

## Candidates
- <outside-round | outside-task | noticed, not verified>: <finding and evidence>; raised by <codex F3, claude R4>

## Matching decisions
- codex F1 + claude R1: one finding; same scenario (value equal to the limit rejected) and requirement, different lines.
- codex F2, claude R2: two findings; same path:line and requirement, different failure scenarios.

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
