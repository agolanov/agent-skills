---
name: independent-review
description: Runs one validated review of committed work by an independent reviewer, or by Codex and Claude together with a cross-check under `--dual`, in the background, a native subagent or a visible window, without changing the checkout. Use when the user wants a one-off or two-model review, or when another skill needs one validated review.
---

# Independent Review

One assigned reviewer reviews one recorded commit target once; this skill launches that attempt, validates it and records the result. It changes nothing in the checkout and commits nothing. A caller such as `review-fix-loop` supplies the absolute checkout, target, requirements/rules/checks, assignment and review context, and applies its own retry budget; direct use supplies them per **Direct use**. With `--dual`, Codex and Claude both review the target and cross-check each other's findings (**Launch**).

Under `--auto`, given directly or by the caller's run, read child-sessions' [auto.md](../child-sessions/references/auto.md): every question below that would go to the user is routed by its Deciding, every prompt says `Auto: yes`, and direct use reports `## Decisions`.

## Assignment

An assignment is a reviewer system and a place. Resolve both before anything starts.

**System:** `--codex`, `--claude`, `--dual` (Codex and Claude together), or equivalent prose. With none, the reviewer is the system opposite to this session's ([Session system](#session-system)), except with the place `subagent`, where it is this session's own system, the only system a native subagent can have. Two system keys conflict: ask which one applies (under `--auto`, routed by [auto.md](../child-sessions/references/auto.md#deciding)).

**Place:** `--run background|subagent|window`, or equivalent words ("let Codex review it in a window"), which the session maps to the key and announces. Default `background`; a resumed dual review keeps its recorded place ([State and resume](references/dual.md#state-and-resume)). Under `--dual` the place holds for both reviewers. `--run inline` is refused before anything starts: reviewing one's own work is not independent.

Refused before any launch, naming the combination:

- `subagent` with a system other than this session's own, for example `--codex --run subagent` from Claude Code;
- `--dual` with `subagent`;
- `subagent` when this session is itself a subagent of a host whose subagents cannot start subagents.

The removed keys are refused, naming their replacements: `--subagent` (now `--run subagent`) and `--reviewer codex|claude` (now `--codex` or `--claude`).

A caller (`review-fix-loop`) passes the system and its `--reviewer-run` as the place; these rules apply to them as to direct use. Explicit model and effort values are validated for the reviewer system these rules resolve.

Read [launch settings](references/launch-settings.md) for the reviewer role; honor independent model/effort overrides, announce and record the resolved assignment. Missing runtime capabilities block this place; changing place/settings needs explicit authorization.

### Session system

Identify this session's own system, Codex or Claude Code, from session identity, never from executable availability, inherited environment variables, directory names or model guesses. The reviewer is the opposite system: Claude for a Codex session, Codex for a Claude Code session. An unknown identity requires clarification before anything starts; under `--auto` that question is routed by [auto.md](../child-sessions/references/auto.md#deciding).

## Review coverage

Scope context to the task's requirements, changed code and relevant dependencies. Select the files or sections that define that scope and its shared invariants. A reference does not make unrelated content required reading. Read required instructions and selected units completely. An explicit user request for whole-document reading remains a requirement.

The reviewer chooses reading, navigation and security-review tools under existing permissions. Tool preferences, unread unrelated sections and non-use of optional helpers do not invalidate substantive work or make Verification incomplete. Keep authority, mandatory instruction loading, required checks and unchanged-state gates binding. A caller claiming missing essential coverage identifies the unreviewed in-scope requirement, changed path or required check and the unresolved question; a preferred method alone is no coverage gap. Preserve covered work and eligible check evidence rather than repeating them solely for a process discrepancy.

## Review prompt

Fill the [review prompt](references/review-prompt.md), the reviewer's capability contract, its `Auto:` line `yes` under `--auto`. The caller supplies the target row, review order, prior findings and requirements/rules/checks; direct use fills them per **Direct use**.

Resolve exact suite and targeted commands once using [checkout state and suite evidence](references/checkout-state.md#resolve-checks-and-bind-suite-evidence); record cwd, sources and unavailable coverage, then forward that set in every prompt.

A caller may supply a complete prompt in place of the review prompt, as the dual review does for its cross-check: the attempt carries that prompt unchanged wherever the guides name the review prompt, and **Validate** judges its report.

## Launch

With `--dual`, read [the dual review](references/dual.md) and follow it: it runs the whole review and calls this skill's sections for every attempt. Read it only with `--dual`.

Read [checkout state](references/checkout-state.md) and record its four ordinary Git commands, actual exits and raw outputs. Verify the requested checkout/branch/HEAD. Every attempt gets a fresh directory outside all checked trees for prompt, answer, logs, before/after Git outputs, comparison, preserved diff and `result.md`; bind the CLI guide's `round_prompt` and `round_dir` there. Obtain successful before evidence, then run one attempt through the guide of the assigned place: `background` → [CLI guide](references/cli-reviewers.md), `subagent` → [native guide](references/subagent-reviewers.md), `window` → [window guide](references/window-reviewers.md). A failed Git boundary launches nothing and spends no attempt. Python is optional legacy compatibility, not an entry requirement.

A parallel caller owns one shared before set and one after both launches finish; window participants must both pass the window guide's stopped-process barrier before that shared after capture. Both results reference that comparison. In clone mode check both trees. Carry the reference's Git evidence limits in each record, including ignored files, untracked-file contents, Git flags/normalization, nested repositories/submodules and transient restored writes.

## Validate

Require successful completion (CLI exit 0, native completion, or a window's `STATUS: done` with a non-empty answer file **and** the [window guide's stopped-process barrier](references/window-reviewers.md#stop-confirm-capture-validate)), substantive target/stage/report coverage, effective assigned model/effort and unchanged recorded Git evidence. Window status alone is insufficient. Inspect all four commands' before/after outputs, real exits and comparison; a command failure is unavailable evidence, never clean. This does not prove all raw filesystem bytes stayed unchanged. Judge omissions by [Review coverage](#review-coverage): optional tool non-use with adequate evidence can pass; a concrete essential coverage/check gap cannot. Failed, empty, stale, substituted or substantively incomplete results are invalid. With a caller-supplied prompt, its required report and checks govern under that same coverage rule; a failed required caller check is `invalid: <the caller's reason>`.

A demonstrated difference has `checkout changed` precedence in `result.md`; preserve available records/content/diff outside the checkout, identify its source and retain command/comparison errors too. **Caller control:** while any window phase participant lacks retained validated ownership or fresh `alive` exit exactly 1 (including unavailable/error liveness), return `blocked: reviewer shutdown unconfirmed` to every single-reviewer caller, even beside a proven difference. A close error with every participant's owned stopped state confirmed remains diagnostic and does not itself trigger that block. When shutdown is unconfirmed, the result retains `checkout changed; otherwise invalid: reviewer shutdown unconfirmed` (or `invalid: reviewer shutdown unconfirmed` without a difference). Preserve the pending attempt/baseline and ownership diagnostics; a diagnostic capture while live is never the final unchanged boundary. Only the stopped-process boundary permits returning a write for caller adjudication. This skill never resets or folds writes into commits. Without a demonstrated difference and after the lifecycle barrier, a Git/comparison failure returns `invalid: state verification unavailable: <error>`, not a write claim. Still record every remaining completion/settings/coverage condition, including both attempts after a shared failed after check.

Apply [Phase recovery and resume](references/checkout-state.md#phase-recovery-and-resume) on every continuation (including a resumed caller's pending single-reviewer round), before retries or new baselines. A pending window phase first needs fresh `alive` exit 1 for every retained participant, then fresh Git comparison to its saved before; missing owner/name records or another exit keeps the caller blocked before adjudication or replacement launch. Retain the invalid-completion outcome when unchanged; apply existing caller retry/spend rules once, preserving prior spend. A failed before check has no attempt or older-phase attribution. Existing budgets govern; persistent unavailability blocks. Keep the evidence limits explicit.

## Result

Before writing each result, separate inherited suite evidence from independently executed evidence, retaining command/cwd/exit/commit/checkout, before/after Git output paths/comparison, environment changes and limits for each actual record. `None: caller supplied no suite evidence` is neither a skipped direct suite nor a failure by itself: a direct final reviewer still independently executes the exact resolved suite. Keep targeted checks separate. Defined unrun/failed required checks remain incomplete under existing validity and clone rules; an absent suite definition stays `no complete suite defined`. Dual review/cross-check attempts inherit their suite without acquiring a complete-suite rerun requirement.

Aggregate these suite exits and retained required-check/coverage gaps under the [Verification marker](references/checkout-state.md#verification-marker). Inherited failed or unrun required checks make this attempt's marker `incomplete`, including an otherwise valid dual answer with no findings. Compute the marker separately from result validity and the unchanged raw verdict.

Write `<attempt dir>/result.md` for every attempt and return its path with the result:

```text
Result: valid | invalid: <reason> | checkout changed; otherwise valid | checkout changed; otherwise invalid: <reason>
Assignment: <background|subagent|window>/<codex|claude>, model <exact>, effort <exact>
Settings evidence: <runtime records>
Target: <target row>; reviewed commit <full sha>
Completion: <exit code | native completion | window status, actual owned close/alive exits, ownership records and retained-window diagnostics>
State: <tree: before/after Git output paths, commands/cwd/exits and comparison; unchanged recorded Git evidence | changed | unavailable; errors/diff; evidence limits>
Resolved checks: <ordered complete-suite and targeted commands; cwd/source; no complete suite defined when applicable>
Suite evidence: inherited: <records | None: caller supplied no suite evidence>; independently executed: <records | None: not required in this phase | missing: commands/reasons | no complete suite defined>
Targeted checks: <actual commands/results and evidence | None>
Verification: complete | incomplete: <specific checks/coverage gaps>
Dialogs: answered <N>; declined <N>; escalated <N>
Answer: <absolute path>
Coverage gaps: <None | list>
```

A dual review records both reviewers in its `state.md` as `Assignment: dual (<background|window>): codex <model>/<effort>; claude <model>/<effort>`; each of its attempts' `result.md` keeps the single form above.

### Dialogs

The controller records each actual dialog response once: `answered` includes approvals and declines; `declined` is its explicitly declined subset; `escalated` counts dialogs forwarded for a decision, even if later answered. These overlapping counters are not summed as distinct dialogs. Navigation keys and stale peeks do not count. Reopening retains earlier counts for that attempt; the child cannot supply controller counts.

An observable window with no dialogs records `answered 0; declined 0; escalated 0`. When terminal observation controls are unsupported, use `Dialogs: not observable: <capability reason>` instead of zeros. Background/native attempts use `Dialogs: not applicable (background|subagent)`, naming their actual place. Carry each attempt's record through direct output and dual reports, including invalid attempts, retries and cross-checks. Deduplicate by saved attempt identity on resume; any sum of observable counters names nonobservable attempts beside that partial total.

## Direct use

`independent-review [--codex | --claude | --dual] [--run background|subagent|window] [--model M] [--effort E] [--codex-model M] [--codex-effort E] [--claude-model M] [--claude-effort E] [--auto] [<range|commit>]`

- **Settings keys:** without `--dual`, `--model` and `--effort` set the single reviewer, and a per-reviewer key (`--codex-model`, `--codex-effort`, `--claude-model`, `--claude-effort`) asks whether `--dual` or `--model`/`--effort` was meant (under `--auto`, routed by [auto.md](../child-sessions/references/auto.md#deciding)). With `--dual`, the per-reviewer keys and `--effort` apply per [step 1](references/dual.md#1-settings-and-target) of the dual review.
- **Target:** the given range `X..Y` (Fixed base `X`, reviewed commit `Y`) or commit `C` (`C^..C`) in the current checkout, otherwise `$(git merge-base <default branch> HEAD)..HEAD`, with full SHAs; resolve the default branch (`main`/`master` or configured default) as review-fix-loop step 2 does. An empty range (merge-base equals HEAD), a checkout on the default branch without an explicit target, or a target that does not resolve (`C^` of a root commit, a default branch that cannot be resolved) asks for the target (under `--auto`, routed by [auto.md](../child-sessions/references/auto.md#deciding)).
- **Uncommitted changes:** run the [direct-use preflight](references/checkout-state.md#direct-use-preflight) before any suite or reviewer launch. Detected tracked/untracked or staged changes, including staged gitlinks, do not stop and raise no question: review the committed state only, per **Reviewed state**, and list those paths as not reviewed. The committed content of such a path stays in the target. Failed Git evidence stops the gate. Keep submodule and other Git evidence limits explicit.
- **Reviewed state:** when the reviewed commit is not HEAD, or the checkout has uncommitted changes, the attempt runs in a disposable clone of the reviewed commit. Create it inside the attempt directory as part of the attempt, under the direct-use request's authority, from the checkout's plain absolute path (a `file://` URL cannot reach a commit that no ref holds): `git clone --quiet --no-checkout <checkout> <attempt dir>/tree && git -C <attempt dir>/tree checkout --quiet --detach <reviewed commit>`. If the clone or its checkout fails, launch no reviewer, spend no attempt and report the git error to the user as blocked. The clone is the prompt's `Checkout:` and the CLI guide's `task_checkout`; the native guide supplies it as the absolute task checkout, and the window guide opens the window there. Launch and Validate record and compare ordinary Git evidence for both the clone and user's checkout at every phase. Result records one State line per tree with output/comparison paths, actual exits, errors and Git evidence limits. Name which tree changed or is unavailable. The user's checkout serves as the clone source and for comparison; review checks and reads run in the clone.
- **Clone limits:** the clone has no untracked or ignored files, no `.git/info/exclude`, no local agent configuration and no initialized submodules; the reviewer discloses any coverage or permission this removes. Put these limits into the review prompt's "Requirements, rules and checks" slot, so the reviewer knows them before it reads or runs anything. Checks and file reads count only in the clone, never in the user's checkout. The one exception to **Validate**'s missing-checks rule is a required check that the reviewer ran in the clone and that failed only because the clone lacks something the reviewed commit does not contain, such as an untracked dependency, local setup or an uninitialized submodule: the reviewer reports the command and its error, `result.md` lists the check under `Coverage gaps` as not run on the reviewed commit, the attempt is neither invalidated nor retried for it, and the output names the unrun check beside the verdict. A required check the reviewer did not attempt is still missing coverage.
- **Requirements:** the documents or text the user names; with none named, the project rules and the commit messages, stated in the prompt as the only requirement sources.
- **Direct-use row:** the final-pass row of the review-fix-loop step 3 table: complete target, complete test suite and security-focused review; prior findings `None`.
- **Retry:** one retry after `invalid`, with the same system, place and settings, never another; a second invalid attempt is reported as blocked. A shutdown block preserves the saved attempt/result and baseline: the same controlling session continues completion recovery after owned shutdown is resolved, before any retry or write adjudication. A fresh invocation cannot silently replace it beside a potentially live reviewer; the window guide's ownership preflight applies. Charge an invalid attempt only once, retaining prior spend. After the stopped-process boundary, `checkout changed` is shown to the user with the preserved diff and is not retried, under `--auto` too: whether the write stays or goes is the user's, since discarding it is [hard to undo](../child-sessions/references/auto.md#hard-to-undo).
- **Output:** on unconfirmed shutdown return `blocked: reviewer shutdown unconfirmed`, naming the saved attempt directory and `result.md` for continuation. Otherwise show the reviewer's raw verdict with `Verification: complete | incomplete: <specific checks/coverage gaps>` and, when the preflight found uncommitted changes, `Not reviewed (uncommitted): <paths>` (the exact repository-relative paths, both paths of a rename or copy entry) immediately beside it, and findings as given, labelled "not adjudicated", plus the `result.md` path. Include per-attempt `Dialogs:` records in direct output, including a shutdown block, and under `--auto` the `## Decisions` of [auto.md](../child-sessions/references/auto.md#decisions). Apply the shared [Verification marker](references/checkout-state.md#verification-marker), including the clone exception and visible `no complete suite defined` when applicable. No commit, no fix.
