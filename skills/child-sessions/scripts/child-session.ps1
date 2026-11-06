# Native Windows lifecycle helper. Dot-source to call Invoke-ChildSessionDispatch
# with a literal string array; direct -File calls use the same grammar.
$script:ChildSessionOwner=$PSCommandPath
$script:Utf8=New-Object Text.UTF8Encoding($false,$true)
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
    $temp=$path+'.'+[Guid]::NewGuid().ToString('N')
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
