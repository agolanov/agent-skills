#!/usr/bin/env python3
"""Stdlib-only external harness; production adapters never call its interpreter."""
import base64
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = ROOT / 'skills/independent-review/scripts'
EVIDENCE = Path(os.environ.get('NATIVE_SMOKE_ARTIFACTS') or tempfile.mkdtemp(prefix='native-platforms-'))
EVIDENCE.mkdir(parents=True, exist_ok=True)
RESULTS = []


def run(argv, *, cwd=None, env=None, want=0):
    if env is None and str(argv[0]) == 'git':
        env = {k: v for k, v in os.environ.items() if not k.startswith('GIT_')}
        env.update(GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_SYSTEM=os.devnull, GIT_CONFIG_GLOBAL=os.devnull)
    result = subprocess.run([str(x) for x in argv], cwd=cwd, env=env,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=300)
    with (EVIDENCE / 'commands.jsonl').open('a', encoding='utf-8') as out:
        out.write(json.dumps(dict(argv=[str(x) for x in argv], cwd=str(cwd or Path.cwd()),
                                  exit=result.returncode, stdout=base64.b64encode(result.stdout).decode(),
                                  stderr=base64.b64encode(result.stderr).decode())) + '\n')
    if want is not None and result.returncode != want:
        raise AssertionError(f'{argv}: exit {result.returncode}, expected {want}\n{result.stderr.decode(errors="replace")}')
    return result


def record(name, status, detail=''):
    row = dict(name=name, status=status, detail=detail)
    RESULTS.append(row)
    print(json.dumps(row), flush=True)


def posix_state():
    # Break caught: dispatcher executes an Apple launcher despite missing developer tools.
    script = '. "$1"; classify_discovery_candidate "$2" "$3" "$4"'
    dispatcher = SCRIPTS / 'checkout-state'
    for candidate, shims, clt, expected in [
            ('/fake/Apple Python', '/fake/Apple Python:/fake/Apple Git', 'unavailable', 2),
            ('/fake/standalone', '/fake/Apple Python', 'unavailable', 0),
            ('/fake/Apple Git', '/fake/Apple Git', 'available', 0)]:
        run(['/bin/sh', '-c', script, 'classifier', dispatcher, candidate, shims, clt], want=expected)
    engine = json.loads(run([dispatcher, 'resolve']).stdout)['argv']
    record('posix-engine', 'pass', repr(engine))
    root = EVIDENCE / 'POSIX project & café $;'
    root.mkdir()
    run(['git', 'init', '-q', root])
    (root / 'raw.txt').write_bytes(b'alpha\n')
    (root / 'tracked').mkdir()
    (root / 'tracked/leaf.txt').write_bytes(b'leaf\n')
    (root / 'café & $;.txt').write_bytes(b'bytes\x00\xff\n')
    run(['git', '-C', root, 'add', '--all'])
    run(['git', '-C', root, '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.test', 'commit', '-qm', 'fixture: native state'])
    time.sleep(2)
    run(['git', '-C', root, 'update-index', '-q', '--ignore-submodules', '--refresh'])
    source_index = (root / '.git/index').read_bytes()
    source_config = (root / '.git/config').read_bytes()
    count = 0

    def state(args, want=0):
        result = run(engine + [str(a) for a in args], want=want)
        if args[0] == 'preflight' and result.returncode == 0:
            gate = json.loads(result.stdout)
            if gate['uncommitted']:
                with (EVIDENCE / 'gate-hints.jsonl').open('a', encoding='utf-8') as hints:
                    hints.write(json.dumps(dict(capture=str(args[2]), paths=gate['paths'],
                                                possible_cause='isolated-normalization-not-applied')) + '\n')
        return result

    def capture(want=0):
        nonlocal count
        count += 1
        out = EVIDENCE / f'posix-capture-{count}'
        state(['capture', '--checkout', root, '--output-dir', out], want)
        return out

    first, second = capture(), capture()
    gate = json.loads(state(['preflight', '--capture-dir', first]).stdout)
    assert gate['uncommitted'] is False
    state(['compare', '--before', first, '--after', second, '--output-dir', EVIDENCE / 'posix-identical'])
    state(['capture', '--checkout', root, '--output-dir', first], 2)
    state(['capture', '--checkout', root, '--output-dir', root / 'unsafe'], 2)
    (root / 'raw.txt').write_bytes(b'bravo\n')
    edited = capture()
    state(['compare', '--before', first, '--after', edited, '--output-dir', EVIDENCE / 'posix-same-size'], 1)
    (root / 'raw.txt').write_bytes(b'alpha\r\n')
    crlf = capture()
    state(['compare', '--before', first, '--after', crlf, '--output-dir', EVIDENCE / 'posix-raw-crlf'], 1)
    (root / 'untracked café &.txt').write_bytes(b'untracked')
    gate = json.loads(state(['preflight', '--capture-dir', capture()]).stdout)
    paths = {base64.b64decode(p).decode() for p in gate['paths']}
    assert paths == {'raw.txt', 'untracked café &.txt'}
    assert (root / '.git/index').read_bytes() == source_index
    assert (root / '.git/config').read_bytes() == source_config
    state(['git-read', '--checkout', root, '--', 'rev-parse', '--verify', 'HEAD'])
    state(['git-read', '--checkout', root, '--', 'show', 'HEAD:raw.txt'])
    for command in [['status'], ['diff', '--no-index', root, EVIDENCE], ['diff', '--', '../escape'], ['symbolic-ref', '--delete', 'HEAD']]:
        state(['git-read', '--checkout', root, '--'] + command, 2)
    run(['git', '-C', root, 'add', '--all'])
    staged = json.loads(state(['preflight', '--capture-dir', capture()]).stdout)
    assert staged['uncommitted'] and base64.b64decode(staged['staged'])
    linked = EVIDENCE / 'POSIX linked café'
    run(['git', '-C', root, '-c', 'core.autocrlf=false', '-c', 'core.eol=lf', 'worktree', 'add', '--detach', linked, 'HEAD'])
    state(['capture', '--checkout', linked, '--output-dir', EVIDENCE / 'posix-linked'])
    state(['capture', '--checkout', linked, '--output-dir', EVIDENCE / 'posix-linked-same'])
    state(['compare', '--before', EVIDENCE / 'posix-linked', '--after', EVIDENCE / 'posix-linked-same', '--output-dir', EVIDENCE / 'posix-linked-identical'])
    (linked / 'raw.txt').write_bytes(b'bravo\n')
    state(['capture', '--checkout', linked, '--output-dir', EVIDENCE / 'posix-linked-edit'])
    state(['compare', '--before', EVIDENCE / 'posix-linked', '--after', EVIDENCE / 'posix-linked-edit', '--output-dir', EVIDENCE / 'posix-linked-changed'], 1)
    malformed = EVIDENCE / 'posix-malformed'
    malformed.mkdir()
    (malformed / 'snapshot.json').write_text('{bad', encoding='utf-8')
    state(['preflight', '--capture-dir', malformed], 2)
    state(['compare', '--before', first, '--after', malformed, '--output-dir', EVIDENCE / 'posix-unavailable'], 2)
    # Converted source with forced racy metadata stays conservative; no helper refresh.
    converted = EVIDENCE / 'POSIX converted'
    run(['git', '-c', 'core.autocrlf=true', 'clone', '-q', root, converted])
    raw = converted / 'raw.txt'
    raw.write_bytes(b'alpha\r\n')
    index = converted / '.git/index'
    stamp = raw.stat().st_mtime_ns
    os.utime(index, ns=(stamp, stamp))
    original = index.read_bytes()
    state(['capture', '--checkout', converted, '--output-dir', EVIDENCE / 'posix-racy'])
    racy = json.loads(state(['preflight', '--capture-dir', EVIDENCE / 'posix-racy']).stdout)
    assert racy['uncommitted'] and base64.b64encode(b'raw.txt').decode() in racy['paths']
    assert index.read_bytes() == original
    record('posix-converted-racy', 'pass', 'dirty isolated gate; possible cause isolated-normalization-not-applied; exact capture posix-racy; no source refresh')
    record('posix-state', 'pass', 'ordinary/linked, raw edits, index/config preservation, schema and allowed/refused Git reads')
    if platform.system() == 'Darwin':
        run(['/usr/bin/osascript', '-l', 'JavaScript', SCRIPTS / 'checkout-state.jxa.js', 'resolve'], want=2)
    record('darwin-jxa-feasibility', 'unavailable', 'No architecture-specific actual-host binding/layout/hash/integer proof; native no-Python engine incomplete.')
    record('darwin-python-native-interoperability', 'unavailable', 'Blocked by native feasibility gate.')


WINDOWS_FIXTURE = r'''
$ErrorActionPreference = 'Stop'
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$lf = [string][char]10
$crlf = [string][char]13 + [char]10
$report = Join-Path $PSScriptRoot 'windows-results.json'
$log = Join-Path $PSScriptRoot 'windows-commands.jsonl'
$rows = New-Object Collections.Generic.List[object]
function Record([string]$name, [string]$status, [string]$detail) { $rows.Add(@{name=$name;status=$status;detail=$detail}) }
function Assert($condition, [string]$message) { if (-not $condition) { throw $message } }
$power = (Get-Process -Id $PID).Path
$git = (Get-Command git.exe -ErrorAction Stop).Source
$env:PATH = [Environment]::SystemDirectory + ';' + (Split-Path $power) + ';' + (Split-Path $git)
$env:MSYS2_ARG_CONV_EXCL = '*'
$env:MSYS_NO_PATHCONV = '1'
$stateScript = Join-Path $PSScriptRoot 'state\checkout-state.ps1'
$source = Join-Path $PSScriptRoot 'state\checkout-state.windows.cs'
try {
    foreach ($tool in @('python','python3','py','jq','tmux')) { Assert ($null -eq (Get-Command $tool -ErrorAction SilentlyContinue)) ('Optional tool discoverable: ' + $tool) }
    . (Join-Path $PSScriptRoot 'consumer-recipe.ps1')
    . $stateScript
    $defaultTemp=[IO.Path]::GetTempPath()
    try { Initialize-CheckoutStateEngine $stateScript; Record 'windows-default-temp' 'observed' 'Private native per-user temp ACL' } catch { Record 'windows-default-temp' 'unavailable' ('Default temp rejected before Add-Type, no ACL change: '+$_.Exception.Message) }
    $env:TEMP=$PSScriptRoot; $env:TMP=$PSScriptRoot
    Initialize-CheckoutStateEngine $stateScript
    $privateTemp=Join-Path $PSScriptRoot 'private temp'
    [CheckoutState.Native]::MakePrivate($privateTemp)
    $env:TEMP=$privateTemp; $env:TMP=$privateTemp
    function GitWrite([string[]]$vector) {
        $environment=New-Object 'Collections.Generic.Dictionary[string,string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach ($entry in [Environment]::GetEnvironmentVariables().GetEnumerator()) {
            if (-not $entry.Key.StartsWith('GIT_',[StringComparison]::OrdinalIgnoreCase)) { $environment[$entry.Key]=$entry.Value }
        }
        $environment['GIT_CONFIG_NOSYSTEM']='1'; $environment['GIT_CONFIG_SYSTEM']='NUL'; $environment['GIT_CONFIG_GLOBAL']='NUL'
        $r = [CheckoutState.Engine]::Run($git, $vector, $PSScriptRoot, $environment, $null, 10000)
        [IO.File]::AppendAllText($log, (ConvertTo-Json -InputObject @{argv=$vector;launch_executable=$r.Executable;launch_argv=$r.Arguments;cwd=$PSScriptRoot;exit=$r.ExitCode;stdout=[Convert]::ToBase64String($r.Stdout);stderr=[Convert]::ToBase64String($r.Stderr)} -Depth 10 -Compress) + $lf, $utf8)
        Assert ($r.ExitCode -eq 0) ('Fixture mutation failed: ' + $utf8.GetString($r.Stderr))
    }
    $root = Join-Path $PSScriptRoot 'project & café $;'
    [IO.Directory]::CreateDirectory($root) | Out-Null
    GitWrite @('init','-q',$root)
    [IO.File]::WriteAllBytes((Join-Path $root 'raw.txt'), $utf8.GetBytes('alpha'+$lf))
    [IO.Directory]::CreateDirectory((Join-Path $root 'tracked')) | Out-Null
    [IO.File]::WriteAllBytes((Join-Path $root 'tracked\leaf.txt'),$utf8.GetBytes('leaf'+$lf))
    [IO.File]::WriteAllBytes((Join-Path $root 'café & $;.txt'), [byte[]]@(0,255,10))
    GitWrite @('-C',$root,'add','--all')
    GitWrite @('-C',$root,'-c','user.name=Fixture','-c','user.email=fixture@example.test','commit','-qm','fixture: native state')
    Start-Sleep -Seconds 2
    GitWrite @('-C',$root,'update-index','-q','--ignore-submodules','--refresh')
    $script:protected = [string[]]@($root,(Join-Path $root '.git'))
    $index = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $root '.git\index')))
    $config = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $root '.git\config')))
    function State([string[]]$vector, [int]$want=0) {
        $r = Invoke-CheckoutStateCommand $power $stateScript $vector $script:protected
        [IO.File]::AppendAllText($log, (ConvertTo-Json -InputObject @{argv=$vector;launch_executable=$r.Executable;launch_argv=$r.Arguments;cwd=$PSScriptRoot;exit=$r.ExitCode;stdout=[Convert]::ToBase64String($r.Stdout);stderr=[Convert]::ToBase64String($r.Stderr)} -Depth 10 -Compress) + $lf, $utf8)
        Assert ($r.ExitCode -eq $want) ('State exit ' + $r.ExitCode + ' expected ' + $want + ': ' + $utf8.GetString($r.Stderr))
        return $r
    }

    function Direct([string[]]$vector) {
        $r=[CheckoutState.Engine]::Run($power,$vector,$PSScriptRoot,$null,$null,30000)
        [IO.File]::AppendAllText($log,(ConvertTo-Json -InputObject @{argv=$vector;cwd=$PSScriptRoot;exit=$r.ExitCode;stdout=[Convert]::ToBase64String($r.Stdout);stderr=[Convert]::ToBase64String($r.Stderr)} -Depth 10 -Compress)+$lf,$utf8)
        return $r
    }
    $script:counter=0
    function Capture([int]$want=0) {
        $script:counter++
        $out=Join-Path $PSScriptRoot ('capture-' + $script:counter)
        $null=State @('capture','--checkout',$root,'--output-dir',$out) $want
        return $out
    }
    $first=Capture
    $second=Capture
    $gate=ConvertFrom-Json ($utf8.GetString((State @('preflight','--capture-dir',$first)).Stdout))
    Assert ($gate.uncommitted -eq $false) 'Ordinary native checkout is dirty'
    $null=State @('compare','--before',$first,'--after',$second,'--output-dir',(Join-Path $PSScriptRoot 'identical'))
    $null=State @('capture','--checkout',$root,'--output-dir',$first) 2
    $null=State @('capture','--checkout',$root,'--output-dir',(Join-Path $root 'unsafe')) 2
    $null=State @('capture','--checkout',$root,'--output-dir',(Join-Path $root '.git\unsafe')) 2
    $null=State @('capture','--checkout',$root,'--output-dir',(Join-Path ($root.ToUpperInvariant()) 'case-alias-unsafe')) 2
    [IO.File]::WriteAllBytes((Join-Path $root 'raw.txt'),$utf8.GetBytes('bravo'+$lf))
    $edited=Capture
    $null=State @('compare','--before',$first,'--after',$edited,'--output-dir',(Join-Path $PSScriptRoot 'same-size')) 1
    [IO.File]::WriteAllBytes((Join-Path $root 'raw.txt'),$utf8.GetBytes('alpha'+$crlf))
    $crlfCapture=Capture
    $null=State @('compare','--before',$first,'--after',$crlfCapture,'--output-dir',(Join-Path $PSScriptRoot 'raw-crlf')) 1
    [IO.File]::WriteAllBytes((Join-Path $root 'untracked café &.txt'),$utf8.GetBytes('new'))
    $dirty=Capture
    $gate=ConvertFrom-Json ($utf8.GetString((State @('preflight','--capture-dir',$dirty)).Stdout))
    $paths=@($gate.paths | ForEach-Object { $utf8.GetString([Convert]::FromBase64String($_)) })
    Assert ($gate.uncommitted -and $paths.Count -eq 2 -and $paths -contains 'raw.txt' -and $paths -contains 'untracked café &.txt') 'Exact Unicode own-path inventory lost'
    Assert ($index -ceq [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $root '.git\index')))) 'Source index changed'
    Assert ($config -ceq [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $root '.git\config')))) 'Source config changed'
    $null=State @('git-read','--checkout',$root,'--','rev-parse','--verify','HEAD')
    $show=State @('git-read','--checkout',$root,'--','show','HEAD:raw.txt')
    Assert ($utf8.GetString($show.Stdout) -ceq ('alpha'+$lf)) 'git-read raw bytes changed'
    foreach ($command in @(@('status'),@('diff','--no-index',$root,$PSScriptRoot),@('diff','--','..\escape'),@('symbolic-ref','--delete','HEAD'),@('diff','--ignore-submodules=none'))) {
        $null=State (@('git-read','--checkout',$root,'--') + $command) 2
    }
    foreach ($literal in @('', 'literal " quote', '--', 'café & $;%()')) {
        $null=State @('git-read','--checkout',$root,'--','check-ref-format','--branch',$literal) 1
    }

    foreach ($literal in @('', 'literal " quote', '--', 'café & $;%()')) {
        $quoted=State @('git-read','--checkout',$root,'--','rev-parse','--sq-quote',$literal)
        Assert ($utf8.GetString($quoted.Stdout) -ceq (" '"+$literal+"'"+$lf)) 'Actual git-read argv changed'
    }
    $null=State @() 2
    $null=State @('resolve')
    GitWrite @('-C',$root,'add','--all')
    $staged=Capture
    $gate=ConvertFrom-Json ($utf8.GetString((State @('preflight','--capture-dir',$staged)).Stdout))
    Assert ($gate.uncommitted -and [Convert]::FromBase64String($gate.staged).Length -gt 0) 'Staged change missing'
    $linked=Join-Path $PSScriptRoot 'linked café $;'
    GitWrite @('-C',$root,'-c','core.autocrlf=false','-c','core.eol=lf','worktree','add','--detach',$linked,'HEAD')
    $script:protected=[string[]]@($root,(Join-Path $root '.git'),$linked)
    $null=State @('capture','--checkout',$linked,'--output-dir',(Join-Path $PSScriptRoot 'linked-capture'))
    $linkedFirst=Join-Path $PSScriptRoot 'linked-capture'
    $linkedSecond=Join-Path $PSScriptRoot 'linked-second'
    $null=State @('capture','--checkout',$linked,'--output-dir',$linkedSecond)
    $null=State @('compare','--before',$linkedFirst,'--after',$linkedSecond,'--output-dir',(Join-Path $PSScriptRoot 'linked-identical'))
    [IO.File]::WriteAllBytes((Join-Path $linked 'raw.txt'),$utf8.GetBytes('bravo'+$lf))
    $linkedEdit=Join-Path $PSScriptRoot 'linked-edit'
    $null=State @('capture','--checkout',$linked,'--output-dir',$linkedEdit)
    $null=State @('compare','--before',$linkedFirst,'--after',$linkedEdit,'--output-dir',(Join-Path $PSScriptRoot 'linked-changed')) 1
    $null=State @('git-read','--checkout',$linked,'--','worktree','list','--porcelain','-z')

    $null=State @('git-read','--checkout',$root,'--','diff','--','\\invalid-native-server\share\escape') 2
    $null=State @('preflight','--capture-dir','C:drive-relative') 2
    [IO.Directory]::Delete((Join-Path $root 'tracked'),$true)
    [IO.File]::WriteAllBytes((Join-Path $root 'tracked'),$utf8.GetBytes('blocked'))
    $blocked=Capture
    $blockedSnapshot=[CheckoutState.Json]::Read([IO.File]::ReadAllText((Join-Path $blocked 'snapshot.json')))
    $blockedKey='path:'+[Convert]::ToBase64String($utf8.GetBytes('tracked/leaf.txt'))
    Assert ($blockedSnapshot['fields'][$blockedKey]['at'] -ceq [Convert]::ToBase64String($utf8.GetBytes('tracked'))) 'Blocked parent was traversed'
    Assert ($blockedSnapshot['fields'][$blockedKey]['kind'] -ceq 'file') 'Blocked parent content missing'
    [IO.File]::Delete((Join-Path $root 'tracked'))
    [IO.Directory]::CreateDirectory((Join-Path $root 'tracked')) | Out-Null
    [IO.File]::WriteAllBytes((Join-Path $root 'tracked\leaf.txt'),$utf8.GetBytes('leaf'+$lf))
    $malformed=Join-Path $PSScriptRoot 'malformed'
    [IO.Directory]::CreateDirectory($malformed) | Out-Null
    [IO.File]::WriteAllText((Join-Path $malformed 'snapshot.json'),'{bad',$utf8)
    $null=State @('preflight','--capture-dir',$malformed) 2
    $null=State @('compare','--before',$first,'--after',$malformed,'--output-dir',(Join-Path $PSScriptRoot 'unavailable')) 2
    $wide='{"file":340282366920938463463374607431768211455,"volume":18446744073709551615}'
    Assert ([CheckoutState.Json]::Write([CheckoutState.Json]::Read($wide)) -ceq $wide) 'Lossless unsigned 128-bit JSON failed'
    $request=Join-Path ([IO.Path]::GetTempPath()) ('checkout-state-request-' + [Guid]::NewGuid().ToString('N'))
    [CheckoutState.Native]::MakePrivate($request)
    try {
        $requestFile=Join-Path $request 'argv.json'
        foreach ($badJson in @('{}','[1]','["resolve",]','["resolve"] trailing')) {
            [IO.File]::WriteAllText($requestFile,$badJson,$utf8)
            $r=Direct @('-NoProfile','-ExecutionPolicy','Bypass','-File',$stateScript,'--argv-file',$requestFile)
            Assert ($r.ExitCode -eq 2) 'Malformed envelope accepted'
        }
        [IO.File]::WriteAllText($requestFile,'["resolve"]',$utf8)
        $r=Direct @('-NoProfile','-ExecutionPolicy','Bypass','-File',$stateScript,'--argv-file',$requestFile,'extra')
        Assert ($r.ExitCode -eq 2) 'Extra envelope tokens accepted'

        $alias=Join-Path ([IO.Path]::GetTempPath()) ('checkout-state-request-'+[Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Junction -Path $alias -Target $request -ErrorAction Stop | Out-Null
        try {
            $r=Direct @('-NoProfile','-ExecutionPolicy','Bypass','-File',$stateScript,'--argv-file',(Join-Path $alias 'argv.json'))
            Assert ($r.ExitCode -eq 2) 'Reparse request ancestor accepted'
        } finally { [IO.Directory]::Delete($alias) }
        $r=Direct @('-NoProfile','-ExecutionPolicy','Bypass','-File',$stateScript,'--argv-file',(Join-Path $PSScriptRoot 'outside-temp.json'))
        Assert ($r.ExitCode -eq 2) 'Unsafe envelope root accepted'
        $acl=[IO.File]::GetAccessControl($requestFile)
        $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule((New-Object Security.Principal.SecurityIdentifier('S-1-1-0')),'Write','Allow')))
        [IO.File]::SetAccessControl($requestFile,$acl)
        $r=Direct @('-NoProfile','-ExecutionPolicy','Bypass','-File',$stateScript,'--argv-file',$requestFile)
        Assert ($r.ExitCode -eq 2) 'Foreign writable request accepted'
    } finally { [IO.Directory]::Delete($request,$true) }

    $converted=Join-Path $PSScriptRoot 'converted café'
    GitWrite @('-c','core.autocrlf=true','clone','-q',$root,$converted)
    $convertedRaw=Join-Path $converted 'raw.txt'
    [IO.File]::WriteAllBytes($convertedRaw,$utf8.GetBytes('alpha'+$crlf))
    $convertedIndex=Join-Path $converted '.git\index'
    [IO.File]::SetLastWriteTimeUtc($convertedIndex,[IO.File]::GetLastWriteTimeUtc($convertedRaw))
    $racyIndex=[Convert]::ToBase64String([IO.File]::ReadAllBytes($convertedIndex))
    $racyCapture=Join-Path $PSScriptRoot 'converted-racy'
    $null=State @('capture','--checkout',$converted,'--output-dir',$racyCapture)
    $racy=ConvertFrom-Json ($utf8.GetString((State @('preflight','--capture-dir',$racyCapture)).Stdout))
    Assert ($racy.uncommitted -and $racy.paths -contains [Convert]::ToBase64String($utf8.GetBytes('raw.txt'))) 'Converted racy state incorrectly clean'
    Assert ($racyIndex -ceq [Convert]::ToBase64String([IO.File]::ReadAllBytes($convertedIndex))) 'Read-only gate refreshed source index'
    Record 'windows-converted-racy' 'pass' ('Dirty gate; possible cause isolated-normalization-not-applied; exact capture '+$racyCapture+'; no source refresh')
    Record 'windows-state' 'pass' ('Native NTFS, PowerShell ' + $PSVersionTable.PSVersion + ', Git ' + $git)
    Record 'windows-source-preservation' 'pass' 'Source index/config byte-identical'
    Record 'windows-envelope' 'pass' 'Exact typed recipe; zero/one arrays, literal argv, malformed/extra tokens, unsafe ACL'
    $target=Join-Path $PSScriptRoot 'junction target'
    [IO.Directory]::CreateDirectory($target) | Out-Null
    $junction=Join-Path $root 'junction'
    try {
        New-Item -ItemType Junction -Path $junction -Target $target -ErrorAction Stop | Out-Null
        $jcap=Capture
        $snapshot=[CheckoutState.Json]::Read([IO.File]::ReadAllText((Join-Path $jcap 'snapshot.json')))
        $key='path:' + [Convert]::ToBase64String($utf8.GetBytes('junction'))
        Assert ($snapshot['fields'][$key]['kind'] -eq 'symlink') 'Junction followed'
        Record 'windows-junction' 'pass' 'Literal reparse target; no target traversal'
    } catch { if (Test-Path $junction) { throw }; Record 'windows-junction' 'unavailable' $_.Exception.Message }


    $pin=[CheckoutState.Native]::Open((Join-Path $root '.git'),$true,$false,$true)
    try {
        $moved=$false
        try { [IO.Directory]::Move((Join-Path $root '.git'),(Join-Path $root '.git-moved')); $moved=$true } catch [IO.IOException] {}
        if ($moved) { [IO.Directory]::Move((Join-Path $root '.git-moved'),(Join-Path $root '.git')) }
        Assert (-not $moved) 'Administrative directory was replaceable while pinned'
    } finally { $pin.Dispose() }
    Record 'windows-administrative-pinning' 'pass' 'Real native directory rename refused while protected handle is held'
    $refs=Join-Path $root '.git\refs'
    $saved=Join-Path $PSScriptRoot 'saved refs'
    [IO.Directory]::Move($refs,$saved)
    try {
        New-Item -ItemType Junction -Path $refs -Target $saved -ErrorAction Stop | Out-Null
        $unavailable=Capture 2
        $diag=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $unavailable 'diagnostic.json')))
        Assert ($diag.complete -eq $false -and $diag.errors.Count -gt 0) 'Administrative reparse accepted'
        Record 'windows-administrative-reparse' 'pass' 'Unavailable diagnostic; protected ancestors are not followed'
    } finally {
        if (Test-Path $refs) { [IO.Directory]::Delete($refs) }
        [IO.Directory]::Move($saved,$refs)
    }
    Record 'windows-cross-drive' 'unavailable' 'No second owned writable native volume fixture'
    Record 'windows-refs-dev-drive' 'unavailable' 'No ReFS/Dev Drive fixture; full-width codec covered separately'
    Record 'windows-python-native-interoperability' 'unavailable' 'No verified native Windows Python'
} catch {
    Record 'windows-state' 'fail' ($_ | Out-String)
    [IO.File]::WriteAllText($report,(ConvertTo-Json -InputObject @($rows.ToArray()) -Depth 20),$utf8)
    [Console]::Error.WriteLine(($_ | Out-String))
    exit 1
}
[IO.File]::WriteAllText($report,(ConvertTo-Json -InputObject @($rows.ToArray()) -Depth 20),$utf8)
exit 0
'''


def windows_state():
    interop = os.name != 'nt'
    powershell = shutil.which('powershell.exe')
    if not powershell:
        record('windows-native', 'unavailable', 'No accessible installed native PowerShell.')
        return
    if interop and not shutil.which('wslpath'):
        record('windows-native', 'unavailable', 'Cannot resolve native fixture paths safely.')
        return
    code = r'''$p=Join-Path ([IO.Path]::GetTempPath()) ('checkout-native-'+[Guid]::NewGuid().ToString('N')); $s=New-Object Security.AccessControl.DirectorySecurity; $u=[Security.Principal.WindowsIdentity]::GetCurrent().User; $s.SetOwner($u); $s.SetAccessRuleProtection($true,$false); $s.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($u,'FullControl','ContainerInherit,ObjectInherit','None','Allow'))); if ([IO.Directory]::Exists($p)) { throw 'Fixture path already exists' }; [IO.Directory]::CreateDirectory($p,$s) | Out-Null; [Console]::Write($p)'''
    native_temp = run([powershell, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand',
                       base64.b64encode(code.encode('utf-16-le')).decode()]).stdout.decode('utf-8').strip()
    temp = Path(run(['wslpath', '-u', native_temp]).stdout.decode().strip()) if interop else Path(native_temp)
    staging = temp
    (staging / 'state').mkdir()
    for name in ['checkout-state.ps1', 'checkout-state.windows.cs']:
        shutil.copy2(SCRIPTS / name, staging / 'state' / name)
    doc = (ROOT / 'skills/independent-review/references/checkout-state.md').read_text(encoding='utf-8')
    section = doc.split('## Native Windows typed invocation', 1)[1]
    fence = chr(96) * 3
    recipe = section.split(fence + 'powershell\n', 1)[1].split(fence, 1)[0]
    (staging / 'consumer-recipe.ps1').write_text(recipe, encoding='utf-8-sig')
    (staging / 'fixture.ps1').write_text(WINDOWS_FIXTURE, encoding='utf-8-sig')
    native_script = str(staging / 'fixture.ps1')
    native_power = powershell
    if interop:
        native_script = run(['wslpath', '-w', native_script]).stdout.decode().strip()
        native_power = run(['wslpath', '-w', powershell]).stdout.decode().strip()
    fixed = "$env:PSExecutionPolicyPreference='Restricted'; & '" + native_power.replace("'", "''") + "' -NoProfile -ExecutionPolicy Bypass -File '" + native_script.replace("'", "''") + "'; exit $LASTEXITCODE"
    result = run([powershell, '-NoProfile', '-EncodedCommand',
                  base64.b64encode(fixed.encode('utf-16-le')).decode()], want=None)
    for name in ['windows-results.json', 'windows-commands.jsonl', 'windows-gate-hints.jsonl']:
        if (staging / name).exists():
            shutil.copy2(staging / name, EVIDENCE / name)
    record('windows-controller', 'observed', ('WSL interop controller; native NTFS/PowerShell processes; ' if interop else 'Native Windows controller; ') + str(staging))
    if (EVIDENCE / 'windows-results.json').exists():
        for row in json.loads((EVIDENCE / 'windows-results.json').read_text(encoding='utf-8-sig')):
            record(row['name'], row['status'], row['detail'])
    if result.returncode:
        raise AssertionError('Native Windows fixture failed: ' + result.stderr.decode(errors='replace'))


def main():
    print('Evidence: ' + str(EVIDENCE), flush=True)
    try:
        if os.name != 'nt':
            posix_state()
        windows_state()
    except Exception as exc:
        record('suite', 'fail', str(exc))
        return 1
    finally:
        (EVIDENCE / 'results.json').write_text(json.dumps(RESULTS, indent=2), encoding='utf-8')
    return 0


if __name__ == '__main__':
    sys.exit(main())
