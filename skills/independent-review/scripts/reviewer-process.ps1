# Dot-source in installed PowerShell 7 to capture reviewer I/O without text pipelines.
function Invoke-ReviewerProcess {
    param(
        [Parameter(Mandatory)][string]$Executable,
        [string[]]$Vector = @(),
        [Parameter(Mandatory)][string]$Checkout,
        [Parameter(Mandatory)][string]$PromptPath,
        [Parameter(Mandatory)][string]$OutputDirectory,
        [string]$OutputName = 'answer.md'
    )
    $ErrorActionPreference = 'Stop'
    $command = Get-Command $Executable -ErrorAction Stop
    $program = $command.Source
    if ([IO.Path]::GetExtension($program) -iin @('.cmd', '.bat')) {
        $program = [IO.Path]::ChangeExtension($program, '.ps1')
        if (-not [IO.File]::Exists($program)) { throw 'Installed shim needs a verified executable or PowerShell sibling.' }
    }
    if ([IO.Path]::GetExtension($program) -ieq '.ps1') {
        $shim = [IO.File]::ReadAllText($program)
        if ($shim -match 'node_modules[/\\]') {
            # npm's $input pipeline can decode/re-encode stdin. Launch its one
            # installed JavaScript target with node instead, retaining raw I/O.
            $targets = @([regex]::Matches($shim, '\$basedir[/\\]([^"\r\n]+\.js)') |
                ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
            if ($targets.Count -ne 1) { throw 'Installed npm shim target is ambiguous.' }
            $directory = [IO.Path]::GetDirectoryName($program)
            $target = [IO.Path]::GetFullPath((Join-Path $directory $targets[0]))
            if (-not [IO.File]::Exists($target)) { throw 'Installed npm target is missing.' }
            $program = Join-Path $directory 'node.exe'
            if (-not [IO.File]::Exists($program)) { $program = (Get-Command node.exe -CommandType Application -ErrorAction Stop).Source }
            $Vector = @($target) + $Vector
        } else {
            $Vector = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $program) + $Vector
            $program = (Get-Process -Id $PID).Path
        }
    }
    if (-not [IO.Path]::IsPathRooted($Checkout) -or -not [IO.Path]::IsPathRooted($PromptPath) -or -not [IO.Path]::IsPathRooted($OutputDirectory)) {
        throw 'Checkout, prompt and output directory must be absolute.'
    }
    [IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $program
    $info.WorkingDirectory = $Checkout
    $info.UseShellExecute = $false
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    foreach ($argument in $Vector) { $info.ArgumentList.Add($argument) }
    $inputFile = $outputFile = $errorFile = $process = $null
    $ioFailure = @()
    try {
        $inputFile = [IO.File]::OpenRead($PromptPath)
        $outputFile = [IO.File]::Create((Join-Path $OutputDirectory $OutputName))
        $errorFile = [IO.File]::Create((Join-Path $OutputDirectory 'stderr.log'))
        $process = [Diagnostics.Process]::Start($info)
        $outTask = $process.StandardOutput.BaseStream.CopyToAsync($outputFile)
        $errTask = $process.StandardError.BaseStream.CopyToAsync($errorFile)
        try { $inputFile.CopyTo($process.StandardInput.BaseStream) }
        catch { $ioFailure += 'stdin: ' + $_.Exception.Message }
        finally { $process.StandardInput.Close() }
        $process.WaitForExit()
        foreach ($task in @($outTask, $errTask)) {
            try { $null=$task.GetAwaiter().GetResult() }
            catch { $ioFailure += 'output: ' + $_.Exception.Message }
        }
        $producerExit = $process.ExitCode
        [IO.File]::WriteAllText((Join-Path $OutputDirectory 'producer.exit'), "$producerExit`n")
        if ($ioFailure.Count) { [IO.File]::WriteAllLines((Join-Path $OutputDirectory 'io-error.txt'), $ioFailure) }
        return [pscustomobject]@{ProducerExit=$producerExit; IOFailure=($ioFailure -join '; ')}
    } finally {
        foreach ($resource in @($inputFile, $outputFile, $errorFile, $process)) {
            if ($resource) { $resource.Dispose() }
        }
    }
}

function Export-ClaudeReviewAnswer {
    param([Parameter(Mandatory)][string]$OutputDirectory)
    $ErrorActionPreference = 'Stop'
    $utf8 = [Text.UTF8Encoding]::new($false, $true)
    try {
        $results = @(
            foreach ($line in [IO.File]::ReadLines((Join-Path $OutputDirectory 'events.jsonl'), $utf8)) {
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    $event = ConvertFrom-Json -InputObject $line -ErrorAction Stop
                    if ($event.type -ceq 'result') { $event }
                }
            }
        )
        $result = $results | Select-Object -Last 1
        if (-not $result -or $result.is_error -eq $true -or $result.result -isnot [string] -or [string]::IsNullOrWhiteSpace($result.result)) {
            throw 'Expected a nonempty, non-error final Claude result event.'
        }
        # Publish whole: a temporary sibling, then a rename.
        $staged = Join-Path $OutputDirectory 'answer.md.tmp'
        [IO.File]::WriteAllText($staged, $result.result, $utf8)
        [IO.File]::Move($staged, (Join-Path $OutputDirectory 'answer.md'))
        [IO.File]::WriteAllText((Join-Path $OutputDirectory 'extraction.exit'), "0`n")
        return 0
    } catch {
        [IO.File]::WriteAllText((Join-Path $OutputDirectory 'extraction-error.txt'), $_.Exception.Message)
        [IO.File]::WriteAllText((Join-Path $OutputDirectory 'extraction.exit'), "1`n")
        return 1
    }
}

# The lean background reviewer launch, the PowerShell form of scripts/reviewer-process.
# Writes the same files into -Directory: argv.txt, session-id, producer.exit, events.jsonl or
# stdout.log, stderr.log, answer.md (atomic), extraction.exit (Claude), plugins.txt (Claude),
# copy.exit on a failed Codex answer publication.
function Invoke-ReviewerLaunch {
    param(
        [Parameter(Mandatory)][ValidateSet('claude', 'codex')][string]$System,
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][string]$Checkout,
        [Parameter(Mandatory)][string]$Prompt,
        [Parameter(Mandatory)][string]$Directory,
        [Parameter(Mandatory)][string]$Model,
        [Parameter(Mandatory)][string]$Effort,
        [Parameter(Mandatory)][ValidateSet('yes', 'no')][string]$Native,
        [ValidateSet('plugins', 'memories', 'skills')][string[]]$KeepFeature = @(),
        [string[]]$PermissionArg = @()
    )
    $ErrorActionPreference = 'Stop'
    $answer = Join-Path $Directory 'answer.md'
    if (Test-Path -LiteralPath $answer) { throw 'The answer path must be absent before launch.' }
    $vector = New-Object Collections.Generic.List[string]
    $sessionId = $null
    if ($System -ceq 'claude') {
        $sessionId = [Guid]::NewGuid().ToString()
        $settings = [ordered]@{ language = 'English' }
        $off = [ordered]@{}
        $lines = New-Object Collections.Generic.List[string]
        try {
            Push-Location -LiteralPath $Checkout
            try { $listed = & $Command plugin list --json 2>$null; $listExit = $LASTEXITCODE } finally { Pop-Location }
            if ($listExit -ne 0) { throw ($Command + ' plugin list --json failed') }
            foreach ($plugin in @(ConvertFrom-Json -InputObject ($listed -join "`n"))) {
                if ($plugin.enabled -ne $true) { continue }
                $path = [string]$plugin.installPath
                $manifest = if ($path) { Join-Path $path '.claude-plugin/plugin.json' } else { $null }
                if (-not $path -or -not [IO.Directory]::Exists($path)) { $lines.Add('on ' + $plugin.id + ' unknown: no readable install path') }
                elseif ([IO.File]::Exists((Join-Path $path 'hooks/hooks.json')) -or
                        ([IO.File]::Exists($manifest) -and (ConvertFrom-Json ([IO.File]::ReadAllText($manifest))).psobject.Properties.Name -contains 'hooks')) {
                    $lines.Add('on ' + $plugin.id + ' hooks')
                } else { $lines.Add('off ' + $plugin.id); $off[[string]$plugin.id] = $false }
            }
            if ($off.Count) { $settings['enabledPlugins'] = $off }
        } catch {
            $lines.Clear(); $lines.Add('unavailable: ' + $_.Exception.Message)
        }
        [IO.File]::WriteAllLines((Join-Path $Directory 'plugins.txt'), $lines)
        foreach ($word in @('--print', '--output-format', 'stream-json', '--verbose')) { $vector.Add($word) }
        foreach ($word in $PermissionArg) { $vector.Add($word) }
        foreach ($word in @('--strict-mcp-config', '--no-chrome',
                '--session-id', $sessionId, '--settings', (ConvertTo-Json -InputObject $settings -Compress -Depth 4))) { $vector.Add($word) }
        if ($Model -cne 'cli-default') { $vector.Add('--model'); $vector.Add($Model) }
        if ($Effort -cne 'cli-default') { $vector.Add('--effort'); $vector.Add($Effort) }
        [IO.File]::WriteAllText((Join-Path $Directory 'session-id'), $sessionId + "`n")
        $outputName = 'events.jsonl'
    } else {
        foreach ($word in $PermissionArg) { $vector.Add($word) }
        if ($KeepFeature -notcontains 'plugins') { $vector.Add('--disable'); $vector.Add('plugins') }
        if ($KeepFeature -notcontains 'memories') { $vector.Add('--disable'); $vector.Add('memories') }
        if ($KeepFeature -notcontains 'skills') { $vector.Add('-c'); $vector.Add('skills.include_instructions=false') }
        $vector.Add('review')
        if ($Model -cne 'cli-default') { $vector.Add('-c'); $vector.Add('model="' + $Model + '"'); $vector.Add('-c'); $vector.Add('review_model="' + $Model + '"') }
        if ($Effort -cne 'cli-default') { $vector.Add('-c'); $vector.Add('model_reasoning_effort="' + $Effort + '"') }
        $vector.Add('-')
        $outputName = 'stdout.log'
    }
    [IO.File]::WriteAllLines((Join-Path $Directory 'argv.txt'), [string[]](@($Command) + $vector.ToArray()))
    $result = Invoke-ReviewerProcess -Executable $Command -Vector $vector.ToArray() -Checkout $Checkout -PromptPath $Prompt -OutputDirectory $Directory -OutputName $outputName
    if ($System -ceq 'codex') {
        foreach ($line in [IO.File]::ReadLines((Join-Path $Directory 'stderr.log'))) {
            if ($line -cmatch '^session id: (\S+)') { $sessionId = $Matches[1]; [IO.File]::WriteAllText((Join-Path $Directory 'session-id'), $sessionId + "`n"); break }
        }
        if ($Native -ceq 'yes') {
            $staged = Join-Path $Directory 'answer.md.tmp'
            try {
                [IO.File]::Copy((Join-Path $Directory 'stdout.log'), $staged, $true)
                [IO.File]::Move($staged, $answer)
            } catch { [IO.File]::WriteAllText((Join-Path $Directory 'copy.exit'), "1`n") }
        }
        $extraction = $null
    } else {
        $extraction = Export-ClaudeReviewAnswer -OutputDirectory $Directory
    }
    return [pscustomobject]@{ProducerExit = $result.ProducerExit; IOFailure = $result.IOFailure; ExtractionExit = $extraction; SessionId = $sessionId}
}
