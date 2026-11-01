# Queue file

Path: `<docs-dir>/queues/<YYYY-MM-DD>-<slug>.md` in the docs main checkout (`docs/superpowers/queues/...` from the project). Queue files were written by the former `prepare-tasks`; `deliver-queue` reads them and writes only `State`.

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
delivering-task <absolute plan in the project checkout> --spec <absolute spec in the project checkout>
```
~~~

- `#` is the confirmed order; `Depends on` names the units that must be merged first (`#` and unit name, comma-separated, or `None`); `Why` is the confirmed one-line reason.
- `Plan` and `Spec` are paths relative to the project checkout. A plan never written keeps its intended path.
- `State` is final only as `ready` (spec and plan merged into docs main, or already there, both fresh) or `not ready: <reason>`: `<window> failed: <reported reason>`, `stopped by the user`, `merge conflict`, `verification failed: <what>`.
- Delivery states: `deliver-queue` later overwrites `State` with `running`, `done awaiting merge`, `rebasing`, `delivered <sha7>`, `failed: <reason>`, `blocked: <question>`, `not started: depends on failed <unit>`, `not started: depends on stopped <unit>`, `not started: depends on not ready <unit>` or `stopped by the user`, at its batch points. The bare `stopped by the user` is the delivery state; `not ready: stopped by the user` is preparation-time. On a rerun, `delivered <sha7>` units are done, `ready` and every other delivery state are candidates again, and every `not ready: ...` stays skipped.
- Commands: one `delivering-task <plan> --spec <spec>` line per `ready` unit, in table order, absolute paths in the main checkout (never a `prep-<slug>` worktree path), in the fenced `sh` block. Not-ready units get no line. A ready unit whose predecessor is not ready keeps its line; name the gap in the final report.
