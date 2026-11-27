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

Review one committed target with the assigned native tool, validate the attempt and return its result. Preserve the checkout. A caller supplies the absolute checkout, target and form, review kind, requirements, checks, assignment and ledger, and owns its retries. Without a caller, start with [Direct use](#direct-use). The user's words count as keys.

Under `--auto`, apply [auto.md](../child-sessions/references/auto.md) to questions, driver briefs, cross-check prompts and direct reporting.

## Assignment

An assignment is a reviewer system and a place, resolved before anything starts.

- **System:** `--codex`, `--claude` or `--dual`. With none, the system opposite to this session's ([Session system](#session-system)). Two system keys conflict: ask which applies.
- **Command:** `--codex=<command>` or `--claude=<command>` chooses that system and starts it through a child-sessions [launch command](../child-sessions/references/run-contract.md#launch-command) such as `codex-avc`; beside `--dual` it sets only that reviewer's command. The command replaces `codex` or `claude` in every launch of that reviewer, is recorded in `Assignment:`, and a resume keeps it.
- **Place:** `--run background` (default) or `--run window`, for both reviewers under `--dual`; a resumed dual review keeps its recorded place ([State and resume](references/dual.md#state-and-resume)).
- **Settings:** resolve by [launch settings](references/launch-settings.md) for the reviewer role (`cli-default` opts a field out), validate explicit values for the resolved system, announce and record the assignment. Changing place or settings needs explicit authorization; a place whose runtime capabilities are missing blocks.

Refused before anything starts, each naming its replacement: `--run subagent` and `--subagent` (`background` or `window`: a native subagent has no native review command); `--run inline` (reviewing one's own work is not independent); `--reviewer codex|claude` (`--codex` or `--claude`); effort `low` for a Claude reviewer (`medium`: at `low` `/code-review` reads the diff only). A caller passes its system and place through these same rules.

### Session system

Identify this session's own system, Codex or Claude Code, from session identity, never from executable availability, environment variables, directory names or model guesses. The reviewer is the opposite system. An unknown identity is a question before anything starts.

## Review coverage

This rule selects what the context file's `Requirements` names ([The context file](references/review-wrapper.md#the-context-file)): the task's requirements, changed code and relevant dependencies, with the files or sections that define that scope and its shared invariants, named completely with their exact sections. A reference does not make unrelated content required reading. A user's request for whole-document reading stays a requirement.

## Review wrapper

Every native attempt carries the wrapper and a context file `<attempt dir>/context.md`, both filled by [review-wrapper.md](references/review-wrapper.md). The native tool finds the defects; nothing else is sent to it. A caller may supply a complete prompt instead, as the dual review does for its cross-check: it goes on stdin unchanged, without `/code-review`, and its required report governs **Validate**.

Before launch apply the [suite contract](references/checkout-state.md#resolve-checks-and-bind-suite-evidence) in the reviewed tree. A scoped round can carry broader coverage pending with passing affected checks. The final review needs complete applicable coverage or the missing runs. Give the reviewer commands and results in the context file. For a reviewer-assigned check include the [reviewer-run line](references/review-wrapper.md#added-lines) and require runtime evidence.

## Launch

With `--dual`, follow [the dual review](references/dual.md) instead: it runs every attempt through these sections.

1. **Identity.** Verify the requested checkout, branch and HEAD by [checkout state](references/checkout-state.md#record-and-compare-git-evidence).
2. **Attempt directory.** A fresh directory outside every checked tree holds the prompt, `context.md`, answer, logs, Git evidence, preserved diff, `findings.md` and `result.md`.
3. **Target.** An [empty target](references/review-wrapper.md#empty-target) launches nothing and spends no attempt.
4. **Before.** Record the four Git commands in every monitored tree; a failed boundary launches nothing and spends no attempt.
5. **Run.** One attempt through the guide of the place: `background` → [CLI reviewers](references/cli-reviewers.md), `window` → [window reviewers](references/window-reviewers.md).
6. **After.** Record and compare the four commands again, after the window guide's stopped-process barrier for a window. A parallel caller uses one shared before and one shared after set; clone mode covers both trees. Carry the reference's evidence limits in every record.

## Validate

Use the evidence from the selected launch guide. For a valid native attempt require all of the following:

- Completion per the selected guide (background: producer exit 0 and a non-error final result), with runtime proof that the assigned native tool ran.
- **Context and target read:** the reviewing process's records hold a read of the attempt's `context.md` and of the range's diff or each target file. A report of no findings is valid only with this.
- **A review report for this target:** findings that each name a path, or an explicit statement of no findings. A question, a refusal, a report on another commit or range, or one a style skill damaged until its findings carry no path is invalid. No verdict line or section is required.
- **Claude level:** the command carried the resolved level (none under `cli-default`) and `--max-findings all`; an observed `low` is `invalid: /code-review ran at low`.
- **Settings:** one targeted lookup by the launch's session ID ([child settings check](references/launch-settings.md#child-settings-check)). A known mismatch of the effective pair pauses acceptance: the user (through the caller; under `--auto` routed as a launch-settings mismatch) accepts the review with the observed settings or has the attempt retried, the retry spending it as an invalid attempt. An `unverified` field leaves the attempt valid and is named in `Settings evidence:`.
- **State:** unchanged recorded Git evidence; a failed command is unavailable evidence, never clean.

Failed, empty, stale or substituted results are invalid. With a caller-supplied prompt, its required report and checks govern; a failed one is `invalid: <the caller's reason>`.

**Unavailable tool.** When the native tool cannot run (installed `codex review --help` lacks the prompt argument; Claude answers that `/code-review` is unknown or disabled; a window shows the same after its confirmed shutdown), the attempt is `invalid: native review tool unavailable: <system>, <evidence>`; a generic refusal is not this. It is not retried, no other engine or prompt is tried, and the caller reports it blocked.

**Changed checkout.** A demonstrated difference takes precedence: `checkout changed` in `result.md`, its content and diff preserved outside the checkout, its source identified, returned for the caller's adjudication. This skill never resets or commits a write. A failed Git comparison without a proven difference is `invalid: state verification unavailable: <error>`. Either way record every other completion, settings and coverage condition, for both attempts after a shared failed after check.

For a window, unconfirmed shutdown takes precedence even over a proven difference. Return the shutdown block and record the outcome per the [window barrier](references/window-reviewers.md#stop-confirm-capture-validate).

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

### Dialogs

For a window, keep the [controller's dialog record](references/window-reviewers.md#dialogs). Background attempts report `not applicable (background)`.

## Direct use

Without a caller, follow [Direct use](references/direct-use.md) for preflight, target, retries and output.
