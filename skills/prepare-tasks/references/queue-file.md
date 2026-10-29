# Queue file

Path: `<docs-dir>/queues/<YYYY-MM-DD>-<slug>.md` in the docs main checkout (`docs/superpowers/queues/...` from the project), date = today, `[a-z0-9-]` slug from the user's words or the first unit. An existing file of that name: add `-2`, `-3`, ... to the slug.

It is written twice, each time staging only this file and committing it in the docs repository as `queue: <slug>`, with the docs main checkout clean afterwards:

1. **After the order is confirmed, before Phase 2:** the table in confirmed order. State is `ready` for units that were already ready, `not ready: <reason>` for units already lost (Phase 1 `failed`), and `pending` for units entering Phase 2. A unit whose Phase 1 failed sits after its known dependencies, else at the end. No commands yet.
2. **After verify and merge:** every `pending` replaced by its final state, and the commands below the table.

## Format

~~~markdown
# Task queue: <short title>

Date: <YYYY-MM-DD>
Project checkout: <absolute project checkout>
Docs repository: <absolute docs main checkout>

| # | Unit | Plan | Spec | Depends on | Why | State |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | <unit> | docs/superpowers/plans/<plan>.md | docs/superpowers/specs/<spec>-design.md | None | <one-line reason for its place> | ready |
| 2 | <unit> | docs/superpowers/plans/<plan>.md | docs/superpowers/specs/<spec>-design.md | 1 <unit> | <one-line reason> | not ready: <reason> |

## Commands

```sh
deliver-task <absolute plan in the project checkout> --spec <absolute spec in the project checkout>
```
~~~

- `#` is the confirmed order; `Depends on` names the units that must be merged first (`#` and unit name, comma-separated, or `None`); `Why` is the confirmed one-line reason.
- `Plan` and `Spec` are paths relative to the project checkout. A plan never written keeps its intended path.
- `State` is final only as `ready` (spec and plan merged into docs main, or already there, both fresh) or `not ready: <reason>`: `<window> failed: <reported reason>`, `stopped by the user`, `merge conflict`, `verification failed: <what>`.
- Delivery states: `deliver-queue` later overwrites `State` with `running`, `done awaiting merge`, `rebasing`, `delivered <sha7>`, `failed: <reason>`, `blocked: <question>`, `not started: depends on failed <unit>`, `not started: depends on not ready <unit>` or `stopped by the user`, at its batch points. `prepare-tasks` never writes them. `delivered <sha7>` units are done; every other delivery state is a candidate again on a rerun.
- Commands: one `deliver-task <plan> --spec <spec>` line per `ready` unit, in table order, absolute paths in the main checkout (never a `prep-<slug>` worktree path), in the fenced `sh` block. Not-ready units get no line. A ready unit whose predecessor is not ready keeps its line; name the gap in the final report.
