# Checkout state and verification evidence

Read this contract before capturing a suite, review, cross-check, retry or resume boundary. Resolve `state_helper` as the absolute `scripts/checkout-state.py` beside the owning installed independent-review `SKILL.md`. Python 3 and that helper are required; unavailable dependencies or impractical full hashing mean unavailable verification, with no porcelain-only fallback.

## Capture and compare

Each invocation owns a **new, nonexistent** output directory outside the reviewed checkout. Create its parent beforehand. Resolve the absolute checkout, including the actual clone when used. Keep prompts, logs, snapshots, preserved unexpected content and differences outside every monitored tree.

```bash
python3 "$state_helper" capture --checkout "$review_tree" --output-dir "$attempt_dir/before"
python3 "$state_helper" capture --checkout "$review_tree" --output-dir "$attempt_dir/after"
python3 "$state_helper" compare --before "$attempt_dir/before" --after "$attempt_dir/after" --output-dir "$attempt_dir/comparison"
```

Run each command separately; retain its real exit and stderr, including when capture fails. Compare successful or diagnostic captures. Existing output directories are refused, including empty ones; a refused/crashed invocation owns no usable output. Never interpret leftover files as its result.

- `snapshot.json`: schema 2, base64 canonical checkout identity, `complete: true`, observed `fields`, empty `errors`, coverage `limits`.
- `diagnostic.json`: same schema, `complete: false`, errors and individually observed fields. It cannot prove equality. Shared successful fields can prove a difference.
- `result.json`: schema 2, `outcome: identical|changed|unavailable`, two input paths and SHA-256 identities (or unavailable-input reason), `differences` with field/before/after evidence, `errors`, and limits. Atomic publication prevents a partial record becoming evidence. Input bytes must still match the recorded identities.

All JSON is UTF-8. Pathnames, symlink text, literal metadata and raw NUL status are base64; content hashes are raw-byte SHA-256. Compare payloads, not artifact paths or timestamps. Validate schema/completeness/encoding and the result's input identities; missing/malformed output, a signal/crash, stale output or exit/result mismatch means unavailable. Never infer a write from exit 1 alone:

```text
capture exit == 0 AND valid complete snapshot -> usable snapshot
compare exit == 0 AND result.outcome == "identical" -> identical monitored state
compare exit == 1 AND result.outcome == "changed" + evidence -> checkout changed
otherwise -> invalid: state verification unavailable (unless proven change
was separately recorded); never infer writes from exit 1 alone.
```

Retain errors even beside a proven change. Preserve available records and unexpected content/diff, identify its source using the caller's attribution rules and return `checkout changed` for adjudication. This helper neither restores nor commits, retries reviewers nor decides ownership. A failed read alone is never a write claim.

## Direct-use preflight

Before the direct-use uncommitted-change decision, run the capture command above into a fresh external directory. Use that complete snapshot's safe status plus an outer **index-only** comparison to its recorded HEAD. Status excludes gitlinks, so the index-only comparison is required to retain staged gitlink additions, removals, conflicts and OID/mode changes. It does not inspect submodule worktrees. Run this recipe as `python3 <recipe.py> "$state_helper" "$capture_dir"`, with the recipe and output outside the checkout:

```python
import json
import runpy
import sys

sys.dont_write_bytecode = True
state = runpy.run_path(sys.argv[1])
record, _ = state['read_record'](sys.argv[2])
if not record['complete']:
    raise ValueError('preflight capture unavailable')
staged = state['git_bytes'](
    state['unb64'](record['checkout']), 'diff-index', '--cached', '--raw', '-z',
    '--no-ext-diff', '--no-textconv', '--ignore-submodules=dirty',
    record['fields']['head'], '--')
print(json.dumps({'uncommitted': bool(state['unb64'](record['fields']['status']) or staged),
                  'status': record['fields']['status'], 'staged': state['b64'](staged),
                  'limits': record['limits']}))
```

Retain the capture, recipe result and real exits. Any failed capture, exception or nonzero recipe exit makes preflight unavailable: launch nothing and do not substitute plain status. A true `uncommitted` value takes the caller's existing commit-or-clone decision; false means no detected outer/staged changes within the disclosed limits, not a clean submodule. Decode the base64 NUL records for the path list. The checked, environment-sanitized Git wrapper and `--cached` are essential: an ordinary worktree status/diff can execute submodule-selected configuration even when its output is empty. Apply this preflight to inherited direct-use callers too.

## Monitored surfaces and limits

Capture observes HEAD, every index path/stage/mode/OID and observation flag, NUL porcelain, every tracked path and every nonignored untracked leaf recursively. Regular files use no-follow raw-byte hashing and executable bits, links literal targets, stable missing tracked paths deletion markers, directory replacements their kind. Git ignore rules apply only to untracked discovery; tracked ignored files and `.gitignore` stay covered. Nonignored FIFO/socket/device entries retain kind and device identity without reading streams. Empty untracked directories need not appear.

Only directories without tracked descendants use the nested-untracked boundary; directories containing tracked descendants retain the same literal `.git` metadata record and still expose their nonignored untracked descendants when that entry is present. Nested untracked repositories are directory records with literal `.git` file/link content or ordinary `.git/HEAD` text, including unborn symbolic HEAD and explicit missing metadata. The literal reader resolves neither pointer targets nor symbolic refs and executes no Git commands/configuration/filters there. Outer Git discovery (`status` and `ls-files --others`) can nevertheless inspect an untracked nested gitfile target and block on a FIFO HEAD; that pre-existing availability gap remains outside this submodule boundary. A tracked file or link already replaced by such a directory also retains its literal metadata record; without tracked descendants its nested content remains unmonitored. Nested content and branch-tip changes with unchanged literal metadata are unmonitored.

Gitlinks retain every index path/stage/mode/OID and observation flag plus no-follow `location` evidence. Outer status uses `--ignore-submodules=all` and a deduplicated literal exclusion pathspec for every mode-160000 path across all index stages. Index/gitlink changes remain detected separately. The exclusions cover the enumerated index; a concurrent gitlink addition can escape that list and cause a target read/hang, within the non-atomic capture limitation below.

A submodule record contains `location` and boolean `metadata_present`, meaning literal `.git` presence only, not usable initialization. A replaced link/file/special/missing gitlink or parent stops traversal at that component and retains its content/kind, with presence false and no metadata fields. An actual directory adds `metadata`, the literal `.git` observation; missing `.git` is explicit and presence is false even if `.git/modules` remains. Gitfiles retain raw text, links only their link text, and special entries their kind/device. Malformed, dangling and legitimately relocated pointers are observations, never instructions to open another repository.

Only an ordinary embedded `.git` directory adds `embedded_head`, a literal `.git/HEAD` observation. Symbolic, unborn and detached HEAD text is not a resolved commit; links are retained without traversal, a missing HEAD is explicit, and a FIFO is recorded without reading its stream. No Git runs in a submodule or resolves its gitfile/link/ref/common-dir targets or configuration through this helper. Unreadable or observably racing metadata makes capture unavailable.

Submodule content, clean-to-dirty and dirty-to-dirty transitions, nonignored untracked content and internal ref/index/config changes are not monitored. Resolved HEAD or branch-tip changes leaving the recorded literal metadata unchanged are unmonitored, including absorbed submodules with unchanged pointer text. Embedded literal HEAD edits are detected; ref-tip changes behind unchanged symbolic HEAD are not. Identical monitored evidence never establishes that a submodule is clean or internally unchanged.

Two inventories/content passes detect observable races; an enumerated untracked path disappearing, failed Git/hash/read, unreadable metadata or changing content/kind makes capture unavailable. Git-local environment overrides are sanitized, pathspecs are literal (filenames cannot act as Git patterns), and optional locks are disabled. This is a phase-boundary comparison, not a lock or atomic snapshot: transient restored writes and undetectable concurrency remain outside its guarantee. Full hashing deliberately costs work proportional to all tracked and discovered untracked bytes, including binaries and LFS worktree data; do not omit clean/flagged files to save time.

Every result/state line carries: **ignored untracked paths not monitored; submodule/nested-repository content not recursively monitored; special-file contents not monitored; submodule resolved HEAD and dirty state not monitored**. Except for the literal nested/submodule metadata described above, Git administrative/configuration files and external dependencies/environment are also unmonitored. The selected outer repository retains its existing administrative/configuration trust boundary; this helper does not close execution through an attacker-writable outer `.git`. These detection limits never authorize checkout writes.

## Phase recovery and resume

Capture before a phase and after it, then compare. For two parallel reviewers, use one pre-phase capture and one post-phase capture after both finish; both attempts reference that comparison. In clone mode monitor **both** the reviewed clone and original checkout throughout suite/review/cross-check/retry/resume, retaining separate records and naming which tree changed or is unavailable.

- Failed **pre-phase** capture: launch nothing and spend no attempt. Resolve the error and obtain a baseline for this pending phase. Do not compare against an earlier completed phase or attribute an authorized fix commit to an earlier reviewer.
- Failed **post-phase** capture: validate and record every other reviewer condition, return unavailable absent proved difference, and spend the existing invalid-attempt budget. For a shared failure each reviewer retains its own completion/coverage/settings result and budget; no new loop retry is added. A suite-phase failure blocks before reviewers, spending none of their attempts.
- Recovery: retain that interrupted phase's last successful pre-phase snapshot. Before retry, suite rerun, evidence reuse or a replacement baseline, compare the **next successful** capture to that saved snapshot. Equality permits continuation; a difference returns `checkout changed` under the original phase attribution. Persistent unavailability blocks. An unavailable capture is neither reusable suite evidence nor proof of restoration.
- Same-HEAD resume, both `scratch` and `invalidating`: require successful equality to the pre-interruption monitored state before applying the answer; otherwise return `checkout changed` again with the answer unapplied. Only then apply the caller's established reuse/spend rules.
- Authorized reconciliation at a new HEAD: require a new target and an explicit reconciled baseline with no unexplained residual changes; void prior results and refresh suite/review on that commit. Preserve spent attempts. Do not demand equality to old committed content. An unresolved failed post-phase capture still requires its recovery comparison/adjudication before accepting a new baseline.

Schema-1 or mixed-schema captures are incompatible and yield unavailable, not equality or a write solely from incompatibility. An interrupted phase with an incompatible retained baseline cannot silently reuse it or replace it with a schema-2 baseline; report unavailable and require explicit reconciliation under the caller's authority.

Caller-approved commits and fully reconciled states establish new phase baselines. Preserve unrelated work and old evidence; never automatically reset it.

## Resolve checks and bind suite evidence

At entry resolve exact ordered complete-suite commands and targeted checks, their working directories and sources. Approved spec Verification is primary; mandatory project checks/defaults still apply, and README supplies commands only where these sources do not define them. Resolve conflicts before review; do not replace explicit commands or drop mandatory checks. Record unavailable coverage. If no complete suite exists, record exactly `no complete suite defined`.

Forward the resolved set to every prompt; reviewers do not rediscover commands. A single final-pass reviewer (direct use included) independently executes the exact complete-suite commands in the reviewed tree. Round 1 adds security focus, not that independent suite rerun. Dual reviewers inherit the session/caller suite and may run targeted reproductions, never concurrent complete suites.

Each suite evidence record contains ordered commands, cwd, exits, reviewed commit, absolute checkout, successful before/after snapshots and comparison, known dependency/environment changes and coverage limits. Reuse requires the **same commit and checkout**, successfully compared monitored state from the run through reuse, and no known environment/dependency change. Failed/unavailable captures prevent reuse. For a completed suite phase on unchanged HEAD, after either caller answer (`scratch` or `invalidating`), successful restoration equality to its pre-suite snapshot supplies the required state proof: retain the original changed comparison and the restoration comparison, then reuse the recorded run on the same commit/checkout and advance to review without rerunning that writing suite. The suite has no reviewer attempts to spend under either answer; this preserves its existing same-HEAD resume semantics. Keep the actual suite exits/coverage, and all other reuse conditions still apply. New-HEAD reconciliation requires fresh suite evidence. A commit after a suite run requires another run on committed HEAD, even for generated-only changes; tree equivalence is insufficient. Keep the loop's pre-commit suite gate as well. Suite writes require caller adjudication and restoration or a task commit before review; a new commit always needs new evidence. Failed post-commit required checks block review/completion without authorizing amend, squash or unreviewed corrective commits.

## Verification marker

Report `Verification: complete | incomplete: <specific required checks or coverage gaps>` beside findings verdicts, and in attempt results. Aggregate suite exits and relevant retained review/cross-check gaps on the current commit. Include command, cwd, exit/reason and missing setup. Superseded invalid attempts replaced by valid retries do not poison current coverage.

`complete` means resolved required verification succeeded within the stated boundaries. Keep `no complete suite defined` visible beside the marker; it is not itself a failed check. A permitted clone-only missing-setup exception still means incomplete; any required check not attempted remains missing coverage. Validity, Verification and findings verdict are separate: direct CLEAN can coexist with incomplete verification, while the loop cannot close clean with failed/unrun required checks.
