# Overlap

Two units may not have live windows at the same time when their plans name a common path. The check is advisory and cheap: a missed overlap only costs a rebase round under `deliver-task`'s main-moved rule, never a wrong merge. Compute each unit's path set once, before the first scheduling.

## Reading a plan

1. Read the whole plan and find every `**Files:**` block: the list lines after a `**Files:**` line, up to the next blank line, heading or non-list line.
2. Take only lines whose label is `Create:`, `Modify:` or `Test:`, with or without a leading `- `. Shared test material is edited in the main checkout, where neither worktrees nor rebasing isolate writes, so `Test:` paths count exactly like the others.
3. From each such line take every backticked span as one path. Without backticks, split the text after the label on commas. Drop a trailing parenthetical (`(new)`, `(function foo)`) and a trailing line range (`:123`, `:123-145`).
4. Normalize each path relative to the project checkout: strip `./`, resolve `..`, turn an absolute path inside the project into its relative form (from the project checkout, `realpath -m --relative-to=. <path>`). A path ending in `/`, or naming an existing directory in the project, is a directory.

A plan with no `**Files:**` block has an empty set and overlaps nothing.

## Comparing units

Units A and B overlap when some path of A equals some path of B, or one of them is a directory containing the other (`src/` contains `src/a.sh`; `src/a` does not contain `src/ab.sh`). Overlap is symmetric and not transitive.

When scheduling, a startable unit is held back if it overlaps a unit with a live window or an earlier unit chosen in the same pass; the earlier unit in queue order goes first and the other waits for its merge. Name the shared path when reporting why a unit waited.
