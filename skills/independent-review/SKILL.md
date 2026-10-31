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

A caller may supply a complete prompt in place of the review prompt, as `dual-review` does for its cross-check: the attempt carries that prompt unchanged wherever the guides name the review prompt, and **Validate** judges its report.

## Launch

Record `git rev-parse HEAD` and `git status --porcelain` of the checkout, then run one attempt through the assigned [CLI guide](references/cli-reviewers.md) or [native guide](references/subagent-reviewers.md). Every attempt, in loop use too, gets a fresh attempt directory outside the checkout for its prompt, answer, logs, preserved diff and `result.md`; the CLI guide's `round_prompt` and `round_dir` bind to that attempt's prompt file and directory.

A caller may run two attempts concurrently in one checkout, as `dual-review` does; it then owns the phase-level state comparison: it records HEAD and porcelain once before starting both and once after both finish, and both attempts' **Validate** and `result.md` use that one comparison.

## Validate

Require successful completion (CLI exit 0 or native tool completion), substantive target/stage/report coverage, effective assigned model/effort and unchanged state. Compare `git rev-parse HEAD` and `git status --porcelain` before and after: both outputs must be identical, so porcelain stays empty when nothing was excluded. Optional tool denial with adequate replacement evidence can pass; missing essential coverage/checks cannot. Failed, partial, empty, stale or substituted results are invalid. With a caller-supplied prompt, the required report and checks are those the prompt and its caller's report checks define; a failed caller check is `invalid: <the caller's reason>`.

Any difference in either output (a moved HEAD, a new or changed file, or an index-only change) requires adjudication by the caller (the loop, or the user in direct use). Preserve the unexpected work and its diff in the attempt directory, identify its source, and return `checkout changed` whatever the other conditions show. This skill never resets it or folds it into a commit; reconciliation, such as the loop's authorized restore after adjudication, belongs to the caller. Still check and record every other condition above, so the caller can use an otherwise valid answer after adjudicating a demonstrably unrelated scratch write.

## Result

Write `<attempt dir>/result.md` for every attempt and return its path with the result:

```text
Result: valid | invalid: <reason> | checkout changed; otherwise valid | checkout changed; otherwise invalid: <reason>
Assignment: <cli|subagent>/<codex|claude>, model <exact>, effort <exact>
Settings evidence: <runtime records>
Target: <target row>; reviewed commit <full sha>
Completion: <exit code | native completion>
State: HEAD <before> -> <after>; porcelain <identical | differs: <preserved diff path>>
Answer: <absolute path>
Coverage gaps: <None | list>
```

## Direct use

`independent-review [--codex|--claude|--subagent|--reviewer codex|claude] [--model M] [--effort E] [<range|commit>]`

- **Target:** the given range `X..Y` (Fixed base `X`, reviewed commit `Y`) or commit `C` (`C^..C`) in the current checkout, otherwise `$(git merge-base <default branch> HEAD)..HEAD`, with full SHAs; resolve the default branch (`main`/`master` or configured default) as review-fix-loop step 2 does. An empty range (merge-base equals HEAD), a checkout on the default branch without an explicit target, or a target that does not resolve (`C^` of a root commit, a default branch that cannot be resolved) asks for the target.
- **Uncommitted changes:** any `git status --porcelain` line stops before launch and asks the user to commit them or to review the committed state only; in the second case the review runs on the committed state per **Reviewed state**, and the report lists those paths' uncommitted changes as not reviewed. The committed content of such a path stays in the target.
- **Reviewed state:** when the reviewed commit is not HEAD, or the user chose the committed state only, the attempt runs in a disposable clone of the reviewed commit. Create it inside the attempt directory as part of the attempt, under the direct-use request's authority, from the checkout's plain absolute path (a `file://` URL cannot reach a commit that no ref holds): `git clone --quiet --no-checkout <checkout> <attempt dir>/tree && git -C <attempt dir>/tree checkout --quiet --detach <reviewed commit>`. If the clone or its checkout fails, launch no reviewer, spend no attempt and report the git error to the user as blocked. The clone is the prompt's `Checkout:` and the CLI guide's `task_checkout`; the native guide supplies it as the absolute task checkout. Launch and Validate record and compare HEAD and porcelain in both the clone and the user's checkout, and the Result `State:` field records both, so a `checkout changed` names the tree that changed: `State: clone HEAD <before> -> <after>; porcelain <identical | differs: <preserved diff path>>; checkout HEAD <before> -> <after>; porcelain <identical | differs: <preserved diff path>>`. The user's checkout is not used for the review: it serves only as the clone source and for the state comparison, and stays unchanged.
- **Clone limits:** the clone has no untracked or ignored files, no `.git/info/exclude`, no local agent configuration and no initialized submodules; the reviewer discloses any coverage or permission this removes. Put these limits into the review prompt's "Requirements, rules and checks" slot, so the reviewer knows them before it reads or runs anything. Checks and file reads count only in the clone, never in the user's checkout. The one exception to **Validate**'s missing-checks rule is a required check that the reviewer ran in the clone and that failed only because the clone lacks something the reviewed commit does not contain, such as an untracked dependency, local setup or an uninitialized submodule: the reviewer reports the command and its error, `result.md` lists the check under `Coverage gaps` as not run on the reviewed commit, the attempt is neither invalidated nor retried for it, and the output names the unrun check beside the verdict. A required check the reviewer did not attempt is still missing coverage.
- **Requirements:** the documents or text the user names; with none named, the project rules and the commit messages, stated in the prompt as the only requirement sources.
- **Direct-use row:** the final-pass row of the review-fix-loop step 3 table: complete target, complete test suite and security-focused review; prior findings `None`.
- **Retry:** one retry after `invalid`, with the same system, method and settings, never another; a second invalid attempt is reported as blocked. `checkout changed` is shown to the user with the preserved diff and is not retried.
- **Output:** the reviewer's verdict and findings as given, labelled "not adjudicated", plus the `result.md` path. No commit, no fix.
