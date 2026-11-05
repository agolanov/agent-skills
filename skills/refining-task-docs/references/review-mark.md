Authoritative copy. `executing-task-docs/references/review-mark.md` holds a display copy of the format and freshness rule; keep both equal.

# Review mark

Last line of a reviewed spec or plan, exact shape:

```text
Review: clean | clean except disputed, <YYYY-MM-DD>, reviewer <claude|codex>, commit <full SHA>
```

`commit` names the docs-repository commit holding the reviewed content, before the mark was appended; the mark is committed afterwards as `mark: <basename>`. `reviewer` is the system that performed the review, taken from the review loop's `Assignment:` (the opposite system by default, the child's own system under `--reviewer-run subagent`). `clean except disputed` is ready; the disputed findings stay in the document. Marks are written only by the child, after its `review-fix-loop` ends `clean` or `clean except disputed`, never by the root.

## Freshness

A document is **fresh** when all three hold for its content (the working file in a checkout, or `git -C <docs-main> show <ref>:<rel>` when checking a branch):

1. The last line matches `^Review: (clean|clean except disputed), [0-9]{4}-[0-9]{2}-[0-9]{2}, reviewer (claude|codex), commit [0-9a-f]{40}$`.
2. It is the only line matching `^Review: (clean|clean except disputed), `.
3. The named commit holds the document (`git -C <docs-repo> rev-parse --verify --quiet <sha>:<rel>` succeeds) and the content without that line equals that blob as bytes, allowing only the uniform CRLF representation described below. Preserve the `show` producer exit before comparison: an unknown SHA or failed producer never supplies an empty successful body.

Exit 1 from the quiet revision/path existence predicate means stale (unknown commit or absent path); exit 2 is unavailable, not stale. A Git/read error or timeout is unavailable verification and stops the dependent action; it is not evidence of a stale document. Retain each exit, including the `show` producer: do not hide a failed producer in process substitution.

Everything else is **stale** and the document needs review: no mark, a mark that is not the last line, two marks, a SHA unknown to the docs repository, or any edit after the mark's commit, committed or not. Name the failing condition in the report.

**Optional legacy Python compatibility:** the first Bash recipe retains `state_helper`, `docs_repo`, `file`, `rel` and its exit interface for existing callers. It is not the native/default route; use the recipes below without Python.

```bash
last=$(tail -n 1 -- "$file")
re='^Review: (clean|clean except disputed), [0-9]{4}-[0-9]{2}-[0-9]{2}, reviewer (claude|codex), commit ([0-9a-f]{40})$'
[[ $last =~ $re ]] && sha=${BASH_REMATCH[3]} &&
[[ $(grep -cE '^Review: (clean|clean except disputed), ' -- "$file") -eq 1 ]] &&
python3 "$state_helper" git-read --checkout "$docs_repo" -- rev-parse --verify --quiet "$sha:$rel" >/dev/null &&
freshness_dir=$(mktemp -d) &&
python3 "$state_helper" git-read --checkout "$docs_repo" -- show "$sha:$rel" > "$freshness_dir/committed" &&
sed '$d' -- "$file" > "$freshness_dir/current" &&
diff "$freshness_dir/committed" "$freshness_dir/current" >/dev/null
```

`rel` is the path relative to the repository that holds `file` (the docs main checkout, or the window's worktree, whose relative paths are the same).

## Native freshness recipes

Use the ordinary Git environment/identity checks from checkout-state first. Bind absolute `docs_repo`, `file`, a fresh external `freshness_dir`, and exact repository-relative `rel`. Return **0 fresh**, **1 stale**, **2 unavailable**; retain producer exits/stderr. The comparison preserves bytes, with one narrow exception: a uniformly CRLF working document may represent the identical LF blob. For that representation exception, mixed endings or a missing body newline is stale; other content changes are always stale. Do not normalize encodings, trim whitespace or rewrite the document to check it.

POSIX Bash (the earlier Bash fence is optional legacy compatibility):

```bash
freshness_check() {
  export GIT_OPTIONAL_LOCKS=0
  last=$(tail -n 1 "$file") || return 2
  cr=$(printf '\r')
  last=${last%"$cr"}
  re='^Review: (clean|clean except disputed), [0-9]{4}-[0-9]{2}-[0-9]{2}, reviewer (claude|codex), commit ([0-9a-f]{40})$'
  [[ $last =~ $re ]] || return 1
  sha=${BASH_REMATCH[3]}
  count=$(LC_ALL=C grep -cE '^Review: (clean|clean except disputed), ' "$file") || return 2
  [[ $count = 1 ]] || return 1
  git -C "$docs_repo" rev-parse --verify --quiet "$sha:$rel" >"$freshness_dir/exists.stdout" 2>"$freshness_dir/exists.stderr"
  exists_exit=$?
  printf '%s\n' "$exists_exit" >"$freshness_dir/exists.exit"
  case $exists_exit in 0) ;; 1) return 1 ;; *) return 2 ;; esac
  git -C "$docs_repo" show "$sha:$rel" >"$freshness_dir/committed" 2>"$freshness_dir/show.stderr"
  show_exit=$?
  printf '%s\n' "$show_exit" >"$freshness_dir/show.exit"
  [[ $show_exit = 0 ]] || return 2
  sed '$d' "$file" >"$freshness_dir/current" || return 2
  cmp -s "$freshness_dir/committed" "$freshness_dir/current"
  compare_exit=$?
  case $compare_exit in 0) return 0 ;; 1) ;; *) return 2 ;; esac
  # Only uniform CRLF of an LF blob can use the representation exception.
  tail -c 1 "$file" >"$freshness_dir/last-byte" || return 2
  last_byte=$(od -An -tu1 "$freshness_dir/last-byte") || return 2
  [[ $last_byte =~ ^[[:space:]]*10[[:space:]]*$ ]] || return 1
  LC_ALL=C awk -v CR="$cr" 'substr($0,length($0),1)!=CR {bad=1} {s=$0; sub(CR "$","",s); if(index(s,CR)) bad=1} END {exit bad}' "$file"
  case $? in 0) ;; 1) return 1 ;; *) return 2 ;; esac
  tail -c 1 "$freshness_dir/committed" >"$freshness_dir/last-byte" || return 2
  last_byte=$(od -An -tu1 "$freshness_dir/last-byte") || return 2
  [[ $last_byte =~ ^[[:space:]]*10[[:space:]]*$ ]] || return 1
  LC_ALL=C awk -v CR="$cr" 'index($0,CR) {bad=1} END {exit bad}' "$freshness_dir/committed"
  case $? in 0) ;; 1) return 1 ;; *) return 2 ;; esac
  sed "s/$cr\$//" "$freshness_dir/current" >"$freshness_dir/current-lf" || return 2
  cmp -s "$freshness_dir/committed" "$freshness_dir/current-lf"
  compare_exit=$?
  case $compare_exit in 0) return 0 ;; 1) return 1 ;; *) return 2 ;; esac
}
freshness_check
freshness_exit=$?
```

Native installed pwsh 7.6.9 uses byte-preserving native redirection and a one-byte encoding solely to compare every byte without decoding/re-encoding the document:

```powershell
$freshness_exit = & {
    $ErrorActionPreference = 'Stop'
    $PSNativeCommandUseErrorActionPreference = $false
    $env:GIT_OPTIONAL_LOCKS = '0'
    try {
        $bytes = [IO.File]::ReadAllBytes($file)
        $byteText = [Text.Encoding]::GetEncoding(28591)
        $text = $byteText.GetString($bytes)
        $mark = [regex]::Match($text, '(?m)^Review: (clean|clean except disputed), [0-9]{4}-[0-9]{2}-[0-9]{2}, reviewer (claude|codex), commit ([0-9a-f]{40})(?:\r?\n)?\z')
        if (-not $mark.Success -or [regex]::Matches($text, '(?m)^Review: (clean|clean except disputed), ').Count -ne 1) { return 1 }
        $sha = $mark.Groups[3].Value
        & git -C $docs_repo rev-parse --verify --quiet ($sha + ':' + $rel) > "$freshness_dir/exists.stdout" 2> "$freshness_dir/exists.stderr"
        $exists_exit = $LASTEXITCODE
        [IO.File]::WriteAllText("$freshness_dir/exists.exit", "$exists_exit`n")
        if ($exists_exit -eq 1) { return 1 }
        if ($exists_exit -ne 0) { return 2 }
        & git -C $docs_repo show ($sha + ':' + $rel) > "$freshness_dir/committed" 2> "$freshness_dir/show.stderr"
        $show_exit = $LASTEXITCODE
        [IO.File]::WriteAllText("$freshness_dir/show.exit", "$show_exit`n")
        if ($show_exit -ne 0) { return 2 }
        $committed = $byteText.GetString([IO.File]::ReadAllBytes("$freshness_dir/committed"))
        $current = $text.Substring(0, $mark.Index)
        if ([string]::Equals($committed, $current, [StringComparison]::Ordinal)) { return 0 }
        if (-not $text.EndsWith("`r`n") -or [regex]::IsMatch($text, '(?<!\r)\n|\r(?!\n)') -or $committed.Contains("`r") -or -not $committed.EndsWith("`n")) { return 1 }
        if ([string]::Equals($committed, $current.Replace("`r`n", "`n"), [StringComparison]::Ordinal)) { return 0 }
        return 1
    } catch {
        [IO.File]::WriteAllText("$freshness_dir/error.txt", $_.Exception.Message)
        return 2
    }
}
```

## Marking procedure

Performed by the child for every document it reviewed or changed, after the review ends `clean` or `clean except disputed`; the refiner brief points here:

1. Delete every line matching `^Review: (clean|clean except disputed), ` anywhere in the document (a stale mark may have been displaced by later edits).
2. For `clean except disputed`, keep the disputed findings and both positions in the document.
3. Make sure the file ends with a newline (else the mark joins its last line), then commit the content when anything changed: `git --literal-pathspecs add -- '<file>'`, then `git --literal-pathspecs commit -m 'docs: <basename>' -- '<file>'`; the pathspec keeps other staged changes out of the commit, and --literal-pathspecs keeps Git from reading a file name such as `:(glob)…` as pathspec magic. Each value a listed command takes (path, file, directory, message, branch) is one literal shell argument, quoted by whoever runs the command for the shell it runs in: in a POSIX shell inside single quotes, a single quote in the value written `'\''`; in PowerShell inside single quotes, a single quote doubled; so that `(`, spaces, `$` and quotes reach Git unchanged. `<sha>` = full `git rev-parse HEAD`.
4. Append exactly one line `Review: <clean|clean except disputed>, <today>, reviewer <the system that performed the review, from the loop's Assignment:>, commit <sha>` as the last line; commit it the same way: `git --literal-pathspecs add -- '<file>'`, then `git --literal-pathspecs commit -m 'mark: <basename>' -- '<file>'`.
5. Run the freshness check; it must pass. A document changed after marking is reviewed and marked again.
