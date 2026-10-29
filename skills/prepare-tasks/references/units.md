# Units, matching and review marks

A **unit** is one plan with its spec; the queue lists units. A **window** maps to a spec: one window handles every unready unit of that spec.

## Inputs to units

| Input | Unit state |
| --- | --- |
| Free-text idea | needs spec, plan, review |
| Spec without plan | needs plan, review |
| Spec with N plans | N units; each needs whatever its plan lacks |
| Plan without spec | one unit; needs spec (Phase 1, written from the plan with the user), then review of both |
| Spec and plan, either without a fresh mark | needs review of each document lacking one |
| Spec and plan, both fresh | ready |

A document "lacks review" whenever it is not fresh (below); a missing, stale, displaced or duplicated mark all count. Review scope is per document: a spec without a plan that was never marked is reviewed in Phase 2 together with its new plan.

A directory input expands to every `.md` file inside it, except `*-tails.md` (delivery leftovers, not plans), anything under `.worktrees/` or `queues/`, and any path inside a registered worktree of the docs repository (`git -C <docs-main> worktree list`). A path under `specs/` or named `*-design.md` is a spec; under `plans/` a plan; anything else, ask. For every included spec, also include its plans found in `plans/` by the matching rules.

## Matching

1. Naming pair: `specs/YYYY-MM-DD-<slug>-design.md` with `plans/YYYY-MM-DD-<slug>.md`.
2. Else the plan's `**Spec:**` header line (path relative to the project checkout).
3. Else ask the user. Never guess a pairing.

## Slugs and paths

All document paths below are relative to the docs dir (`specs/...`, `plans/...`).

- Spec slug: `<slug>` of `YYYY-MM-DD-<slug>-design.md`. Window and branch are `prep-<slug>`; replace characters outside `[A-Za-z0-9_-]` with `-`.
- Plan without spec: slug = plan stem without its date; spec path `specs/<plan-date>-<slug>-design.md`.
- Idea: slug of `[a-z0-9-]` from the idea's key words (`add a --version flag` → `version-flag`), date = today; spec `specs/<today>-<slug>-design.md`, plan `plans/<today>-<slug>.md`.
- Spec without plan: plan `plans/<spec-date>-<slug>.md`.
- Unit name: plan stem without its date (`gamma-2`), or the slug when no plan exists yet.
- Two units or windows colliding on a slug, or a slug colliding with an existing branch, worktree or window: ask the user for a distinct one.

In a brief every path becomes absolute inside the window's worktree: `<worktree>/<path relative to the docs repository>`. Tracked layout: `<worktree>/docs/superpowers/specs/x-design.md`; nested layout (`docs/superpowers` is the repository): `<worktree>/specs/x-design.md`. Plan headers always use the path relative to the project checkout (`docs/superpowers/specs/<basename>` in the usual layout).

## Review mark

Last line of a reviewed spec or plan, exact shape:

```text
Review: clean | clean except disputed, <YYYY-MM-DD>, reviewer <claude|codex>, commit <full SHA>
```

`commit` names the docs-repository commit holding the reviewed content, before the mark was appended; the mark is committed afterwards as `mark: <basename>`. `reviewer` is the opposite system that performed the review. `clean except disputed` is ready; the disputed findings stay in the document. Marks are written only by the child, after its `auto-cross-refine` ends `clean` or `clean except disputed`, never by the root.

## Freshness

A document is **fresh** when all three hold for its content (the working file in a checkout, or `git -C <docs-main> show <ref>:<rel>` when checking a branch):

1. The last line matches `^Review: (clean|clean except disputed), [0-9]{4}-[0-9]{2}-[0-9]{2}, reviewer (claude|codex), commit [0-9a-f]{40}$`.
2. It is the only line matching `^Review: (clean|clean except disputed), `.
3. The content without that line equals the named commit's version: `diff <(git -C <docs-repo> show <sha>:<rel>) <(sed '$d' <file>)` prints nothing and exits 0.

Everything else is **stale** and the unit needs review: no mark, a mark that is not the last line, two marks, a SHA unknown to the docs repository, or any edit after the mark's commit, committed or not. Name the failing condition in the unit table.

```bash
last=$(tail -n 1 -- "$file")
re='^Review: (clean|clean except disputed), [0-9]{4}-[0-9]{2}-[0-9]{2}, reviewer (claude|codex), commit ([0-9a-f]{40})$'
[[ $last =~ $re ]] && sha=${BASH_REMATCH[3]} &&
[[ $(grep -cE '^Review: (clean|clean except disputed), ' -- "$file") -eq 1 ]] &&
diff <(git -C "$docs_repo" show "$sha:$rel") <(sed '$d' -- "$file") >/dev/null
```

`rel` is the path relative to the repository that holds `file` (the docs main checkout, or the window's worktree, whose relative paths are the same). Checking a branch, use `git -C <docs-main> show prep-<slug>:<rel>` as the content; once the worktree's `git status --short` is empty, its working file is equivalent.

## Marking procedure

Performed by the child for every document it reviewed or changed, after the review ends `clean` or `clean except disputed`; the brief templates repeat it verbatim:

1. Delete every line matching `^Review: (clean|clean except disputed), ` anywhere in the document (a stale mark may have been displaced by later edits).
2. For `clean except disputed`, keep the disputed findings and both positions in the document.
3. Make sure the file ends with a newline (else the mark joins its last line), then commit the content (`git add <file>`, commit `docs: <basename>` when anything changed); `<sha>` = full `git rev-parse HEAD`.
4. Append exactly one line `Review: <clean|clean except disputed>, <today>, reviewer <opposite system>, commit <sha>` as the last line; commit it as `mark: <basename>`.
5. Run the freshness check; it must pass. A document changed after marking is reviewed and marked again.
