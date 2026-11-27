#Requires -Version 7.0
# Foreground wrapper; the caller retains its native host task handle.
. (Join-Path $PSScriptRoot 'child-session.ps1')
$ErrorActionPreference = 'Stop'
$utf8 = [Text.UTF8Encoding]::new($false, $true)
function Read-Record([string]$Name) {
  $path = Join-Path $runDir $Name
  if ([IO.File]::GetAttributes($path) -band [IO.FileAttributes]::ReparsePoint) { throw "Linked record: $Name" }
  $value = $utf8.GetString([IO.File]::ReadAllBytes($path))
  if ($value.StartsWith([string][char]0xFEFF, [StringComparison]::Ordinal) -or $value.Contains("`r") -or $value.Contains([string][char]0)) {
    throw ('Malformed record: ' + $Name)
  }
  return $value
}
function Read-LaunchTime {
  $launch = Read-Record 'launch.time'
  if ($launch -cnotmatch '\A[0-9]+\n\z') { throw 'Invalid launch.time' }
  [long]$launchTime = 0
  if (-not [long]::TryParse($launch.Substring(0, $launch.Length - 1), [Globalization.NumberStyles]::None,
      [Globalization.CultureInfo]::InvariantCulture, [ref]$launchTime)) { throw 'Invalid launch.time' }
  return $launchTime
}
function Read-Identity {
  $identity = Read-Record 'wrapper.identity'
  if ($identity -cnotmatch '\A([1-9][0-9]*)\n([1-9][0-9]*)\n\z') { throw 'Invalid wrapper.identity' }
  [int]$wrapperPid = 0
  if (-not [int]::TryParse($Matches[1], [ref]$wrapperPid)) { throw 'Invalid wrapper.identity' }
  $wrapperStart = $Matches[2]
  return @{ Pid = $wrapperPid; Start = $wrapperStart }
}
function Test-Complete {
  try {
    if (-not (Test-Path -LiteralPath (Join-Path $runDir 'wrapper.done') -ErrorAction Stop)) { return 1 }
    try { $null = Read-LaunchTime; $null = Read-Identity } catch { [Console]::Error.WriteLine($_); return 2 }
    $completedExit = Read-Record 'producer.exit'
    $completedId = Read-Record 'session.id'
    if ((Read-Record 'wrapper.done') -cne "complete`n" -or
        $completedExit -cnotmatch '\A[+-]?[0-9]+\n\z' -or
        $completedId -cnotmatch '\A[^\r\n]*\n\z') { return 3 }
    [Console]::Write("producer_exit: " + $completedExit + "session_id: " + $completedId)
    return 0
  } catch { [Console]::Error.WriteLine($_); return 3 }
}
# OS-read leaf only; the caller interprets the raw error and properties.
function Read-ProcessObservation([int]$ProcessId) {
  try { return @{ Process = (Get-Process -Id $ProcessId -ErrorAction Stop); Error = $null } }
  catch { return @{ Process = $null; Error = $_ } }
}
function Inspect-Process([int]$ProcessId) {
  $observation = Read-ProcessObservation $ProcessId
  if ($null -ne $observation.Error) {
    [Console]::Error.WriteLine($observation.Error)
    if ($observation.Error.FullyQualifiedErrorId -ceq 'NoProcessFoundForGivenId,Microsoft.PowerShell.Commands.GetProcessCommand') {
      return @{ Code = 1; Start = '' }
    }
    return @{ Code = 2; Start = '' }
  }
  try {
    $start = $observation.Process.StartTime.ToUniversalTime().Ticks.ToString([Globalization.CultureInfo]::InvariantCulture)
    if ($start -cnotmatch '\A[1-9][0-9]*\z') { throw 'Malformed process start identity' }
    if ($observation.Process.HasExited) { return @{ Code = 1; Start = $start } }
    return @{ Code = 0; Start = $start }
  } catch { [Console]::Error.WriteLine($_); return @{ Code = 2; Start = '' } }
}
function Watch-Main {
  try {
    if ($watchSeconds -lt 1 -or $watchSeconds -gt 60 -or -not [IO.Path]::IsPathFullyQualified($runDir)) { return 2 }
    if ((Inspect-Process $PID).Code -ne 0) { return 2 }
    $clock = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
      $complete = Test-Complete
      if ($complete -ne 1) { return $complete }
      $launchTime = Read-LaunchTime
      if (-not (Test-Path -LiteralPath (Join-Path $runDir 'wrapper.identity') -ErrorAction Stop)) {
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        if ($now -lt $launchTime -or $now - $launchTime -ge 30) { return 2 }
      } else {
        $identity = Read-Identity
        $wrapperPid = $identity.Pid
        $wrapperStart = $identity.Start
        $observed = Inspect-Process $wrapperPid
        if ($observed.Code -eq 2) {
          $complete = Test-Complete
          if ($complete -ne 1) { return $complete }
          return 2
        }
        if ($observed.Code -eq 1 -or $observed.Start -cne $wrapperStart) {
          $complete = Test-Complete
          if ($complete -ne 1) { return $complete }
          return 3
        }
      }
      if ($clock.Elapsed.TotalSeconds -ge $watchSeconds) { return 124 }
      Start-Sleep -Seconds 1
    }
  } catch { [Console]::Error.WriteLine($_); return 2 }
}

function Invoke-Producer {
  if ($agent -ceq 'claude') {
    $perm = if (Test-Path Env:CHILD_SESSION_CLAUDE_ARGS) { @($env:CHILD_SESSION_CLAUDE_ARGS -split '\s+' | Where-Object { $_ -ne '' }) } else { @('--permission-mode', 'bypassPermissions') }
    $vector = $lead + @('--print', '--output-format', 'stream-json', '--verbose') + $perm
    if ($sessionId) { $vector += @('--resume', $sessionId) }
    if ($model -cne 'cli-default') { $vector += @('--model', $model) }
    if ($effort -cne 'cli-default') { $vector += @('--effort', $effort) }
    $vector += @($cliArgs)
    $outName = 'events.jsonl'; $idSource = 'events.jsonl'; $idPattern = '"session_id"\s*:\s*"([^"]+)"'
  } else {
    $perm = if (Test-Path Env:CHILD_SESSION_CODEX_ARGS) { @($env:CHILD_SESSION_CODEX_ARGS -split '\s+' | Where-Object { $_ -ne '' }) } else { @('--dangerously-bypass-approvals-and-sandbox') }
    $vector = $lead + @('exec')
    if ($sessionId) { $vector += 'resume' }
    $vector += $perm
    if ($model -cne 'cli-default') { $vector += @('-c', ('model="' + $model + '"')) }
    if ($effort -cne 'cli-default') { $vector += @('-c', ('model_reasoning_effort="' + $effort + '"')) }
    if ($sessionId) { $vector += $sessionId }
    $vector += '-'
    $outName = 'stdout.log'; $idSource = 'stderr.log'; $idPattern = '^session id: (\S+)'
  }
  $psi = [Diagnostics.ProcessStartInfo]::new($exe)
  foreach ($word in $vector) { $psi.ArgumentList.Add($word) }
  $psi.WorkingDirectory = $checkout
  $psi.UseShellExecute = $false
  $psi.RedirectStandardInput = $true
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  foreach ($childVariable in @($psi.Environment.Keys)) {
    if (Test-ChildSessionParentMetadata $childVariable) {
      [void]$psi.Environment.Remove($childVariable)
    }
  }
  $outFile = $null; $errFile = $null; $process = $null
  try {
    $outFile = [IO.File]::Create((Join-Path $runDir $outName))
    $errFile = [IO.File]::Create((Join-Path $runDir 'stderr.log'))
    $process = [Diagnostics.Process]::Start($psi)
    $outCopy = $process.StandardOutput.BaseStream.CopyToAsync($outFile)
    $errCopy = $process.StandardError.BaseStream.CopyToAsync($errFile)
    $promptFile = [IO.File]::OpenRead((Join-Path $runDir 'prompt.md'))
    try { $promptFile.CopyTo($process.StandardInput.BaseStream) } finally { $promptFile.Dispose(); $process.StandardInput.Close() }
    $process.WaitForExit(); $outCopy.Wait(); $errCopy.Wait()
    $producerExit = $process.ExitCode
  } finally {
    if ($null -ne $outFile) { $outFile.Dispose() }
    if ($null -ne $errFile) { $errFile.Dispose() }
    if ($null -ne $process) { $process.Dispose() }
  }
  [IO.File]::WriteAllText((Join-Path $runDir 'producer.exit'),
    ($producerExit.ToString([Globalization.CultureInfo]::InvariantCulture) + "`n"), $utf8)
  $found = Select-String -LiteralPath (Join-Path $runDir $idSource) -Pattern $idPattern -ErrorAction Stop | Select-Object -First 1
  $recordedId = if ($found) { $found.Matches[0].Groups[1].Value } else { '' }
  if ($recordedId.Contains("`r") -or $recordedId.Contains("`n") -or $recordedId.StartsWith([string][char]0xFEFF, [StringComparison]::Ordinal)) { throw 'Malformed CLI session ID' }
  [IO.File]::WriteAllText((Join-Path $runDir 'session.id'), ($recordedId + "`n"), $utf8)
  [IO.File]::WriteAllText((Join-Path $runDir 'wrapper.done.tmp'), "complete`n", $utf8)
  [IO.File]::Move((Join-Path $runDir 'wrapper.done.tmp'), (Join-Path $runDir 'wrapper.done'))
}

function Invoke-Background([string[]]$Words) {
  if (-not $IsWindows) { throw 'Use the Bash background helper on POSIX' }
  $action = $Words[0]
  $allowed = switch -CaseSensitive ($action) {
    prepare { @('--run-dir','--prompt') }
    run { @('--run-dir','--checkout','--agent','--model','--effort','--resume','--cli-arg') }
    wait { @('--run-dir','--seconds') }
    default { throw 'Expected prepare, run or wait' }
  }
  $options = @{}; $cliArgs = @()
  for ($i = 1; $i -lt $Words.Count; $i += 2) {
    $key = $Words[$i]
    if ($key -cnotin $allowed) { throw "Unknown $action option: $key" }
    if ($i + 1 -ge $Words.Count -or -not $Words[$i+1]) { throw "Missing value for $key" }
    if ($key -ceq '--cli-arg') { $cliArgs += $Words[$i+1]; continue }
    if ($options.ContainsKey($key)) { throw "Duplicate option: $key" }
    $options[$key] = $Words[$i+1]
  }
  $runDir = $options['--run-dir']
  if (-not $runDir -or -not [IO.Path]::IsPathFullyQualified($runDir)) { throw '--run-dir requires an absolute directory path' }
  if ($action -ceq 'prepare') {
    $prompt = $options['--prompt']
    if (-not $prompt -or -not [IO.Path]::IsPathFullyQualified($prompt) -or -not [IO.File]::Exists($prompt)) { throw '--prompt requires an absolute file path' }
    # Directory.Move claims a new name atomically; CreateDirectory alone can reopen an existing run.
    $temporary = Join-Path ([IO.Path]::GetDirectoryName($runDir)) ([Guid]::NewGuid().ToString())
    [void][IO.Directory]::CreateDirectory($temporary)
    try { [IO.Directory]::Move($temporary, $runDir) } finally { if ([IO.Directory]::Exists($temporary)) { [IO.Directory]::Delete($temporary) } }
    [IO.File]::Copy($prompt, (Join-Path $runDir 'prompt.md'))
    if ((Inspect-Process $PID).Code -ne 0) { throw 'Process inspection unavailable' }
    $epoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString([Globalization.CultureInfo]::InvariantCulture)
    [IO.File]::WriteAllText((Join-Path $runDir 'launch.time'), ($epoch + "`n"), $utf8)
    return 0
  }
  $dir = Get-Item -LiteralPath $runDir -ErrorAction Stop
  if (-not $dir.PSIsContainer -or ($dir.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Owned run directory unavailable' }
  if ($action -ceq 'wait') {
    $watchSeconds = $options['--seconds'] ?? '60'
    if ($watchSeconds -cnotmatch '\A([1-9]|[1-5][0-9]|60)\z') { throw '--seconds must be in 1..60' }
    $watchSeconds = [int]$watchSeconds
    return (Watch-Main)
  }

  $checkout = $options['--checkout']
  if (-not $checkout -or -not [IO.Path]::IsPathFullyQualified($checkout) -or -not [IO.Directory]::Exists($checkout)) { throw '--checkout requires an absolute directory path' }
  $agent, $command = $options['--agent'] -csplit ':', 2
  if ($agent -cnotin @('claude','codex')) { throw '--agent requires claude or codex, optionally SYSTEM:COMMAND' }
  $command = $command ?? $agent
  if ($command -cnotmatch '\A[A-Za-z0-9._/\\:+-]+\z') { throw 'Invalid launch command' }
  if ($command -match '[/\\]' -and -not [IO.Path]::IsPathFullyQualified($command)) { $command = Join-Path $checkout $command }
  if ($agent -ceq 'codex' -and $cliArgs.Count) { throw 'Codex takes no --cli-arg' }
  $launch = Resolve-ChildSessionAgent $command
  if (-not $launch.executable) { throw 'Native executable or installed npm shim required for background' }
  $exe = $launch.executable; $lead = @($launch.prefix)
  $model = $options['--model'] ?? 'cli-default'; $effort = $options['--effort'] ?? 'cli-default'; $sessionId = $options['--resume']
  $null = Read-LaunchTime
  $promptPath = Join-Path $runDir 'prompt.md'
  if (-not [IO.File]::Exists($promptPath) -or ([IO.File]::GetAttributes($promptPath) -band [IO.FileAttributes]::ReparsePoint)) { throw 'Prepared prompt unavailable' }
  # The claim survives the process. Neither a failed nor an active run may be reused.
  [IO.File]::Open((Join-Path $runDir 'run.claim'), [IO.FileMode]::CreateNew).Dispose()
  foreach ($name in @('wrapper.identity','wrapper.identity.tmp','wrapper.done','wrapper.done.tmp','producer.exit','session.id','stderr.log','stdout.log','events.jsonl')) {
    if (Test-Path -LiteralPath (Join-Path $runDir $name)) { throw "Run directory has prior output: $name" }
  }
  $wrapper = Inspect-Process $PID
  if ($wrapper.Code -ne 0) { throw 'Wrapper process identity unavailable' }
  $identity = $PID.ToString([Globalization.CultureInfo]::InvariantCulture) + "`n" + $wrapper.Start + "`n"
  [IO.File]::WriteAllText((Join-Path $runDir 'wrapper.identity.tmp'), $identity, $utf8)
  [IO.File]::Move((Join-Path $runDir 'wrapper.identity.tmp'), (Join-Path $runDir 'wrapper.identity'))
  Invoke-Producer
  return 0
}
if ($MyInvocation.InvocationName -eq '.') { return }
try { exit (Invoke-Background ([string[]]$args)) }
catch { [Console]::Error.WriteLine("background: $_"); exit 2 }
