Display copy. `prepare-tasks/references/units.md` (later `reviewing-task-docs`) holds the marking procedure; keep the format and freshness rule equal in both.

# Review mark

Last line of a reviewed spec or plan, exact shape:

```text
Review: clean | clean except disputed, <YYYY-MM-DD>, reviewer <claude|codex>, commit <full SHA>
```

## Freshness

A document is **fresh** when all three hold for its content (the working file in a checkout, or `git -C <docs-main> show <ref>:<rel>` when checking a branch):

1. The last line matches `^Review: (clean|clean except disputed), [0-9]{4}-[0-9]{2}-[0-9]{2}, reviewer (claude|codex), commit [0-9a-f]{40}$`.
2. It is the only line matching `^Review: (clean|clean except disputed), `.
3. The named commit holds the document (`git -C <docs-repo> rev-parse --verify --quiet <sha>:<rel>` succeeds) and the content without that line equals that version: `diff <(git -C <docs-repo> show <sha>:<rel>) <(sed '$d' <file>)` prints nothing and exits 0. Without the revision/path existence check, an unknown SHA yields an empty stream and a mark-only document passes.

Exit 1 from the quiet revision/path existence predicate means stale (unknown commit or absent path); exit 2 is unavailable, not stale. A helper error/timeout is unavailable verification and stops the dependent action; it is not evidence of a stale document. Retain each exit, including the `show` producer: do not hide a failed producer in process substitution.

Everything else is **stale** and the unit needs review: no mark, a mark that is not the last line, two marks, a SHA unknown to the docs repository, or any edit after the mark's commit, committed or not. Name the failing condition in the unit table.

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

`rel` is the path relative to the repository that holds `file` (the docs main checkout, or the window's worktree, whose relative paths are the same). Checking a branch, use `git -C <docs-main> show prep-<slug>:<rel>` as the content; once the worktree's checkout-state preflight is clean (per the owning skill), its working file is equivalent.
