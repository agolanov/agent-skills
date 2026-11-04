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
- While a spec-level step runs, the stage list is not final (a spec being split has no stages yet), so the file holds one spec line instead of stage lines: `spec | <state> | - | -`. The spec line is replaced by the stage lines, one per stage in number order, once the stage list is final: after the split question is answered "proceed", after the stale staged spec's review, or at once when the staged spec is fresh. A run that stops before any spec-level step (a spec refused in Preflight, a `## Stages` that does not parse) writes no stage line.
- Rewrite the line at every state change, before acting on the next step. It is the root's only live record.

## States

- `pending`: not acted on in this run yet: a stage with or without a plan, a fresh plan still to deliver. Later stages stay `pending` when the run ends earlier and are reported never started.
- `splitting`: spec line only, while `splitting-spec-into-stages` runs.
- `planning`: while `planning-task-docs` runs for the stage.
- `refining`: while `refining-task-docs` runs for the stage's plan; on the spec line, while it reviews the spec itself (after a split, or of a stale staged spec).
- `delivering`: while `delivering-task` runs for the stage, both halves, a `--resume` included.
- `delivered <sha7>`: after the stage's merge, or at once when the run finds the merge; `<sha7>` is the merge commit.
- `failed: <skill>: <reason>` or `failed: <reason>`: the run ends here. The first is for a sub-skill (`splitting-spec-into-stages`, `planning-task-docs`, `refining-task-docs`, `delivering-task`) that refuses, stops, or ends `failed` or `blocked` while the user does not answer, naming the sub-skill. The second is for this skill's own stop, naming the rule: two plans matching one stage, a plan the planner reported that is not stage NN's, a changed Scope or Done when of a fresh plan's stage, a rename, renumbering or removal of a delivered or running stage by a refiner, an unproven leftover, a resumed stage whose plan is stale, an unstaged plan of the staged spec. It is written on the line of the stage the run is at, or on the spec line while a spec-level step runs or when Split 2 stops before writing the stage lines. A run that stops in Preflight writes no line: a stop before Preflight 4 creates no state file and leaves an earlier run's file as it is.
- `stopped by the user`: the user stopped the run at this stage, or answered the split question with "stop" (to edit the section by hand and rerun), on the spec line.

Nothing is committed: the state file is the run's only record, and the final report carries the table.
