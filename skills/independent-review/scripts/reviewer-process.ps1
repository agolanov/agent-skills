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
        [IO.File]::WriteAllText((Join-Path $OutputDirectory 'answer.md'), $result.result, $utf8)
        [IO.File]::WriteAllText((Join-Path $OutputDirectory 'extraction.exit'), "0`n")
        return 0
    } catch {
        [IO.File]::WriteAllText((Join-Path $OutputDirectory 'extraction-error.txt'), $_.Exception.Message)
        [IO.File]::WriteAllText((Join-Path $OutputDirectory 'extraction.exit'), "1`n")
        return 1
    }
}
