# Checkout state and verification evidence

Use ordinary Git evidence at every suite, review, cross-check, retry, resume and clean/path gate. Local repositories and agents are trusted; these checks protect against accidental changes. They need Git and the installed shell, with no Python prerequisite. Keep evidence outside every checkout being checked.

## Record and compare Git evidence

For each boundary record the absolute checkout, command, cwd, actual exit, stdout and stderr of all four commands:

```text
git -C CHECKOUT rev-parse HEAD
git -C CHECKOUT status --porcelain=v1 -z --untracked-files=all
git -C CHECKOUT diff --binary --no-ext-diff --no-textconv
git -C CHECKOUT diff --cached --binary --no-ext-diff --no-textconv
```

Set `GIT_OPTIONAL_LOCKS=0` for these reads. Use a fresh external directory for each boundary. Preserve stdout bytes, including NULs and binary patches; do not pass them through a text pipeline or command substitution. Retain failed commands and diagnostics. A launch error or nonzero Git exit makes that boundary unavailable, never clean. Obtain all four successful results before starting the dependent action.

At entry and continuation, verify `git -C CHECKOUT rev-parse --show-toplevel`, the actual branch (`symbolic-ref --quiet --short HEAD`, or the caller's expected detached state) and the recorded HEAD against the requested task identity. Record their outputs/exits too. Inherited `GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE` and `GIT_COMMON_DIR` can redirect these commands: diagnose them or clear them only in the current command process before checking. An unexpected checkout, branch, index override or HEAD blocks the dependent action until reconciled; `-C` alone does not establish identity.

On POSIX, bind absolute `checkout` and fresh external `evidence` directories. Run in a command shell that saves failures before continuing (without `errexit`):

```bash
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
export GIT_OPTIONAL_LOCKS=0
git -C "$checkout" rev-parse HEAD >"$evidence/head.stdout" 2>"$evidence/head.stderr"
printf '%s\n' "$?" >"$evidence/head.exit"
git -C "$checkout" status --porcelain=v1 -z --untracked-files=all >"$evidence/status.stdout" 2>"$evidence/status.stderr"
printf '%s\n' "$?" >"$evidence/status.exit"
git -C "$checkout" diff --binary --no-ext-diff --no-textconv >"$evidence/worktree-diff.stdout" 2>"$evidence/worktree-diff.stderr"
printf '%s\n' "$?" >"$evidence/worktree-diff.exit"
git -C "$checkout" diff --cached --binary --no-ext-diff --no-textconv >"$evidence/cached-diff.stdout" 2>"$evidence/cached-diff.stderr"
printf '%s\n' "$?" >"$evidence/cached-diff.exit"
```

On native Windows, use the verified installed PowerShell executable. This recipe uses pwsh 7.6.9's byte-preserving direct native stdout redirection; run it in that shell, with absolute `checkout` and fresh external `evidence` directories. Resolve the executable first; a launch/redirection exception is unavailable evidence even if an old `$LASTEXITCODE` exists.

```powershell
$git = (Get-Command git -CommandType Application -ErrorAction Stop).Source
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
foreach ($name in 'GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_COMMON_DIR') { Remove-Item -LiteralPath ('Env:' + $name) -ErrorAction SilentlyContinue }
$env:GIT_OPTIONAL_LOCKS = '0'
& $git -C $checkout rev-parse HEAD > "$evidence/head.stdout" 2> "$evidence/head.stderr"
$LASTEXITCODE | Set-Content -LiteralPath "$evidence/head.exit" -Encoding ascii
& $git -C $checkout status --porcelain=v1 -z --untracked-files=all > "$evidence/status.stdout" 2> "$evidence/status.stderr"
$LASTEXITCODE | Set-Content -LiteralPath "$evidence/status.exit" -Encoding ascii
& $git -C $checkout diff --binary --no-ext-diff --no-textconv > "$evidence/worktree-diff.stdout" 2> "$evidence/worktree-diff.stderr"
$LASTEXITCODE | Set-Content -LiteralPath "$evidence/worktree-diff.exit" -Encoding ascii
& $git -C $checkout diff --cached --binary --no-ext-diff --no-textconv > "$evidence/cached-diff.stdout" 2> "$evidence/cached-diff.stderr"
$LASTEXITCODE | Set-Content -LiteralPath "$evidence/cached-diff.exit" -Encoding ascii
```

Record the commands/cwd alongside these files and inspect all exits before proceeding. For another installed shell, use its ordinary file/process APIs to preserve stdout bytes and record real exits. Keep any unsupported shell case explicit; do not install a runtime to satisfy this reference.

Record before and after each phase, then compare corresponding stdout files as bytes, for example with `cmp` on POSIX or `fc.exe /b` on Windows. Retain each comparison's output and real exit: 0 is equal, 1 is different, and a comparison error is unavailable evidence. Any difference requires inspection and disposition, including a status-only difference. Report **unchanged recorded Git evidence**, not proof that all filesystem bytes were unchanged. In a parallel review use one shared before/after set; in clone mode record and compare both checkouts separately.

## Direct-use preflight

Use the four-command boundary immediately before each clean/path gate; an earlier result is not a later gate. Confirm the recorded HEAD is the required commit. A **clean gate** requires successful commands, empty status and empty worktree/cached diffs. A direct review with a dirty result reviews the committed state, per **Uncommitted changes** in [direct use](../SKILL.md#direct-use). Preserve unrelated work.

For path gates, parse the raw NUL-delimited porcelain v1 status, not its displayed lines. Each entry starts with two status columns and a space, followed by a repository-relative path; rename/copy entries have a second NUL-delimited path. Include both rename/copy paths. Compare exact paths with the caller's file set, preserving case, spaces and other literal characters; substring matching is insufficient. If the status cannot be parsed faithfully or conflicts with the diffs, stop that gate and inspect the evidence.

- A **follow-ups-only gate** requires every affected path to equal the one follow-ups file.
- An **own-paths gate** requires no affected path to equal any caller-owned file; unrelated dirty paths pass that gate.
- Stage and commit only explicitly task-owned paths. A path gate grants no write, merge or push authority.

**OPTIONAL COMPATIBILITY:** the retained `scripts/checkout-state.py` is the unchanged legacy Python helper. Existing callers/tests may explicitly use its capture/compare/module interfaces on a compatible installed runtime. It is not the default gate, a native Windows requirement or a fallback that turns failed Git evidence into clean evidence. Legacy records retain their own schema and limits; keep their evidence separate from ordinary Git outputs.

The first Python recipe below preserves the legacy `(checkout-state.py, capture_dir)` interface. It reads an existing successful legacy capture; recipe and output stay outside the checkout:

```python
import json
import runpy
import sys

sys.dont_write_bytecode = True
state = runpy.run_path(sys.argv[1])
record, _ = state['read_record'](sys.argv[2])
print(json.dumps(state['preflight'](record)))
```

For this optional recipe, retain the capture/recipe exits and errors; an exception, diagnostic capture or nonzero exit is unavailable. The result's `uncommitted` boolean and base64 `paths` retain their legacy meanings. Decode paths and use the exact-path gate rules above. Legacy successful evidence does not expand the ordinary Git guarantee.

## Other read-only Git gates

Use ordinary Git for branch, ancestry, root, commit and artifact checks too, with `GIT_OPTIONAL_LOCKS=0`, literal argument arrays/quoting and actual exits. Examples:

```bash
GIT_OPTIONAL_LOCKS=0 git -C "$directory" rev-parse --show-toplevel
GIT_OPTIONAL_LOCKS=0 git -C "$review_tree" log --oneline "$base..$branch"
GIT_OPTIONAL_LOCKS=0 git -C "$docs_tree" diff --no-ext-diff --no-textconv --quiet "$branch" HEAD -- "$artifact"
```

For a comparison such as `diff --quiet`, exit 0 means equal and 1 means different; an error is neither. For lookups, distinguish a documented absence result from a command/setup failure. Retain stderr and stop dependent actions when required evidence is unavailable. There is no mandatory wrapper, private-index capture or normalization/stat-refresh ceremony. Explicit mutating actions keep their existing authority.

## Evidence limits

These are ordinary trusted-local checks, not an atomic snapshot or adversarial filesystem proof. They can miss ignored files, changes to already-untracked file contents, assume-unchanged/skip-worktree paths, bytes hidden by Git normalization/filters, nested repository/submodule contents and transient writes restored before the next boundary. The ordinary repository configuration applies. A clean outer result does not certify clean submodules. No result authorizes writes to those surfaces.

Carry these limits in state/suite/review records. A finding verdict, result validity and verification coverage are separate decisions. Disclose any additional known gap rather than claiming that Git output equality proved raw-byte equality.

## Phase recovery and resume

Keep the successful before evidence until a phase is resolved. Clone mode tracks both the reviewed clone and original checkout, naming which changed or is unavailable.

- Failed **before** evidence: launch nothing and spend no attempt. Resolve the error and obtain the pending phase's baseline; do not attribute a later authorized commit to an earlier reviewer.
- Failed **after** evidence: record every other completion/settings/coverage condition. Absent a proven difference, return `invalid: state verification unavailable: <error>`. A review spends its existing invalid-attempt budget; a suite failure blocks before reviewers and spends none. Parallel attempts retain separate validity and budgets.
- Before retry, rerun, reuse or a replacement baseline, compare the next successful four-command results to the interrupted phase's saved before results. Unchanged evidence permits continuation; a difference returns `checkout changed` for the original phase's adjudication. Persistent unavailability blocks.
- Same-HEAD resume, both `scratch` and `invalidating`, requires unchanged recorded evidence against the pre-interruption baseline before applying the answer and existing reuse/spend rules. Keep the answer unapplied while changes remain unexplained.
- Authorized new-HEAD reconciliation requires an explicit reconciled baseline, a new target and no unexplained residual changes. Resolve an interrupted phase first; preserve old evidence and spent attempts. Refresh suite/review evidence for the new commit.

A demonstrated difference returns `checkout changed` even beside errors. Preserve outputs, available unexpected content and diffs externally, identify their source and let the caller adjudicate. A read failure alone is not a write claim. Never reset or fold unexpected writes into commits automatically.

An interrupted legacy-helper phase keeps its original evidence method until it is resolved or explicitly reconciled by its caller; ordinary Git outputs cannot silently certify equality with a legacy capture. New phases use the ordinary Git boundary by default.

## Resolve checks and bind suite evidence

At entry resolve exact ordered complete-suite commands and targeted checks, their working directories and sources. Approved spec Verification is primary; mandatory project checks/defaults still apply, and README supplies commands only where these sources do not define them. Resolve conflicts before review; do not replace explicit commands or drop mandatory checks. Record unavailable coverage. If no complete suite exists, record exactly `no complete suite defined`.

Forward the resolved set to every prompt; reviewers do not rediscover commands. A single final-pass reviewer (direct use included) independently executes the exact complete-suite commands in the reviewed tree. Round 1 adds security focus, not that independent suite rerun. Dual reviewers inherit the session/caller suite and may run targeted reproductions, never concurrent complete suites.

Each suite evidence record contains ordered commands, cwd, exits, reviewed commit, absolute checkout, successful before/after Git outputs and their comparison, known dependency/environment changes and evidence limits. Reuse requires the **same commit and checkout**, unchanged recorded Git evidence from the run through reuse, and no known environment/dependency change. Failed/unavailable boundary checks prevent reuse.

For a completed suite phase on unchanged HEAD, after either caller answer (`scratch` or `invalidating`), successful restoration comparison to the before-suite outputs supplies the required evidence: retain the original changed comparison and the restoration comparison, then reuse the recorded run on the same commit/checkout and advance to review without rerunning that writing suite. The suite has no reviewer attempts to spend under either answer. Keep actual suite exits/coverage and all other reuse conditions. New-HEAD reconciliation requires fresh suite evidence. A commit after a suite run requires another run on committed HEAD, even for generated-only changes; tree equivalence is insufficient. Keep the loop's pre-commit suite gate too.

Suite writes require caller adjudication and restoration or a task commit before review. Failed post-commit required checks block review/completion without authorizing amend, squash or unreviewed corrective commits.

## Verification marker

Report `Verification: complete | incomplete: <specific required checks or coverage gaps>` beside findings verdicts, and in attempt results. Aggregate suite exits and relevant retained review/cross-check gaps on the current commit. Include command, cwd, exit/reason and missing setup. Superseded invalid attempts replaced by valid retries do not poison current coverage.

`complete` means resolved required verification succeeded within the stated boundaries. Keep `no complete suite defined` visible beside the marker; it is not itself a failed check. A permitted clone-only missing-setup exception still means incomplete; any required check not attempted remains missing coverage. Validity, Verification and findings verdict are separate: direct CLEAN can coexist with incomplete verification, while the loop cannot close clean with failed/unrun required checks.
