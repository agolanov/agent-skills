# Cross-Check Prompt

Fill one prompt per verifier from `state.md` and the raiser's valid review answer; resolve identifiers and paths before launch. The sent prompt is self-contained: paste the text each slot names, never a pointer to `state.md` or a context file. A requirement document that the context files name by path and section stays named that way: the verifier reads it as the reviewers did. The cross-check is no review: it tests another reviewer's claims, so it keeps this prompt of its own and runs without `/code-review`. The first slot is the role block below, with this verifier's `Assignment:` line, the run's `Auto:` line (`Auto: yes` under `--auto`) and its report delivery. The evidence slot is the content of the context files' `Check commands`, pasted. For a review phase recorded before the native review tools, which has no context files, the requirements and evidence slots take the requirements, rules and checks of that phase's filled review prompts and `state.md` ([dual guide](dual.md#state-and-resume)). The related-code slot copies the `Related code:` checkout of the context files' `Under review` when it has one (a document review), and widens no authority. The coordination slot is the wrapper's dual line, present only when both cross-checks run at once. These slots carry provenance and coordination; the Instructions below determine this cross-check's required executions. "Findings to verify" holds each finding verbatim as its raiser stated it, under the source ID this session gave it (`F<n>` by the raiser's report order), and nothing else about it: no assessment or check result of this session, no matching notes, none of the verifier's own findings.

```text
Role and assignment
You verify findings that another independent reviewer raised; only the implementing session decides findings and fixes code.
Assignment: <place/system/concrete model/effort; existing permissions>.
Auto: <yes|no>. With yes, ask the user nothing and put a question you cannot settle under coverage and limitations in your report.
Do not change the checkout. Keep scratch files outside it.
Report delivery: <background Codex: write the complete Required report atomically to the absent absolute answer-file path given here, before returning; background Claude: return the complete Required report as your final response; window: write the complete Required report to the answer file named after this prompt>.

Scope
Checkout: <absolute checkout the review phase ran in>.
Branch: <branch>. Fixed base: <base>. Reviewed HEAD: <reviewed commit>.
Target: the findings listed below, raised on <the review phase's target: range <base>..<head> or files <paths> at <head>> by the other independent reviewer of this target.
<when the context files' Under review names related code: the line "Related code: <absolute project checkout>, read-only context for checking the findings."; omitted otherwise>

Requirements, rules and checks
<the context files' Requirements content, pasted>
<the context files' Check commands content, pasted: resolved commands with cwd, their last results and commits, pending and merge-candidate checks>
<when both cross-checks run at once: the line "Another reviewer works in this checkout at the same time: run no complete test suite, and report a check that fails in a way a concurrent run could explain as such, not as a defect."; omitted when this cross-check carries an explicitly assigned complete-check obligation, which runs it alone>

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
