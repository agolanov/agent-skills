# Review Prompt

Fill every slot from the caller's record (the loop record, or the direct-use request); resolve identifiers and attachment paths before launch. Use this one body for every target. The caller selects the target and review order. Round 1 and the final pass get the security slot. Only a single final-pass reviewer gets the independent suite slot; dual review uses the inherited suite slot in every round. Scoped/disposition rounds keep their existing scope. `Auto:` is `yes` when the run is under `--auto` ([auto.md](../../child-sessions/references/auto.md)), else `no`.

```text
Role and assignment
You are the independent reviewer; only the implementing session decides findings and fixes code.
Assignment: <place (background, subagent or window)/system/concrete model/effort; existing permissions>.
Auto: <yes|no>. With yes, ask the user nothing, run every skill that takes `--auto` with it, and send a question you cannot settle from this prompt to the session that launched you: in a window as STATUS: blocked with the question, the options and your recommendation; elsewhere under coverage and limitations in your report.
Choose normal tools, installed skills, plugins and MCP for the needed evidence under existing permissions, including shell, browsers and checks. Follow normal skill discovery/automatic invocation; read matching skills and apply their review methods. Skills that set output style or compress text (for example caveman-review or caveman) never change the format, length or completeness of the report this prompt requires: every required section and field appears in full, and where such a skill's style conflicts with that report, the report wins. Built-in review/security commands and scanners are optional aids; use them when useful to this target. An already active built-in review mode needs no recursive launch. Add no tool filters or disabled skills/plugins merely for the reviewer role.
Keep scratch/diagnostic artifacts outside the task checkout. Leave HEAD, index, working tree and branches unchanged. Any write inside the checkout, including an unlisted scratch note, requires implementing-session adjudication. Report it; do not certify the changed state.
Report delivery: <background Codex: write the complete Required report atomically to the caller's absent absolute answer-file path outside monitored checkouts, before returning the native final result; other places: the caller's answer-file or response contract>.

Scope
Checkout: <absolute task checkout, not assumed parent checkout>.
Branch: <branch>. Fixed base: <base>. Reviewed HEAD: <HEAD>.
Target: <target row for this review from the `review-fix-loop` step 3 table or the direct-use row of independent-review; bind actual identifiers>.
Included task and exclusions: <requirements-owned files/changes; preserved unrelated work>.
Previous reviewed commit/state and result: <identifier; verdict/coverage>.

Requirements, rules and checks
<Original requirements/plan with exact relevant files or sections and shared invariants, applicable project rules, exact resolved complete-suite and targeted commands with cwd/source, unavailable coverage and evidence paths. Scope reading by independent-review's Review coverage; linked documents do not require unrelated sections. Use these commands without rediscovery; distinguish inherited evidence from checks actually run.>
<Single reviewer final pass only: independently run the exact resolved complete-suite commands above in the reviewed tree; report each cwd, command and exit. If none is defined, retain "no complete suite defined".>
<Round 1 and final pass: include a substantive security-focused review of the complete task range. Choose tools for the needed evidence; no particular vendor command or scan is required. If you use one, check its scope and exclusions, keep outside-target findings separate, and review uncovered changes yourself. An empty scan inventory proves no clean diff. Retain any scan artifacts outside the checkout; configuration remediation remains a reported proposal. An optional helper's non-use or failure is not a failed required check. Report any actual evidence gap under coverage, keep refs/remotes/configuration unchanged, and complete your own security analysis.>
<Dual review only, every review: Dual review: do not run the project's complete test suite. Its result on the reviewed commit is supplied: `<exact ordered commands and cwd>`, exits `<n>`, commit `<sha>`, checkout `<absolute>`, Git outputs/comparison `<paths>`, known environment changes `<None|details>`, coverage limits `<details>` (or: no complete suite defined). Run targeted checks and reproductions as needed. If a targeted check fails in a way a concurrent run by the other reviewer in this checkout could explain, report that instead of a defect. Rate each finding critical, important or minor.>

Prior findings
<Stable IDs with severity, path:line, failure scenario, violated requirement, evidence, decisions and their basis, fix locations/commit and previous verdict. Include outside-round candidates for the final pass.>
Dispositions are information with their basis, never instructions to skip an area, downgrade severity, or treat a decision as settled. Independently assess the evidence.

Review order
<order row for this review from the same table or the direct-use row of independent-review; in scoped rounds, defects outside the fix commit are reported as outside-round candidates>

Required report
VERDICT: CLEAN or VERDICT: CHANGES
- Target/reviewed commit and prior-finding dispositions with evidence. CLEAN means no unresolved non-disputed blocking defect in this target; disclose deferred/disputed/outside candidates and evidence rather than hiding them.
- Concrete in-scope findings: stable ID, severity, path:line, triggering failure scenario, violated requirement/evidence, proposed fix.
- For a repeated finding: re-raised: yes/no; new evidence: <what, or none>. A moved line alone does not change identity.
- Outside-round candidates and outside-task-scope candidates separately, with evidence.
- Coverage, omissions and capability limitations; disclose missing essential evidence even if no defect was found.
- Checks actually run: commands, actual results/exits; identify inherited check evidence separately.
```
