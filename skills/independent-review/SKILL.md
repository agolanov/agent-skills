---
name: independent-review
description: Runs one independent reviewer, a separate Codex or Claude CLI process or a native subagent, over committed work once and validates the result without changing the checkout. Use when the user wants a one-off review by another agent, or when another skill needs one validated review.
---

# Independent Review

One assigned reviewer reviews one recorded commit target once; this skill launches that attempt, validates it and records the result. It changes nothing in the checkout and commits nothing. A caller such as `review-fix-loop` supplies the absolute checkout, target, requirements/rules/checks, assignment and review context, and applies its own retry budget; direct use supplies them per **Direct use**.

## Assignment

Require method (`cli` or `subagent`), system (`codex` or `claude`), and any explicit settings/permissions. Direct use, of this skill or of review-fix-loop, accepts `--codex`, `--claude`, `--subagent`, `--reviewer codex|claude`, or equivalent prose; without an assignment ask which method, and resolve conflicting selectors before proceeding. Only auto-cross-refine chooses the opposite system automatically.

Read [reviewer settings](references/reviewer-settings.md); honor independent model/effort overrides, announce and record the resolved assignment. Missing runtime capabilities block this method; changing method/settings needs explicit authorization.

## Review prompt

Fill the [review prompt](references/review-prompt.md), the reviewer's capability contract. The caller supplies the target row, review order, prior findings and requirements/rules/checks; direct use fills them per **Direct use**.

Resolve exact suite and targeted commands once using [checkout state and suite evidence](references/checkout-state.md#resolve-checks-and-bind-suite-evidence); record cwd, sources and unavailable coverage, then forward that set in every prompt.

A caller may supply a complete prompt in place of the review prompt, as `dual-review` does for its cross-check: the attempt carries that prompt unchanged wherever the guides name the review prompt, and **Validate** judges its report.

## Launch

Read [checkout state](references/checkout-state.md) and use its helper by absolute installed path. Every attempt gets a fresh directory outside all monitored trees for prompt, answer, logs, snapshots, comparison, preserved diff and `result.md`; bind the CLI guide's `round_prompt` and `round_dir` there. Obtain a successful pre-phase capture before one attempt through the assigned [CLI guide](references/cli-reviewers.md) or [native guide](references/subagent-reviewers.md). Failed pre-capture launches nothing and spends no attempt.

A parallel caller owns one shared capture before both launches and one after both finish. Both results reference that comparison. In clone mode capture both trees. Monitored coverage: ignored untracked paths not monitored; submodule/nested-repository content not recursively monitored; special-file contents not monitored; submodule resolved HEAD and dirty state not monitored.

## Validate

Require successful completion (CLI exit 0 or native completion), substantive target/stage/report coverage, effective assigned model/effort and identical monitored state through the shared helper. Inspect both the comparison record and process exit; HEAD/status alone cannot certify equality. Optional tool denial with adequate replacement evidence can pass; missing essential coverage/checks cannot. Failed, partial, empty, stale or substituted results are invalid. With a caller-supplied prompt, its required report and checks govern; a failed caller check is `invalid: <the caller's reason>`.

A proven difference returns `checkout changed` regardless of other conditions; preserve available records/content/diff outside the checkout, identify its source and retain capture errors too. The caller adjudicates; this skill never resets or folds writes into commits. Without proven difference, capture/comparison failure returns `invalid: state verification unavailable: <error>`, not a write claim. Still validate and record every remaining completion/settings/coverage condition, including for both attempts after a shared failed post-capture.

Apply [Phase recovery and resume](references/checkout-state.md#phase-recovery-and-resume) before retries or new baselines: retain the failed post-phase's successful baseline and compare the next successful capture to it first. A failed pre-phase has no attempt or older-phase attribution. Existing caller budgets govern; persistent unavailability blocks. Record coverage explicitly: ignored untracked paths not monitored; submodule/nested-repository content not recursively monitored; special-file contents not monitored; submodule resolved HEAD and dirty state not monitored.

## Result

Before writing each result, aggregate the supplied suite exits and retained required-check/coverage gaps under the [Verification marker](references/checkout-state.md#verification-marker). Inherited failed or unrun required checks make this attempt’s marker `incomplete`, including an otherwise valid dual answer with no findings. Compute the marker from that evidence, separately from result validity and raw verdict.

Write `<attempt dir>/result.md` for every attempt and return its path with the result:

```text
Result: valid | invalid: <reason> | checkout changed; otherwise valid | checkout changed; otherwise invalid: <reason>
Assignment: <cli|subagent>/<codex|claude>, model <exact>, effort <exact>
Settings evidence: <runtime records>
Target: <target row>; reviewed commit <full sha>
Completion: <exit code | native completion>
State: <tree: before/after snapshot or diagnostic paths; comparison/result and exits; identical monitored state | changed | unavailable; errors/diff>; ignored untracked paths not monitored; submodule/nested-repository content not recursively monitored; special-file contents not monitored; submodule resolved HEAD and dirty state not monitored
Resolved checks: <ordered complete-suite and targeted commands; cwd/source; no complete suite defined when applicable>
Suite evidence: <command/cwd/exit/commit/checkout/snapshots/comparison/environment changes>
Verification: complete | incomplete: <specific checks/coverage gaps>
Answer: <absolute path>
Coverage gaps: <None | list>
```

## Direct use

`independent-review [--codex|--claude|--subagent|--reviewer codex|claude] [--model M] [--effort E] [<range|commit>]`

- **Target:** the given range `X..Y` (Fixed base `X`, reviewed commit `Y`) or commit `C` (`C^..C`) in the current checkout, otherwise `$(git merge-base <default branch> HEAD)..HEAD`, with full SHAs; resolve the default branch (`main`/`master` or configured default) as review-fix-loop step 2 does. An empty range (merge-base equals HEAD), a checkout on the default branch without an explicit target, or a target that does not resolve (`C^` of a root commit, a default branch that cannot be resolved) asks for the target.
- **Uncommitted changes:** run the [direct-use preflight](references/checkout-state.md#direct-use-preflight) before any suite or reviewer launch. Detected outer tracked/untracked or staged changes, including staged gitlinks, stop and ask the user to commit them or review the committed state only; in the second case use **Reviewed state** and list those paths' uncommitted changes as not reviewed. The committed content of such a path stays in the target. An unavailable preflight stops without a raw-status fallback. Submodule worktree HEAD/dirty state remains unmonitored under the shared limits.
- **Reviewed state:** when the reviewed commit is not HEAD, or the user chose the committed state only, the attempt runs in a disposable clone of the reviewed commit. Create it inside the attempt directory as part of the attempt, under the direct-use request's authority, from the checkout's plain absolute path (a `file://` URL cannot reach a commit that no ref holds): `git clone --quiet --no-checkout <checkout> <attempt dir>/tree && git -C <attempt dir>/tree checkout --quiet --detach <reviewed commit>`. If the clone or its checkout fails, launch no reviewer, spend no attempt and report the git error to the user as blocked. The clone is the prompt's `Checkout:` and the CLI guide's `task_checkout`; the native guide supplies it as the absolute task checkout. Launch and Validate capture and compare both the clone and user's checkout under the shared contract for every phase. Result records one State line per tree with snapshot/diagnostic/comparison paths, exits and errors; each line ends `ignored untracked paths not monitored; submodule/nested-repository content not recursively monitored; special-file contents not monitored; submodule resolved HEAD and dirty state not monitored`. Name which tree changed or is unavailable. The user's checkout is not used for the review: it serves only as the clone source and for the state comparison, and stays unchanged.
- **Clone limits:** the clone has no untracked or ignored files, no `.git/info/exclude`, no local agent configuration and no initialized submodules; the reviewer discloses any coverage or permission this removes. Put these limits into the review prompt's "Requirements, rules and checks" slot, so the reviewer knows them before it reads or runs anything. Checks and file reads count only in the clone, never in the user's checkout. The one exception to **Validate**'s missing-checks rule is a required check that the reviewer ran in the clone and that failed only because the clone lacks something the reviewed commit does not contain, such as an untracked dependency, local setup or an uninitialized submodule: the reviewer reports the command and its error, `result.md` lists the check under `Coverage gaps` as not run on the reviewed commit, the attempt is neither invalidated nor retried for it, and the output names the unrun check beside the verdict. A required check the reviewer did not attempt is still missing coverage.
- **Requirements:** the documents or text the user names; with none named, the project rules and the commit messages, stated in the prompt as the only requirement sources.
- **Direct-use row:** the final-pass row of the review-fix-loop step 3 table: complete target, complete test suite and security-focused review; prior findings `None`.
- **Retry:** one retry after `invalid`, with the same system, method and settings, never another; a second invalid attempt is reported as blocked. `checkout changed` is shown to the user with the preserved diff and is not retried.
- **Output:** the reviewer's raw verdict with `Verification: complete | incomplete: <specific checks/coverage gaps>` immediately beside it, and findings as given, labelled "not adjudicated", plus the `result.md` path. Apply the shared [Verification marker](references/checkout-state.md#verification-marker), including the clone exception and visible `no complete suite defined` when applicable. No commit, no fix.
