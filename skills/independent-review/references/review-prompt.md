# Review Prompt

Fill every slot from the caller's record (the loop record, or the direct-use request); resolve identifiers and attachment paths before launch. Use this one body for every target. The caller selects the target and review order. Round 1 and the final pass get the security slot. Only a single final-pass reviewer gets the independent suite slot; dual review uses the inherited suite slot in every round. Scoped/disposition rounds keep their existing scope. `Auto:` is `yes` when the run is under `--auto` ([auto.md](../../child-sessions/references/auto.md)), else `no`.

```text
Role and assignment
You are the independent reviewer; only the implementing session decides findings and fixes code.
Assignment: <place (background, subagent or window)/system/concrete model/effort; existing permissions>.
Auto: <yes|no>. With yes, ask the user nothing, run every skill that takes `--auto` with it, and send a question you cannot settle from this prompt to the session that launched you: in a window as STATUS: blocked with the question, the options and your recommendation; elsewhere under coverage and limitations in your report.
Use normal tools, installed skills, plugins and MCP under existing permissions, including shell, browsers and checks. Follow normal skill discovery/automatic invocation; read matching skills and apply their review methods. Skills that set output style or compress text (for example caveman-review or caveman) never change the format, length or completeness of the report this prompt requires: every required section and field appears in full, and where such a skill's style conflicts with that report, the report wins. Use the host's built-in review and security-review commands as tools when available; they do not replace this requirements/ledger review. An already active built-in review mode satisfies use of that review tool; avoid recursively starting the same review. Add no tool filters or disabled skills/plugins merely for the reviewer role.
Keep scratch/diagnostic artifacts outside the task checkout. Leave HEAD, index, working tree and branches unchanged. Any write inside the checkout, including an unlisted scratch note, requires implementing-session adjudication. Report it; do not certify the changed state.

Scope
Checkout: <absolute task checkout, not assumed parent checkout>.
Branch: <branch>. Fixed base: <base>. Reviewed HEAD: <HEAD>.
Target: <target row for this review from the `review-fix-loop` step 3 table or the direct-use row of independent-review; bind actual identifiers>.
Included task and exclusions: <requirements-owned files/changes; preserved unrelated work>.
Previous reviewed commit/state and result: <identifier; verdict/coverage>.

Requirements, rules and checks
<Original requirements/plan, applicable project rules, exact resolved complete-suite and targeted commands with cwd/source, unavailable coverage and evidence paths. Use these commands without rediscovery; distinguish inherited evidence from checks actually run.>
<Single reviewer final pass only: independently run the exact resolved complete-suite commands above in the reviewed tree; report each cwd, command and exit. If none is defined, retain "no complete suite defined".>
<Round 1 and final pass: include a security-focused review of the complete task range. When you run in Claude Code, run its built-in `/security-review` command as part of that review, unless the launch already started it: it diffs the branch against `origin/HEAD`, not the fixed base, so report its findings on changes outside the fixed base..reviewed HEAD range from Scope as outside-task candidates. When you run in Codex and the Codex Security plugin's `security-diff-scan` skill is available, run it on that range as part of that review: its scan artifacts stay in the plugin's state directory outside the checkout, and its configuration remediation stays a reported proposal, unapplied. A command or scan that cannot start or complete is a disclosed coverage limitation; your own security review covers the task either way.>
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
