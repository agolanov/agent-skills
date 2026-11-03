# Platform runtime and capabilities

Resolve the entrypoint beside the installed `child-sessions/SKILL.md` and retain its absolute path and installed shell for the run. POSIX uses `scripts/child-session` with Bash. Native Windows uses `scripts/child-session.ps1` with the installed PowerShell; WSL is a separate Linux environment. The Bash entrypoint refuses MSYS/Cygwin. Use installed tools only, without installation, profile changes or persistent configuration changes.

## Runtime and backend

`runtime-dir` prints the absolute owner-local storage directory. An explicit `CHILD_SESSION_RUNTIME_DIR` wins; otherwise POSIX uses `XDG_RUNTIME_DIR/child-sessions` or a user-specific directory under the system temporary directory. Windows uses `[IO.Path]::GetTempPath()/child-sessions`. Keep briefs/status outside monitored checkouts and Git administration. POSIX launch files use private modes; Windows uses the ordinary inherited protection of the user's native temp directory. Do not choose a shared directory for secret-bearing launch material. These are trusted-local checks, with no hostile-filesystem or atomic ancestry guarantee.

An explicit compatible `CHILD_SESSION_BACKEND=herdr|tmux|terminal` wins. Otherwise use a connected herdr workspace (`HERDR_ENV=1` and actual workspace/pane lookup), then installed tmux on POSIX, then an installed terminal. Stale herdr IDs fail; never substitute a focused user pane. Dependencies belong only to the selected path: herdr needs its CLI and an installed JSON reader (Python on POSIX, built-in JSON on Windows); tmux/terminal need no Python. The self-contained Bash script also works when copied alone.

Linux plain-terminal launch recognizes installed xterm/zutty `-e` interfaces. macOS uses stock Bash, `ps -o lstart=`, `open -a Terminal` and a private `.command` launcher; it never invokes Apple's Python installer shim. Native macOS is unverified here. Windows uses the current installed shell and Windows Terminal. The tested current shell is `C:\Program Files\PowerShell\7\pwsh.exe` 7.6.9 Core, .NET 10.0.14; useful Windows PowerShell 5.1 compatibility is checked separately and does not establish that every backend works there. Missing tools/backend interfaces are unavailable capabilities, never an installation request or a success claim.

## Native Windows invocation

In an existing native PowerShell command tool, dot-source the resolved owner and pass literal string arrays. `Invoke-ChildSessionDispatch` returns the lifecycle exit code; catch exceptions as command errors. Do not put a task string through `Invoke-Expression`, `cmd /c` or Bash interpolation.

```powershell
$child = 'C:\absolute\skills\child-sessions\scripts\child-session.ps1'
. $child
$runtimeExit = Invoke-ChildSessionDispatch @('runtime-dir')
$openExit = Invoke-ChildSessionDispatch @('open','--agent','codex','--model',$model,'--effort',$effort,'--',$name,$checkout,$brief)
$capsExit = Invoke-ChildSessionDispatch @('capabilities',$name)
$waitExit = Invoke-ChildSessionDispatch @('wait',$name,$status,'240')
$closeExit = Invoke-ChildSessionDispatch @('close',$name)
$aliveExit = Invoke-ChildSessionDispatch @('alive',$name)
```

For a separate process, invoke the verified installed `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File ABS\scripts\child-session.ps1 COMMAND ...` with the command tool's literal argv support and retain its actual process exit. The dispatcher array recipe avoids another native argument boundary when a tool offers only PowerShell code. There is no per-call request-file protocol.

The helper uses ordinary `System.Diagnostics.ProcessStartInfo`, `Process`, JSON and file APIs. Current pwsh uses `ArgumentList`; the 5.1 compatibility path uses standard Windows argument quoting. Executable CLIs and installed PowerShell shims are supported. An npm shim must resolve to its installed Node target, or the helper reports unavailable; `.cmd/.bat` needs its PowerShell sibling, never arbitrary command evaluation. The full caller environment travels in a random launch-local JSON file, is restored at the actual launcher and is removed after consumption or owned close. Parent metadata matching `^(CLAUDE|CODEX_COMPANION_|CODEX_)` is stripped again there, preserving `CLAUDE_CONFIG_DIR` and `CODEX_HOME`. Windows Terminal receives a fixed shell and encoded owned bootstrap, keeping task arguments out of its semicolon parser. A launch failure retains evidence and any unconsumed transport for diagnosis/owned cleanup.

## Owned lifecycle

The small launch record contains an unpredictable launch token, checkout, backend/workspace/pane/window identifiers, launcher/agent PID and available start evidence, phase and actual agent exit. The Bash record contains data only and is never sourced. Its `.state` marker remains for legacy fixtures/diagnostics. Linux checks `/proc` start ticks and rejects zombies; macOS uses ordinary `ps` start time; Windows uses `Process.StartTime` ticks. This prevents ordinary PID-reuse mistakes, with no race-proof or process-tree ownership guarantee.

`capabilities NAME` prints JSON containing `backend`, `launch_id`, `checkout` and booleans `open`, `alive`, `wait`, `close`, `list`, `peek`, `send`, `key`, `split`, `window_close`. Unknown/unowned sessions are command errors. Controls bind to recorded backend IDs, never a title search. `alive` is 0 for the running recorded launcher and agent, 1 for absence/exit; malformed ownership evidence is a command error. A retained shell alone is not a live agent.

Plain terminals have no `peek/send/key/split/window_close`. At launch tell the user that questions/dialogs need direct attention in the visible window, with counts **not observable**. Continue file-based waiting. Repeat the notice only in a report ending/escalating waiting; timeout alone creates no question and grants no input/approval. A known blocked status uses the unchanged status contract and keeps the live agent open.

`wait` recognizes only the exact first `STATUS: done|blocked|failed` line, with exit 0; it does not interpret success. Timeout is 124; silent exit is 3, after the existing 120-second never-seen startup grace or an observed running agent's exit. Other failures remain errors. The caller owns the single reopen budget.

Before stopping, compare every live recorded PID/start value. A mismatch or missing ownership preserves the process/session. Stop only the recorded agent and launcher; never kill an unverified descendant tree or a whole terminal. Close an independently owned tmux/herdr window only through its recorded IDs. Windows currently retains its terminal/herdr window and reports `window_close: false` separately. Confirm `alive` exit 1 before freeing a queue slot; surviving window appearance is separate from agent exit.

Stopping a recorded PowerShell script wrapper and launcher does not prove that unrecorded descendants have exited.
