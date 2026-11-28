# Delivery names

## Branch and window

Use `--branch` when given. Otherwise default branch to the task document's stem (the plan's stem for a plan or a spec resolved to its plan); validate with `git check-ref-format --branch`, asking for a valid override if invalid (under `--auto`, routed by [auto.md](../../child-sessions/references/auto.md#deciding)). Use window `<name> = impl-<branch>` for `[A-Za-z0-9_-]+` branches; otherwise replace disallowed branch characters with `-` and use `impl-<slug>-<hash8>` (first eight SHA-256 hex characters of the full branch name). Record the unique name; never alias slash/dot branches by slug alone.

## Worktree path

Use the project's worktree convention, otherwise `<main-checkout>/.worktrees/<branch>`.
