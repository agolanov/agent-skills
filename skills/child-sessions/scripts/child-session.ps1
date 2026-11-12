# Native Windows lifecycle helper. Dot-source to call Invoke-ChildSessionDispatch
# with a literal string array; direct -File calls use the same grammar.
$script:ChildSessionOwner=$PSCommandPath
$script:Utf8=New-Object Text.UTF8Encoding($false,$true)
# Screens, status files and logs: an invalid byte reads as U+FFFD instead of failing.
$script:Utf8Lenient=New-Object Text.UTF8Encoding($false,$false)
function Test-ChildSessionParentMetadata {
    param([string]$Name)
    # Windows environment names are case-insensitive; preserve all other names.
    return $Name -in @(
        'CLAUDECODE',
        'CLAUDE_CODE_SESSION_ID',
        'CLAUDE_CODE_CHILD_SESSION',
        'CLAUDE_CODE_MESSAGING_SOCKET',
        'CLAUDE_CODE_MESSAGING_TOKEN',
        'CLAUDE_EFFORT',
        'CODEX_THREAD_ID',
        'CODEX_COMPANION_SESSION_ID',
        'CODEX_COMPANION_TRANSCRIPT_PATH',
        'CODEX_SESSION_ID',
        'CODEX_TOOL_CALL_ID',
        'CLAUDE_PID',
        'CLAUDE_CODE_SESSION_ATTENDED',
        'CLAUDE_CODE_ENTRYPOINT'
    )
}
function Get-ChildSessionProcessStart {
    param([int]$ProcessId)
    try { $p=Get-Process -Id $ProcessId -ErrorAction Stop }
    catch {
        if ($_.CategoryInfo.Category -eq [Management.Automation.ErrorCategory]::ObjectNotFound) { return $null }
        throw
    }
    if (-not $p.HasExited) { return $p.StartTime.ToUniversalTime().Ticks.ToString() }
}
function Stop-ChildSessionProcess {
    param($Identity)
    $now=Get-ChildSessionProcessStart ([int]$Identity.pid)
    if (-not $now) { return }
    if (-not $Identity.start -or $now -cne $Identity.start) { throw 'PID/start mismatch; process preserved.' }
    # Recheck on the actual Process object immediately before stopping it.
    $p=Get-Process -Id ([int]$Identity.pid) -ErrorAction Stop
    if ($p.StartTime.ToUniversalTime().Ticks.ToString() -cne $Identity.start) { throw 'PID/start mismatch; process preserved.' }
    try { $p.Kill() } catch { $p.Refresh(); if (-not $p.HasExited) { throw } }
    $p.WaitForExit(10000) | Out-Null
    if (-not $p.HasExited) { throw 'Owned process still running; session preserved.' }
}
function Get-ChildSessionDescendants {
    param($Identity)
    # Parent links come from one snapshot. A descendant must have started after
    # its parent and before the snapshot (or before the recorded exit of a
    # parent that is gone), so a reused PID never joins the tree.
    $snapshot=[DateTime]::UtcNow.Ticks
    $children=@{}
    foreach ($p in @(Get-CimInstance Win32_Process -Property ProcessId,ParentProcessId -ErrorAction Stop)) {
        $parent=[int]$p.ParentProcessId;$id=[int]$p.ProcessId
        if ($id -eq $parent) { continue }
        if (-not $children.ContainsKey($parent)) { $children[$parent]=New-Object Collections.Generic.List[int] }
        $children[$parent].Add($id)
    }
    $now=Get-ChildSessionProcessStart ([int]$Identity.pid)
    if ($now -and $now -cne $Identity.start) { throw 'PID/start mismatch; process preserved.' }
    if ($now) { $limit=$snapshot } elseif ($Identity.exit) { $limit=[long]$Identity.exit } else { return @() }
    $found=New-Object Collections.Generic.List[object]
    $queue=New-Object Collections.Generic.Queue[object]
    $queue.Enqueue(@{pid=[int]$Identity.pid;start=[long]$Identity.start;limit=$limit})
    while ($queue.Count) {
        $node=$queue.Dequeue()
        if (-not $children.ContainsKey($node.pid)) { continue }
        foreach ($id in $children[$node.pid]) {
            $start=Get-ChildSessionProcessStart $id
            if (-not $start -or [long]$start -lt $node.start -or [long]$start -gt $node.limit) { continue }
            $found.Add(@{pid=$id;start=$start})
            $queue.Enqueue(@{pid=$id;start=[long]$start;limit=$snapshot})
        }
    }
    return $found.ToArray()
}
function Stop-ChildSessionTree {
    param($Identity)
    # Stop the recorded process, then each verified descendant it left behind.
    $tree=@(Get-ChildSessionDescendants $Identity)
    Stop-ChildSessionProcess $Identity
    foreach ($id in $tree) { Stop-ChildSessionProcess $id }
}
function ConvertTo-ChildSessionNativeArgument {
    param([AllowEmptyString()][string]$Value)
    # Windows CommandLineToArgvW convention for ProcessStartInfo on Windows PS 5.1.
    $quoted='"'; $slashes=0
    foreach ($c in $Value.ToCharArray()) {
        if ($c -eq '\') { $slashes++; continue }
        if ($c -eq '"') { $quoted+=('\' * ($slashes*2+1))+'"' }
        else { $quoted+=('\' * $slashes)+$c }
        $slashes=0
    }
    return $quoted+('\' * ($slashes*2))+'"'
}
function ConvertTo-ChildSessionPowerShellLiteral {
    param([AllowEmptyString()][string]$Value)
    # The PowerShell tokenizer also recognizes typographic single quotes.
    return "'"+[Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($Value)+"'"
}
function Start-ChildSessionProcess {
    param([string]$Executable,[string[]]$Vector,[string]$Cwd,[bool]$Capture=$false)
    $info=New-Object Diagnostics.ProcessStartInfo
    $info.FileName=$Executable; $info.WorkingDirectory=$Cwd
    $info.UseShellExecute=$false; $info.CreateNoWindow=$Capture
    if ($info.PSObject.Properties.Name -contains 'ArgumentList') {
        foreach ($argument in $Vector) { $info.ArgumentList.Add($argument) }
    } else { $info.Arguments=(@($Vector | ForEach-Object { ConvertTo-ChildSessionNativeArgument $_ }) -join ' ') }
    $info.RedirectStandardOutput=$Capture; $info.RedirectStandardError=$Capture
    return [Diagnostics.Process]::Start($info)
}
function Invoke-ChildSessionNative {
    param([string]$Executable,[string[]]$Vector,[string]$Cwd)
    $p=Start-ChildSessionProcess $Executable $Vector $Cwd $true
    $stdout=New-Object IO.MemoryStream; $stderr=New-Object IO.MemoryStream
    try {
        $outTask=$p.StandardOutput.BaseStream.CopyToAsync($stdout)
        $errTask=$p.StandardError.BaseStream.CopyToAsync($stderr)
        $p.WaitForExit(); [void]$outTask.GetAwaiter().GetResult(); [void]$errTask.GetAwaiter().GetResult()
        return [pscustomobject]@{Stdout=$stdout.ToArray();Stderr=$stderr.ToArray();ExitCode=$p.ExitCode}
    } finally { $p.Dispose();$stdout.Dispose();$stderr.Dispose() }
}
function Get-ChildSessionRuntime {
    if ($env:CHILD_SESSION_RUNTIME_DIR) { $root=$env:CHILD_SESSION_RUNTIME_DIR }
    else { $root=Join-Path ([IO.Path]::GetTempPath()) 'child-sessions' }
    if (-not [IO.Path]::IsPathRooted($root)) { throw 'Runtime directory must be absolute.' }
    $root=[IO.Path]::GetFullPath($root).TrimEnd('\')
    $at=$root
    while ($at) {
        if ([IO.Path]::GetFileName($at) -ieq '.git' -or (Test-Path -LiteralPath (Join-Path $at '.git'))) { throw 'Runtime must be outside checkout/Git administration.' }
        $parent=[IO.Path]::GetDirectoryName($at);if ($parent -eq $at) { break };$at=$parent
    }
    [IO.Directory]::CreateDirectory($root) | Out-Null
    $script:Runtime=$root; return $root
}
function Read-ChildSessionRecord {
    param([string]$Name)
    if ($Name -cnotmatch '^[A-Za-z0-9_-]+$') { throw 'Window names must match [A-Za-z0-9_-]+' }
    $path=Join-Path $script:Runtime ($Name+'.json')
    if (-not [IO.File]::Exists($path)) { return $null }
    # Readers must permit the launcher's atomic replacement of this record.
    $reader=[IO.StreamReader]::new([IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)),$script:Utf8)
    try { $r=ConvertFrom-Json ($reader.ReadToEnd()) } finally { $reader.Dispose() }
    if ($r.name -cne $Name -or -not $r.launch_id -or $r.runtime -cne $script:Runtime) { throw 'Owned launch record mismatch.' }
    return $r
}
function Write-ChildSessionRecord {
    param($Record)
    $path=Join-Path $script:Runtime ($Record.name+'.json')
    $temp=Join-Path $script:Runtime ((Get-ChildSessionNamePart $Record.name)+'.json.'+[Guid]::NewGuid().ToString('N'))
    [IO.File]::WriteAllText($temp,(ConvertTo-Json -InputObject $Record -Depth 12 -Compress),$script:Utf8)
    if ([IO.File]::Exists($path)) { [IO.File]::Replace($temp,$path,[NullString]::Value) }
    else { [IO.File]::Move($temp,$path) }
}
function Test-ChildSessionAlive {
    param($Record,[switch]$Control)
    if (-not $Record -or $Record.closed -or $Record.phase -eq 'exited') { return $false }
    if ($Record.phase -ne 'running') { return $false }
    # The agent may outlive its launcher; input also needs the launcher.
    $ids=@($Record.agent);if ($Control) { $ids+=$Record.launcher }
    foreach ($id in $ids) {
        if (-not $id -or -not $id.pid -or -not $id.start) { throw 'Process identity inconclusive; liveness unknown and session preserved.' }
        if ((Get-ChildSessionProcessStart ([int]$id.pid)) -cne $id.start) { return $false }
    }
    return $true
}
function Find-ChildSessionHerdrCaller {
    param([string]$Herdr)
    $script:HerdrWorkspace=$env:HERDR_WORKSPACE_ID
    $script:HerdrPane=$env:HERDR_PANE_ID
    $caller=$env:CODEX_THREAD_ID;$agent='codex'
    if (-not $caller) { $caller=$env:CLAUDE_CODE_SESSION_ID;$agent='claude' }
    if ($caller) {
        $result=Invoke-ChildSessionNative $Herdr @('agent','list') $script:Runtime
        if ($result.ExitCode -ne 0) { return $false }
        $rows=(ConvertFrom-Json ($script:Utf8.GetString($result.Stdout))).result.agents
        $matches=@($rows | Where-Object { $_.agent_session.agent -ceq $agent -and $_.agent_session.kind -ceq 'id' -and $_.agent_session.value -ceq $caller })
        if ($matches.Count -ne 1) { return $false }
        foreach ($value in @($matches[0].workspace_id,$matches[0].pane_id,$matches[0].tab_id)) {
            if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value) -or $value -match '\s') { return $false }
        }
        $script:HerdrWorkspace=$matches[0].workspace_id;$script:HerdrPane=$matches[0].pane_id
    }
    if (-not $script:HerdrWorkspace -or -not $script:HerdrPane) { return $false }
    $result=Invoke-ChildSessionNative $Herdr @('pane','list','--workspace',$script:HerdrWorkspace) $script:Runtime
    if ($result.ExitCode -ne 0) { return $false }
    $panes=(ConvertFrom-Json ($script:Utf8.GetString($result.Stdout))).result.panes
    if (@($panes | Where-Object { $_.pane_id -ceq $script:HerdrPane }).Count -ne 1) { return $false }
    if ($script:HerdrWorkspace -cne $env:HERDR_WORKSPACE_ID -or $script:HerdrPane -cne $env:HERDR_PANE_ID) {
        [Console]::Error.WriteLine('child-session: recovered current '+$agent+' caller in herdr workspace '+$script:HerdrWorkspace+', pane '+$script:HerdrPane)
    }
    return $true
}
function Get-ChildSessionBackend {
    $backend=$env:CHILD_SESSION_BACKEND
    if (-not $backend) { if ($env:HERDR_ENV -eq '1') { $backend='herdr' } else { $backend='terminal' } }
    if ($backend -notin @('herdr','terminal')) { throw 'Native Windows backend must be herdr or terminal; tmux is a separate optional WSL environment.' }
    if ($backend -eq 'herdr') {
        $connected=$false
        try { $herdr=(Get-Command herdr.exe -ErrorAction Stop).Source;$connected=Find-ChildSessionHerdrCaller $herdr }
        catch { [Console]::Error.WriteLine('child-session: herdr caller lookup unavailable: '+$_.Exception.Message) }
        if ($connected) { $script:Herdr=$herdr }
        elseif ($env:CHILD_SESSION_BACKEND) { throw 'Explicit herdr requires a proven unique caller connection; no focused-pane substitution.' }
        else { $backend='terminal';[Console]::Error.WriteLine('child-session: no proven herdr caller connection; using terminal') }
    }
    if ($backend -eq 'terminal') {
        $script:Terminal=(Get-Command wt.exe -ErrorAction Stop).Source
        # Windows Terminal receives only fixed native bootstrap tokens below.
    }
    return $backend
}
function Resolve-ChildSessionAgent {
    param([string]$Agent)
    $command=Get-Command ($Agent+'.exe') -ErrorAction SilentlyContinue
    if (-not $command) { $command=Get-Command $Agent -ErrorAction Stop }
    $path=$command.Source
    if ($command.CommandType -eq 'Application' -and [IO.Path]::GetExtension($path) -ieq '.exe') { return @{executable=$path;prefix=@()} }
    if ([IO.Path]::GetExtension($path) -iin @('.cmd','.bat')) {
        $sibling=[IO.Path]::ChangeExtension($path,'.ps1')
        if (-not [IO.File]::Exists($sibling)) { throw 'Installed command shim has no verified executable or PowerShell sibling; native quoting path unavailable.' }
        $path=$sibling
    }
    if ([IO.Path]::GetExtension($path) -ieq '.ps1') {
        # PowerShell scripts consume an in-process typed array through an encoded
        # bootstrap. Native npm shims need explicit target resolution because 5.1
        # script-to-native forwarding cannot preserve every quoted argument.
        $text=[IO.File]::ReadAllText($path)
        if ($text -match 'node_modules[/\\]') {
            $matches=[regex]::Matches($text,'\$basedir[/\\]([^"\r\n]+\.js)')
            $targets=@($matches | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
            if ($targets.Count -ne 1) { throw 'Installed npm shim target is ambiguous.' }
            $target=[IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetDirectoryName($path)) $targets[0]))
            $node=Join-Path ([IO.Path]::GetDirectoryName($path)) 'node.exe'
            if (-not [IO.File]::Exists($node)) { $node=(Get-Command node.exe -ErrorAction Stop).Source }
            if (-not [IO.File]::Exists($target)) { throw 'Installed npm shim executable target missing.' }
            return @{executable=$node;prefix=@($target)}
        }
        return @{script=$path}
    }
    throw 'Installed agent command has no verified native executable/shim path.'
}
function Get-ChildSessionCapabilities {
    param($Record)
    $controls=$Record.backend -eq 'herdr'
    return [ordered]@{backend=$Record.backend;launch_id=$Record.launch_id;checkout=$Record.checkout;open=$true;alive=$true;wait=$true;close=$true;list=$true;peek=$controls;send=$controls;key=$controls;split=$controls;window_close=$false}
}
function Assert-ChildSessionPane {
    param($Record)
    if ($Record.backend -ne 'herdr') { throw 'Screen/input control unavailable; use the visible terminal directly.' }
    $script:Herdr=(Get-Command herdr.exe -ErrorAction Stop).Source
    $result=Invoke-ChildSessionNative $script:Herdr @('pane','list','--workspace',$Record.workspace) $script:Runtime
    if ($result.ExitCode -ne 0) { throw 'Recorded herdr workspace unavailable.' }
    $panes=ConvertFrom-Json ($script:Utf8.GetString($result.Stdout))
    $pane=@($panes.result.panes | Where-Object { $_.pane_id -ceq $Record.pane -and $_.tab_id -ceq $Record.window })
    if ($pane.Count -ne 1) { throw 'Recorded pane identity mismatch; control refused.' }
}
function Start-ChildSession {
    param([string[]]$Vector)
    $agent=$env:CHILD_SESSION_AGENT; if (-not $agent) { $agent='claude' }
    $model='';$effort='';$split='';$i=0
    while ($i -lt $Vector.Count -and $Vector[$i].StartsWith('--') -and $Vector[$i] -ne '--') {
        if ($i+1 -ge $Vector.Count -or $Vector[$i+1] -eq '') { throw 'Open option requires a value.' }
        switch -CaseSensitive ($Vector[$i]) {
            '--agent' { $agent=$Vector[$i+1] }
            '--model' { $model=$Vector[$i+1] }
            '--effort' { $effort=$Vector[$i+1] }
            '--split' { $split=$Vector[$i+1]; if ($split -notin @('right','down')) { throw '--split must be right or down' } }
            default { throw ('Unknown option '+$Vector[$i]) }
        }; $i+=2
    }
    if ($i -lt $Vector.Count -and $Vector[$i] -eq '--') { $i++ }
    if ($Vector.Count-$i -ne 3) { throw 'open requires NAME CWD BRIEF' }
    $name=$Vector[$i];$cwd=[IO.Path]::GetFullPath($Vector[$i+1]);$brief=[IO.Path]::GetFullPath($Vector[$i+2])
    if ($name -notmatch '^[A-Za-z0-9_-]+$') { throw 'Window names must match [A-Za-z0-9_-]+' }
    if ($agent -cnotin @('claude','codex')) { throw '--agent must be claude or codex' }
    if ($script:Runtime -ieq $cwd -or $script:Runtime.StartsWith($cwd.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Runtime must be outside checkout.' }
    if (-not [IO.Directory]::Exists($cwd) -or -not [IO.File]::Exists($brief)) { throw 'Checkout/brief unavailable.' }
    $backend=Get-ChildSessionBackend
    $existing=Read-ChildSessionRecord $name
    if ($existing -and -not $existing.closed) { throw 'Window already exists.' }
    $resolved=Resolve-ChildSessionAgent $agent
    $cli=New-Object Collections.Generic.List[string]
    if ($agent -eq 'claude') {
        if (Test-Path Env:CHILD_SESSION_CLAUDE_ARGS) { foreach ($word in ($env:CHILD_SESSION_CLAUDE_ARGS -split '\s+' | Where-Object { $_ -ne '' })) { $cli.Add($word) } }
        else { $cli.Add('--permission-mode');$cli.Add('bypassPermissions') }
        if ($model) { $cli.Add('--model');$cli.Add($model) }; if ($effort) { $cli.Add('--effort');$cli.Add($effort) }
    } else {
        if (Test-Path Env:CHILD_SESSION_CODEX_ARGS) { foreach ($word in ($env:CHILD_SESSION_CODEX_ARGS -split '\s+' | Where-Object { $_ -ne '' })) { $cli.Add($word) } }
        else { $cli.Add('--dangerously-bypass-approvals-and-sandbox') }
        if ($model) { $cli.Add('-m');$cli.Add($model) }; if ($effort) { $cli.Add('-c');$cli.Add('model_reasoning_effort='+$effort) }
    }
    $cli.Add('Read the brief at '+$brief+' completely and carry it out.')
    $launch=[Guid]::NewGuid().ToString('N')+[Guid]::NewGuid().ToString('N')
    $r=[pscustomobject]@{name=$name;backend=$backend;launch_id=$launch;runtime=$script:Runtime;checkout=$cwd;workspace=$script:HerdrWorkspace;window='';pane='';launcher=$null;agent=$null;phase='starting';exit_code=$null;closed=$false;dialog_counts='not observable'}
    $r | Add-Member -NotePropertyName supported_operations -NotePropertyValue (Get-ChildSessionCapabilities $r)
    $environment=@{}
    foreach ($entry in [Environment]::GetEnvironmentVariables().GetEnumerator()) {
        if (Test-ChildSessionParentMetadata $entry.Key) { continue }
        $environment[$entry.Key]=$entry.Value
    }
    $transport=Join-Path $script:Runtime ($name+'-'+$launch+'.transport.json')
    $request=@{owner=$script:ChildSessionOwner;runtime=$script:Runtime;name=$name;launch_id=$launch;cwd=$cwd;environment=$environment;resolved=$resolved;arguments=$cli.ToArray();power=(Get-Process -Id $PID).Path}
    [IO.File]::WriteAllText($transport,(ConvertTo-Json -InputObject $request -Depth 12 -Compress),$script:Utf8)
    Write-ChildSessionRecord $r
    # All caller strings are inside the owned JSON; wt parses only a fixed native
    # executable and base64 bootstrap. No arbitrary path reaches its ';' parser.
    $bootstrap='. '+(ConvertTo-ChildSessionPowerShellLiteral $script:ChildSessionOwner)+'; Invoke-ChildSessionLauncher '+(ConvertTo-ChildSessionPowerShellLiteral $transport)
    $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($bootstrap))
    $power=(Get-Process -Id $PID).Path
    if ($backend -eq 'terminal') {
        if ($split) { [Console]::Error.WriteLine('child-session: --split needs herdr; opening a plain terminal tab') }
        $result=Invoke-ChildSessionNative $script:Terminal @('new-tab',$power,'-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded) $script:Runtime
        if ($result.ExitCode -ne 0) { throw 'Installed Windows Terminal visible launch failed; owned starting record retained.' }
        [Console]::Error.WriteLine('child-session: questions/dialogs in the visible window need your direct attention; screen/input controls unavailable. Dialog counts: not observable.')
    } else {
        $direction=''
        if ($split) {
            $listed=Invoke-ChildSessionNative $script:Herdr @('pane','list','--workspace',$r.workspace) $script:Runtime
            $panes=(ConvertFrom-Json ($script:Utf8.GetString($listed.Stdout))).result.panes
            $parent=@($panes | Where-Object { $_.pane_id -ceq $script:HerdrPane })[0]
            if (@($panes | Where-Object { $_.tab_id -ceq $parent.tab_id }).Count -eq 1) { $direction=$split }
            else { [Console]::Error.WriteLine('child-session: opener tab already has another pane; opening a tab') }
        }
        if ($direction) {
            $created=Invoke-ChildSessionNative $script:Herdr @('pane','split',$script:HerdrPane,'--direction',$direction,'--cwd',$cwd,'--no-focus') $script:Runtime
            $data=ConvertFrom-Json ($script:Utf8.GetString($created.Stdout));$r.pane=$data.result.pane.pane_id;$r.window=$parent.tab_id
        } else {
            $created=Invoke-ChildSessionNative $script:Herdr @('tab','create','--workspace',$r.workspace,'--cwd',$cwd,'--label',$name,'--no-focus') $script:Runtime
            $data=ConvertFrom-Json ($script:Utf8.GetString($created.Stdout));$r.pane=$data.result.root_pane.pane_id;$r.window=$data.result.tab.tab_id
        }
        if ($created.ExitCode -ne 0 -or -not $r.pane) { throw 'Native herdr did not create a proven owned pane.' }
        $environment['HERDR_ENV']='1';$environment['HERDR_WORKSPACE_ID']=$r.workspace
        $environment['HERDR_PANE_ID']=$r.pane;$environment['HERDR_TAB_ID']=$r.window
        [IO.File]::WriteAllText($transport,(ConvertTo-Json -InputObject $request -Depth 12 -Compress),$script:Utf8)
        Write-ChildSessionRecord $r
        $ready=$false
        for ($n=0;$n -lt 30;$n++) {
            $null=Invoke-ChildSessionNative $script:Herdr @('pane','run',$r.pane,'Write-Output ("child-session-ready-" + (6*7))') $script:Runtime
            $seen=Invoke-ChildSessionNative $script:Herdr @('pane','wait-output',$r.pane,'--match','child-session-ready-42','--timeout','2000') $script:Runtime
            if ($seen.ExitCode -eq 0) { $ready=$true;break }
        }
        if (-not $ready) { throw 'Native herdr shell readiness unavailable; owned pane preserved.' }
        $command='& '+(ConvertTo-ChildSessionPowerShellLiteral $power)+' -NoProfile -ExecutionPolicy Bypass -EncodedCommand '+$encoded
        $sent=Invoke-ChildSessionNative $script:Herdr @('pane','run',$r.pane,$command) $script:Runtime
        if ($sent.ExitCode -ne 0) { throw 'Native herdr owned launch failed.' }
    }
    for ($n=0;$n -lt 100;$n++) { if ((Read-ChildSessionRecord $name).phase -ne 'starting') { break }; Start-Sleep -Milliseconds 100 }
}
function Invoke-ChildSessionLauncher {
    param([string]$Transport)
    $ErrorActionPreference='Stop'
    try {
        $request=ConvertFrom-Json ([IO.File]::ReadAllText($Transport,$script:Utf8))
        $env:CHILD_SESSION_RUNTIME_DIR=$request.runtime
        $null=Get-ChildSessionRuntime
        $r=Read-ChildSessionRecord $request.name
        if ($r.launch_id -cne $request.launch_id -or $r.checkout -cne $request.cwd -or $r.phase -ne 'starting') { throw 'Launcher identity mismatch.' }
        foreach ($entry in [Environment]::GetEnvironmentVariables().GetEnumerator()) { Remove-Item -LiteralPath ('Env:'+$entry.Key) -ErrorAction SilentlyContinue }
        foreach ($entry in $request.environment.psobject.Properties) { [Environment]::SetEnvironmentVariable($entry.Name,[string]$entry.Value,'Process') }
        foreach ($entry in [Environment]::GetEnvironmentVariables().GetEnumerator()) {
            if (Test-ChildSessionParentMetadata $entry.Key) { Remove-Item -LiteralPath ('Env:'+$entry.Key) -ErrorAction SilentlyContinue }
        }
        [IO.File]::Delete($Transport)
        Set-Location -LiteralPath $request.cwd
        $r.launcher=@{pid=$PID;start=(Get-ChildSessionProcessStart $PID)}
        if ($request.resolved.script) {
            $cliJson=ConvertTo-Json -InputObject ([string[]]@($request.arguments)) -Compress
            $code='$v=ConvertFrom-Json '+(ConvertTo-ChildSessionPowerShellLiteral $cliJson)+'; & '+(ConvertTo-ChildSessionPowerShellLiteral $request.resolved.script)+' @v; if ($null -ne $LASTEXITCODE) { exit $LASTEXITCODE }; if (-not $?) { exit 1 }'
            $process=Start-ChildSessionProcess $request.power @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code))) $request.cwd
        } else {
            $vector=@($request.resolved.prefix)+@($request.arguments)
            $process=Start-ChildSessionProcess $request.resolved.executable ([string[]]$vector) $request.cwd
        }
        $r.agent=@{pid=$process.Id;start=(Get-ChildSessionProcessStart $process.Id)};$r.phase='running';Write-ChildSessionRecord $r
        $process.WaitForExit();$r.agent.exit=$process.ExitTime.ToUniversalTime().Ticks.ToString();$r.phase='exited';$r.exit_code=$process.ExitCode;Write-ChildSessionRecord $r
        exit $process.ExitCode
    } catch { [Console]::Error.WriteLine('child-session launcher: '+($_ | Out-String)); exit 2 }
}
# Set watcher (wait --watch) and wake, with the same grammar, files and exits as
# the POSIX entrypoint; herdr is the only stall and caller backend here. The watch
# object carries the parsed set and the run state (claims, record), so wait --watch
# and wake-run run the same pieces. Comparisons of screens, claims and input lines
# are ordinal: PowerShell's -ceq ignores characters such as NUL.
function Get-ChildSessionClock {
    return [Diagnostics.Stopwatch]::GetTimestamp()/[double][Diagnostics.Stopwatch]::Frequency
}
function Read-ChildSessionFirstLine {
    param([string]$Path)
    # Null when the file is missing or unreadable; a concurrent replacement is allowed.
    try {
        $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        try { $text=(New-Object IO.StreamReader($stream,$script:Utf8Lenient)).ReadToEnd() } finally { $stream.Dispose() }
    } catch { return $null }
    $end=$text.IndexOf([char]10);if ($end -ge 0) { $text=$text.Substring(0,$end) }
    if ($text.Length -gt 0 -and [int]$text[$text.Length-1] -eq 13) { $text=$text.Substring(0,$text.Length-1) }
    return $text
}
function Test-ChildSessionPathPresent { param([string]$Path) return ([IO.File]::Exists($Path) -or [IO.Directory]::Exists($Path)) }
function Remove-ChildSessionFile { param([string]$Path) try { [IO.File]::Delete($Path) } catch { } }
function Save-ChildSessionFile {
    param([string]$Path,[string]$Temporary,[string]$Text)
    # Atomic replacement through a temporary file in the same directory (UTF-8, no BOM).
    try {
        [IO.File]::WriteAllText($Temporary,$Text,$script:Utf8)
        if ([IO.File]::Exists($Path)) { [IO.File]::Replace($Temporary,$Path,[NullString]::Value) } else { [IO.File]::Move($Temporary,$Path) }
        return $true
    } catch { Remove-ChildSessionFile $Temporary;return $false }
}
function Read-ChildSessionWatchArguments {
    param([AllowEmptyCollection()][string[]]$Vector,[string]$Command='wait --watch')
    # [--stall SECONDS] [--rearm NAME]... <name> <status-file> [<name> <status-file>]...
    # [seconds]: after the options, an odd count makes the last argument the deadline.
    if ($null -eq $Vector) { $Vector=@() }
    $names=New-Object Collections.Generic.List[string];$files=New-Object Collections.Generic.List[string]
    $rearm=New-Object Collections.Generic.List[string];$indexes=New-Object Collections.Generic.List[int]
    $seconds=43200;$stall=180;$stallGiven=$false;$i=0
    while ($i -lt $Vector.Count -and ([string]$Vector[$i]).StartsWith('--',[StringComparison]::Ordinal)) {
        if ($i+1 -ge $Vector.Count) { throw ($Vector[$i]+': a value is required') }
        $option=$Vector[$i];$value=$Vector[$i+1];$number=0
        if ($option -ceq '--stall') {
            if ($stallGiven) { throw '--stall is given twice' }
            if ($value -cnotmatch '\A[0-9]+\z' -or -not [int]::TryParse($value,[ref]$number) -or $number -le 0) { throw '--stall must be a positive integer' }
            $stall=$number;$stallGiven=$true
        } elseif ($option -ceq '--rearm') {
            if ($value -cnotmatch '\A[A-Za-z0-9_-]+\z') { throw 'Window names must match [A-Za-z0-9_-]+' }
            $rearm.Add($value)
        } else { throw ('unknown option '+$option) }
        $i+=2
    }
    $end=$Vector.Count
    if ($end-$i -lt 2) { throw ($Command+' needs at least one <name> <status-file> pair') }
    if (($end-$i) % 2) {
        $end--
        if ($Vector[$end] -cnotmatch '\A[0-9]+\z' -or -not [int]::TryParse($Vector[$end],[ref]$seconds)) { throw 'wait seconds must be a nonnegative integer' }
    }
    for (;$i -lt $end;$i+=2) {
        $name=[string]$Vector[$i];$file=[string]$Vector[$i+1]
        # An option after the set is no launch name.
        if ($name.StartsWith('-',[StringComparison]::Ordinal)) { throw ($name+' is not a launch name: options come before the watched launches') }
        if ($name -cnotmatch '\A[A-Za-z0-9_-]+\z') { throw 'Window names must match [A-Za-z0-9_-]+' }
        if ($names.Contains($name)) { throw ('launch '+$name+' is watched twice') }
        # The record keeps one line per key.
        if (-not $file -or $file.IndexOf([char]10) -ge 0 -or $file.IndexOf([char]13) -ge 0) { throw 'a watched status file must be a nonempty one-line path' }
        $names.Add($name);$files.Add($file);$indexes.Add($i+1)
    }
    foreach ($name in $rearm) { if (-not $names.Contains($name)) { throw ('--rearm '+$name+' names no watched launch') } }
    return [pscustomobject]@{Command=$Command;Names=$names.ToArray();Files=$files.ToArray();Rearm=$rearm.ToArray();Seconds=$seconds;Stall=$stall;FileIndexes=$indexes.ToArray()
        Launch='';StatusFile='';Line='';ClaimText='';ClaimError='';Claimed=(New-Object Collections.Generic.List[string]);Recording=$false;Written=$false;Text=''}
}
# Claim <runtime>/<name>.watcher holds "<pid> <start ticks>".
function Test-ChildSessionClaimLive {
    param([string]$Text)
    # Live while that PID keeps that start; unavailable evidence never frees a claim that may be live.
    if (-not $Text) { return $false }
    $space=$Text.IndexOf([char]32)
    if ($space -lt 1) { return $false }
    $id=$Text.Substring(0,$space);$identity=$Text.Substring($space+1);$number=0
    if ($id -cnotmatch '\A[0-9]+\z' -or -not $identity -or -not [int]::TryParse($id,[ref]$number) -or $number -le 0) { return $false }
    try { $now=Get-ChildSessionProcessStart $number } catch { return $true }
    return [string]::Equals([string]$now,$identity,[StringComparison]::Ordinal)
}
function Get-ChildSessionNamePart {
    param([string]$Name)
    # A launch name inside a marker or temporary file name: its first 64 characters,
    # so a long name keeps those names under the 255-character limit.
    if ($Name.Length -gt 64) { return $Name.Substring(0,64) }
    return $Name
}
function Get-ChildSessionClaimKey {
    param([string]$Text)
    # Every character outside [A-Za-z0-9] becomes _, the first 32 kept; an empty text gives none.
    if (-not $Text) { return 'none' }
    $key=[regex]::Replace($Text,'[^A-Za-z0-9]','_')
    if ($key.Length -gt 32) { $key=$key.Substring(0,32) }
    return $key
}
function Test-ChildSessionIrregularPath {
    param([string]$Path)
    # Something other than a regular file (a directory or a link) is at the path.
    try { $attributes=[IO.File]::GetAttributes($Path) } catch { return $false }
    return [bool]($attributes -band ([IO.FileAttributes]::Directory -bor [IO.FileAttributes]::ReparsePoint))
}
function Add-ChildSessionClaimFile {
    param($Watch,[string]$Path)
    # A move without replacement fails while the path exists: an exclusive create
    # of a complete file holding this watcher's claim text. Null when the text
    # cannot be prepared (ClaimError says so).
    $prepared=Join-Path $script:Runtime ('.watcher-claim-'+$PID+'-'+[Guid]::NewGuid().ToString('N'))
    try { [IO.File]::WriteAllText($prepared,$Watch.ClaimText+"`n",$script:Utf8) }
    catch { Remove-ChildSessionFile $prepared;$Watch.ClaimError='watcher claim could not be prepared';return $null }
    try { [IO.File]::Move($prepared,$Path);return $true } catch { Remove-ChildSessionFile $prepared;return $false }
}
function Read-ChildSessionClaimLine {
    param([string]$Path)
    # Its first line; '' when present but unreadable, null when absent.
    $line=Read-ChildSessionFirstLine $Path
    if ($null -eq $line -and (Test-ChildSessionPathPresent $Path)) { $line='' }
    return $line
}
# A stale claim is removed only by the watcher holding the marker
# .<name>.watcher-after-<key of its text>, created exclusively. That is safe: the
# claim's owner is dead and never releases it, no claim is created while one
# exists, and only that marker's holder removes a claim with that text, so a claim
# that still reads the text under the marker cannot change before it is removed.
# Every other watcher looks again; no watcher moves or removes a claim at any other
# point. A marker whose holder is dead is passed through the marker named after
# that holder (at most 3 links); a killed marker holder leaves its marker behind.
# Marker names are bounded: the launch-name part is the name's first 64
# characters and every key its first 32, so the deepest marker name is
# 1 + 64 + 15 + 32 + 3 x 33 = 211 characters, under the 255-character name limit.
# Two stale texts, or two launches sharing 64 characters, may then share a marker;
# that only serializes them, since the holder removes a claim only when it reads
# the full text again and a chain level is entered only past a dead holder. The
# cut is deterministic, so every watcher reading one dead holder chains to the
# same marker.
function Request-ChildSessionClaim {
    param($Watch,[string]$Name)
    $target=Join-Path $script:Runtime ($Name+'.watcher')
    $text='';$marker=$null;$links=0;$part=Get-ChildSessionNamePart $Name
    for ($attempt=0;$attempt -lt 10;$attempt++) {
        if ($null -eq $marker) {
            if ([IO.Directory]::Exists($target)) { $Watch.ClaimError='claim '+$target+' is a directory';return $false }
            $placed=Add-ChildSessionClaimFile $Watch $target
            if ($null -eq $placed) { return $false }
            if ($placed) { $Watch.Claimed.Add($Name);return $true }
            $text=Read-ChildSessionClaimLine $target
            if ($null -eq $text) { continue }
            if (Test-ChildSessionClaimLive $text) { $Watch.ClaimError='launch '+$Name+' already has a live watcher';return $false }
            $marker=Join-Path $script:Runtime ('.'+$part+'.watcher-after-'+(Get-ChildSessionClaimKey $text));$links=0
        }
        $placed=Add-ChildSessionClaimFile $Watch $marker
        if ($null -eq $placed) { return $false }
        if ($placed) {
            $now=Read-ChildSessionClaimLine $target
            if ($null -ne $now -and [string]::Equals($now,$text,[StringComparison]::Ordinal)) { try { [IO.File]::Delete($target) } catch { } }
            Remove-ChildSessionFile $marker
            $marker=$null
            continue
        }
        if (Test-ChildSessionIrregularPath $marker) { $Watch.ClaimError='claim marker '+$marker+' is not a regular file';return $false }
        # A vanished marker is tried again.
        $holder=Read-ChildSessionClaimLine $marker
        if ($null -eq $holder) { continue }
        if (Test-ChildSessionClaimLive $holder) { Start-Sleep -Milliseconds 200;$marker=$null;continue }
        $links++
        if ($links -gt 3) { break }
        $marker=$marker+'-'+(Get-ChildSessionClaimKey $holder)
    }
    $Watch.ClaimError='the claim on launch '+$Name+' kept changing'
    return $false
}
function Request-ChildSessionClaims {
    param($Watch)
    # Claims every watched launch for this process. On a refusal it releases the
    # claims it took and leaves the message in ClaimError.
    $Watch.ClaimError='';$Watch.Claimed.Clear();$start=$null
    try { $start=Get-ChildSessionProcessStart $PID } catch { $start=$null }
    if (-not $start) { $Watch.ClaimError='watcher start identity unavailable';return $false }
    $Watch.ClaimText=[string]$PID+' '+$start
    foreach ($name in $Watch.Names) { if (-not (Request-ChildSessionClaim $Watch $name)) { Remove-ChildSessionClaims $Watch;return $false } }
    return $true
}
function Remove-ChildSessionClaims {
    param($Watch)
    # Only claims this process took and that still hold its own text.
    foreach ($name in $Watch.Claimed.ToArray()) {
        $path=Join-Path $script:Runtime ($name+'.watcher')
        if ([string]::Equals([string](Read-ChildSessionFirstLine $path),$Watch.ClaimText,[StringComparison]::Ordinal)) { Remove-ChildSessionFile $path }
    }
    $Watch.Claimed.Clear()
}
# Result record <runtime>/<first name>.result. The text stays in the watch object,
# so a later rewrite works from memory, never from the file.
function Save-ChildSessionResultText {
    param($Watch,[string]$Text)
    $first=$Watch.Names[0]
    return (Save-ChildSessionFile (Join-Path $script:Runtime ($first+'.result')) (Join-Path $script:Runtime ('.'+(Get-ChildSessionNamePart $first)+'.result-'+$PID+'-'+[Guid]::NewGuid().ToString('N'))) $Text)
}
function Write-ChildSessionResult {
    param($Watch,[string]$Launch,[string]$StatusFile,[int]$Exit,[string]$Line)
    $Line=$Line.Replace([string][char]13,' ').Replace([string][char]10,' ')
    $Watch.Text='launch: '+$Launch+"`n"+'status_file: '+$StatusFile+"`n"+'exit: '+$Exit+"`n"+'line: '+$Line+"`n"+'watcher: '+$PID+"`n"+'launches: '+($Watch.Names -join ' ')+"`n"
    $Watch.Written=$true
    return (Save-ChildSessionResultText $Watch $Watch.Text)
}
function Start-ChildSessionResult {
    param($Watch)
    # After all claims: the old record goes, and every end writes a new one.
    $Watch.Recording=$true;$Watch.Written=$false;$Watch.Text=''
    [IO.File]::Delete((Join-Path $script:Runtime ($Watch.Names[0]+'.result')))
}
function Add-ChildSessionResultNote {
    param($Watch,[string]$Note)
    $Watch.Text+=$Note+"`n"
    if (-not (Save-ChildSessionResultText $Watch $Watch.Text)) { [Console]::Error.WriteLine('child-session: result record could not be written') }
}
function Get-ChildSessionScreen {
    param($Record,[switch]$Ansi)
    # The visible screen of a herdr pane, as text or with its ANSI attributes.
    if ($Record.backend -cne 'herdr') { throw 'Screen capture needs a herdr pane.' }
    $vector=@('pane','read',[string]$Record.pane,'--source','visible')
    if ($Ansi) { $vector+=@('--format','ansi') }
    $result=Invoke-ChildSessionNative (Get-Command herdr.exe -ErrorAction Stop).Source $vector $script:Runtime
    if ($result.ExitCode -ne 0) { throw 'herdr pane read failed.' }
    return $script:Utf8Lenient.GetString($result.Stdout)
}
function Test-ChildSessionWaitingScreen {
    param([string]$Text)
    # A child waiting for free ends its turn with the notice
    #   [child-session waiting] <what it waits for>; watcher <handle>; any input wakes this session.
    # among the last 12 non-blank lines of its screen, CSI sequences removed.
    if (-not $Text) { return $false }
    $kept=New-Object Collections.Generic.List[string]
    foreach ($line in ([regex]::Replace($Text,'\x1b\[[0-?]*[ -/]*[@-~]','')).Split([char]10)) { if ($line -cmatch '[^ \t\n\v\f\r ]') { $kept.Add($line) } }
    for ($i=[Math]::Max(0,$kept.Count-12);$i -lt $kept.Count;$i++) { if ($kept[$i].Contains('[child-session waiting]')) { return $true } }
    return $false
}
function Update-ChildSessionSgrDim {
    param([string]$Parameters,[int]$Dim)
    # One SGR parameter list read as operations from left to right: an empty list,
    # 0 (an empty element is 0) or 22 clears dim, 2 sets it; 38, 48 and 58 consume
    # their operands (5;<n> or 2;<r>;<g>;<b>), so the 2 of a truecolour selector is
    # no dim; an element holding ':' is one colour operation; any other element
    # leaves dim as it is. -1 for an extended colour without its operands.
    if ($Parameters.Length -eq 0) { return 0 }
    $parts=$Parameters.Split([char]';')
    for ($i=0;$i -lt $parts.Count;$i++) {
        if ($parts[$i].IndexOf([char]':') -ge 0) { continue }
        $part=$parts[$i].TrimStart([char]'0')
        if ($part -ceq '' -or $part -ceq '22') { $Dim=0 }
        elseif ($part -ceq '2') { $Dim=1 }
        elseif ($part -ceq '38' -or $part -ceq '48' -or $part -ceq '58') {
            if ($i+1 -ge $parts.Count) { return -1 }
            $selector=$parts[$i+1].TrimStart([char]'0')
            if ($selector -ceq '5' -and $i+2 -lt $parts.Count) { $i+=2 }
            elseif ($selector -ceq '2' -and $i+4 -lt $parts.Count) { $i+=4 }
            else { return -1 }
        }
    }
    return $Dim
}
function Get-ChildSessionFormState {
    param([string[]]$Raw,[int]$Marker,[char]$MarkerChar,[int]$InputEnd)
    # One form of the capture -> empty, draft or unknown. Dim state carries across
    # lines (a capture re-emits attributes only on change), so SGR is read from the
    # top, dim off at the start. The marker is the first visible character of its
    # line, so its first occurrence in the raw line is the marker itself.
    $dim=0;$text=New-Object Text.StringBuilder
    for ($i=0;$i -le $InputEnd;$i++) {
        $rest=$Raw[$i]
        if ($i -eq $Marker) { $at=$rest.IndexOf($MarkerChar);if ($at -ge 0) { $rest=$rest.Remove($at,1) } }
        while ($rest.Length -gt 0) {
            if ([int]$rest[0] -eq 27) {
                $csi=[regex]::Match($rest,'\A\x1b\[([0-?]*)([ -/]*)([@-~])')
                if ($csi.Success) {
                    $rest=$rest.Substring($csi.Length)
                    if ($csi.Groups[3].Value -ceq 'm' -and $csi.Groups[2].Length -eq 0 -and $csi.Groups[1].Value -cmatch '\A[0-9:;]*\z') {
                        $dim=Update-ChildSessionSgrDim $csi.Groups[1].Value $dim
                        if ($dim -lt 0) { return 'unknown' }
                    }
                    continue
                }
                $chunk=[string][char]27
            } else {
                $at=$rest.IndexOf([char]27);if ($at -lt 0) { $chunk=$rest } else { $chunk=$rest.Substring(0,$at) }
            }
            $rest=$rest.Substring($chunk.Length)
            if ($dim -eq 0 -and $i -ge $Marker) { [void]$text.Append($chunk) }
        }
    }
    if ([regex]::Replace($text.ToString(),'[ \t\n\v\f\r ]','').Length -gt 0) { return 'draft' }
    return 'empty'
}
function Get-ChildSessionInputState {
    param([string]$Ansi)
    # An ANSI capture of a caller pane -> empty, draft or unknown. The Claude Code
    # form is the input between its last two rule lines, the Codex form the input
    # from its marker down to the footer at the bottom. Both forms are looked for,
    # and each one found is read on its own: characters drawn dim (a suggestion, a
    # placeholder) and the marker are no input. No form found gives unknown, one
    # form its state; with both, draft if either is a draft, else unknown if either
    # is unknown, else empty. So it errs toward draft or unknown, never empty.
    if ($null -eq $Ansi) { $Ansi='' }
    $space=[char[]]@(32,9,10,11,12,13);$blank='\A[ \t\n\v\f\r]*\z';$context='Context [0-9]+% used'
    # Visible text: CSI sequences removed, CR dropped, NBSP counted as a space.
    $rawLines=$Ansi.Split([char]10);$visLines=([regex]::Replace($Ansi,'\x1b\[[0-?]*[ -/]*[@-~]','')).Split([char]10)
    $count=$rawLines.Count;$raw=New-Object string[] $count;$vis=New-Object string[] $count
    for ($i=0;$i -lt $count;$i++) { $raw[$i]=$rawLines[$i].Replace([string][char]13,'');$vis[$i]=$visLines[$i].Replace([string][char]13,'').Replace([string][char]0xA0,' ') }
    $last=$count-1
    while ($last -ge 0 -and $vis[$last] -cmatch $blank) { $last-- }
    if ($last -lt 0) { return 'unknown' }
    $claudeMarker=-1;$claudeEnd=-1;$codexMarker=-1;$codexEnd=-1
    # Claude Code: the last two lines of ten or more U+2500 and nothing else (trailing
    # whitespace aside), the lower one among the last 6 non-blank lines, the first line
    # between them U+276F after spaces.
    $lower=-1;$upper=-1
    for ($i=$last;$i -ge 0;$i--) {
        if ($vis[$i].TrimEnd($space) -cnotmatch '\A─{10,}\z') { continue }
        if ($lower -lt 0) { $lower=$i } else { $upper=$i;break }
    }
    if ($upper -ge 0 -and $upper+1 -lt $lower) {
        $seen=0
        for ($i=$lower;$i -le $last;$i++) { if ($vis[$i] -cnotmatch $blank) { $seen++ } }
        $line=$vis[$upper+1].TrimStart($space)
        if ($seen -le 6 -and $line.Length -gt 0 -and [int]$line[0] -eq 0x276F) { $claudeMarker=$upper+1;$claudeEnd=$lower-1 }
    }
    # Codex: the footer fixed at the bottom (a Context line, or a Context line above
    # "? for shortcuts", trailing whitespace aside); the marker the last line, among
    # the last 6 non-blank lines above it, whose first column is U+203A followed by a
    # space or the line end. The input runs from the marker to the footer, blank lines included.
    $footer=-1
    if ($vis[$last] -cmatch $context) { $footer=$last }
    elseif ([string]::Equals($vis[$last].Trim($space),'? for shortcuts',[StringComparison]::Ordinal)) {
        $i=$last-1
        while ($i -ge 0 -and $vis[$i] -cmatch $blank) { $i-- }
        if ($i -ge 0 -and $vis[$i] -cmatch $context) { $footer=$i }
    }
    $seen=0
    for ($i=$footer-1;$footer -ge 0 -and $i -ge 0 -and $seen -lt 6;$i--) {
        $line=$vis[$i]
        if ($line -cmatch $blank) { continue }
        $seen++
        if ([int]$line[0] -eq 0x203A -and ($line.Length -eq 1 -or [int]$line[1] -eq 32)) { $codexMarker=$i;$codexEnd=$footer-1;break }
    }
    $states=@()
    if ($claudeMarker -ge 0) { $states+=Get-ChildSessionFormState $raw $claudeMarker ([char]0x276F) $claudeEnd }
    if ($codexMarker -ge 0) { $states+=Get-ChildSessionFormState $raw $codexMarker ([char]0x203A) $codexEnd }
    if ($states.Count -eq 0) { return 'unknown' }
    if ($states -ccontains 'draft') { return 'draft' }
    if ($states -ccontains 'unknown') { return 'unknown' }
    return 'empty'
}
function Set-ChildSessionWatchEvent {
    param($Watch,[string]$Launch,[string]$StatusFile,[string]$Line,[int]$Code)
    # The event that ends the watch; launch and status file are empty for a deadline.
    $Watch.Launch=$Launch;$Watch.StatusFile=$StatusFile;$Watch.Line=$Line
    [Console]::WriteLine($Line)
    return $Code
}
function Test-ChildSessionStall {
    param($Watch,$State,[string]$Name)
    # A capture equal to the last one stalls an armed launch after Stall seconds
    # unless it is a waiting screen; a changed, waiting or failed capture restarts
    # the time. A re-armed launch is armed only by a capture that differs from its
    # first one. A failed capture never ends the watcher by itself.
    if (-not $State.On) { return $false }
    try {
        $r=Read-ChildSessionRecord $Name
        if (-not $r -or $r.closed) { throw 'No owned session.' }
        Assert-ChildSessionPane $r
        $screen=Get-ChildSessionScreen $r
    } catch { $State.Since=Get-ChildSessionClock;return $false }
    $now=Get-ChildSessionClock
    if (-not $State.Sampled) {
        $State.Sampled=$true;$State.Last=$screen;$State.Since=$now;$State.Armed=(-not $State.Rearmed)
        if ($State.Rearmed) { $State.Baseline=$screen }
        return $false
    }
    if (-not [string]::Equals($screen,$State.Last,[StringComparison]::Ordinal)) {
        $State.Last=$screen;$State.Since=$now
        if (-not $State.Armed -and -not [string]::Equals($screen,$State.Baseline,[StringComparison]::Ordinal)) { $State.Armed=$true }
        return $false
    }
    if (Test-ChildSessionWaitingScreen $screen) { $State.Since=$now;return $false }
    return ($State.Armed -and (($now-$State.Since) -ge $Watch.Stall))
}
function Invoke-ChildSessionWatchLoop {
    param($Watch)
    # Each round: every status in set order, then the deadline, then every launch's
    # liveness (plain wait's rule, per launch), then stalls. Prints the event line and
    # returns its exit; an error throws. Plain wait's cadence, its sleep capped at
    # max(1, stall / 3) s while any launch is stall-watched (a herdr launch).
    $count=$Watch.Names.Count;$seen=New-Object bool[] $count;$states=$null;$cap=0
    $Watch.Launch='';$Watch.StatusFile='';$Watch.Line=''
    $started=Get-ChildSessionClock
    while ($true) {
        for ($i=0;$i -lt $count;$i++) {
            $first=$null
            if ([IO.File]::Exists($Watch.Files[$i])) { $first=Read-ChildSessionFirstLine $Watch.Files[$i] }
            if ($null -ne $first -and $first -cmatch '\ASTATUS: (done|blocked|failed)\z') { return (Set-ChildSessionWatchEvent $Watch $Watch.Names[$i] $Watch.Files[$i] $first 0) }
        }
        $elapsed=[long][Math]::Floor((Get-ChildSessionClock)-$started)
        if ($elapsed -ge $Watch.Seconds) { return (Set-ChildSessionWatchEvent $Watch '' '' ('TIMEOUT: '+$Watch.Seconds+' s without status') 124) }
        for ($i=0;$i -lt $count;$i++) {
            $name=$Watch.Names[$i]
            try { $r=Read-ChildSessionRecord $name;$alive=Test-ChildSessionAlive $r }
            catch { throw ('alive check of window '+$name+' failed: '+$_.Exception.Message) }
            if ($alive) { $seen[$i]=$true }
            elseif ($seen[$i] -or $elapsed -ge 120) {
                [Console]::Error.WriteLine('Owned launch '+$r.launch_id+' phase '+$r.phase+' exit '+$r.exit_code)
                return (Set-ChildSessionWatchEvent $Watch $name $Watch.Files[$i] ('EXITED: agent in window '+$name+' is gone, no status') 3)
            }
        }
        # Prepared at the first stall check, so a status already present returns at once.
        if ($null -eq $states) {
            $states=New-Object Collections.Generic.List[object]
            foreach ($name in $Watch.Names) {
                $on=$false
                try { $r=Read-ChildSessionRecord $name;$on=($null -ne $r -and -not $r.closed -and $r.backend -ceq 'herdr') } catch { $on=$false }
                if ($on) { $cap=[Math]::Max(1,[int][Math]::Floor($Watch.Stall/3)) }
                $states.Add(@{On=$on;Rearmed=($Watch.Rearm -ccontains $name);Sampled=$false;Armed=$false;Last='';Since=0.0;Baseline=''})
            }
        }
        for ($i=0;$i -lt $count;$i++) {
            $name=$Watch.Names[$i]
            if (Test-ChildSessionStall $Watch $states[$i] $name) { return (Set-ChildSessionWatchEvent $Watch $name $Watch.Files[$i] ('STALLED: screen of window '+$name+' unchanged for '+$Watch.Stall+' s') 4) }
        }
        $elapsed=[long][Math]::Floor((Get-ChildSessionClock)-$started)
        $remaining=$Watch.Seconds-$elapsed
        if ($remaining -le 0) { continue }
        if ($elapsed -lt 120) { $delay=[Math]::Min(5,120-$elapsed) } else { $delay=30 }
        if ($cap -gt 0 -and $delay -gt $cap) { $delay=$cap }
        if ($delay -gt $remaining) { $delay=$remaining }
        Start-Sleep -Seconds ([int]$delay)
    }
}
function Invoke-ChildSessionWatch {
    param($Watch)
    # wait --watch: claims, the old record removed, the loop, the record, the claims
    # released. A refused claim writes no record and removes none; every end after
    # the claims writes the record, an error included (exit 2, its message as line).
    if (-not (Request-ChildSessionClaims $Watch)) { throw $Watch.ClaimError }
    $code=2;$failure=$null
    try {
        try { Start-ChildSessionResult $Watch;$code=Invoke-ChildSessionWatchLoop $Watch }
        catch { $failure=$_.Exception.Message;$code=2 }
        if ($null -ne $failure) { if ($Watch.Recording) { $null=Write-ChildSessionResult $Watch '' '' 2 $failure } }
        elseif (-not (Write-ChildSessionResult $Watch $Watch.Launch $Watch.StatusFile $code $Watch.Line)) { $failure='result record could not be written';$code=2 }
    } finally {
        # An end without an event (a stopped pipeline) is never a status.
        if ($Watch.Recording -and -not $Watch.Written) { $null=Write-ChildSessionResult $Watch '' '' 2 'watcher ended without an event' }
        Remove-ChildSessionClaims $Watch
    }
    if ($null -ne $failure) { throw $failure }
    return $code
}
function Find-ChildSessionWakeCaller {
    # The caller's own herdr pane, proven as open proves it; title, focus and cwd
    # never select a pane. The terminal backend cannot type.
    if ($env:CHILD_SESSION_BACKEND -eq 'terminal') { throw 'wake: the terminal backend cannot type' }
    $proven=$false
    if ($env:HERDR_ENV -eq '1') {
        try { $proven=[bool](Find-ChildSessionHerdrCaller (Get-Command herdr.exe -ErrorAction Stop).Source) } catch { $proven=$false }
    }
    if (-not $proven -or -not $script:HerdrPane -or -not $script:HerdrWorkspace) { throw 'wake: no proven caller pane' }
    return [pscustomobject]@{backend='herdr';pane=[string]$script:HerdrPane;workspace=[string]$script:HerdrWorkspace}
}
function Write-ChildSessionWakeAck {
    param([string]$Path,[string]$Text)
    # <runtime>/<first>.wake-ack-<nonce>, written atomically; wake-run never removes it.
    # Names hold no dot, so the name part ends at the first one.
    $file=[IO.Path]::GetFileName($Path);$dot=$file.IndexOf('.')
    if ($dot -gt 0) { $file=(Get-ChildSessionNamePart $file.Substring(0,$dot))+$file.Substring($dot) }
    return (Save-ChildSessionFile $Path (Join-Path $script:Runtime ('.'+$file+'-'+$PID+'-'+[Guid]::NewGuid().ToString('N'))) ($Text+"`n"))
}
function Test-ChildSessionCallerListed {
    param($Caller)
    # 0 when a listing shows the caller pane in its workspace, 1 when a listing
    # succeeds without it, 2 when the listing call fails or cannot be read.
    try {
        $result=Invoke-ChildSessionNative (Get-Command herdr.exe -ErrorAction Stop).Source @('pane','list','--workspace',$Caller.workspace) $script:Runtime
        if ($result.ExitCode -ne 0) { return 2 }
        $data=ConvertFrom-Json ($script:Utf8.GetString($result.Stdout))
        if ($null -eq $data -or $null -eq $data.result -or $null -eq $data.result.panes) { return 2 }
        foreach ($pane in @($data.result.panes)) { if ([string]::Equals([string]$pane.pane_id,$Caller.pane,[StringComparison]::Ordinal)) { return 0 } }
        return 1
    } catch { return 2 }
}
function Invoke-ChildSessionWakeTyping {
    param($Watch,$Caller,[string]$Line)
    # Every 2 s: a listing without the caller pane, or three failed listing calls in
    # a row, gives the record "wake: caller pane gone"; a failed listing call alone
    # types nothing and looks again. Only in a round whose listing shows the pane is
    # an empty input typed, once, the line with its Enter in one herdr call; a draft
    # or an unknown input keeps looking. A failed typing call is tried again.
    $failures=0
    while ($true) {
        $listed=Test-ChildSessionCallerListed $Caller
        if ($listed -eq 1) { Add-ChildSessionResultNote $Watch 'wake: caller pane gone';return }
        if ($listed -eq 2) {
            $failures++
            if ($failures -ge 3) { Add-ChildSessionResultNote $Watch 'wake: caller pane gone';return }
        } else {
            $failures=0;$screen=''
            try { $screen=Get-ChildSessionScreen $Caller -Ansi } catch { $screen='' }
            if ((Get-ChildSessionInputState $screen) -ceq 'empty') {
                $typed=$false
                try { $typed=((Invoke-ChildSessionNative (Get-Command herdr.exe -ErrorAction Stop).Source @('pane','run',$Caller.pane,$Line) $script:Runtime).ExitCode -eq 0) } catch { $typed=$false }
                if ($typed) { Add-ChildSessionResultNote $Watch 'wake: typed';return }
            }
        }
        Start-Sleep -Seconds 2
    }
}
function Test-ChildSessionPathQualified {
    param([string]$Path)
    # Fully qualified: X:\ or X:/, \\ or // (UNC and device paths), and / on a
    # host other than Windows. A drive-relative or root-relative path is not.
    if ($Path -cmatch '\A[A-Za-z]:[\\/]' -or $Path -cmatch '\A[\\/]{2}') { return $true }
    return ([IO.Path]::DirectorySeparatorChar -eq [char]47 -and $Path.StartsWith('/',[StringComparison]::Ordinal))
}
function Start-ChildSessionWake {
    param([AllowEmptyCollection()][string[]]$Vector)
    # Proves the caller pane, classifies its input and refuses a launch with a live
    # watcher, all before detaching; then starts wake-run detached with the caller
    # and the watch as its arguments, waits up to 10 s for its acknowledgement and
    # prints the handle.
    if ($null -eq $Vector) { $Vector=@() }
    $watch=Read-ChildSessionWatchArguments $Vector 'wake'
    $caller=Find-ChildSessionWakeCaller
    $screen=''
    try { $screen=Get-ChildSessionScreen $caller -Ansi } catch { $screen='' }
    $state=Get-ChildSessionInputState $screen
    if ($state -cne 'empty' -and $state -cne 'draft') { throw 'wake: caller input cannot be classified' }
    foreach ($name in $watch.Names) {
        $claim=Join-Path $script:Runtime ($name+'.watcher')
        if (-not (Test-ChildSessionPathPresent $claim)) { continue }
        if (Test-ChildSessionClaimLive ([string](Read-ChildSessionFirstLine $claim))) { throw ('launch '+$name+' already has a live watcher') }
    }
    # wake-run runs in the runtime directory, so it keeps no checkout directory in
    # use; a status file that is not fully qualified (relative, C:name, \name) is
    # handed over as the full path it names here.
    $set=[string[]]$Vector.Clone()
    foreach ($index in $watch.FileIndexes) { if (-not (Test-ChildSessionPathQualified $set[$index])) { $set[$index]=[IO.Path]::GetFullPath($set[$index]) } }
    $nonce=[Guid]::NewGuid().ToString('N');$first=$watch.Names[0]
    $ack=Join-Path $script:Runtime ($first+'.wake-ack-'+$nonce)
    $arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$script:ChildSessionOwner,'wake-run',$nonce,'herdr',$caller.pane,$caller.workspace,'--')+@($set)
    $list=@($arguments | ForEach-Object { ConvertTo-ChildSessionNativeArgument $_ })
    try { Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList $list -WindowStyle Hidden -WorkingDirectory $script:Runtime }
    catch { throw 'wake: detached watcher did not start' }
    $present=$false
    for ($n=0;$n -lt 100;$n++) { if (Test-ChildSessionPathPresent $ack) { $present=$true;break };Start-Sleep -Milliseconds 100 }
    if (-not $present) { throw 'wake: detached watcher did not start' }
    $item=Get-Item -LiteralPath $ack -Force
    if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'wake: the acknowledgement is not a regular file' }
    $reply=[string](Read-ChildSessionFirstLine $ack)
    Remove-ChildSessionFile $ack
    if ($reply.StartsWith('started ',[StringComparison]::Ordinal)) {
        $watcher=$reply.Substring(8)
        if ($watcher -cnotmatch '\A[0-9]+\z') { throw 'wake: unreadable acknowledgement' }
        [Console]::WriteLine('WAKE: watcher '+$watcher+' result '+(Join-Path $script:Runtime ($first+'.result')))
        return 0
    }
    if ($reply.StartsWith('refused ',[StringComparison]::Ordinal)) { throw $reply.Substring(8) }
    throw 'wake: unreadable acknowledgement'
}
function Invoke-ChildSessionWakeWatch {
    param($Watch,$Caller,[string]$Ack,[bool]$Valid)
    if (-not $Valid) { $null=Write-ChildSessionWakeAck $Ack 'refused wake: malformed caller pane in the handoff';throw 'wake: malformed caller pane in the handoff' }
    # A refused claim writes no record and removes none.
    if (-not (Request-ChildSessionClaims $Watch)) { $null=Write-ChildSessionWakeAck $Ack ('refused '+$Watch.ClaimError);throw $Watch.ClaimError }
    $code=2;$failure=$null;$pending=$false
    try {
        try {
            Start-ChildSessionResult $Watch
            # Before the watch loop, so a status already present cannot outrun it.
            if (-not (Write-ChildSessionWakeAck $Ack ('started '+$PID))) { throw 'wake: the acknowledgement could not be written' }
            # From here an error end still records, types and only then releases.
            $pending=$true
            $code=Invoke-ChildSessionWatchLoop $Watch
        } catch { $failure=$_.Exception.Message;$code=2 }
        if ($null -ne $failure) { if ($Watch.Recording) { $null=Write-ChildSessionResult $Watch '' '' 2 $failure } }
        elseif (-not (Write-ChildSessionResult $Watch $Watch.Launch $Watch.StatusFile $code $Watch.Line)) { $failure='result record could not be written';$code=2 }
        if ($pending) {
            # The line comes from this process's own event and arguments, never from
            # the record: the event's launch, or for a deadline or an error the watched
            # names joined by ",".
            $launch=$Watch.Launch;if (-not $launch) { $launch=$Watch.Names -join ',' }
            Invoke-ChildSessionWakeTyping $Watch $Caller ('child-session wake: '+$launch+'; result record '+(Join-Path $script:Runtime ($Watch.Names[0]+'.result')))
        }
    } finally {
        if ($Watch.Recording -and -not $Watch.Written) { $null=Write-ChildSessionResult $Watch '' '' 2 'watcher ended without an event' }
        # Only after the typing loop, so no second watcher or wake starts over a
        # launch whose wake is pending.
        Remove-ChildSessionClaims $Watch
    }
    if ($null -ne $failure) { throw $failure }
    return $code
}
function Invoke-ChildSessionWakeRun {
    param([AllowEmptyCollection()][string[]]$Handoff)
    # wake-run <nonce> herdr <pane_id> <workspace_id> -- <watch options and set>: the
    # caller and the watch arrive only as arguments. Its output and errors go to
    # <runtime>/<first>.wake.log, since Start-Process cannot send both streams to one file.
    if ($null -eq $Handoff) { $Handoff=@() }
    if ($Handoff.Count -lt 5 -or $Handoff[4] -cne '--' -or $Handoff[0] -cnotmatch '\A[A-Za-z0-9]{16,}\z') { throw 'wake-run: malformed handoff' }
    $id='\A[A-Za-z0-9_][A-Za-z0-9_:.-]*\z'
    $valid=($Handoff[1] -ceq 'herdr' -and $Handoff[2] -cmatch $id -and $Handoff[3] -cmatch $id)
    $caller=[pscustomobject]@{backend='herdr';pane=$Handoff[2];workspace=$Handoff[3]}
    $set=@();if ($Handoff.Count -gt 5) { $set=@($Handoff[5..($Handoff.Count-1)]) }
    $watch=Read-ChildSessionWatchArguments $set 'wake-run'
    $ack=Join-Path $script:Runtime ($watch.Names[0]+'.wake-ack-'+$Handoff[0])
    $log=$null
    try {
        $log=New-Object IO.StreamWriter([IO.File]::Open((Join-Path $script:Runtime ($watch.Names[0]+'.wake.log')),[IO.FileMode]::Append,[IO.FileAccess]::Write,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)),$script:Utf8Lenient)
        $log.AutoFlush=$true
    } catch { $log=$null }
    $savedOut=[Console]::Out;$savedError=[Console]::Error
    if ($log) { [Console]::SetOut($log);[Console]::SetError($log) }
    try { return (Invoke-ChildSessionWakeWatch $watch $caller $ack $valid) }
    catch { [Console]::Error.WriteLine('child-session: '+$_.Exception.Message);return 2 }
    finally { if ($log) { [Console]::SetOut($savedOut);[Console]::SetError($savedError);$log.Dispose() } }
}
function Invoke-ChildSessionDispatch {
    param([AllowEmptyCollection()][string[]]$Vector)
    $null=Get-ChildSessionRuntime
    if ($Vector.Count -eq 0) { throw 'A lifecycle command is required.' }
    $command=$Vector[0];$rest=@();if ($Vector.Count -gt 1) { $rest=@($Vector[1..($Vector.Count-1)]) }
    if ($command -ceq 'open') { Start-ChildSession $rest;return 0 }
    if ($command -cin @('runtime-dir','list')) {
        if ($rest.Count -ne 0) { throw 'Command takes no arguments.' }
        if ($command -ceq 'runtime-dir') { [Console]::WriteLine($script:Runtime) }
        else { foreach ($file in [IO.Directory]::GetFiles($script:Runtime,'*.json')) { $name=[IO.Path]::GetFileNameWithoutExtension($file);if ($name -match '^[A-Za-z0-9_-]+$' -and $name -notmatch '-[0-9a-f]{64}\.(agent|transport)$') { $r=Read-ChildSessionRecord $name;if ($r -and -not $r.closed) { [Console]::WriteLine($r.name+' '+$r.backend+' '+$r.phase+' '+$r.checkout) } } } }
        return 0
    }
    if ($command -ceq 'wait' -and $rest.Count -gt 0 -and $rest[0] -ceq '--watch') {
        $set=@();if ($rest.Count -gt 1) { $set=@($rest[1..($rest.Count-1)]) }
        return (Invoke-ChildSessionWatch (Read-ChildSessionWatchArguments $set 'wait --watch'))
    }
    if ($command -ceq 'wake') { return (Start-ChildSessionWake $rest) }
    # Internal: the detached half of wake.
    if ($command -ceq 'wake-run') { return (Invoke-ChildSessionWakeRun $rest) }
    if ($command -cnotin @('alive','close','capabilities','send','key','peek','wait')) { throw 'Unknown lifecycle command.' }
    $expected=@{alive=1;close=1;capabilities=1;send=2;key=2}
    if ($expected.ContainsKey($command)) { if ($rest.Count -ne $expected[$command]) { throw 'Invalid command arity.' } }
    elseif ($command -ceq 'peek') { if ($rest.Count -notin @(1,2)) { throw 'peek requires NAME [LINES]' } }
    elseif ($command -ceq 'wait') { if ($rest.Count -notin @(2,3)) { throw 'wait requires NAME STATUS [SECONDS]' } }
    else { throw 'Unknown lifecycle command.' }
    $r=Read-ChildSessionRecord $rest[0]
    if ($command -ceq 'alive') { if (Test-ChildSessionAlive $r) { return 0 };return 1 }
    if ((-not $r -or $r.closed) -and $command -cne 'wait') { if ($command -ceq 'close') { return 0 };throw 'No owned session.' }
    switch -CaseSensitive ($command) {
        'capabilities' { [Console]::WriteLine((ConvertTo-Json -InputObject (Get-ChildSessionCapabilities $r) -Compress));return 0 }
        'wait' {
            $seconds=43200;if ($rest.Count -eq 3) { if ($rest[2] -notmatch '^\d+$' -or -not [int]::TryParse($rest[2],[ref]$seconds)) { throw 'wait seconds must be a nonnegative integer' } }
            $watch=[Diagnostics.Stopwatch]::StartNew();$seen=$false
            while ($true) {
                if ([IO.File]::Exists($rest[1])) {
                    $bytes=[IO.File]::ReadAllBytes($rest[1]);$text=$script:Utf8.GetString($bytes);$end=$text.IndexOf([char]10)
                    if ($end -ge 0) { $first=$text.Substring(0,$end);if ($first.EndsWith([string][char]13)) { $first=$first.Substring(0,$first.Length-1) } } else { $first=$text }
                    if ($first -cmatch '^STATUS: (done|blocked|failed)$') { [Console]::WriteLine($first);return 0 }
                }
                $elapsed=[int][Math]::Floor($watch.Elapsed.TotalSeconds)
                if ($elapsed -ge $seconds) { [Console]::WriteLine('TIMEOUT: '+$seconds+' s without status');return 124 }
                $r=Read-ChildSessionRecord $rest[0]
                if (Test-ChildSessionAlive $r) { $seen=$true } elseif ($seen -or $elapsed -ge 120) { [Console]::WriteLine('EXITED: agent in window '+$rest[0]+' is gone, no status');[Console]::Error.WriteLine('Owned launch '+$r.launch_id+' phase '+$r.phase+' exit '+$r.exit_code);return 3 }
                $delay=30;if ($elapsed -lt 120) { $delay=[Math]::Min(5,120-$elapsed) };Start-Sleep -Seconds ([Math]::Min($delay,$seconds-$elapsed))
            }
        }
        'close' {
            if ($r.phase -eq 'starting' -or ($r.phase -ne 'exited' -and (-not $r.agent -or -not $r.launcher))) { throw 'Startup process identities inconclusive; session preserved.' }
            if ($r.phase -ne 'exited') {
            foreach ($id in @($r.agent,$r.launcher)) {
                if (-not $id -or -not $id.start) { throw 'Process start evidence unavailable; session preserved.' }
                $now=Get-ChildSessionProcessStart ([int]$id.pid)
                if ($now -and $now -cne $id.start) { throw 'PID/start mismatch; process preserved.' }
            }
            foreach ($id in @($r.agent,$r.launcher)) { Stop-ChildSessionTree $id }
            } elseif ($r.agent -and $r.agent.exit) {
                # Descendants of a script-wrapped agent can outlive its exit.
                foreach ($id in @(Get-ChildSessionDescendants $r.agent)) { Stop-ChildSessionProcess $id }
            }
            for ($n=0;$n -lt 50;$n++) { if (-not (Test-ChildSessionAlive $r)) { break };Start-Sleep -Milliseconds 200 }
            if (Test-ChildSessionAlive $r) { throw 'Owned agent still alive; window retained.' }
            $r.closed=$true;$r.phase='exited';Write-ChildSessionRecord $r
            foreach ($suffix in @('.transport.json')) { $path=Join-Path $script:Runtime ($r.name+'-'+$r.launch_id+$suffix);if ([IO.File]::Exists($path)) { [IO.File]::Delete($path) } }
            [Console]::Error.WriteLine('child-session: owned processes stopped; window_close: false (terminal window retained)');return 0
        }
        default {
            if ($command -cne 'peek' -and -not (Test-ChildSessionAlive $r -Control)) { throw 'Owned agent or its launcher is not running; input refused.' }
            Assert-ChildSessionPane $r
            $vector=@('pane')
            if ($command -ceq 'send') { if ($rest[1] -ne '') { $sent=Invoke-ChildSessionNative $script:Herdr @('pane','send-text',$r.pane,$rest[1]) $script:Runtime;if ($sent.ExitCode -ne 0) { throw 'send-text failed' };Start-Sleep -Milliseconds 300 };$vector=@('pane','send-keys',$r.pane,'enter') }
            elseif ($command -ceq 'key') { if ($rest[1] -cnotmatch '^(Escape|Up|Down|[0-9])$') { throw 'key must be Escape, Up, Down or one digit 0-9' };$key=$rest[1].ToLowerInvariant();if ($key -eq 'escape') { $key='esc' };if ($key -match '^\d$') { $vector=@('pane','send-text',$r.pane,$key) } else { $vector=@('pane','send-keys',$r.pane,$key) } }
            elseif ($command -ceq 'peek') { $lines=60;if ($rest.Count -eq 2) { if ($rest[1] -notmatch '^\d+$') { throw 'peek lines must be nonnegative' };$lines=[int]$rest[1] };$vector=@('pane','read',$r.pane,'--source','recent-unwrapped','--lines',[string]$lines) }
            $result=Invoke-ChildSessionNative $script:Herdr $vector $script:Runtime
            [Console]::OpenStandardOutput().Write($result.Stdout,0,$result.Stdout.Length);[Console]::OpenStandardError().Write($result.Stderr,0,$result.Stderr.Length);return $result.ExitCode
        }
    }
}
if ($MyInvocation.InvocationName -eq '.') { return }
$ErrorActionPreference='Stop'
try {
    exit (Invoke-ChildSessionDispatch ([string[]]$args))
} catch { [Console]::Error.WriteLine('child-session: '+($_ | Out-String));exit 2 }
