---
name: independent-review
description: Runs one validated review of committed work by an independent reviewer, or by Codex and Claude together with a cross-check under `--dual`, in the background or a visible window, without changing the checkout. Use when the user wants a one-off or two-model review, or when another skill needs one validated review.
---

# Independent Review

```text
independent-review [--codex[=<command>] | --claude[=<command>] | --dual] [--run background|window]
                   [--model M] [--effort E] [--codex-model M] [--codex-effort E] [--claude-model M] [--claude-effort E]
                   [--auto] [<range|commit>]
```

One assigned reviewer reviews one recorded target once with its system's native review tool (Codex `codex review -`, Claude `/code-review`). This skill launches that attempt, validates it, turns the native report into findings with a derived verdict and writes `result.md`. It changes nothing in the checkout and commits nothing. A caller such as `review-fix-loop` supplies the absolute checkout, target and its form, review kind, requirements, checks, assignment and ledger, and owns its retry budget; direct use resolves them by [Direct use](#direct-use). With `--dual`, Codex and Claude both review and cross-check each other ([dual review](references/dual.md)). The user's words count as the keys.

The reviewer takes the review row of [launch settings](references/launch-settings.md#roles): Opus / Sol, the other system, `high`. `cli-default` opts a field out.

Under `--auto` read child-sessions' [auto.md](../child-sessions/references/auto.md): a question below that would go to the user is routed by its Deciding, every window driver brief and cross-check prompt says `Auto: yes`, and direct use reports `## Decisions`.

## Assignment

An assignment is a reviewer system and a place, resolved before anything starts.

- **System:** `--codex`, `--claude` or `--dual`. With none, the system opposite to this session's ([Session system](#session-system)). Two system keys conflict: ask which applies.
- **Command:** `--codex=<command>` or `--claude=<command>` chooses that system and starts it through a child-sessions [launch command](../child-sessions/references/run-contract.md#launch-command) such as `codex-avc`; beside `--dual` it sets only that reviewer's command. The command replaces `codex` or `claude` in every launch of that reviewer, is recorded in `Assignment:`, and a resume keeps it.
- **Place:** `--run background` (default) or `--run window`, for both reviewers under `--dual`; a resumed dual review keeps its recorded place ([State and resume](references/dual.md#state-and-resume)).
- **Settings:** resolve by [launch settings](references/launch-settings.md) for the reviewer role, validate explicit values for the resolved system, announce and record the assignment. Changing place or settings needs explicit authorization; a place whose runtime capabilities are missing blocks.

Refused before anything starts, each naming its replacement: `--run subagent` and `--subagent` (`background` or `window`: a native subagent has no native review command); `--run inline` (reviewing one's own work is not independent); `--reviewer codex|claude` (`--codex` or `--claude`); effort `low` for a Claude reviewer (`medium`: at `low` `/code-review` reads the diff only). A caller passes its system and place through these same rules.

### Session system

Identify this session's own system, Codex or Claude Code, from session identity, never from executable availability, environment variables, directory names or model guesses. The reviewer is the opposite system. An unknown identity is a question before anything starts.

## Review coverage

This rule selects what the context file's `Requirements` names ([The context file](references/review-wrapper.md#the-context-file)): the task's requirements, changed code and relevant dependencies, with the files or sections that define that scope and its shared invariants, named completely with their exact sections. A reference does not make unrelated content required reading. A user's request for whole-document reading stays a requirement.

## Review wrapper

Every native attempt carries the wrapper and a context file `<attempt dir>/context.md`, both filled by [review-wrapper.md](references/review-wrapper.md). The native tool finds the defects; nothing else is sent to it. A caller may supply a complete prompt instead, as the dual review does for its cross-check: it goes on stdin unchanged, without `/code-review`, and its required report governs **Validate**.

**What the session owns.** The session that runs the review owns everything procedural:

- **Suite.** Resolve, inspect and run the required checks before the launch by the [suite contract](references/checkout-state.md#resolve-checks-and-bind-suite-evidence), and keep the run and acceptance records. The reviewer gets the commands and their results as data in `Check commands`, never record paths.
- **A run the requirement gives to the reviewer.** A requirement that names the reviewer as the one who runs a check stays the reviewer's: the wrapper carries the reviewer-run line, and the obligation is met only by runtime records showing each command and how it ended; without them it stays `pending`.
- **Unchanged checkout.** Only the before/after Git evidence of **Launch** proves it; the wrapper's "Do not change the checkout" is a request.
- **Verdict and findings.** The session writes `findings.md` and derives the verdict ([Findings and derived verdict](references/review-wrapper.md#findings-and-derived-verdict)).

## Launch

With `--dual`, follow [the dual review](references/dual.md) instead: it runs every attempt through these sections.

1. **Identity.** Verify the requested checkout, branch and HEAD by [checkout state](references/checkout-state.md#record-and-compare-git-evidence).
2. **Attempt directory.** A fresh directory outside every checked tree holds the prompt, `context.md`, answer, logs, Git evidence, preserved diff, `findings.md` and `result.md`.
3. **Target.** An [empty target](references/review-wrapper.md#empty-target) launches nothing and spends no attempt.
4. **Before.** Record the four Git commands in every monitored tree; a failed boundary launches nothing and spends no attempt.
5. **Run.** One attempt through the guide of the place: `background` → [CLI reviewers](references/cli-reviewers.md), `window` → [window reviewers](references/window-reviewers.md).
6. **After.** Record and compare the four commands again, after the window guide's stopped-process barrier for a window. A parallel caller uses one shared before and one shared after set; clone mode covers both trees. Carry the reference's evidence limits in every record.

## Validate

A native attempt is valid when all of these hold; the [window guide](references/window-reviewers.md#stop-confirm-capture-validate) supplies its own evidence where it names one.

- **Completion:** producer exit 0 and a non-error final result, or a window's `STATUS: done`, a non-empty answer and the stopped-process barrier.
- **The native tool ran:** the runtime records show `/code-review` or `codex review` ran for this attempt ([Result handling](references/cli-reviewers.md#result-handling)).
- **Context and target read:** the reviewing process's records hold a read of the attempt's `context.md` and of the range's diff or each target file. A report of no findings is valid only with this.
- **A review report for this target:** findings that each name a path, or an explicit statement of no findings. A question, a refusal, a report on another commit or range, or one a style skill damaged until its findings carry no path is invalid. No verdict line or section is required.
- **Claude level:** the command carried the resolved level (none under `cli-default`) and `--max-findings all`; an observed `low` is `invalid: /code-review ran at low`.
- **Settings:** one targeted lookup by the launch's session ID ([child settings check](references/launch-settings.md#child-settings-check)). A known mismatch of the effective pair pauses acceptance: the user (through the caller; under `--auto` routed as a launch-settings mismatch) accepts the review with the observed settings or has the attempt retried, the retry spending it as an invalid attempt. An `unverified` field leaves the attempt valid and is named in `Settings evidence:`.
- **State:** unchanged recorded Git evidence; a failed command is unavailable evidence, never clean.

Failed, empty, stale or substituted results are invalid. With a caller-supplied prompt, its required report and checks govern; a failed one is `invalid: <the caller's reason>`.

**Unavailable tool.** When the native tool cannot run (installed `codex review --help` lacks the prompt argument; Claude answers that `/code-review` is unknown or disabled; a window shows the same after its confirmed shutdown), the attempt is `invalid: native review tool unavailable: <system>, <evidence>`; a generic refusal is not this. It is not retried, no other engine or prompt is tried, and the caller reports it blocked.

**Changed checkout.** A demonstrated difference takes precedence: `checkout changed` in `result.md`, its content and diff preserved outside the checkout, its source identified, returned for the caller's adjudication. This skill never resets or commits a write. A failed Git comparison without a proven difference is `invalid: state verification unavailable: <error>`. Either way record every other completion, settings and coverage condition, for both attempts after a shared failed after check.

**Unconfirmed shutdown.** While any window participant lacks validated ownership or a fresh `alive` exit 1, return `blocked: reviewer shutdown unconfirmed`, even beside a proven difference; `result.md` keeps `invalid: reviewer shutdown unconfirmed` (or `checkout changed; otherwise invalid: …`). A capture taken while a reviewer may live is never the final boundary.

Every continuation applies [Phase recovery and resume](references/checkout-state.md#phase-recovery-and-resume) before a retry or new baseline, charging an invalid attempt once.

## Result

After a valid native attempt write `findings.md` and the derived verdict ([Findings and derived verdict](references/review-wrapper.md#findings-and-derived-verdict)); an invalid attempt gets none. Keep the session's suite records apart from the reviewer's checks, apply the [suite contract](references/checkout-state.md#resolve-checks-and-bind-suite-evidence) for the current target and set the [Verification marker](references/checkout-state.md#verification-marker) separately from validity and verdict. Write `<attempt dir>/result.md` for every attempt and return its path:

```text
Result: valid | invalid: <reason> | checkout changed; otherwise valid | checkout changed; otherwise invalid: <reason>
Assignment: <background|window>/<codex|claude>[ via <command>], model <exact>, effort <exact>; engine native: codex review | native: /code-review <level | none (cli-default)> | caller-supplied prompt
Settings evidence: <requested and observed model/effort, the record read; unverified fields named>
Target: <review kind; range <base>..<head> | files <paths> at <head>>; reviewed commit <full sha>
Derived verdict: <CLEAN | CHANGES> (derived by this session from the native report) | none: <invalid attempt | caller-supplied prompt>
Findings: <absolute findings.md | None>
Completion: <producer exit | window status, owned close/alive exits and ownership records>
State: <per tree: before/after Git output paths, exits, comparison; unchanged recorded Git evidence | changed | unavailable; evidence limits>
Resolved checks: <ordered commands with cwd/source; phase/producer obligations; no complete suite defined>
Suite evidence: <the session's run and acceptance records | missing: commands/reasons | no complete suite defined>
Acceptance: <current target; retained/fresh/pending/failed coverage per check; remaining obligations>
Targeted checks: <commands/results | None>
Reviewer checks: <commands the report or runtime records show | none seen>
Verification: complete | incomplete: <specific checks/coverage gaps>
Dialogs: answered <N>; declined <N>; escalated <N> | not observable: <reason> | not applicable (background)
Answer: <absolute path>
Coverage gaps: <None | list>
```

A dual review records `Assignment: dual (<place>): codex[ via <command>] <model>/<effort>; claude[ via <command>] <model>/<effort>` in its `state.md`; each attempt's `result.md` keeps the form above.

### Dialogs

The controller counts each actual window dialog response once: `answered` includes approvals and declines, `declined` is its subset, `escalated` counts dialogs forwarded for a decision. Navigation keys and stale peeks do not count; reopening keeps the attempt's counts; the child never supplies them. Carry each attempt's record, invalid attempts and cross-checks included, through direct output and dual reports, deduplicated by attempt identity on resume; a total of observable counters names the nonobservable attempts beside it.

## Direct use

1. **Settings keys.** Without `--dual`, `--model` and `--effort` set the reviewer, and a per-reviewer key asks whether `--dual` was meant. With `--dual` they apply by [dual review](references/dual.md#1-settings-and-target) step 1.
2. **Target.** The given range `X..Y` or commit `C` (`C^..C`), else `$(git merge-base <default branch> HEAD)..HEAD`, full SHAs, always the range form of the [wrapper](references/review-wrapper.md#target). An empty range, a checkout on the default branch without a target, or a target that does not resolve asks for the target.
3. **Uncommitted changes.** Run the [direct-use preflight](references/checkout-state.md#direct-use-preflight) before any suite or launch. Uncommitted paths raise no question: the committed state is reviewed and those paths are listed as not reviewed.
4. **Reviewed state.** When the reviewed commit is not HEAD or the checkout is dirty, the attempt runs in a disposable clone inside the attempt directory: `git clone --quiet --no-checkout <checkout> <attempt dir>/tree && git -C <attempt dir>/tree checkout --quiet --detach <reviewed commit>` (a plain path: a `file://` URL cannot reach an unreferenced commit). A failed clone launches nothing, spends nothing and is reported as blocked. Checks and reads count only in the clone; Git evidence covers the clone and the user's checkout, one State line each.
5. **Clone limits.** The clone lacks untracked and ignored files, `.git/info/exclude`, local agent configuration and submodules: say so in the context file's `Limits`. A required check that failed only for such a lack is a `Coverage gaps` entry named beside the verdict, not an invalid attempt.
6. **Requirements and kind.** The documents or text the user names, else the project rules and commit messages as the only sources. The final-pass kind: complete target, security line, `Prior findings` and `Candidates` `None`; the session runs the missing suite in the reviewed tree first.
7. **Retry.** One retry after `invalid`, same system, place and settings; a second invalid attempt is blocked. A shutdown block is continued by the same session after shutdown is confirmed. `checkout changed` is shown to the user with the preserved diff and not retried, under `--auto` too, since discarding a write is [hard to undo](../child-sessions/references/auto.md#hard-to-undo).
8. **Output.** The derived verdict, named as derived by this session from the native report, with `Verification:` and, when the preflight found them, `Not reviewed (uncommitted): <exact paths>` beside it; the findings as given, labelled "not adjudicated"; the `result.md` path; `Dialogs:`; under `--auto` `## Decisions`. On unconfirmed shutdown: `blocked: reviewer shutdown unconfirmed` with the attempt directory. No commit, no fix.
