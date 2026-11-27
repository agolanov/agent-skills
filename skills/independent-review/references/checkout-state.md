# Checkout state and verification evidence

Ordinary Git evidence guards every suite, review, cross-check, retry, resume and clean/path gate. Local repositories and agents are trusted; these checks catch accidental changes. They need Git and the installed shell, no Python. Evidence lives outside every checked checkout.

## Record and compare Git evidence

A boundary is these four commands for one absolute checkout, each with its command, cwd, actual exit, stdout and stderr, in a fresh external directory:

```text
git -C CHECKOUT rev-parse HEAD
git -C CHECKOUT status --porcelain=v1 -z --untracked-files=all
git -C CHECKOUT diff --binary --no-ext-diff --no-textconv
git -C CHECKOUT diff --cached --binary --no-ext-diff --no-textconv
```

Run them with `GIT_OPTIONAL_LOCKS=0` and with `GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE` and `GIT_COMMON_DIR` cleared in that process only. Keep stdout as bytes (NULs and binary patches included), never through a text pipeline or command substitution. A launch error or nonzero exit makes the boundary unavailable, never clean; all four must succeed before the dependent action.

```bash
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; export GIT_OPTIONAL_LOCKS=0
git -C "$checkout" rev-parse HEAD >"$evidence/head.stdout" 2>"$evidence/head.stderr"; echo $? >"$evidence/head.exit"
git -C "$checkout" status --porcelain=v1 -z --untracked-files=all >"$evidence/status.stdout" 2>"$evidence/status.stderr"; echo $? >"$evidence/status.exit"
git -C "$checkout" diff --binary --no-ext-diff --no-textconv >"$evidence/worktree-diff.stdout" 2>"$evidence/worktree-diff.stderr"; echo $? >"$evidence/worktree-diff.exit"
git -C "$checkout" diff --cached --binary --no-ext-diff --no-textconv >"$evidence/cached-diff.stdout" 2>"$evidence/cached-diff.stderr"; echo $? >"$evidence/cached-diff.exit"
```

On native Windows run the same four in PowerShell 7 with the resolved `git` application, `$ErrorActionPreference = 'Stop'`, `$PSNativeCommandUseErrorActionPreference = $false`, the four variables removed from `Env:`, direct `>`/`2>` redirection (byte-preserving in PowerShell 7) and `$LASTEXITCODE` written to each `.exit` file; a launch or redirection exception is unavailable evidence. Another shell uses its own byte-preserving file and process APIs; an unsupported shell stays explicit, and no runtime is installed for this.

At entry and continuation also record `git rev-parse --show-toplevel`, the branch (`symbolic-ref --quiet --short HEAD`, or the caller's expected detached state) and HEAD, and check them against the task identity; a mismatch blocks until reconciled.

Compare before and after stdout as bytes (`cmp`, `fc.exe /b`), keeping each comparison's exit: 0 equal, 1 different, other unavailable. Any difference, status-only included, is inspected and disposed of. A parallel review uses one shared before/after set; clone mode records both checkouts. Report **unchanged recorded Git evidence**, never proof that all bytes stayed unchanged.

## Direct-use preflight

Take a fresh boundary immediately before each gate and confirm HEAD is the required commit. A **clean gate** needs four successful commands, empty status and empty diffs; a dirty direct review reviews the committed state ([direct use](../SKILL.md#direct-use)). Path gates parse the raw NUL-delimited status (two status columns, a space, a path; rename and copy entries carry a second path, both counted) and compare exact repository-relative paths, case and spaces included, never substrings; a status that cannot be parsed or conflicts with the diffs stops the gate.

- **Follow-ups-only gate:** every affected path equals the one follow-ups file.
- **Own-paths gate:** no affected path equals a caller-owned file; unrelated dirty paths pass.

Stage and commit only explicitly task-owned paths. A gate grants no write, merge or push authority.

The retained `scripts/checkout-state.py` is optional legacy for existing callers on a compatible runtime: never the default gate, a Windows requirement or a fallback that makes failed Git evidence clean. Its records keep their own schema; a phase begun with it keeps it until resolved.

## Other read-only Git gates

Branch, ancestry, root, commit and artifact checks use ordinary Git with `GIT_OPTIONAL_LOCKS=0`, literal arguments and actual exits (for example `git -C "$tree" log --oneline "$base..$branch"`, `git diff --quiet "$branch" HEAD -- "$artifact"`). For a comparison, 0 is equal, 1 different, other an error; for a lookup, a documented absence is not a failure. Unavailable evidence stops the dependent action.

## Evidence limits

These checks are not an atomic snapshot. They miss ignored files, content changes of already-untracked files, assume-unchanged and skip-worktree paths, bytes hidden by Git filters or normalization, nested repositories and submodules, and transient writes restored before the next boundary. Carry these limits in every state, suite and review record, and disclose any further known gap. Finding verdict, result validity and verification coverage are separate decisions.

## Phase recovery and resume

**Pending window phase first.** Before any Git recovery, every participant of a phase with unconfirmed shutdown needs a fresh `alive` exit exactly 1 from its retained owner and name records ([window barrier](window-reviewers.md#stop-confirm-capture-validate)). Missing records or another exit keep the caller `blocked: reviewer shutdown unconfirmed` (system-qualified with `state.md` in a dual review), even beside a proven difference; nothing is compared, adjudicated, retried or rebaselined meanwhile.

Then compare a fresh boundary of every monitored tree with the phase's saved before, which is kept until the phase is resolved:

- **Failed before:** nothing launched, no attempt spent; obtain the baseline first.
- **Failed after:** record every other condition; without a proven difference the result is `invalid: state verification unavailable: <error>`, spending the review's budget (a suite failure blocks before reviewers and spends none).
- **Retry, rerun, reuse or new baseline:** unchanged evidence continues; a difference returns `checkout changed` for the original phase's adjudication; persistent unavailability blocks. An unchanged continuation keeps the invalid outcome, charged once; no resume double-charges or resets a budget.
- **Same-HEAD resume** (`scratch` or `invalidating`): needs unchanged evidence against the pre-interruption baseline before the answer is applied.
- **New-HEAD reconciliation:** needs an explicit reconciled baseline, a new target and no unexplained residual change; old review answers do not apply, and suite applicability is refreshed.

A proven difference keeps `checkout changed` precedence even beside errors. Preserve outputs, unexpected content and diffs externally with their source; a read failure alone is no write claim. Never reset unexpected writes or fold them into commits.

## Resolve checks and bind suite evidence

At entry resolve the exact ordered complete-suite and targeted commands with cwd, requirement source, intended coverage and mandatory phase/producer obligations: approved spec Verification first, then mandatory project rules, then README for commands nothing else defines. Resolve conflicts first; record unavailable coverage, or `no complete suite defined`. Inspect retained run records, implementation runs included, before scheduling checks, and forward the resolved set, run/acceptance paths and remaining checks to every worker. A reviewer gets commands and results as data in its [context file](review-wrapper.md#the-context-file); the session running the review owns the suite and its records. A requirement that names the reviewer as the one who runs a check stays the reviewer's, met only by runtime records showing each command and how it ended, else `pending`.

### Merge-candidate checks

A required check whose Verification item names the merge candidate as its phase (for example `Phase: merge candidate`) is due on the merge candidate: the reviewed branch on the current main, after review and before the merge. Until then every record, context file and result carries it as `pending: merge candidate` with its command; it is no coverage gap. A later change of the candidate makes it pending again unless the acceptance retains its evidence for the new HEAD.

### Run records and applicability

A run record is immutable: tested checkout, branch, HEAD and working/index state (dirty inputs included), ordered commands, cwd, outputs and exits, before/after boundaries with comparisons, relevant runtime, fixture, dependency, configuration and environment facts, known writes and limits. Unknown facts stay unknown.

Reuse stays in the same absolute tested checkout. Each reuse gets a separate acceptance record:

1. Inspect the actual records and outputs; passing coverage needs successful commands and historical boundaries.
2. Resolve pending phase recovery first, then compare a current boundary with the last accepted one and dispose of every difference.
3. Inspect the complete intervening diff against the tested state; equal HEAD or tree IDs alone are not enough.
4. Keep coverage of unchanged inputs; rerun checks whose inputs changed, the complete suite when the effect is broad or unknown.
5. Publish per check `retained`, `fresh`, `pending` or `failed/unavailable`, preserving the original run identities.

A passing dirty run covers a task-state commit when inspection proves exactly those inputs were committed. After a bounded test-only cleanup, prior complete coverage covers unaffected tests once the whole changed test file and relevant static checks pass. A completed writing suite on unchanged HEAD may be retained after restoration is proven against its before-suite evidence; suite writes otherwise need adjudication and restoration or an authorized task commit before review. A failed required check blocks dependent work and grants no amend, squash or unreviewed corrective commit.

```text
Original runs: absolute record paths; original tested states
Current target: checkout, branch, full committed SHA and successful Git boundary
Recovery prerequisite: none | resolved, comparison/disposition paths | pending, blocks replacement checks
Intervening change: diff/evidence paths and disposition of every difference
Applicability: per check, unchanged coverage and inspected inputs
Fresh checks: record paths with command/cwd/exit and coverage
Required phase/producer: source and satisfied or pending obligation
Coverage: retained | fresh | pending | failed/unavailable, per item
Limits: Git evidence limits and other known gaps
```

### Run and hand off a suite

Use from the first complete suite meant for review-fix-loop, implementation checks included. A delegated brief carries `Suite evidence:` with this reference's path, an external records directory and retained run/acceptance paths (`None` when absent).

1. **Inspect retained runs** by the acceptance sequence above; pending recovery blocks replacement checks.
2. **Prepare and capture.** A fresh external run directory; record commands, cwd, tested identity and state, coverage and obligations; capture the before boundary (a failed one runs nothing).
3. **Run and capture.** Run in the recorded cwd, keep outputs and exits, then capture and compare the after boundary, also after a failure.
4. **Publish the run** as an immutable record, linked beside its result in the producer's `Checks`, failed runs included.
5. **Accept for the current target** in a separate acceptance record, and forward run/acceptance paths and remaining checks to every worker.

## Verification marker

Report `Verification: complete | incomplete: <specific required checks or coverage gaps>` beside every findings verdict and in attempt results. `complete` means every required check and phase/producer obligation has applicable passing evidence for the current committed target; name each pending, failed or unavailable one with command, cwd and exit or reason. Keep `no complete suite defined` visible beside the marker; it is not a failed check. A [merge-candidate check](#merge-candidate-checks) still pending is named beside the marker and does not change it. A host review command that could not start or apply (such as `/security-review` without `origin/HEAD`) is a disclosed tool limitation, not a required check; refs, remotes and Git configuration stay as they are. A clone-only missing-setup exception still means incomplete. Superseded invalid attempts do not poison current coverage. Validity, Verification and verdict are separate: a direct CLEAN may stand beside incomplete verification, while the loop cannot close clean with a failed or unrun required check.
