# Run contract

One contract for every child outside `inline`: the parent writes a brief, starts the child in its place, waits for the status file, answers or relays the child's questions and reads its report. A `window` runs through [SKILL.md](../SKILL.md) unchanged; this file adds `subagent` and `background` and the rules all three places share.

## Places

| Value | Place |
|---|---|
| `inline` | the current session does the work itself |
| `subagent` | a native subagent of the current session's host (Claude Code's agent tool, Codex subagents); always the same system as the session that starts it |
| `background` | a separate non-interactive CLI process (`claude --print`, `codex exec`, `codex review -`) started by the current session; not visible; either system |
| `window` | a visible interactive session through `child-sessions` (herdr, else tmux, else the native terminal); either system |

`--run <place>` places a skill's **worker**, the agent that does the work the skill exists for; each skill names its default.

- A skill whose root only prepares, waits and verifies (the planner's, the implementer's) keeps its root in the calling session and moves only the worker.
- A skill whose root is its worker (`review-fix-loop`, `delivering-task-follow-ups`, the orchestrators) moves as a whole: the calling session becomes a **thin launcher**, which writes the brief, waits, relays questions and reports the child's result.
- Any skill can be run as a whole outside `inline` by its caller, a parent skill or the user's words, through this contract; `--run` only names each skill's default target of that move.
- The user's words set places as keys do ("run the plan without a window", "let Codex review it in a window"): the session maps them to keys and announces the mapping.

**System.** `--agent claude|codex`, optionally with a [launch command](#launch-command), chooses the worker's system. Without it the worker is the caller's own system, identified from session identity as independent-review's [Session system](../../independent-review/SKILL.md#session-system) says, and a window's `open` receives it as `--agent`; the helper's own default is not this rule. A reviewer is the opposite system unless `--codex`, `--claude` or `--dual` chooses it; with `subagent` and no system key it is the caller's own system. A `subagent` is always the caller's own system.

### Launch command

An agent value is `<system>` or `<system>:<command>`, for example `codex:codex-avc`. The system (`claude` or `codex`) decides everything a system decides: CLI flags, native review tool, runtime records, the opposite system, review marks and window names. A reviewer's command comes from its own key ([independent-review Assignment](../../independent-review/SKILL.md#assignment)). The command is the executable a `window` or `background` launch starts in place of the system's own `claude` or `codex`: one word of `[A-Za-z0-9._/+-]` (also `\` and `:` on native Windows), found on `PATH` or given as a path, taking the system's CLI arguments unchanged. Without a command the system's own executable runs; an `inline` or `subagent` worker starts no CLI and refuses a command ([Refused combinations](#refused-combinations)). Carry the value whole wherever the agent travels: `--agent` to `open` (the helper splits it), the brief's `Agent:` line, nested calls and state records; compare and choose systems by its system part only.

## Brief

Write the brief by [brief-writing.md](brief-writing.md), outside the checkout under child-sessions' `runtime-dir` ([platform-runtime.md](platform-runtime.md)), with an absent status path beside it; its `Terminal controls:` item belongs to `window` only. A run-contract brief opens with these identity lines, paths absolute:

```text
Skill: <absolute SKILL.md>
Arguments: <the caller's keys and values, verbatim, except those the launcher consumes>
Checkout: <absolute>
Authority: <what the child may write, commit and decide>
Place: <window|subagent|background>
Auto: <yes|no>
Status file: <absolute>
Nested agents: <the line of launch-settings' Nested agents, with the rows the child's work uses>
```

- A thin launcher consumes `--run` and the keys that set the worker it launches (`--model`, `--effort`) and writes every other key into `Arguments:`. In the orchestrators `--model` and `--effort` set the implementer, so they stay in `Arguments:`.
- The child reads `Skill:` completely and performs that skill `inline` in its own session with `Arguments:`, adding `--auto` when `Auto: yes` (the parent writes `yes` when its own run has `--auto`), and then follows [auto.md](auto.md) as a child; with `Auto: no` it asks as the skill says. `Authority:` bounds what it writes, commits and decides. It writes the status file by [status-file.md](status-file.md).
- A skill's own brief template is a run-contract brief too. Its identity block carries `Place:` and `Auto:`; its Work replaces `Skill:` and `Arguments:`. Its explicit `Authority:` line, or its explicit Work, Ownership and boundary instructions together, supplies the authority bound. These instructions must agree. An omitted label grants no additional authority.
- A subagent's last message lands in the parent's context: the brief tells it to end with the status file's first line only.

## Thin launchers

When a whole skill moves outside `inline`, the child does the work. The parent follows the caller's `Run elsewhere` parameters.

1. **Prepare.** Resolve the installed [entrypoint](platform-runtime.md), private `runtime-dir`, checkout, inputs and scope. Apply [place selection](#places), [refusals](#refused-combinations) and the caller's local limits before launch.
2. **Settings.** Resolve the role, model and effort by [precedence](../../independent-review/references/launch-settings.md#precedence). An explicit `cli-default` omits that field. Orchestrators forward implementer settings and use their own role defaults. Stop if the chosen place cannot supply the resolved pair.
3. **Brief.** For local name `<name>` use `<runtime>/<name>-brief.md`, `<runtime>/<name>-status.md` and a fresh `<runtime>/<name>-run-<n>` per background start. Refuse a live window of that name. Check [earlier runs](#earlier-runs) before archiving files as `<file>-old-<n>` with the smallest unused number. Write the [brief fields](#brief), [launch settings](../../independent-review/references/launch-settings.md#record), inputs and caller's reporting/completion rules. Include the local question payload. The child writes status before ending each turn and returns its exact first line.
4. **Launch and relay.** Use [Launch and wait](#launch-and-wait) and [Questions and continuation](#questions-and-continuation). In an interactive window the child may ask the caller's local questions directly unless under `--auto`. Otherwise it writes blocked Questions with options and recommendation. Show them verbatim or use [auto routing](auto.md#deciding), then continue the child.
5. **Report.** On done or failed, give the local result and [settings line](../../independent-review/references/launch-settings.md#child-settings-check) with the role and sources. Include each background producer exit and session ID, and all decisions under `--auto`. Apply the caller's final checks and decisions before closing a successful owned window. Preserve failed or unaccepted work and evidence.

## Earlier runs

Before archiving old files, check whether another run still uses them. Treat these as possibly live:

- A `subagent` or `background` brief with a missing status or a first line other than `STATUS: done` or `STATUS: failed`.
- A run directory with `launch.time` or `wrapper.identity` and no valid [completed recording](#background-recording).
- A legacy directory with neither field and no `producer.exit`.

Show the paths and ask the user whether the earlier run ended, including under `--auto`. Rename only on confirmation. Otherwise stop and name the files.

## Launch and wait

Every place starts the child with the window's prompt:

```text
Read the brief at <absolute brief> completely and carry it out.
```

**Lean launch.** A local-only Claude worker (every Claude child that is not a reviewer) starts with the literal words `--strict-mcp-config --no-chrome`: in a window as `open --cli-arg --strict-mcp-config --cli-arg --no-chrome`, in the background as the recipes' `cli_args`. When its brief or task names an MCP server, leave out `--strict-mcp-config`, so the user's own configuration supplies the server; no MCP configuration file is written. When the task needs the browser, leave out `--no-chrome`. Pass the same words on every start, reopen, retry and resume of that child. Codex workers, subagents and reviewers (independent-review's own launch) take none of these words.

- **`window`:** [SKILL.md](../SKILL.md) as today: `open`, Startup, [Wait](../SKILL.md#wait), Dialogs and the single reopen after a silent exit.
- **`subagent`:** start a fresh agent with the host's agent tool ([Host mechanisms](#host-mechanisms)): the prompt above, no parent history, the host's normal tool set, and the pair of [Settings](#settings). For an orchestrator's phase agent, use its whole phase brief from [Nested calls](nested-calls.md#briefs) instead of that prompt, with the pair launch-settings' [Nested agents](../../independent-review/references/launch-settings.md#nested-agents) gives phase agents. It starts in the parent's working directory; the brief's `Checkout:` is where it works. Wait with the host's wait tools until it ends; it writes the status file before it ends.
- **`background`.** Use the installed [background commands](#background-recording). On Claude, start the producer once with Bash `run_in_background: true` and retain the host task ID. On Codex use `exec_command` and continue the same yielded `session_id` with `write_stdin` at intervals of at most 60 seconds. A host task handle and a CLI conversation ID serve different purposes.

Keep the [quiet wait](../SKILL.md#wait). Use rung 1 for a background child only when [Host mechanisms](#host-mechanisms) verifies notifications for the waiting host and session kind. Print the usual waiting notice with the host handle and end the turn. Background children have no rung 2. In the foreground, use the host wait when available (Claude `TaskOutput` with `block: true`, up to 60000 ms), otherwise the [completion check](#completion-marker-fallback). Report the applicable `Wait:` line. If neither a host execution/wait pair nor the shell/liveness fallback is usable, refuse before launch.

After completion, dispatch the exact [status](../SKILL.md#exits-and-statuses). For a block, follow [Questions and continuation](#questions-and-continuation). A child ending without valid status gets one restart via that same section, with this message:

> Your turn ended without a status file. Continue from the current state of the checkout: read git log and git status first.

On a second silent exit, report the producer exit, stderr and run directory and preserve the checkout. A launch exception or CLI usage error before a session ID is issued gets no restart. Report the actual error.

### Background recording

Use the installed [Bash helper](../scripts/background) or native [PowerShell 7 helper](../scripts/background.ps1) with literal arguments. Start the PowerShell producer in its own process with `pwsh -NoProfile -File <absolute background.ps1>`. Windows PowerShell 5.1 does not support this background path.

1. Write the prompt outside the checkout. Before scheduling a producer, run `prepare --run-dir <fresh absolute directory> --prompt <absolute prompt file>`. This copies the prompt, verifies process inspection and records the launch time. Use a fresh directory for every start or resume.
2. Launch `run --run-dir <directory> --checkout <absolute checkout> --agent <system[:command]> [--model M] [--effort E] [--resume ID] [--cli-arg WORD]...` once through the host. Apply [Permissions](#permissions) and [lean launch](#launch-and-wait). Each extra word is a literal argument. Keep the run directory and host handle.
3. Run `wait --run-dir <directory> [--seconds N]` to verify publication before reading the child status. On success the helper prints `producer_exit:` and `session_id:` from the completed recording. Keep the wrapper result, actual CLI exit and child status distinct. A missing ID is a launch failure. Retain logs on error.

### Completion-marker fallback

On each rung 1 wake, including user input, run the background helper's `wait --run-dir <directory> --seconds 1`. On the foreground fallback use 60 seconds with a host timeout that allows the command to finish (Claude Bash `timeout: 75000` ms).

| Exit | Action |
|---|---|
| 0 | Record the printed producer exit and conversation ID, then dispatch status. |
| 124 | Still pending. On rung 1, answer any input, repeat the notice with the original handle and end the turn. In the foreground, wait again on the same directory. |
| 2 or 3 | Process or timestamp evidence is unavailable (2) or recording is incomplete (3). Preserve diagnostics and stop. |

If the host unexpectedly backgrounds the foreground wait, settle its retained handle and report the failure. Start no competing waiter or producer. When relying on the marker, report that the outer host exit notification was not independently awaited. The marker grants no process cleanup authority.

## Child environment

Window and background helpers remove only their fourteen named parent-session metadata variables from the child launch environment. Matching is case-sensitive on POSIX and case-insensitive on Windows. Preserve the caller's environment, other variables including `CLAUDE_CONFIG_DIR` and `CODEX_HOME`, and the literal launch arguments. Do not print credentials.

## Questions and continuation

- A `subagent` or `background` child asks nobody directly: a question ends its turn with `STATUS: blocked`, its Questions holding the question, the options and its recommendation. In a `window` an interactive skill (brainstorming) may still ask the user in the window, except under `--auto`; any other question takes the same status.
- Without `--auto`, the parent answers within its authority or asks the user, showing the question, options and recommendation as written.
- Under `--auto`, [auto.md](auto.md) governs both sides: the child asks nobody, in a window either, and the parent routes the question by its [Deciding](auto.md#deciding) and records an answer given without the user under `## Decisions`.
- Before continuing, archive the status: rename it to `<file>-blocked-<n>` with an unused number, as for a window ([status-file.md](status-file.md)); the child writes a fresh status at the original path.
- Continue **the same child conversation** by the host mechanism of [Host mechanisms](#host-mechanisms), the answer as one message (multiline content in a file, the message naming its absolute path), then wait as at launch:
  - `subagent`: the host's message tool to the same agent;
  - `background`: use [Background recording](#background-recording) with a fresh directory, the answer as the prompt, `--resume <recorded session ID>`, and the same permissions, launch words and settings;
  - `window`: child-sessions' `blocked` row.
- Otherwise start a **fresh child**: the original brief, followed by every question and answer so far and the line "Continue from the current state of the checkout: read git log and git status first.". Otherwise means no mechanism for the host, no recorded session ID, or a continuation the host refuses (its message tool returns an error, or the resume exits nonzero without a status); that fallback belongs to the same answer or restart.

## Host mechanisms

For window and background waits, host notification was observed in interactive Claude Code 2.1.322 on Linux/WSL2. It was unusable for its native subagent and unverified for print sessions. Codex host notification was unverified on 0.167.0 and 0.167.2. An unlisted host or session kind does not qualify for rung 1.

For window workers, a successful `wake` proves rung 2 for this run. A short Codex 0.167.2/tmux own-pane wake was observed on WSL2. Other platforms/backends, long Codex waits and simultaneous user typing remain unverified. Use installed host tools for subagent start, join and continuation. See [the host evidence table](host-evidence.md) for exact versions, controls, record locations and coverage limits of each mechanism.

## Permissions

A non-interactive child has nowhere to ask for a permission. A writing worker in `background` gets a window's permission arguments on every start and resume, built as `open` builds them: Claude `--permission-mode bypassPermissions`, Codex `--dangerously-bypass-approvals-and-sandbox`, or, when `CHILD_SESSION_CLAUDE_ARGS`/`CHILD_SESSION_CODEX_ARGS` is set, its whitespace-separated words without shell evaluation (a whitespace-only value means no arguments). Words the CLI refuses (for example `-a`, which `codex exec` does not take) make every start a launch failure ([Launch and wait](#launch-and-wait)). A `subagent` runs with its host session's permissions. In every place the brief's `Authority:` bounds what the child does with them. A reviewer keeps [CLI reviewers](../../independent-review/references/cli-reviewers.md)' permission rules in every place, a window included ([window reviewers](../../independent-review/references/window-reviewers.md) step 5).

## Settings

Every role keeps its launch-settings row in every place: resolve and pass the pair as [launch settings Places](../../independent-review/references/launch-settings.md#places) says, and report it by its [child settings check](../../independent-review/references/launch-settings.md#child-settings-check).

## Refused combinations

Refused before anything starts, naming the combination:

- a `subagent` reviewer, in every skill (`--run subagent` of `independent-review`, `--reviewer-run subagent` of every skill that passes it), naming `background` and `window`: a native subagent has no native review command;
- a worker `subagent` of a system other than the current session's, for example `--agent codex --run subagent` from Claude Code;
- a `subagent` started by a session that is itself a subagent, where the host's subagents cannot start subagents ([Host mechanisms](#host-mechanisms)): the session checks its own agent tool and, on Codex, `[agents] max_depth` in the user's `config.toml` against its own depth (the segments of its canonical task name after `/root`). A spawn the host refuses at launch is reported as this combination, with no fallback to another place. Prepare alone starts no non-window worker and does not apply the refusal for this session being itself a subagent: judge that combination for its caller, which is never a subagent (both orchestrators refuse `--run subagent`); a refused worker start is Nested calls' `launch failure`. Every other refusal stays Prepare's, including an implementer subagent that would itself start subagents;
- a place that cannot select the role's model and effort ([Settings](#settings));
- `--model` or `--effort` with an `inline` worker, except in the orchestrators, where they set the implementer;
- an `inline` worker with `--agent` naming a system other than the current session's ([Session system](../../independent-review/SKILL.md#session-system)), refused before any edit;
- an `inline` or `subagent` worker whose `--agent` carries a [launch command](#launch-command), naming the value.

## Nested calls

When an orchestrator dispatches Prepare and Accept, follow [Nested calls](nested-calls.md).
