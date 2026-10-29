---
name: child-sessions
description: Runs Claude Code or Codex in a visible terminal window (herdr tab or tmux) from a brief file and waits for its status file. Use when a task must run in a separate agent session the user can watch, or when another skill needs to open, answer, or close such a session.
metadata:
  internal: true
---

# Child Sessions

Run a child in a visible window; coordinate through a brief, terminal input, and a child-written status file. This skill controls the session lifecycle. The calling task supplies the scope and any integration authority.

## Locate and open

Resolve the installed `SKILL.md` to its absolute path, then locate the executable beside it:

```bash
child_session="$(dirname -- "$skill_file")/scripts/child-session"
```

Always call `"$child_session"`; never resolve `child-session` through `PATH`. Bash, tmux, and the selected agent CLI are required; herdr also needs `herdr` and `jq`.

Before opening, read [brief-writing.md](references/brief-writing.md) and [status-file.md](references/status-file.md). Write the brief outside the repository under `${XDG_RUNTIME_DIR:-/tmp}/child-sessions/`. Choose an absolute status path that does not already exist, and a unique window name matching `[A-Za-z0-9_-]+`.

```bash
"$child_session" open --agent codex "$name" "$checkout" "$brief"
```

`checkout` and `brief` are absolute paths. Quote every path, including paths containing spaces or `$`. Optional `--model M` and `--effort E` pass through to the CLI; omission keeps CLI defaults. The script defaults to Claude unless `CHILD_SESSION_AGENT` is set. The caller chooses the agent.

Herdr is selected when `HERDR_ENV=1`; otherwise tmux is used. Herdr opens a tab by default; `--split right|down` opens a pane and requires herdr. In tmux, attach to the named tmux session if the best-effort Windows Terminal tab does not appear.

If herdr reports workspace/pane not found, validate this session's live workspace and pane using the herdr CLI before retrying: inherited IDs may be stale. Match this session's identity and checkout; never guess or select the user's focused pane as a substitute. Stop if ownership is ambiguous.

## Foreground wait loop

Use foreground `wait` calls with an explicit bounded duration: **540 seconds on Claude Code**, **240 seconds on Codex**. Fit other hosts to their shell execution limit with margin. Keep each call longer than 120 seconds where supported: repeatedly starting fresh short waits resets the script's 120-second grace for a child that exited before it was ever seen alive.

```bash
"$child_session" wait "$name" "$status_file" 240
```

Codex's `exec_command.yield_time_ms` (up to 30000 ms) controls when the tool yields; it is **not an execution timeout**. If it returns `session_id`, poll that same foreground command with `write_stdin` in intervals of at most 60 seconds until it exits. A tool yield is not exit 124. Only after the command exits, handle its actual code:

| Exit | Required action |
|---|---|
| `0` | Read only the first status line first (`head -n 1 -- "$status_file"`). Dispatch by the exact status below, then read the relevant named sections. Exit 0 alone does not mean success. |
| `124` | `peek "$name" 40`. Work in progress: call bounded `wait` again. A question/dialog: answer via `send` within existing authority, or obtain the user's decision; then wait again. |
| `3` | `peek "$name" 40` and show the captured diagnostics. Reopen **once** using the recovery procedure below. |
| Other | Report the command error and preserve the session and checkout for diagnosis. |

Keep waiting in the foreground. Do not replace this loop with background jobs, hooks, wakeup tools, or manual sleep polling.

| Exact first line | Required action |
|---|---|
| `STATUS: done` | Read the sections the calling task needs (for example Commits, Checks, Review, Out of scope), then perform its completion checks. |
| `STATUS: blocked` | Read Questions, present the question/options/recommendation, and obtain the answer. Rename the file to `<file>-blocked-<n>` using an unused number **before** sending the answer. Send one line, or write a multiline answer to a file and send an instruction to read its absolute path. Wait for a fresh status at the original path. |
| `STATUS: failed` | Show the reported failure and relevant status sections, preserve the status file, window, and checkout, and stop. The user decides the next action. |

The root never rewrites a child status. Read the first line before selecting sections; avoid repeatedly loading the whole report.

## Recover a silent exit

After exit 3, retain the original task instructions in the runtime brief and append this exact continuation instruction before reopening:

> Continue from the current state of the checkout: read git log and git status first.

Close the stale named window with `close "$name"` if it still exists, then `open` with the same agent/options, name, checkout, and augmented brief. Wait again. **An unchanged brief is not a continuation. A second silent exit ends the task:** show diagnostics and preserve the remaining window and checkout. A reported `STATUS: failed` is never an automatic reopen trigger.

## Other operations and environment

`send <name> <text>` types one line and Enter; multiline content belongs in a file. `peek <name> [lines]` reads visible terminal output. `alive <name>` returns 0 for a running agent, 1 otherwise; a surviving shell window does not prove liveness. `list` lists sessions. After the calling task has completed its checks, `close <name>` closes the window; it does not remove the checkout or branch.

| Variable | Meaning |
|---|---|
| `CHILD_SESSION_BACKEND` | Force `herdr` or `tmux`. |
| `CHILD_SESSION_AGENT` | Default agent, `claude` or `codex`. |
| `CHILD_SESSION_TMUX_SESSION` | Tmux session name; default `child-sessions`. |
| `CHILD_SESSION_TAB=0` | Disable best-effort Windows Terminal tab creation. |
| `CHILD_SESSION_CLAUDE_ARGS` | Replace Claude's default `--permission-mode bypassPermissions`. |
| `CHILD_SESSION_CODEX_ARGS` | Replace Codex's default `--dangerously-bypass-approvals-and-sandbox`. |
| `XDG_RUNTIME_DIR` | Runtime parent directory; fallback `/tmp`. |
| `HERDR_ENV`, `HERDR_WORKSPACE_ID`, `HERDR_PANE_ID` | Herdr detection/workspace and source pane for splits. |

Argument overrides are whitespace-separated words without shell evaluation. Children have parent session metadata matching `^(CLAUDE|CODEX_COMPANION_|CODEX_)` stripped; the configuration variables `CLAUDE_CONFIG_DIR` and `CODEX_HOME` are preserved.
