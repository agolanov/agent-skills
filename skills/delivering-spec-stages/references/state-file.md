# State file

## Names

- `<runtime>` is the resolved installed child helper's successful `runtime-dir` output, outside Git.
- `<spec-stem>` is the spec's stem by the Spec stem rule of [stages-section.md](stages-section.md#parsing-rules), with every character outside `[A-Za-z0-9_-]` replaced by `-` (as `splitting-spec-into-stages` Preflight 5 names its window).

## State file

Path: `<runtime>/<spec-stem>-stages-state.md`. An earlier run's file at the path is renamed to an unused `<file>-old-<n>` (`n` the smallest unused number, never replacing an existing file) and the new file starts fresh. It is never read back: every run derives the states again from Git and the documents (plan present, mark fresh, merge found). Git is the durable record; the state file records only what this run did.

Header: `# spec: <absolute spec path>`. Then one line per stage in number order:

```text
<NN> | <state> | <plan path or -> | <merge sha7 or ->
```

- `<state>` is one of the states below. No other spelling.
- The plan field is the plan's path relative to the project checkout (as `**Spec:**` headers give it), or `-`. The merge field is the merge's short SHA (7), or `-`.
- The spec line `spec | failed: unstaged plan <plan> | - | -` is written instead of stage lines only when Stage list 1's Unstaged plan check stops the run. Otherwise the stage lines, one per stage in number order, follow the header at once. A run that stops in Preflight (an unstaged spec, a `## Stages` that does not parse) writes no line.
- Rewrite the line at every state change, before acting on the next step. It is the root's only live record.

## States

- `pending`: not acted on in this run yet: a stage with or without a plan, a fresh plan still to deliver. Later stages stay `pending` when the run ends earlier and are reported never started.
- `planning`: while `planning-task-docs` runs for the stage.
- `refining`: while `refining-task-docs` runs for the stage's plan.
- `delivering`: while `delivering-task` runs for the stage, Execute through Cleanup, a `--resume` included.
- `delivered <sha7>`: after the stage's merge, or at once when the run finds the merge; `<sha7>` is the merge commit.
- `failed: <skill>: <reason>` or `failed: <reason>`: the run ends here. The first is for a sub-skill (`planning-task-docs`, `refining-task-docs`, `delivering-task`) that refuses, stops, or ends `failed` or `blocked` while the user does not answer, naming the sub-skill. The second is for this skill's own stop, naming the rule: two plans matching one stage, a plan the planner reported that is not stage NN's, a changed Scope or Done when of a fresh plan's stage, a rename, renumbering or removal of a delivered or running stage by a refiner, an unproven leftover, a resumed stage whose plan is stale, an unstaged plan of the staged spec. It is written on the line of the stage the run is at, or on the spec line when Stage list 1's Unstaged plan check stops before writing the stage lines. A run that stops in Preflight writes no line: a stop before Preflight 4 creates no state file and leaves an earlier run's file as it is.
- `stopped by the user`: the user stopped the run at this stage.

Nothing is committed: the state file is the run's only record, and the final report carries the table.
