# Task document paths

Shared location and naming rules for planning, refining, splitting and delivery. Read this reference before classifying a task document, pairing it or enumerating its plans. Each caller retains its own explicit overrides, missing/multiple-match decisions, stage rules and write authority.

## Location and kind

Resolve `R` as the supplied document's repository top level with successful ordinary Git identity evidence. Derive its directory's repository-relative path using `git -C <document-dir> rev-parse --show-prefix` and append the literal filename; use that with `R` for membership, not an unnormalized caller path. Compare repository identity through its registered main checkout, not unequal worktree paths. `D` is the nearest enclosing directory at or below `R` ending in path components `docs/superpowers` whose `plans/` or `specs/` subtree contains the document, including `R/packages/a/docs/superpowers` and `R/superpowers` when `R` ends in `docs`. If none exists, a separate docs repository with input under `R/plans/` or `R/specs/` uses `D = R`. Otherwise keep the header/spec/other tests without location-based plan recognition. Nested `plans` directories never redefine `D`: `D/plans/releases/plans/foo.md` maps to `D/specs/releases/plans/foo-design.md`; a headerless `project/notes/plans/x/brief.md` remains Other.

Classify in order: follow-ups/tails retain the caller's dedicated handling and are never discovered plans; an actual superpowers plan header (`> **For agentic workers:** REQUIRED SUB-SKILL:`) identifies a plan; otherwise a filename ending `-design.md` identifies a spec; otherwise a file anywhere below `D/plans/` identifies a plan; otherwise a file below `D/specs/` or in another `specs/` directory identifies a spec; otherwise Other. Outside a recognised `D`, a directory named `plans` alone grants no plan classification.

## Plan to spec

For `D/plans/<relative-directory>/<stem>.md`, try `<stem>-design.md` in the plan's own directory, then `D/specs/<relative-directory>/<stem>-design.md`. The relative directory may be empty or have several components. A nested plan never falls back to an equal-stem spec at `D/specs/`. Outside `D/plans/`, a header-recognized plan keeps the same-directory then sibling-`specs/` lookup. Finally try its `**Spec:**` header, relative to the project checkout. A caller's explicit `--spec` takes precedence over these rules; the caller decides what a missing match means.

## Spec to plans

A sidecar spec first pairs with `<stem>.md` in its own directory. Otherwise, within `D/specs/`, its naming pair is at `D/plans/` with the same relative directory. Search every plan anywhere below `D/plans/` whose `**Spec:**` header names this spec, in addition to that naming pair. Outside these layouts keep the sibling-`plans/` search. Compare resolved identities and deduplicate naming/header matches. Do not descend symlink directories or include discovered candidates resolving outside the resolved search tree; explicit inputs keep the caller's handling. Discovery uses the kind rules above, so a design sidecar or follow-ups file never becomes an extra plan merely by location. A queue directory input still enumerates only direct Markdown children.

## Stage directory and candidates

The stage directory is a sidecar spec's own directory; for a spec below `D/specs/`, it is the mirrored directory below `D/plans/`; otherwise it is the sibling `plans/` directory. Stage plans live directly in that directory. Candidates are its direct Markdown children classified as plans, plus the spec-to-plans matches above (including header matches elsewhere below `D/plans/`), deduplicated by resolved identity. Follow-ups, tails and design sidecars without a plan header are excluded. Each candidate's naming-pair ownership uses Plan to spec, including mirrored relative directories. Stage matching and ambiguity stops remain the caller's rules.
