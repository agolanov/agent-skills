# Launch Settings

Settings configure a launched agent for the work it is given, not the session that launches it; the CLI's configured defaults and the launching session's own model are no substitute. One table serves every child actually started and every nested agent. Accept `--model MODEL`, `--effort LEVEL` and equivalent prose independently.

## Roles

| Work | Claude / Codex | Effort |
| --- | --- | --- |
| Supplied text or code, isolated mechanical edit, mechanically checkable handoff | Haiku / Luna | `medium` |
| Ordinary implementation, integration and routine fixes, by a subagent or by an owner in any mode; consolidating an approved plan; ordinary coordination once the handoff is simplified | Sonnet / Terra | `high` |
| Planning, refinement, splitting a spec; architecture, concurrency, subtle correctness; consequential acceptance or merge decision | Opus / Sol | `high`; `xhigh` for demanding owner work |
| Independent review and cross-check | Opus / Sol, the other system | `high`, also on the final pass |
| Difficult follow-up research; dual consultation | Fable / Astra | researcher `high` or `xhigh` by difficulty; consultants `high` |

The two cheaper rows are starting points, judged on cost per completed job with retries and escalations counted; a row that costs more than the row above it goes back up.

Role names other skills use map to rows:

- `planner`, `refiner`, `splitter`: the planning row (Opus / Sol `high`). The `consolidating-plans` worker keeps role `planner` but takes the Sonnet / Terra `high` row.
- `implementer` and `solo implementer` (one rule for both), the `review-fix-loop` loop owner outside `inline`, `follow-ups fixer`: the row of the most demanding step of the work they are given ([Effort by task](#effort-by-task)). Adjudicating review findings is fixing work, not a consequential acceptance.
- `orchestrator` (`delivering-spec-stages` outside `inline`) and the orchestrators' phase agents: Opus / Sol `high`; Accept is a consequential acceptance.
- `reviewer` (`independent-review` in `background` and `window`, both reviewers of `--dual` in both phases): the review row.
- The follow-ups researcher: the research row.

Fable (Claude) and Astra (Codex) are chosen automatically only by the research row; elsewhere they are allowed explicitly.

## Effort by task

The session that launches the agent, or resolves the policy for it, picks the row from the most demanding step of the work the agent is given, not the average step or the file count; on the Opus / Sol row, `xhigh` is for demanding owner work (architecture, subtle concurrency or correctness reasoning the owner must carry itself). This holds for solo and non-solo owners alike: the implementation mode says nothing about difficulty. The choice is a policy value (source `policy`) and applies only to a field with no explicit, recorded or caller-resolved value. The record names the step in one phrase.

## Precedence

For each field (model, effort) separately: the current explicit value; else the recorded value when continuing the same run (reopen, retry, `--resume`, the same review loop); else the row's value. An explicit value for one field leaves the other on its own precedence. A resume keeps the resolved pair.

A caller that resolved values from this policy for the agent it launches through another skill passes them as policy values, not explicit overrides: the receiving skill records them with source `policy` and does not resolve them again.

## CLI-defaults opt-out

`cli-default` for a model or effort (`--model`, `--effort`, `--reviewer-model`, `--reviewer-effort`), or prose such as "use the CLI's default model", opts that field out on every launch path, the reviewer's included: the launch omits that field's flag or override, the record says `cli-default`, and nothing is compared for it. The other field keeps its own precedence and is passed explicitly.

## Resolution

Resolve the newest version of the row's family that the account can use, by the launch method: for a CLI child (`window`, `background`), Codex app-server `model/list` and Claude's model picker, account information and official model documentation; for a `subagent`, the native tool's model options (a CLI catalog does not establish native availability, and an alias can resolve to an older version). A higher version of another family does not qualify, and the model belongs to the launched system. Check that the pair is supported for that model; effort `low` is refused for a Claude reviewer, whose `/code-review` level is its effort ([review wrapper](review-wrapper.md#carrying-the-wrapper)). An unresolved or unsupported pair stops before launch, reported, never guessed or coerced. Pass both values explicitly, `high` included.

## Record

Resolve once per run, record the concrete values with their source and discovery evidence, and reuse them for every later launch of that role in the run. Briefs (planner, splitter, refiner, implementer, and every other worker outside `inline` in its [run-contract](../../child-sessions/references/run-contract.md#brief) brief) carry, after the identity lines:

```text
Launch settings: model <exact | cli-default> (<policy | explicit | cli-default>), effort <exact | cli-default> (<policy | explicit | cli-default>)[; effort step: <most demanding step, one phrase>]; resolved <YYYY-MM-DD> from <discovery evidence, one phrase>
```

The `effort step:` clause appears only when [Effort by task](#effort-by-task) chose the value; a caller passing such a value forwards its step. Refiner and implementer briefs also record their cross review's reviewer:

```text
Reviewer settings: <reviewer policy | model <M> (explicit) and/or effort <E> (explicit), the rest by reviewer policy>
```

The child passes explicit reviewer values to `review-fix-loop` as `--reviewer-model`/`--reviewer-effort`, none with `reviewer policy`. Before opening, the root checks that an explicit reviewer model belongs to the reviewer system of the brief's `Reviewer agent:` line and that the pair is supported; a mismatch stops before any window. The reviewer's own records are independent-review's `Assignment:` and `Settings evidence:` lines.

## Child settings check

The settings evidence of every launched child. It is read after the launch, from what the launch returns or one record it names, never from invocation flags or the child's self-report. No other check, pause, retry or transcript scan.

- **Ordinary policy-selected workers.** One line in the parent's report: `Settings: requested <model>/<effort>, observed <model|unverified>/<effort|unverified>`, from what the launch itself returns: Claude's `init` event or result `modelUsage`, Codex's stderr header, the native agent tool's result. A field the launch does not return is `unverified`.
- **Explicitly selected fields and the reviewer.** One targeted lookup of the record the launch's own session ID names, by [Typed settings fields](#typed-settings-fields). Claude: the ID passed with `--session-id` (or read from the `init` event); for `/code-review` the command's agent records under `<project dir>/<session id>/subagents/` included. A Claude window whose fields are checked this way opens with `--cli-arg --session-id --cli-arg <uuid>`, a fresh UUID on each opening. Codex: the ID in the stderr header; for a review, the delegate whose `parent_thread_id` is that ID (a window's nested `codex review -` writes its stderr into the attempt directory). If the launch returns no ID, or the bound record lacks the field, that field is `unverified` and the lookup ends.
- **Mismatch.** A known mismatch of the reviewer's effective pair pauses acceptance of that review and goes to the user, who accepts the review with the observed settings or has the attempt retried; a retry spends the attempt as an invalid one does. Under `--auto` the question is routed by child-sessions' [auto.md](../../child-sessions/references/auto.md#deciding) as a launch-settings mismatch. A known mismatch of an explicitly selected value of any other child, or of a policy value, is disclosed in the report, with no pause.
- **Unverified.** A field marked `unverified` is reported and pauses nothing; a reviewer attempt stays valid and its `Settings evidence:` line names the field.
- **Opt-out.** A `cli-default` field is not compared; the report states its observed value or `unverified`.

## Typed settings fields

The fields the targeted lookup reads. Records live under `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/<project dir>/<session id>.jsonl` and `${CODEX_HOME:-$HOME/.codex}/sessions/**/rollout-*-<id>.jsonl` (on PowerShell, the same locations through `$env:CLAUDE_CONFIG_DIR`/`$env:CODEX_HOME` or `$HOME`, with `Join-Path`).

| Record | Model | Effort |
| --- | --- | --- |
| Claude `init` event of the launch | `model` | none |
| Claude assistant record of the bound session | `message.model` | top-level `effort` |
| Claude `/code-review` agent record (`<project dir>/<session id>/subagents/agent-*.jsonl`) | `message.model` | top-level `effort`, or `output_config.effort` |
| Codex `turn_context` of the bound rollout | `payload.model` | `payload.effort` |
| Codex review delegate (`session_meta.payload.source` `{"subagent":"review"}`, `parent_thread_id` the producer's ID): `turn_context` and `thread_settings_applied` | `payload.model`, `thread_settings.model` | `payload.effort`, `thread_settings.reasoning_effort` |

Every concrete value of the bound records counts: one conflicting value is a mismatch, a delegate run on another model by a `review_model` override included; a missing value in one record is not. The Codex producer's header and its own settings corroborate the launch only; the delegate is what ran the review.

## Places

Every role keeps its row in every place of the [run contract](../../child-sessions/references/run-contract.md#places):

- **`inline`:** the worker is the current session. No settings are resolved; explicit `--model`/`--effort` for it are refused before anything starts, except in the orchestrators, where they set the implementer.
- **`window`:** `open` passes the pair; a local-only Claude worker also gets the run contract's lean launch words ([Launch and wait](../../child-sessions/references/run-contract.md#launch-and-wait)).
- **`subagent`:** set both fields with the native tool's controls (Claude's agent tool `model` and `effort`; Codex `model`, `reasoning_effort` and `fork_turns: "none"`); an opted-out field stays unset. A pair the place cannot select is refused before launch, naming the place and the pair.
- **`background`:** the pair as CLI flags (run contract [Launch and wait](../../child-sessions/references/run-contract.md#launch-and-wait)).

## Nested agents

Every nested spawn sets both fields, unless the user opted a field out: on Claude's agent tool `model` and `effort`, on Codex `model`, `reasoning_effort` and `fork_turns: "none"`. The dispatcher's brief carries the applicable rows and that rule on one line, in the run contract's brief, every skill's brief template and the orchestrators' phase briefs:

```text
Nested agents: set model and effort on every agent you start (Claude Agent tool: model, effort; Codex: model, reasoning_effort, fork_turns "none"), by these rows: <rows of the Roles table, each as "<work>: <Claude>/<Codex> <effort>">
```

The orchestrators' Prepare and Accept phase agents take Opus / Sol `high`. A Claude reviewer's `/code-review` agents are the review itself: their records are read with the reviewer's ([Typed settings fields](#typed-settings-fields)).

Sources: [Codex model discovery](https://learn.chatgpt.com/docs/app-server#list-models-modellist), [Codex subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents), [Claude model configuration](https://code.claude.com/docs/en/model-config), [Claude subagent models and effort](https://code.claude.com/docs/en/sub-agents).
