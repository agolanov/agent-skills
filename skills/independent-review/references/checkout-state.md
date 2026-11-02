# Checkout state and verification evidence

Read this contract before capturing a suite, review, cross-check, retry or resume boundary. Resolve the owner beside the installed independent-review `SKILL.md`. Select by native OS before shell. On native Windows, including Git Bash, use the installed PowerShell executable with `-NoProfile -ExecutionPolicy Bypass -File ABS/scripts/checkout-state.ps1` through `Invoke-CheckoutStateCommand` below. POSIX uses `ABS/scripts/checkout-state`; MSYS/Cygwin callers receive exit 2 and the native Windows recipe. WSL is Linux. `checkout-state.py` remains a compatible Python CLI/module, not a universal prerequisite.

On POSIX run `checkout-state resolve` once and retain its JSON `argv` vector, engine/version and host provenance outside snapshots. Use that exact vector throughout the phase; do not rediscover PATH or change engines between captures. Discovery probes installed Python features rather than declaring a new version floor. On macOS it classifies known Apple Python/Git launchers and probes `xcode-select -p` before executing them; missing developer tools never starts an installer. No proven no-Python Darwin engine is shipped yet: stock JXA returns unavailable until architecture-specific native bindings, layouts, integer JSON and CommonCrypto feasibility pass on that actual architecture. Missing runtime/API proof or impractical full hashing means unavailable verification and incomplete host portability. Use existing software; do not prescribe installing a runtime or fall back to porcelain-only checks.

The vectors below use the retained POSIX engine array `state_command`; normal native Windows consumers use the typed function. Python examples remain Linux compatibility examples. Windows PowerShell 5.1/.NET Framework is the native baseline; managed policy or Constrained Language restrictions are unavailable capability. The process-only policy argument changes no user/machine setting. Engine provenance stays outside schema-3 records.

## Capture and compare

Each invocation owns a **new, nonexistent** output directory outside the reviewed checkout. Create its parent beforehand. Resolve the absolute checkout, including the actual clone when used. Keep prompts, logs, snapshots, preserved unexpected content and differences outside every monitored tree.

```bash
"${state_command[@]}" capture --checkout "$review_tree" --output-dir "$attempt_dir/before"
"${state_command[@]}" capture --checkout "$review_tree" --output-dir "$attempt_dir/after"
"${state_command[@]}" compare --before "$attempt_dir/before" --after "$attempt_dir/after" --output-dir "$attempt_dir/comparison"
```

Run each command separately; retain its real exit and stderr, including when capture fails. Compare successful or diagnostic captures. Existing output directories are refused, including empty ones; a refused/crashed invocation owns no usable output. Never interpret leftover files as its result.

- `snapshot.json`: schema 3, base64 canonical checkout identity, `complete: true`, observed `fields`, empty `errors`, coverage `limits`.
- `diagnostic.json`: same schema, `complete: false`, errors and individually observed fields. It cannot prove equality. Shared successful fields can prove a difference.
- `result.json`: schema 3, `outcome: identical|changed|unavailable`, two input paths and SHA-256 identities (or unavailable-input reason), `differences` with field/before/after evidence, `errors`, and limits. Atomic publication prevents a partial record becoming evidence. Input bytes must still match the recorded identities.

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

Use this preflight for direct review and every clean/path gate in delivery and task preparation, including continuations, child verification, integration, queue updates and follow-ups. Run the capture command above into a fresh external directory for the checkout being checked. Normal consumers run the retained engine vector with `preflight --capture-dir ABS` (Windows: typed recipe below). It reads one existing complete capture and writes the same JSON object to stdout, exit 0; invalid/diagnostic evidence returns exit 2 and stderr. It never captures or performs live Git reads implicitly.

The first block below is the Linux/Python compatibility recipe only, accepting `(checkout-state.py, capture_dir)`, with recipe/output outside the checkout:

```python
import json
import runpy
import sys

sys.dont_write_bytecode = True
state = runpy.run_path(sys.argv[1])
record, _ = state['read_record'](sys.argv[2])
print(json.dumps(state['preflight'](record)))
```

The result uses one complete snapshot: safe status, manually discovered untracked entries and the index-only comparison to its recorded HEAD. It includes staged gitlink additions, removals, conflicts and OID/mode changes without reading submodule contents. A gitlink location replaced by a file, link, special entry or missing path makes the gate dirty; an empty uninitialized directory remains normal. `paths` is the sorted base64 list of affected paths; status renames contribute both paths. Decode bytes and compare exact repository-relative paths for allowlists (such as a follow-ups-only commit); substring or line-based matching is insufficient.

Retain capture, recipe result and real exits. Any failed capture, exception or nonzero recipe exit makes preflight unavailable: launch/integrate nothing and preserve the checkout. No plain status/diff fallback. The private status index clears assume-unchanged and clears skip-worktree for present paths; source flags remain unchanged and monitored. Missing skip-worktree paths remain normal sparse-checkout omissions. A clean gate requires `uncommitted: false`; a follow-ups-only gate requires every decoded `paths` entry to equal that follow-ups file; an **own-paths gate** takes the caller's set of owned repository-relative file paths and requires that no decoded `paths` entry equals an owned path, so changes to any other path pass. A direct-use true value takes the caller's existing commit-or-clone decision. False means no detected outer/staged changes within the disclosed limits, not a clean submodule. Re-capture immediately before each dependent action; an older result is not a later gate.

Every dirty isolated gate carries the caller-side possible-cause hint `isolated-normalization-not-applied` beside the exact decoded paths and capture/preflight evidence. This is a possible cause, never a diagnosis of line-ending conversion. The helper's pure preflight JSON keeps its existing fields; callers attach the hint externally, with no live reads. It never refreshes a source index or rewrites source files, config or attributes.

Only immediately after an already-authorized successful working-tree rewrite in that same checkout may its controller wait one fixed two-second settling interval from completion, then run the same operational Git once with `update-index -q --ignore-submodules --refresh`, with a separate ten-second deadline. Record its exit/diagnostics, stop dependent writes on failure/timeout, and capture/preflight afresh after success. This stat-only write uses the rewrite's authority, never the helper or a gate retry loop; no lock removal or automatic repeat. Already-authorized owned clones/worktrees use process-local `-c core.autocrlf=false -c core.eol=lf` at creation/detached checkout before the settling/refresh baseline. A real edit must remain dirty. An in-tree CRLF policy may still block the isolated gate; no attribute or persistent configuration change is authorized.

Without rewrite authority, preserve the checkout and report the exact manual action the user may take with their operational Git: `git -C ABS update-index -q --ignore-submodules --refresh`, then retry the helper gate. Never execute it just because the gate is dirty or certify clean with configuration-enabled status. A status-only phase flip remains `checkout changed` for attribution and reconciliation.

These read-only checks use generated Git configuration. Repository/global normalization filters, CRLF settings and external ignore files are not applied: their files may conservatively appear changed/untracked. Resolve such a result explicitly; never substitute a config-enabled status to certify cleanliness. Authorized commit/merge commands retain the workflow's separate write authority and operational trust requirements; this helper does not sandbox them.

## Native Windows typed invocation

Define this owner-local function in the native PowerShell command tool. Supply the recorded absolute PowerShell executable, absolute owner script, a `[string[]]` argument vector and all caller-protected checkout/gitdir/common-dir roots. It returns raw `Stdout`/`Stderr` byte arrays and `ExitCode`; retain them without text pipelines. Use `Engine.Utf8.GetString($result.Stdout)` only for JSON/text consumers, never for binary `git-read show` output. The `Add-Type` reads trusted installed source, not observed repository files.

```powershell
function Invoke-CheckoutStateCommand {
    param(
        [Parameter(Mandatory=$true)][string]$PowerShellExecutable,
        [Parameter(Mandatory=$true)][string]$OwnerScript,
        [Parameter(Mandatory=$true)][AllowEmptyCollection()][AllowEmptyString()][string[]]$ArgumentVector,
        [Parameter(Mandatory=$true)][AllowEmptyCollection()][string[]]$ProtectedRoots
    )
    # Import trusted owner functions only; no argv is forwarded by dot-sourcing.
    . $OwnerScript
    Initialize-CheckoutStateEngine $OwnerScript $ProtectedRoots
    $requestJson = ConvertTo-Json -InputObject ([string[]]$ArgumentVector) -Compress
    [CheckoutState.Engine]::InvokeJson($PowerShellExecutable, $OwnerScript, $requestJson, $ProtectedRoots)
}
```

Before Add-Type, the initializer rejects a nonprivate temp owner/ACL and reparse ancestry using managed checks, and assigns CodeDom a fresh private compilation directory. Known unsafe temp roots fail before compilation. After loading, the native layer repeats root checks with no-reparse handles. Initial compilation necessarily precedes native handle availability; its preliminary managed ancestry checks do not supply a native pinned-bootstrap proof. Record that limitation separately from protected request consumption. No existing root ACL is changed.\n\nThe function bootstraps an exclusive random current-user private directory directly under the validated native per-user temp root, outside the supplied protected roots. Its request file uses create-new/no-sharing semantics and inherits that private ACL. The child validates owner/ACL, every no-reparse ancestor and pinned file/directory identity before decoding strict UTF-8. Only exactly two process tokens, `--argv-file ABS_JSON`, select this envelope. The decoded complete array must contain strings; it is parsed once as ordinary argv without evaluation. Empty strings, quotes, one-element/zero-element arrays and `--` survive unchanged. Extra envelope tokens and malformed/non-string arrays return exit 2. A fixed vector starts the recorded PowerShell via `System.Diagnostics.Process` with verified MSVCRT quoting; only owned request material is removed after completion/errors. Normal callers invoke this typed function with an array, never forward arbitrary arguments with a bare call operator or shell-evaluated command string.

```powershell
# $protected is an exact array including checkout, gitdir and common-dir.
$before = Invoke-CheckoutStateCommand $powershell $stateScript @('capture', '--checkout', $checkout, '--output-dir', $beforeDir) $protected
$after = Invoke-CheckoutStateCommand $powershell $stateScript @('capture', '--checkout', $checkout, '--output-dir', $afterDir) $protected
$comparison = Invoke-CheckoutStateCommand $powershell $stateScript @('compare', '--before', $beforeDir, '--after', $afterDir, '--output-dir', $comparisonDir) $protected
$gate = Invoke-CheckoutStateCommand $powershell $stateScript @('preflight', '--capture-dir', $beforeDir) $protected
$read = Invoke-CheckoutStateCommand $powershell $stateScript @('git-read', '--checkout', $checkout, '--', 'show', 'HEAD:README.md') $protected
```

Native absolute paths use their Windows filesystem spelling and identity, including drive/UNC containment and case aliases. Git-relative path keys retain exact UTF-8 bytes from native Git; they are neither lowercased nor Unicode-normalized. Invalid UTF-8 or names not representable safely on Windows produce unavailable evidence. Symlinks and junctions are opened as reparse entries; their literal substitute targets use UTF-8 base64 in schema-3 `target`. Compatible optional path-observation fields `reparse_tag`, `reparse_flags` and `reparse_directory` retain and validate the native tag, relative-target flag and directory bit; a tag-only change remains a difference. Unsupported tags/flags are unavailable. The top-level schema and preflight fields stay unchanged. Administrative reparse traversal is refused. Volume serial and all 128 file-ID bits remain unsigned integer JSON tokens, never floating point. Ordinary checkouts need no symlink privilege or Developer Mode. Windows executable representation follows the recorded Git index mode because Windows has no POSIX executable bits. Captures preserve raw LF/CRLF bytes.

Native macOS without an adequate installed Python remains unavailable until its actual-host feasibility gate passes. Do not claim JXA/Python interoperability without those native observations. On macOS with a verified Python engine, use the retained POSIX vector for the four commands above; its raw-byte schema and errors match Linux.

## Other read-only Git gates

Delivery/preparation verification also reads commits, ancestry, branches, repository roots and artifact diffs. Use the same isolation for these reads, including inside copied child briefs and shell recipes:

```bash
"${state_command[@]}" git-read --checkout "$directory" -- rev-parse --show-toplevel
"${state_command[@]}" git-read --checkout "$review_tree" -- log --oneline "$base..$branch"
"${state_command[@]}" git-read --checkout "$docs_tree" -- diff --quiet "$branch" HEAD -- "$artifact"
```

`git-read` finds the containing checkout by walking ancestors for a literal `.git` entry, without running Git during discovery. Commands run at that checkout's root: supply root-relative or absolute file paths, not paths relative to a child directory. Supported read commands are `rev-parse`, `log`, `show`, `diff`, `merge-base`, `check-ignore`, single-target `symbolic-ref`, `cat-file -e|-p|-t|-s <object>`, `check-ref-format --branch <name>`, and `worktree list --porcelain -z`. Worktree registration metadata is copied with no-follow reads; listing requires the main repository to use an ordinary `.git` directory (other layouts report unavailable). Diff/log/show force `--ignore-submodules=dirty --submodule=short`: caller overrides accept only ignore values `dirty`/`all` and format `short`, never negated or ambiguous forms. This suppresses submodule status processes and recursive submodule rendering while retaining ordinary gitlink OID differences. Diff helpers/textconv, output-file options and remerge/diff-merges modes that could generate objects are disabled; diff paths must remain inside the checkout under both lexical normalization and symlink resolution, including dash-prefixed operands after `--`; this also rejects implicit no-index escapes. Exit 0/1 retains the command's meaning (for example equal/different for `diff --quiet`, ignored/not ignored for `check-ignore`); errors/timeouts return 2 with a diagnostic and block the gate. `check-ref-format --branch` normalizes an invalid name to exit 1; setup failures remain exit 2. Retain actual output and exit; a failed lookup is not a missing ref or a clean comparison. Worktree diffs may resolve a gitlink HEAD as data; an inaccessible or blocking target yields unavailable under the ten-second Git timeout. They are extra reads, not literal-only phase observations. Required tree-to-tree comparisons and capture do not need those worktree HEAD reads. Cleanliness still uses capture/preflight, never `git-read diff` as a replacement. Explicit mutating actions use their existing authorized commands.

## Monitored surfaces and limits

Capture observes HEAD, every index path/stage/mode/OID and observation flag, safe NUL status, selected outer administration identity, every tracked path and every nonignored untracked leaf recursively. Regular files use no-follow raw-byte hashing and executable bits, links literal targets, stable missing tracked paths deletion markers, directory replacements their kind. Worktree `.gitignore` and ordinary common-dir `info/exclude` rules apply only to untracked discovery; tracked ignored files and `.gitignore` stay covered. Nonignored FIFO/socket/device entries retain kind and device identity without reading streams. Empty untracked directories need not appear.

Only directories without tracked descendants use the nested-untracked boundary; directories containing tracked descendants retain the same literal `.git` metadata record and still expose their nonignored untracked descendants when that entry is present. Nested untracked repositories are directory records with literal `.git` file/link content or ordinary `.git/HEAD` text, including unborn symbolic HEAD and explicit missing metadata. The literal reader resolves neither pointer targets nor symbolic refs and executes no Git commands/configuration/filters there. A tracked file or link already replaced by such a directory also retains its literal metadata record; without tracked descendants its nested content remains unmonitored. Nested content and branch-tip changes with unchanged literal metadata are unmonitored.

Gitlinks retain every index path/stage/mode/OID and observation flag plus no-follow `location` evidence. Outer status uses `--ignore-submodules=all` and a deduplicated literal exclusion pathspec for every mode-160000 path across all index stages. Index/gitlink changes remain detected separately. The private index is frozen for each inventory. Status disables untracked traversal; the no-follow walker supplies those entries. Tracked files replaced by directories are excluded from native status and reported as deletions.

A submodule record contains `location` and boolean `metadata_present`, meaning literal `.git` presence only, not usable initialization. A replaced link/file/special/missing gitlink or parent stops traversal at that component and retains its content/kind, with presence false and no metadata fields. An actual directory adds `metadata`, the literal `.git` observation; missing `.git` is explicit and presence is false even if `.git/modules` remains. Gitfiles retain raw text, links only their link text, and special entries their kind/device. Malformed, dangling and legitimately relocated pointers are observations, never instructions to open another repository.

Only an ordinary embedded `.git` directory adds `embedded_head`, a literal `.git/HEAD` observation. Symbolic, unborn and detached HEAD text is not a resolved commit; links are retained without traversal, a missing HEAD is explicit, and a FIFO is recorded without reading its stream. During capture, no Git runs in a submodule or resolves its gitfile/link/ref/common-dir targets or configuration. The separate `git-read` worktree-diff boundary is stated above; it never supplies phase equality evidence. Unreadable or observably racing metadata makes capture unavailable.

Submodule content, clean-to-dirty and dirty-to-dirty transitions, nonignored untracked content and internal ref/index/config changes are not monitored. Resolved HEAD or branch-tip changes leaving the recorded literal metadata unchanged are unmonitored, including absorbed submodules with unchanged pointer text. Embedded literal HEAD edits are detected; ref-tip changes behind unchanged symbolic HEAD are not. Identical monitored evidence never establishes that a submodule is clean or internally unchanged.

Two inventories/content passes detect observable races; an enumerated untracked path disappearing, failed Git/hash/read, unreadable metadata or changing content/kind makes capture unavailable. All inherited `GIT_*` overrides and global/system Git configuration are disabled, pathspecs are literal (filenames cannot act as Git patterns), and optional locks are disabled. This is a phase-boundary comparison, not a lock or atomic snapshot: transient restored writes and undetectable concurrency remain outside its guarantee. Full hashing deliberately costs work proportional to all tracked and discovered untracked bytes, including binaries and LFS worktree data; do not omit clean/flagged files to save time.

Every result/state line carries: **ignored untracked paths not monitored; submodule/nested-repository content not recursively monitored; special-file contents not monitored; submodule resolved HEAD and dirty state not monitored**.

Outer `.git` location identity, gitfile text, resolved administration directory identity and common-dir pointer/identity are monitored. The temporary root (`TMPDIR`, `TEMP`, `TMP`, otherwise `/tmp`) must exist, allow private directory creation and resolve outside the checkout and source administration; an invalid configured root is unavailable rather than falling back to another root, and an unsafe choice fails before temporary files are created. Each inventory uses a private temporary Git directory with copied HEAD, refs, packed refs and index, generated non-executing configuration and explicit object storage. Copied index/shared-index timestamps are preserved, including after private flag updates, so Git retains its racy-clean content checks. Source config is parsed without includes only to recognize object format and supported extensions. No Git runs in the source administration context. Administrative files are bounded ordinary no-follow reads; unsafe metadata makes capture unavailable. Every Git subprocess has a ten-second timeout. Objects/alternates remain data inputs, never configuration, and inaccessible or blocking object storage makes verification unavailable.

Ordinary and linked worktrees, packed refs, SHA-1/SHA-256 and split indexes are supported. Reftable/unknown extensions, symlinked administrative components and unsupported index formats fail unavailable. Worktree-specific configuration, includes, filters, fsmonitor, external attributes/ignore files and global/system settings are not executed or applied. Git's default external ignore/attribute files are explicitly disabled, including system attributes; the source-config parser cannot discover a parent repository above its temporary directory. This may conservatively report dirt for repositories relying on normalization or external ignores. Administrative contents other than the explicitly observed identity/HEAD/index and literal nested metadata, plus external dependencies/environment, remain outside change detection. These limits never authorize checkout writes.


## Phase recovery and resume

Capture before a phase and after it, then compare. For two parallel reviewers, use one pre-phase capture and one post-phase capture after both finish; both attempts reference that comparison. In clone mode monitor **both** the reviewed clone and original checkout throughout suite/review/cross-check/retry/resume, retaining separate records and naming which tree changed or is unavailable.

- Failed **pre-phase** capture: launch nothing and spend no attempt. Resolve the error and obtain a baseline for this pending phase. Do not compare against an earlier completed phase or attribute an authorized fix commit to an earlier reviewer.
- Failed **post-phase** capture: validate and record every other reviewer condition, return unavailable absent proved difference, and spend the existing invalid-attempt budget. For a shared failure each reviewer retains its own completion/coverage/settings result and budget; no new loop retry is added. A suite-phase failure blocks before reviewers, spending none of their attempts.
- Recovery: retain that interrupted phase's last successful pre-phase snapshot. Before retry, suite rerun, evidence reuse or a replacement baseline, compare the **next successful** capture to that saved snapshot. Equality permits continuation; a difference returns `checkout changed` under the original phase attribution. Persistent unavailability blocks. An unavailable capture is neither reusable suite evidence nor proof of restoration.
- Same-HEAD resume, both `scratch` and `invalidating`: require successful equality to the pre-interruption monitored state before applying the answer; otherwise return `checkout changed` again with the answer unapplied. Only then apply the caller's established reuse/spend rules.
- Authorized reconciliation at a new HEAD: require a new target and an explicit reconciled baseline with no unexplained residual changes; void prior results and refresh suite/review on that commit. Preserve spent attempts. Do not demand equality to old committed content. An unresolved failed post-phase capture still requires its recovery comparison/adjudication before accepting a new baseline.

Schema-1/2 or mixed-schema captures are incompatible and yield unavailable, not equality or a write solely from incompatibility. An interrupted phase with an incompatible retained baseline cannot silently reuse it or replace it with a schema-3 baseline; report unavailable and require explicit reconciliation under the caller's authority.

Caller-approved commits and fully reconciled states establish new phase baselines. Preserve unrelated work and old evidence; never automatically reset it.

## Resolve checks and bind suite evidence

At entry resolve exact ordered complete-suite commands and targeted checks, their working directories and sources. Approved spec Verification is primary; mandatory project checks/defaults still apply, and README supplies commands only where these sources do not define them. Resolve conflicts before review; do not replace explicit commands or drop mandatory checks. Record unavailable coverage. If no complete suite exists, record exactly `no complete suite defined`.

Forward the resolved set to every prompt; reviewers do not rediscover commands. A single final-pass reviewer (direct use included) independently executes the exact complete-suite commands in the reviewed tree. Round 1 adds security focus, not that independent suite rerun. Dual reviewers inherit the session/caller suite and may run targeted reproductions, never concurrent complete suites.

Each suite evidence record contains ordered commands, cwd, exits, reviewed commit, absolute checkout, successful before/after snapshots and comparison, known dependency/environment changes and coverage limits. Reuse requires the **same commit and checkout**, successfully compared monitored state from the run through reuse, and no known environment/dependency change. Failed/unavailable captures prevent reuse. For a completed suite phase on unchanged HEAD, after either caller answer (`scratch` or `invalidating`), successful restoration equality to its pre-suite snapshot supplies the required state proof: retain the original changed comparison and the restoration comparison, then reuse the recorded run on the same commit/checkout and advance to review without rerunning that writing suite. The suite has no reviewer attempts to spend under either answer; this preserves its existing same-HEAD resume semantics. Keep the actual suite exits/coverage, and all other reuse conditions still apply. New-HEAD reconciliation requires fresh suite evidence. A commit after a suite run requires another run on committed HEAD, even for generated-only changes; tree equivalence is insufficient. Keep the loop's pre-commit suite gate as well. Suite writes require caller adjudication and restoration or a task commit before review; a new commit always needs new evidence. Failed post-commit required checks block review/completion without authorizing amend, squash or unreviewed corrective commits.

## Verification marker

Report `Verification: complete | incomplete: <specific required checks or coverage gaps>` beside findings verdicts, and in attempt results. Aggregate suite exits and relevant retained review/cross-check gaps on the current commit. Include command, cwd, exit/reason and missing setup. Superseded invalid attempts replaced by valid retries do not poison current coverage.

`complete` means resolved required verification succeeded within the stated boundaries. Keep `no complete suite defined` visible beside the marker; it is not itself a failed check. A permitted clone-only missing-setup exception still means incomplete; any required check not attempted remains missing coverage. Validity, Verification and findings verdict are separate: direct CLEAN can coexist with incomplete verification, while the loop cannot close clean with failed/unrun required checks.
