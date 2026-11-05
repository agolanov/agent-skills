# Launch Settings

Settings configure a launched agent for the role it plays, not the session that launches it. The CLI's configured defaults and the launching session's own model are not substitutes for this policy. Accept `--model MODEL`, `--effort LEVEL`, and equivalent prose independently.

## Roles

Automatic policy, consolidated 2026-11-01 (family policy, not a pinned version list):

| Role | Launched agent | Claude | Codex | Effort |
| --- | --- | --- | --- | --- |
| planner | `planning-task-docs` child, and the `consolidating-plans` worker outside `inline` | latest available Opus | latest available Sol | high |
| refiner | `refining-task-docs` child, which fixes the findings | latest available Opus | latest available Sol | high |
| splitter | `splitting-spec-into-stages` child | latest available Opus | latest available Sol | high |
| implementer | `delivering-task` child in `subagents` or `direct` mode (one document or each unit of its queue), including its later fixes, and the `review-fix-loop` loop owner outside `inline` | latest available Opus | latest available Sol | xhigh |
| inline implementer | `delivering-task` child in `inline` mode (one document or each unit of its queue), including its later fixes | latest available Sonnet | latest available Sol | `medium` or `high`, chosen by the root per `delivering-task` Execution mode |
| reviewer | `independent-review` reviewer in every place; both reviewers of `--dual` in the review and the cross-check phases | latest available Opus | latest available Sol | high |
| triager | `triaging-task-follow-ups` worker outside `inline` | latest available Opus | latest available Sol | high |
| orchestrator | `delivering-spec-stages` and `delivering-task-follow-ups` outside `inline` | latest available Opus | latest available Sol | high |

The root chooses between the two implementer roles by the execution mode it decides in `delivering-task`; the other roles, the loop owner's included, do not depend on it.

Excluded from automatic choice, allowed explicitly: Fable (Claude), Astra (Codex).

## Precedence

For each field (model, effort) separately: the current explicit value; else the recorded value when continuing the same run (reopen, retry, `--resume`, the same review loop); else the role default. An explicit value for one field leaves the other on its own precedence.

A caller that resolved values from this policy for the agent it launches through another skill, or through its own per-unit sections (as `delivering-task`'s queue does for its units), passes them as policy values, not explicit overrides: the receiving skill records them with source `policy` and does not re-resolve them.

## CLI-defaults opt-out

The value `cli-default` for a model or effort (`--model`, `--effort`, `--reviewer-model`, `--reviewer-effort`), or equivalent prose such as "use the CLI's default model", is an explicit opt-out for that field: the launch omits that field's flag or override, the record says `cli-default`, and no report claims the policy applied to it. The opt-out is per field on every launch path, the reviewer's included; the other field keeps its own precedence and is passed explicitly.

Validation (reviewer **Validate**, the child settings check) compares only the fields not opted out, and records the observed value of an opted-out field, or `unavailable`.

## Resolution

Resolve the exact account/provider-available version using evidence relevant to the launch method:

- **CLI:** for Codex, use app-server `model/list` with the launched agent's provider and task configuration, following pagination. For Claude, use model-picker/account/provider information and current official model-configuration documentation. Verify alias mappings; `best` can select Fable. Children in `window` and `background` are CLI launches and use this bullet.
- **Native:** use the current native tool's model options and effective agent settings. A CLI catalog does not establish native availability. Resolve aliases to the actual model; an alias can inherit the parent's older version.

Choose the newest version of the required family that the account can use; a higher version number in another family does not qualify. The model must belong to the launched system. If the mapping or availability cannot be established, report the unresolved setting rather than guess.

Verify the model/effort pair is supported and permitted for that concrete model before launch. An unsupported or unresolved pair stops before any window or reviewer launch and is reported, never guessed, coerced or silently replaced. Pass both resolved values explicitly, including `high` when it is the default. Silent model fallback or effort coercion does not satisfy the settings.

## Record

Resolve once per run, record the concrete values with their source and discovery evidence, and reuse the record for every later launch of that role in the run. When changing system or launch method, re-resolve incompatible recorded values.

Child sessions (planner, splitter, refiner, implementer) record the settings in the runtime brief's identity block, filled by the root, and so does the child of every other worker role outside `inline` (the loop owner, the `consolidating-plans` worker, triager, orchestrator) in its [run-contract](../../child-sessions/references/run-contract.md#brief) brief, after the identity lines:

```text
Launch settings: model <exact | cli-default> (<policy | explicit | cli-default>), effort <exact | cli-default> (<policy | explicit | cli-default>); resolved <YYYY-MM-DD> from <discovery evidence, one phrase>
```

Refiner and implementer briefs also record the settings of the reviewer their cross review starts:

```text
Reviewer settings: <reviewer policy | model <M> (explicit) and/or effort <E> (explicit), the rest by reviewer policy>
```

The child passes the explicit reviewer values to `review-fix-loop` as `--reviewer-model`/`--reviewer-effort`; with `reviewer policy` it passes none. Before opening, the root checks that an explicit reviewer model belongs to the reviewer system the brief's `Reviewer run:` place resolves (the child's own system for `subagent`, otherwise the system opposite to the child's agent) and that the pair is supported; a mismatch stops before any window.

The reviewer path keeps its `Assignment:` and `Settings evidence:` records in independent-review **Result**.

## Child settings check

The root verifies the effective model and effort of every child it launches for a role other than the reviewer (whose evidence independent-review **Validate** judges), in every place but `inline` ([Places](#places)), from the child's runtime records, never from invocation flags or the child's self-report.

**Binding a record to an opening.** Brief paths repeat across runs, so the brief path alone does not identify a session. Immediately before every `open` of the run (first open, silent-exit reopen, dead-agent reopen, main-moved reopen, `--resume`), the root appends to the runtime brief one line:

```text
Opened: <UTC time, ISO 8601 to the second>
```

The record of an opening is the one session file that matches the selector below and whose first user message containing the brief's absolute path has its own `timestamp` at or after that opening's `Opened:` time and before the brief's next `Opened:` time (no upper bound for the last). Leading records of a Claude transcript without a timestamp (`last-prompt`, `mode` and similar) are skipped. At the final check, no such file is `unavailable: no record` and more than one is `unavailable: ambiguous records <paths>`; at the early check both only mean the record is not yet established. Keep each matched record path for the final check and the report.

- **Claude child:** session transcripts `*.jsonl` under `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/` holding a user message that contains the brief's absolute path. Evidence: `message.model` of assistant records and `message.output_config.effort` of request records (observed field names on Claude Code, 2026-11-01).
- **Codex child:** rollouts `*.jsonl` under `${CODEX_HOME:-$HOME/.codex}/sessions/` whose `session_meta` cwd is the child's checkout and which hold a user message containing the brief's absolute path; that message need not be the first user message, since a rollout can begin with an environment-context user message. Evidence: `turn_context.payload.model` and `turn_context.payload.effort` (observed 2026-11-01).

Every opening of the window in the run has its own record, and each is checked.

When:

1. **Early check:** at the first return of the foreground `wait` after each `open`. Only a mismatch acts: the root stops the wait loop, shows the user the expected and observed values and the record path, and asks whether to continue or stop; the window stays. A record not yet found or not yet unique, or a found record without the fields yet, is left to the final check. `delivering-task`'s queue runs this check in its own Wait loop.
2. **Final check:** in Verify, after a `done` status, over every record of the run. A thin launcher (the loop owner, the `consolidating-plans` worker, triager, orchestrator; [Places](#places)) has no Verify: it runs the final check after its child's `done`, before reporting.

Outcomes:

- **Match** on every record: the report names the effective settings and the record paths.
- **Mismatch** (a record shows another model or effort, including a mid-session change): Verify does not pass silently. Show expected and observed values and ask the user to accept the result with the observed settings (recorded as accepted in the report) or stop with everything preserved. Nothing is discarded automatically.
- **Unavailable** (no record, ambiguous records, or the fields are absent): the same question as a mismatch, stating `settings unverified: <reason>`.
- **Opt-out field:** nothing to compare; the report states the observed value or `unavailable`, with no question.

## Native filesystem paths

Use the selected runtime's actual home/configuration directory when finding runtime records. On PowerShell, read `$env:CLAUDE_CONFIG_DIR`/`$env:CODEX_HOME` or join `$HOME` with `.claude`/`.codex`, using `Join-Path` and `Get-ChildItem -LiteralPath`; POSIX notation above describes the same locations, not a Bash prerequisite. Preserve full caller configuration. A fake process or requested flag proves transport only; it never proves effective model/effort. Missing runtime fields keep the existing unverified-settings outcome.

## Places

Every role keeps its policy in every place of the [run contract](../../child-sessions/references/run-contract.md#places):

- **`inline`** (the place `--run inline`, not the `inline` execution mode of the **inline implementer** row): the worker is the current session. No settings are resolved, and explicit `--model`/`--effort` for it are refused before anything starts; in the orchestrators these keys set the implementer instead.
- **`window`:** unchanged: `open` passes the pair.
- **`subagent`:** resolve by the **Native** bullet of **Resolution** and set the pair with the host's native controls, as the [native subagent reviewer](subagent-reviewers.md) steps 1 and 3 describe, for any role. A pair the place cannot select and verify is refused before launch, naming the place and the pair.
- **`background`:** resolve by the **CLI** bullet and pass the pair as CLI flags (run contract [Launch and wait](../../child-sessions/references/run-contract.md#launch-and-wait)).

The child settings check covers every opening in every place. The `Opened:` line goes into the brief before every launch of a `subagent` or `background` child and before every fresh child, also one an answer or a restart falls back to, as before an `open`. An answer or a restart that continues the same conversation is no opening and never gets one: its turns land in the opening's record. The early check runs at the first status after each opening.

- **`background`:** the record is the CLI session's transcript or rollout, selected as for a window (**Claude child**, **Codex child**) and bound by the brief path and the `Opened:` line.
- **`subagent`:** the record is the host's runtime record named in run contract [Host mechanisms](../../child-sessions/references/run-contract.md#host-mechanisms), bound the same way. A record marked `unverified` there gives `settings unverified: <reason>`, the same question as an unavailable record.

## Nested agents

A launched agent's settings govern that session only. Agents it starts itself (for example subagents of `superpowers:subagent-driven-development`) follow the skill and host that start them; this policy does not set or verify them. An orchestrator's nested-call subagents ([run contract](../../child-sessions/references/run-contract.md#nested-calls)) are such agents: they take the host's default, the orchestrator session's model, neither set nor verified, and the nested skill's own workers take their roles as above.

Sources: [Codex model discovery](https://learn.chatgpt.com/docs/app-server#list-models-modellist), [Claude model configuration](https://code.claude.com/docs/en/model-config).
