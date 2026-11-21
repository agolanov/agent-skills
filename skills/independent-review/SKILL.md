---
name: independent-review
description: Runs one validated review of committed work by an independent reviewer, or by Codex and Claude together with a cross-check under `--dual`, in the background or a visible window, without changing the checkout. Use when the user wants a one-off or two-model review, or when another skill needs one validated review.
---

# Independent Review

One assigned reviewer reviews one recorded target once with its system's native review tool (Codex `codex review`, Claude `/code-review`); this skill launches that attempt, validates it, turns the native report into findings with a derived verdict and records the result. It changes nothing in the checkout and commits nothing. A caller such as `review-fix-loop` supplies the absolute checkout, the target and its form, the review kind, requirements/rules/checks, assignment and review context, and applies its own retry budget; direct use supplies them per **Direct use**. With `--dual`, Codex and Claude both review the target and cross-check each other's findings (**Launch**).

Under `--auto`, given directly or by the caller's run, read child-sessions' [auto.md](../child-sessions/references/auto.md): every question below that would go to the user is routed by its Deciding, every window driver brief and cross-check prompt says `Auto: yes`, and direct use reports `## Decisions`.

## Assignment

An assignment is a reviewer system and a place. Resolve both before anything starts.

**System:** `--codex`, `--claude`, `--dual` (Codex and Claude together), or equivalent prose. With none, the reviewer is the system opposite to this session's ([Session system](#session-system)). Two system keys conflict: ask which one applies (under `--auto`, routed by [auto.md](../child-sessions/references/auto.md#deciding)).

**Place:** `--run background|window`, or equivalent words ("let Codex review it in a window"), which the session maps to the key and announces. Default `background`; a resumed dual review keeps its recorded place ([State and resume](references/dual.md#state-and-resume)). Under `--dual` the place holds for both reviewers.

Refused before anything starts, naming the combination:

- `--run subagent`, naming `background` and `window`: a native subagent has no native review command;
- `--run inline`: reviewing one's own work is not independent;
- effort `low` for a Claude reviewer, as an unsupported pair, naming `medium`: at `low` `/code-review` reads the diff only. Effort `max` gives the Claude level `max` only when the user set it explicitly, never by policy; under the effort opt-out (`cli-default`) the command keeps the level it remembers ([Claude level](references/review-wrapper.md#carrying-the-wrapper)).

The removed keys are refused, naming their replacements: `--subagent` and `--run subagent` (now `--run background` or `--run window`) and `--reviewer codex|claude` (now `--codex` or `--claude`).

A caller (`review-fix-loop`) passes the system and its `--reviewer-run` as the place; these rules apply to them as to direct use. Explicit model and effort values are validated for the reviewer system these rules resolve.

Read [launch settings](references/launch-settings.md) for the reviewer role; honor independent model/effort overrides, announce and record the resolved assignment. Missing runtime capabilities block this place; changing place/settings needs explicit authorization.

### Session system

Identify this session's own system, Codex or Claude Code, from session identity, never from executable availability, inherited environment variables, directory names or model guesses. The reviewer is the opposite system: Claude for a Codex session, Codex for a Claude Code session. An unknown identity requires clarification before anything starts; under `--auto` that question is routed by [auto.md](../child-sessions/references/auto.md#deciding).

## Review coverage

This rule selects the requirements the session puts into the context file ([The context file](references/review-wrapper.md#the-context-file)). Scope context to the task's requirements, changed code and relevant dependencies. Select the files or sections that define that scope and its shared invariants. A reference does not make unrelated content required reading. Name required instructions and selected units completely, with their exact sections. An explicit user request for whole-document reading remains a requirement.

## Review wrapper

Every attempt carries the wrapper and a context file, both filled by [review-wrapper.md](references/review-wrapper.md): the wrapper says what is under review and where the data is, the context file `<attempt dir>/context.md` holds the data. The caller supplies the target form (range or files) and target, the review kind, the prior findings, the candidates and the requirements; direct use fills them per **Direct use**. The native tool finds the defects; nothing else is sent to it.

**What the session owns.** The session that runs the review owns everything procedural, in every assignment:

- **Suite.** Resolve exact suite and targeted commands once using [checkout state and suite evidence](references/checkout-state.md#resolve-checks-and-bind-suite-evidence); record cwd, sources, intended coverage, required phase/producer obligations and unavailable coverage. Inspect retained runs before scheduling checks, run the missing required checks in the reviewed tree before the reviewer launches, and keep the run and acceptance records. The reviewer receives the commands and their results as data in the context file's `Check commands`, never the record paths. Scoped caller rounds may retain explicitly pending broader coverage; final review needs applicable complete coverage or the required missing executions, subject to direct-use incomplete-verification disclosure.
- **A run the requirement gives to the reviewer.** A resolved phase/producer requirement that names the reviewer as the one who runs a check (a fresh independent run) stays binding and cannot move to the session. The wrapper then carries its reviewer-run line with those commands. The obligation is met only by runtime records that show each command and how it ended, never by the report's word; without them it stays `pending` and Verification is incomplete.
- **Unchanged checkout.** The before and after Git evidence of **Launch** and **Validate** is the only proof. The wrapper's "Do not change the checkout" is a request, not evidence.
- **Verdict and findings.** The session writes `<attempt dir>/findings.md` and derives the verdict ([Findings and derived verdict](references/review-wrapper.md#findings-and-derived-verdict)).

A caller may supply a complete prompt in place of the wrapper, as the dual review does for its cross-check: the attempt carries that prompt unchanged on stdin, without `/code-review`, wherever the guides name the attempt's prompt, and **Validate** judges its report.

## Launch

With `--dual`, read [the dual review](references/dual.md) and follow it: it runs the whole review and calls this skill's sections for every attempt. Read it only with `--dual`.

Read [checkout state](references/checkout-state.md) and record its four ordinary Git commands, actual exits and raw outputs. Verify the requested checkout/branch/HEAD. Every attempt gets a fresh directory outside all checked trees for the prompt, `context.md`, answer, logs, before/after Git outputs, comparison, preserved diff, `findings.md` and `result.md`; bind the CLI guide's `round_prompt` and `round_dir` there. Check that the target holds something ([Empty target](references/review-wrapper.md#empty-target)): an empty target launches nothing and spends no attempt. Obtain successful before evidence, then run one attempt through the guide of the assigned place: `background` → [CLI guide](references/cli-reviewers.md), `window` → [window guide](references/window-reviewers.md). A failed Git boundary launches nothing and spends no attempt. Python is optional legacy compatibility, not an entry requirement.

A parallel caller owns one shared before set and one after both launches finish; window participants must both pass the window guide's stopped-process barrier before that shared after capture. Both results reference that comparison. In clone mode check both trees. Carry the reference's Git evidence limits in each record, including ignored files, untracked-file contents, Git flags/normalization, nested repositories/submodules and transient restored writes.

## Validate

A native attempt is valid when all of these hold; window attempts add the [window guide's](references/window-reviewers.md#stop-confirm-capture-validate) conditions, and where that guide names its own evidence for a condition below, a window attempt is judged by that evidence instead:

- **Completion:** CLI exit 0 and a non-error final result, or a window's `STATUS: done` with a non-empty answer file **and** the window guide's stopped-process barrier. Window status alone is insufficient.
- **The native tool ran:** for a background Claude attempt, the stream's result event names the command (`local_command: code_review` in Claude Code 2.1.330) or the stream holds the expanded command; for Codex, the review-mode session record of the launch ([CLI guide](references/cli-reviewers.md#result-handling)). A window attempt has no event stream: its own check is the window guide's **The native tool ran**.
- **The context file was read:** the runtime records (Claude's event stream or transcript, Codex's stderr log or session record) hold a tool call or command that reads the attempt's `context.md` path.
- **The target was read:** the same records hold a command or tool call that reads the range's diff or commits, or each target file. A report of no findings is valid only with this evidence.
- **The answer is a review report for this target:** findings that each name a path, or an explicit statement of no findings (`(none)`, or a Codex summary with no review comments). An answer that asks a question, refuses, says it could not read the diff or the context file, or reviewed another commit or range is invalid. A report whose form a style skill damaged so far that its findings carry no path is invalid like any other. No `VERDICT:` line and no report section is required.
- **Claude level:** the command carried the resolved level (none under the effort opt-out) and `--max-findings all`; an observed `low` is `invalid: /code-review ran at low`.
- **Settings:** effective model and effort, read where the review ran ([CLI guide](references/cli-reviewers.md#result-handling), [launch settings](references/launch-settings.md#typed-settings-fields)).
- **State:** unchanged recorded Git evidence. Inspect all four commands' before/after outputs, real exits and comparison; a command failure is unavailable evidence, never clean. This does not prove all raw filesystem bytes stayed unchanged.

Failed, empty, stale or substituted results are invalid. With a caller-supplied prompt, its required report and checks govern; a failed required caller check is `invalid: <the caller's reason>`.

**Unavailable tool.** When the native tool cannot run (an installed `codex review --help` without the prompt argument, a Claude answer, a window's `STATUS: failed` or its bound transcript showing `/code-review` is unknown or disabled, read after the window's confirmed shutdown; a generic refusal is not this), the attempt is `invalid: native review tool unavailable: <system>, <evidence>`. It is not retried and no other engine or prompt is tried: a single reviewer returns it as blocked; the dual review returns `blocked: <system> invalid result` with the reason in `state.md`.

A demonstrated difference has `checkout changed` precedence in `result.md`; preserve available records/content/diff outside the checkout, identify its source and retain command/comparison errors too. **Caller control:** while any window phase participant lacks retained validated ownership or fresh `alive` exit exactly 1 (including unavailable/error liveness), return `blocked: reviewer shutdown unconfirmed` to every single-reviewer caller, even beside a proven difference. A close error with every participant's owned stopped state confirmed remains diagnostic and does not itself trigger that block. When shutdown is unconfirmed, the result retains `checkout changed; otherwise invalid: reviewer shutdown unconfirmed` (or `invalid: reviewer shutdown unconfirmed` without a difference). Preserve the pending attempt/baseline and ownership diagnostics; a diagnostic capture while live is never the final unchanged boundary. Only the stopped-process boundary permits returning a write for caller adjudication. This skill never resets or folds writes into commits. Without a demonstrated difference and after the lifecycle barrier, a Git/comparison failure returns `invalid: state verification unavailable: <error>`, not a write claim. Still record every remaining completion/settings/coverage condition, including both attempts after a shared failed after check.

Apply [Phase recovery and resume](references/checkout-state.md#phase-recovery-and-resume) on every continuation (including a resumed caller's pending single-reviewer round), before retries or new baselines. A pending window phase first needs fresh `alive` exit 1 for every retained participant, then fresh Git comparison to its saved before; missing owner/name records or another exit keeps the caller blocked before adjudication or replacement launch. Retain the invalid-completion outcome when unchanged; apply existing caller retry/spend rules once, preserving prior spend. A failed before check has no attempt or older-phase attribution. Existing budgets govern; persistent unavailability blocks. Keep the evidence limits explicit.

## Result

After a valid native attempt, write `<attempt dir>/findings.md` and the derived verdict by [Findings and derived verdict](references/review-wrapper.md#findings-and-derived-verdict); an invalid attempt gets no derived verdict.

Before writing each result, separate the session's suite records from the checks the reviewer ran. Retain immutable run identities/tested states, command/cwd/exit/checkout, historical/current Git boundaries and comparisons, dependency/profile/environment facts, acceptance links and limits. Apply the [canonical applicability contract](references/checkout-state.md#resolve-checks-and-bind-suite-evidence); acceptance names the current target without rewriting where an original command ran. Without supplied suite evidence the session inspects available task records, then runs the required missing checks in the reviewed tree before the launch; this does not waive direct-use verification. A reviewer-run obligation counts only through runtime records that show each command and how it ended ([What the session owns](#review-wrapper)). Keep targeted reproductions separate. Concrete gaps and unrun/failed requirements remain incomplete under existing validity/clone rules; an absent suite stays `no complete suite defined`. Dual ownership/coordination governs required full executions; cross-checks keep their narrower checks.

Aggregate applicable retained/fresh coverage and unresolved required-check/phase/producer gaps under the [Verification marker](references/checkout-state.md#verification-marker). Failed or pending requirements without applicable passing replacement evidence make this attempt's marker `incomplete`, including an otherwise valid dual answer with no findings. A [merge-candidate check](references/checkout-state.md#merge-candidate-checks) awaiting its phase is reported `pending: merge candidate` and leaves the marker as the other requirements set it. Preserve earlier failed/unrun records without letting superseded results invalidate current applicable coverage. Compute the marker separately from result validity and the derived verdict.

Write `<attempt dir>/result.md` for every attempt and return its path with the result:

```text
Result: valid | invalid: <reason> | checkout changed; otherwise valid | checkout changed; otherwise invalid: <reason>
Assignment: <background|window>/<codex|claude>, model <exact>, effort <exact>; engine native: codex review | native: /code-review <level | none (cli-default)> | caller-supplied prompt
Settings evidence: <runtime records>
Target: <review kind; range <base>..<head> | files <paths> at <head>>; reviewed commit <full sha>
Derived verdict: <CLEAN | CHANGES> (derived by this session from the native report) | none: <invalid attempt | caller-supplied prompt>
Findings: <absolute path of findings.md | None>
Completion: <exit code | native completion | window status, actual owned close/alive exits, ownership records and retained-window diagnostics>
State: <tree: before/after Git output paths, commands/cwd/exits and comparison; unchanged recorded Git evidence | changed | unavailable; errors/diff; evidence limits>
Resolved checks: <ordered complete-suite and targeted commands; cwd/source/coverage; mandatory phase/producer and requirement source; no complete suite defined when applicable>
Suite evidence: <the session's run and acceptance records | missing: commands/reasons | no complete suite defined>
Acceptance: <current committed target; actual inspected run/acceptance paths; intervening changes/applicability and retained/fresh/pending/failed coverage; remaining phase/producer obligations>
Targeted checks: <actual commands/results and evidence | None>
Reviewer checks: <commands the report or the runtime records show | none seen>
Verification: complete | incomplete: <specific checks/coverage gaps>
Dialogs: answered <N>; declined <N>; escalated <N>
Answer: <absolute path>
Coverage gaps: <None | list>
```

A dual review records both reviewers in its `state.md` as `Assignment: dual (<background|window>): codex <model>/<effort>; claude <model>/<effort>`; each of its attempts' `result.md` keeps the single form above.

### Dialogs

The controller records each actual dialog response once: `answered` includes approvals and declines; `declined` is its explicitly declined subset; `escalated` counts dialogs forwarded for a decision, even if later answered. These overlapping counters are not summed as distinct dialogs. Navigation keys and stale peeks do not count. Reopening retains earlier counts for that attempt; the child cannot supply controller counts.

An observable window with no dialogs records `answered 0; declined 0; escalated 0`. When terminal observation controls are unsupported, use `Dialogs: not observable: <capability reason>` instead of zeros. Background attempts use `Dialogs: not applicable (background)`. Carry each attempt's record through direct output and dual reports, including invalid attempts, retries and cross-checks. Deduplicate by saved attempt identity on resume; any sum of observable counters names nonobservable attempts beside that partial total.

## Direct use

`independent-review [--codex | --claude | --dual] [--run background|window] [--model M] [--effort E] [--codex-model M] [--codex-effort E] [--claude-model M] [--claude-effort E] [--auto] [<range|commit>]`

- **Settings keys:** without `--dual`, `--model` and `--effort` set the single reviewer, and a per-reviewer key (`--codex-model`, `--codex-effort`, `--claude-model`, `--claude-effort`) asks whether `--dual` or `--model`/`--effort` was meant (under `--auto`, routed by [auto.md](../child-sessions/references/auto.md#deciding)). With `--dual`, the per-reviewer keys and `--effort` apply per [step 1](references/dual.md#1-settings-and-target) of the dual review.
- **Target:** the given range `X..Y` (Fixed base `X`, reviewed commit `Y`) or commit `C` (`C^..C`) in the current checkout, otherwise `$(git merge-base <default branch> HEAD)..HEAD`, with full SHAs, always in the range form of the [wrapper](references/review-wrapper.md#target); the files form is for callers. Resolve the default branch (`main`/`master` or configured default) as review-fix-loop step 2 does. An empty range (merge-base equals HEAD), a checkout on the default branch without an explicit target, or a target that does not resolve (`C^` of a root commit, a default branch that cannot be resolved) asks for the target (under `--auto`, routed by [auto.md](../child-sessions/references/auto.md#deciding)).
- **Uncommitted changes:** run the [direct-use preflight](references/checkout-state.md#direct-use-preflight) before any suite or reviewer launch. Detected tracked/untracked or staged changes, including staged gitlinks, do not stop and raise no question: review the committed state only, per **Reviewed state**, and list those paths as not reviewed. The committed content of such a path stays in the target. Failed Git evidence stops the gate. Keep submodule and other Git evidence limits explicit.
- **Reviewed state:** when the reviewed commit is not HEAD, or the checkout has uncommitted changes, the attempt runs in a disposable clone of the reviewed commit. Create it inside the attempt directory as part of the attempt, under the direct-use request's authority, from the checkout's plain absolute path (a `file://` URL cannot reach a commit that no ref holds): `git clone --quiet --no-checkout <checkout> <attempt dir>/tree && git -C <attempt dir>/tree checkout --quiet --detach <reviewed commit>`. If the clone or its checkout fails, launch no reviewer, spend no attempt and report the git error to the user as blocked. The clone is the tree the wrapper's "this checkout" means and the CLI guide's `task_checkout`, and the window guide opens the window there. Launch and Validate record and compare ordinary Git evidence for both the clone and user's checkout at every phase. Result records one State line per tree with output/comparison paths, actual exits, errors and Git evidence limits. Name which tree changed or is unavailable. The user's checkout serves as the clone source and for comparison; review checks and reads run in the clone.
- **Clone limits:** the clone has no untracked or ignored files, no `.git/info/exclude`, no local agent configuration and no initialized submodules; put these limits into the context file's `Limits`, so the reviewer knows them before it reads or runs anything. Checks and file reads count only in the clone, never in the user's checkout. A required check that the session ran in the clone and that failed only because the clone lacks something the reviewed commit does not contain, such as an untracked dependency, local setup or an uninitialized submodule, is listed in `result.md` under `Coverage gaps` as not run on the reviewed commit, with its command and error; the attempt is neither invalidated nor retried for it, and the output names the unrun check beside the verdict. A required check the session did not attempt is still missing coverage.
- **Requirements:** the documents or text the user names; with none named, the project rules and the commit messages, stated in the context file's `Requirements` as the only requirement sources.
- **Review kind:** the final-pass kind: the complete target, the wrapper with its security line, `Prior findings` and `Candidates` as `None`. Inspect available records under the canonical contract; without acceptable evidence, the session runs the missing resolved suite in the reviewed tree before the reviewer launches, and gives the reviewer the commands and results in `Check commands`. Clones obtain their own checks: source-tree evidence is not reusable in a clone. Preserve any explicit independent producer/phase requirement and disclose failed/unavailable coverage under existing direct-use rules.
- **Retry:** one retry after `invalid`, with the same system, place and settings, never another; a second invalid attempt is reported as blocked. A shutdown block preserves the saved attempt/result and baseline: the same controlling session continues completion recovery after owned shutdown is resolved, before any retry or write adjudication. A fresh invocation cannot silently replace it beside a potentially live reviewer; the window guide's ownership preflight applies. Charge an invalid attempt only once, retaining prior spend. After the stopped-process boundary, `checkout changed` is shown to the user with the preserved diff and is not retried, under `--auto` too: whether the write stays or goes is the user's, since discarding it is [hard to undo](../child-sessions/references/auto.md#hard-to-undo).
- **Output:** on unconfirmed shutdown return `blocked: reviewer shutdown unconfirmed`, naming the saved attempt directory and `result.md` for continuation. Otherwise show the derived verdict, named as derived by this session from the native report, with `Verification: complete | incomplete: <specific checks/coverage gaps>` and, when the preflight found uncommitted changes, `Not reviewed (uncommitted): <paths>` (the exact repository-relative paths, both paths of a rename or copy entry) immediately beside it, and findings as given, labelled "not adjudicated", plus the `result.md` path. Include per-attempt `Dialogs:` records in direct output, including a shutdown block, and under `--auto` the `## Decisions` of [auto.md](../child-sessions/references/auto.md#decisions). Apply the shared [Verification marker](references/checkout-state.md#verification-marker), including the clone exception and visible `no complete suite defined` when applicable. No commit, no fix.
