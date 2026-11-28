# Launch choices

## Agent and place

Use `--agent <claude|codex>[:<command>]` or identify the session's system by [Session system](../../independent-review/SKILL.md#session-system). Unknown identity requires clarification. Select `--run` (the user's words count), default `window`, or `inline`, `subagent`, `background`. Refuse other values. On `--resume` recover recorded agent, place, mode and settings by [Resume delivery](resume.md) before making new choices. Explicit conflicts stop.

Apply the implementer [refusals](../../child-sessions/references/run-contract.md#refused-combinations) before any worktree or window. Inline and subagent require the session's system; inline refuses explicit model/effort and resolves no settings. On a host without subagent nesting, refuse a subagent implementer in `subagents` mode, or when the launching session is itself a subagent. A Prepare agent defers non-window starts to its caller, so evaluate the latter refusal for the caller. A worker start the host refuses is launch failure.

## Implementer settings

Outside inline and resume, apply [launch settings](../../independent-review/references/launch-settings.md#precedence) by the mode and [work table](../../independent-review/references/launch-settings.md#roles) row chosen in [Implementation mode](prepare.md#implementation-mode). Explicit flags win per field, `cli-default` omits that field, and a caller-resolved policy value stays `policy`. Use the [Places](../../independent-review/references/launch-settings.md#places) controls. Refuse an unresolved, unsupported or unselectable pair before opening, naming the place and pair.

## Reviewer settings

Map the user's reviewer choice to keys. Before any worktree or window refuse these combinations with the key/value: `--reviewer-run subagent` (offer `background` or `window`), unknown reviewer place/system, `--reviewer-agent` plus `--reviewer-dual`, or `--reviewer-dual` plus any `--reviewer-model` (including `cli-default`). The system is dual when requested, otherwise the explicit system/command or the opposite of the implementer. Same-system review is valid. Validate explicit model and effort for the selected system(s), including both efforts under dual. Claude does not support `low` (name `medium`). Accept `cli-default`. Record Reviewer agent as the value plus `(explicit)` or `(default)`, Reviewer settings as the flags or `reviewer policy`, and Reviewer run as the chosen place and source, default `background (default)`. On resume use the recorded values and the compatibility checks in [Resume delivery](resume.md).

## Inline under a caller

A phase-alone Prepare whose place resolves to `inline` (the key, the user's words, or a resumed brief's recorded place) first applies inline's own refusals as written, then performs the run as place `subagent` with the model and effort of the row [Implementation mode](prepare.md#implementation-mode) 3 picks, as policy values (explicit and `cli-default` values keep their precedence). This takes precedence over Inline's no-phase path for this call. The worker brief says `Place: subagent` and records that pair on its `Launch settings:` line, resolved from the inline place under a caller; Waiting has `Action: start subagent` and `Action settings:` with that pair. Put `inline place under a caller: subagent worker, <model>/<effort>` in Report carries; End 4's and Cleanup 2's implementer settings line uses it in place of `inline: current session`. A queue does this for every unit, one at a time.
