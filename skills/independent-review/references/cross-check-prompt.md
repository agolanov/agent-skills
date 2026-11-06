# Cross-Check Prompt

Fill one prompt per verifier from `state.md` and the raiser's valid review answer; resolve identifiers and paths before launch. The sent prompt is self-contained: paste the text each slot names, never a pointer to it. The first slot is the "Role and assignment" block of independent-review's [review prompt](review-prompt.md), verbatim, with this verifier's `Assignment:` line and the run's `Auto:` line (`Auto: yes` under `--auto`); the evidence slot is that prompt's common verification-evidence slot, filled from the same run/acceptance records and pending coverage, followed by its dual coordination slot without its last sentence, the severity request, which the cross-check states itself. These slots carry provenance and coordination; the Instructions below determine this cross-check's required executions. "Findings to verify" holds each finding verbatim as its raiser stated it, under the ID its raiser gave it, and nothing else about it: no assessment or check result of this session, no matching notes, none of the verifier's own findings.

```text
<the "Role and assignment" block of independent-review/references/review-prompt.md, verbatim, with this verifier's Assignment line and the line Auto: <yes|no>>

Scope
Checkout: <absolute checkout, as in the review prompts>.
Branch: <branch>. Fixed base: <base>. Reviewed HEAD: <reviewed commit>.
Target: the findings listed below, raised on <the review prompts' target row, bound> by the other independent reviewer of this target.

Requirements, rules and checks
<the requirements, rules and checks of the review prompts, without the security-focus instruction, regardless of originating round; retain exact resolved commands/cwd/source and coverage>
<the common verification-evidence slot of independent-review/references/review-prompt.md, filled with immutable original run identities/tested states, current target/boundaries, inspected acceptance links, retained/fresh/pending/failed coverage, environment/dependency/profile facts, limits and remaining phase/producer obligations>
<the dual coordination slot of independent-review/references/review-prompt.md, filled as in the review prompts, without its last sentence "Rate each finding critical, important or minor.">

Findings to verify
<source ID>: <the finding verbatim from the raiser's answer>
<one entry per listed finding>

Instructions
Check each listed finding on its own in the code of the reviewed commit; the finding is a claim to test.
Run the checks your verdicts need. Check commands under the requirements above are context for your verdicts, not automatically this cross-check's required executions. Independently inspect supplied applicability evidence; a phase/producer obligation explicitly assigned to this cross-check remains required and is coordinated through the controller. Preserve the narrower finding scope.
`confirmed` and `rejected` each need checkable evidence: code you read, quoted with path:line; a reproduction or check you ran, with command and result; or a quoted requirement.
When a finding supplies a runnable reproduction, run it. A rejection of such a finding gives that run's command and result and shows, against a quoted requirement, that the result demonstrates no violation; a rejection without that is evidence-free.
Give each finding your own severity: critical, important or minor.
Report defects you notice outside the list under "Noticed, not verified", with their evidence, without verifying them.

Required report
CROSS-CHECK REPORT
- <source ID>: confirmed|rejected; severity <critical|important|minor>; evidence: <what was read, run or quoted>; reproduction run: <command and result | none supplied>
Noticed, not verified: <items | None>
Coverage and limitations: <...>
Checks actually run: <commands/cwd/exits and tested states; independently inspected inherited run/acceptance links separately; coverage and remaining required obligations>
```
