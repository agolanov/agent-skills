---
name: child-sessions
description: Runs Claude Code or Codex in a visible terminal window (herdr tab or tmux) from a brief file and waits for its status file. Use when a task must run in a separate agent session the user can watch, or when another skill needs to open, answer, or close such a session.
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
| `124` | `peek "$name" 40`. A pending choice on screen: follow [Dialogs](#dialogs). Work in progress: call bounded `wait` again. |
| `3` | `peek "$name" 40` and show the captured diagnostics. Reopen **once** using the recovery procedure below. |
| Other | Report the command error and preserve the session and checkout for diagnosis. |

Keep waiting in the foreground. Do not replace this loop with background jobs, hooks, wakeup tools, or manual sleep polling.

| Exact first line | Required action |
|---|---|
| `STATUS: done` | Read the sections the calling task needs (for example Commits, Checks, Review, Out of scope), then perform its completion checks. |
| `STATUS: blocked` | Read Questions, present the question/options/recommendation, and obtain the answer. Rename the file to `<file>-blocked-<n>` using an unused number **before** sending the answer. Send one line, or write a multiline answer to a file and send an instruction to read its absolute path. Wait for a fresh status at the original path. |
| `STATUS: failed` | Show the reported failure and relevant status sections, preserve the status file, window, and checkout, and stop. The user decides the next action. |

The root never rewrites a child status. Read the first line before selecting sections; avoid repeatedly loading the whole report.

## Dialogs

A dialog is pending when the bottom of the peeked screen shows a choice the agent is waiting on: a numbered option list with a selection marker and a prompt such as "Do you want to proceed?", an approval request naming a command, or the agent's own question to the user. A working spinner without a choice is work in progress. When the top of the dialog (its title or border) or any line of its command is cut off, peek once more with `peek "$name" 120`; still cut, the dialog goes to the user unanswered.

The root approves a permission dialog on its own only after reading the whole command on screen, and only when all of these hold. Every path the command reads or writes lies inside the child's own checkout named in its brief, a temporary directory under `$TMPDIR` or `/tmp` that the child's task created for disposable fixtures, or the ignored-material paths the brief grants in the main checkout (a sibling directory that merely shares a prefix with one of these names lies outside). Paths count only as resolved: each is literal, or its value is visible in the same command or in the child's visible earlier output (for example the output of `mktemp -d`); an unresolved variable or command substitution, a glob that can match outside the allowed directories (for example at `/tmp` level), or a `..` that leaves them makes the dialog unclassifiable. The command's only effects are reading and writing files under those paths, plus commits on the child's own branch: it does not push, touches the main checkout or docs main checkout only at the granted paths, changes no Git state of any other repository, deletes nothing outside those paths, uses no network, sends no process signals or kills, installs no packages, escalates no privileges, moves no Git ref other than the child's own branch, changes no stash, Git config or worktree list (a worktree shares refs, stash and config with the main checkout), and writes no agent or Git configuration files directly (`.git*`, `.claude/`, `.codex/`, hooks); the objects and refs that a commit on the child's own branch writes into the Git directory belong to that allowed commit and are no configuration write. And the child's brief allows the operation itself, since its prohibitions (for example rebase, merge or push) still apply inside those paths and an approval never grants authority the child lacks. Everything else is out of scope: decline it first, so the child is not left blocked, then show it to the user with the whole command and the reason it lies outside the child's authority. A dialog the root cannot classify goes to the user unanswered. The child's content questions follow the calling task's rule: answer within its authority or ask the user.

Answer one dialog per action; a dialog answer uses only bare Enter, `Up`, `Down` and `Escape` (the line after a decline, below, and answers to content questions are not dialog answers). Approve only when the highlighted option is the approving one (plain "Yes"), with `send "$name" ""`. When the highlight is elsewhere, move it with `key "$name" Up` or `key "$name" Down` and peek: a capture still showing the old highlight is stale, so pause and re-peek as after an answer (below) instead of pressing again, and send the bare Enter only once the approving option shows highlighted. Decline with the agent's cancel key, `key "$name" Escape` in Claude Code, or by highlighting its explicit No option and sending the bare Enter. Option digits are never typed, least of all through `send`: in Claude Code a digit selects at once and `send`'s trailing Enter lands on the next, unread dialog. Each approval covers one command; an "always allow" / "don't ask again" option is never chosen.

After each answer (Enter, cancel or No), peek until the screen no longer shows the answered dialog: its counter or command changed, or no dialog remains. A capture still showing it is stale, never the next dialog: pause with `wait "$name" "$status_file" 5` and peek again, at most three times. This pause is not the wait loop: the bounded-wait rule (calls longer than 120 seconds) still governs the loop itself. A pause exiting `0` or `3` goes to the exit table above; `124` means keep re-peeking. A screen still showing the same command with no counter or the same counter may be a new identical request: leave it unanswered and run `alive "$name"`. Exit 1 means the child is gone: handle it as exit `3` above (peek diagnostics, the single reopen of [Recover a silent exit](#recover-a-silent-exit), and the calling task's exit-3 accounting). Exit 0: show it to the user as a possibly new identical request and wait for the decision before any key. In a stack ("2 of 3"), read and classify each dialog on its own before its key: a decline does not stop the next in-scope approval, and an approval does not carry over. When no dialog remains, return to the bounded `wait`.

A decline can end the agent's turn: in Claude Code, Escape or "No, and tell Claude what to do differently" leaves it idle at an empty input prompt, with no choice and no spinner. When the re-peek after a decline shows the child waiting at its empty input prompt, send one line with `send "$name" "<text>"` that names the declined command and the reason, and tells it to continue without that command or to write `STATUS: blocked` with its question. This line is the only text the root types for a declined dialog.

Tell the user about each answered dialog as it happens, in one line: window, command summary, answer. Declined or escalated dialogs are shown in full: window, whole command, reason. The calling task's final report counts the dialogs answered, declined and escalated.

## Recover a silent exit

After exit 3, retain the original task instructions in the runtime brief and append this exact continuation instruction before reopening:

> Continue from the current state of the checkout: read git log and git status first.

Close the stale named window with `close "$name"` if it still exists, then `open` with the same agent/options, name, checkout, and augmented brief. Wait again. **An unchanged brief is not a continuation. A second silent exit ends the task:** show diagnostics and preserve the remaining window and checkout. A reported `STATUS: failed` is never an automatic reopen trigger.

## Other operations and environment

`send <name> <text>` types one line and Enter; multiline content belongs in a file. `send <name> ""` sends a bare Enter. `key <name> <key>` sends one key without Enter: `Escape`, `Up`, `Down` or one digit `0`–`9`. `peek <name> [lines]` reads visible terminal output. `alive <name>` returns 0 for a running agent, 1 otherwise; a surviving shell window does not prove liveness. `list` lists sessions. After the calling task has completed its checks, `close <name>` closes the window; it does not remove the checkout or branch.

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
