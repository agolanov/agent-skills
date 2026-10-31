# Cross-Check Prompt

Fill one prompt per verifier from `state.md` and the raiser's valid review answer; resolve identifiers and paths before launch. The sent prompt is self-contained: paste the text each slot names, never a pointer to it. The first slot is the "Role and assignment" block of independent-review's [review prompt](../../independent-review/references/review-prompt.md), verbatim, with this verifier's `Assignment:` line; the suite slot is that prompt's dual complete-suite instruction, filled as in the review prompts. "Findings to verify" holds each finding verbatim as its raiser stated it, under the ID its raiser gave it, and nothing else about it: no assessment or check result of this session, no matching notes, none of the verifier's own findings.

```text
<the "Role and assignment" block of independent-review/references/review-prompt.md, verbatim, with this verifier's Assignment line>

Scope
Checkout: <absolute checkout, as in the review prompts>.
Branch: <branch>. Fixed base: <base>. Reviewed HEAD: <reviewed commit>.
Target: the findings listed below, raised on <the review prompts' target row, bound> by the other independent reviewer of this target.

Requirements, rules and checks
<the requirements, rules and checks of the review prompts, without the final-pass security-focus instruction>
<the dual complete-suite instruction of independent-review/references/review-prompt.md, filled as in the review prompts>

Findings to verify
<source ID>: <the finding verbatim from the raiser's answer>
<one entry per listed finding>

Instructions
Check each listed finding on its own in the code of the reviewed commit; the finding is a claim to test.
Run the checks your verdicts need. Check commands under the requirements above are context for your verdicts, not checks this cross-check requires.
`confirmed` and `rejected` each need checkable evidence: code you read, quoted with path:line; a reproduction or check you ran, with command and result; or a quoted requirement.
When a finding supplies a runnable reproduction, run it. A rejection of such a finding gives that run's command and result and shows, against a quoted requirement, that the result demonstrates no violation; a rejection without that is evidence-free.
Give each finding your own severity: critical, important or minor.
Report defects you notice outside the list under "Noticed, not verified", with their evidence, without verifying them.

Required report
CROSS-CHECK REPORT
- <source ID>: confirmed|rejected; severity <critical|important|minor>; evidence: <what was read, run or quoted>; reproduction run: <command and result | none supplied>
Noticed, not verified: <items | None>
Coverage and limitations: <...>
Checks actually run: <commands and exits>
```
