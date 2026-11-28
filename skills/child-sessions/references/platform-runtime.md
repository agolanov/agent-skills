# Platform runtime and capabilities

Resolve the entrypoint beside the installed `child-sessions/SKILL.md` and retain its absolute path and installed shell for the run. POSIX uses `scripts/child-session` with Bash. Native Windows uses `scripts/child-session.ps1` with the installed PowerShell; WSL is a separate Linux environment. The Bash entrypoint refuses MSYS/Cygwin. Use installed tools only, without installation, profile changes or persistent configuration changes.

## Runtime and backend

`runtime-dir` prints the absolute owner-local storage directory. An explicit `CHILD_SESSION_RUNTIME_DIR` wins; otherwise POSIX uses `XDG_RUNTIME_DIR/child-sessions` or a user-specific directory under the system temporary directory. Windows uses `[IO.Path]::GetTempPath()/child-sessions`. Keep briefs/status outside monitored checkouts and Git administration. POSIX launch files use private modes; Windows uses the ordinary inherited protection of the user's native temp directory. Do not choose a shared directory for secret-bearing launch material. These are trusted-local checks, with no hostile-filesystem or atomic ancestry guarantee.

An explicit compatible `CHILD_SESSION_BACKEND=herdr|tmux|terminal` wins. Otherwise the helper tries a proven herdr connection, installed tmux on POSIX, then a supported terminal. Herdr needs its CLI and a JSON reader (Python on POSIX, built-in on Windows). With a caller session ID, the helper requires exactly one matching live session. Without one, only live injected workspace/pane IDs qualify. Stale IDs fall back automatically or fail with explicit herdr. Controls use the owned launch record. Herdr opens a tab by default. `--split right|down` needs an opener alone in its tab.

Linux plain terminals support the xterm/zutty `-e` interface. The stock macOS Terminal path remains unverified. Windows uses the installed PowerShell and Windows Terminal. The native window helper supports PowerShell 7 and has partial 5.1 coverage. Missing tools are reported as unavailable.

| Setting | Effect |
|---|---|
| `CHILD_SESSION_AGENT` | Helper default, `claude` unless set. Accepts `<system>:<command>`. |
| `CHILD_SESSION_TMUX_SESSION` | tmux session name, default `child-sessions`. |
| `CHILD_SESSION_TAB=0` | Disable best-effort Windows Terminal tab creation. |
| `CHILD_SESSION_CLAUDE_ARGS`, `CHILD_SESSION_CODEX_ARGS` | Replace the default [permission arguments](run-contract.md#permissions). Words are separated by whitespace without shell evaluation. |

## Native Windows invocation

Set `$child` to the absolute installed entrypoint. Dot-source it and call `Invoke-ChildSessionDispatch @('runtime-dir')` before writing the brief. For the [window launch](../SKILL.md#locate-and-open), pass the literal argument array in `$openArgs` and run this block in one PowerShell tool process. The dispatcher prints evidence and returns the lifecycle exit code. Never evaluate task strings through `Invoke-Expression`, `cmd /c` or Bash interpolation.

```powershell
try {
    . $child
    $code = Invoke-ChildSessionDispatch (@('open') + $openArgs)
    if ($code -eq 0) { $code = Invoke-ChildSessionDispatch @('capabilities', $name) }
    if ($code -eq 0) { $code = Invoke-ChildSessionDispatch @('startup', $name, $statusFile) }
    exit $code
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 2
}
```

For a separate process, invoke the verified installed `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File ABS\scripts\child-session.ps1 COMMAND ...` with the command tool's literal argv support and retain its actual process exit. The dispatcher array recipe avoids another native argument boundary when a tool offers only PowerShell code. There is no per-call request-file protocol.

The helper resolves executable CLIs and supported PowerShell/npm shims. Only the named [parent metadata](run-contract.md#child-environment) is stripped from the child environment. A launch failure preserves its diagnostics and any unconsumed transport for owned cleanup.

## Owned lifecycle

`capabilities NAME` reports the backend, launch ID, checkout and booleans for open, alive, wait, close, list, peek, send, key, split and window_close. Controls use the recorded backend IDs. An owned agent can outlive its launcher or window. Input requires a live launcher. The name stays reserved while an owned process survives.

Plain terminals have no peek, send, key, split or window close. Follow the [plain-terminal notice and file-based wait](../SKILL.md#locate-and-open). For wait codes and recovery use [Exits and statuses](../SKILL.md#exits-and-statuses).

`close` verifies recorded PIDs and start identities before signalling. A mismatch preserves the process. Linux and macOS stop the recorded agent and launcher. Windows also stops proven descendants, based on parent links and start times in one snapshot. After a recorded agent exit, only descendants it started before exit qualify. Later or unproven descendants may survive. Windows retains its window (`window_close: false`). Confirm `alive` exit 1 before freeing a queue slot.

## Inconclusive native liveness

Native `alive` exit 1 proves absence only with a matching retained launch record and complete recorded PID/start identity for a running agent. A running record missing that identity or a failed process query returns an error (exit 2 for direct invocation), not stopped. `starting` retains its ordinary startup grace and is not proof of shutdown. Native `close` refusals such as inconclusive startup, missing PID/start or PID reuse preserve the session; never turn the following `alive` result into permission to discard those records. Resolve ownership and liveness before continuation. A separate terminal-cleanup error may remain diagnostic only after all owned processes are proven stopped.
