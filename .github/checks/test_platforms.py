#!/usr/bin/env python3
"""Focused disposable smoke. Python is the external test harness only."""
import base64
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
ARTIFACTS = Path(os.environ.get('NATIVE_SMOKE_ARTIFACTS') or tempfile.mkdtemp(prefix='skill-platform-smoke-'))
ARTIFACTS.mkdir(parents=True, exist_ok=True)
RESULTS = []


def run(argv, *, cwd=None, env=None, want=0):
    result = subprocess.run([str(v) for v in argv], cwd=cwd, env=env, capture_output=True, timeout=90)
    with (ARTIFACTS / 'commands.jsonl').open('a') as out:
        out.write(json.dumps(dict(argv=list(map(str, argv)), cwd=str(cwd or Path.cwd()), exit=result.returncode,
                                 stdout=base64.b64encode(result.stdout).decode(), stderr=base64.b64encode(result.stderr).decode())) + '\n')
    if want is not None:
        assert result.returncode == want, (argv, result.returncode, result.stdout, result.stderr)
    return result


def report(name, result, detail):
    row = dict(name=name, result=result, detail=detail)
    RESULTS.append(row)
    print(json.dumps(row), flush=True)


def recipe(language):
    text = (ROOT / 'skills/independent-review/references/checkout-state.md').read_text()
    return text.split('```' + language + '\n', 1)[1].split('```', 1)[0]


def posix_git():
    root = ARTIFACTS / 'ordinary Git café $;'
    root.mkdir()
    run(['git', 'init', '-q', root])
    (root / 'tracked').write_bytes(b'before\n')
    run(['git', '-C', root, 'add', '--all'])
    run(['git', '-C', root, '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.test', 'commit', '-qm', 'fixture'])
    def capture(name, checkout=root):
        evidence = ARTIFACTS / name
        evidence.mkdir()
        env = dict(os.environ, checkout=str(checkout), evidence=str(evidence))
        run(['bash', '-c', recipe('bash')], env=env)
        return evidence
    first = capture('posix-before')
    assert all((first / (name + '.exit')).read_text().strip() == '0' for name in ('head', 'status', 'worktree-diff', 'cached-diff'))
    assert not (first / 'status.stdout').read_bytes()
    same = capture('posix-same')
    for name in ('head', 'status', 'worktree-diff', 'cached-diff'):
        run(['cmp', first / (name + '.stdout'), same / (name + '.stdout')])
    (root / 'tracked').write_bytes(b'after\n')
    (root / 'untracked $;.txt').write_bytes(b'untracked')
    dirty = capture('posix-dirty')
    assert b' M tracked\0' in (dirty / 'status.stdout').read_bytes()
    assert b'?? untracked $;.txt\0' in (dirty / 'status.stdout').read_bytes()
    run(['cmp', first / 'status.stdout', dirty / 'status.stdout'], want=1)
    run(['git', '-C', root, 'add', '--', 'tracked'])
    staged = capture('posix-staged')
    assert (staged / 'cached-diff.stdout').read_bytes()
    missing = capture('posix-failed', root / 'missing')
    assert all((missing / (name + '.exit')).read_text().strip() != '0' for name in ('head', 'status', 'worktree-diff', 'cached-diff'))
    report('posix-ordinary-git', 'pass', 'documented recipe: byte outputs, unchanged/dirty/staged comparisons and real failed-command exits')


def consumer_recipe(relative, language, index=0):
    return (ROOT / relative).read_text().split('```' + language + '\n')[index + 1].split('```', 1)[0]


def posix_consumers():
    fixture = ARTIFACTS / 'posix-consumers'; fixture.mkdir()
    checkout = fixture / 'docs café $;'; checkout.mkdir()
    run(['git', 'init', '-q', checkout])
    doc = checkout / 'doc café $;.md'
    body = b'\xef\xbb\xbf# caf\xc3\xa9  \nSecond\tline\n'
    doc.write_bytes(body)
    run(['git', '-C', checkout, 'add', '--', doc.name])
    run(['git', '-C', checkout, '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.test', 'commit', '-qm', 'document'])
    sha = run(['git', '-C', checkout, 'rev-parse', 'HEAD']).stdout.decode().strip()
    mark = ('Review: clean, 2026-11-03, reviewer codex, commit ' + sha + '\n').encode()
    recipe = consumer_recipe('skills/refining-task-docs/references/review-mark.md', 'bash', 1)
    for name, content, expected in [('lf', body+mark, 0), ('crlf', (body+mark).replace(b'\n',b'\r\n'), 0),
                                    ('mixed', body+mark.replace(b'\n',b'\r\n'), 0),
                                    ('mixed-body', body.replace(b'Second\tline\n', b'Second\tline\r\n')+mark, 1),
                                    ('edit', body.replace(b'  ',b' ')+mark, 1), ('double', body+mark+mark, 1),
                                    ('missing', body+mark.replace(sha.encode(),b'0'*40), 1)]:
        doc.write_bytes(content)
        evidence = fixture / name; evidence.mkdir()
        env = dict(os.environ, file=str(doc), docs_repo=str(checkout), rel=doc.name, freshness_dir=str(evidence))
        run(['bash', '-c', recipe+'\nexit "$freshness_exit"'], env=env, want=expected)
    # A real failing show producer must be unavailable even with an empty output.
    bin_dir = fixture / 'bin'; bin_dir.mkdir()
    git = bin_dir / 'git'
    git.write_text('#!/bin/bash\nif [[ $3 == show ]]; then exec "$REAL_GIT" -C "$2" show nonexistent-ref; fi\nexec "$REAL_GIT" "$@"\n')
    git.chmod(0o700)
    doc.write_bytes(body+mark); evidence=fixture / 'show-failed'; evidence.mkdir()
    env = dict(os.environ, PATH=str(bin_dir)+os.pathsep+os.environ['PATH'], REAL_GIT=shutil.which('git'), file=str(doc), docs_repo=str(checkout), rel=doc.name, freshness_dir=str(evidence))
    run(['bash', '-c', recipe+'\nexit "$freshness_exit"'], env=env, want=2)
    assert (evidence / 'show.exit').read_text().strip() != '0'

    # Execute the actual documented Claude recipe with a disposable CLI transport.
    fake = bin_dir / 'claude'
    fake.write_text('#!/bin/bash\ncat > "$PROMPT_LOG"\nprintf "%s\\n" "$EVENTS"\nprintf stderr >&2\nexit "$PRODUCER_EXIT"\n')
    fake.chmod(0o700)
    prompt = fixture / 'prompt.md'; prompt.write_bytes(b'prompt \x00 caf\xc3\xa9\r\n')
    recipe = consumer_recipe('skills/independent-review/references/cli-reviewers.md', 'bash', 1)
    for name, events, producer, extraction in [('valid', '{"type":"result","result":"VERDICT: CLEAN"}', 0, 0), ('failed-producer', '{"type":"result","result":"answer"}', 17, 0), ('bad-json', '{bad', 0, 1), ('missing-result', '{"type":"system"}', 0, 1)]:
        attempt=fixture / ('cli-'+name); attempt.mkdir()
        env=dict(os.environ, PATH=str(bin_dir)+os.pathsep+os.environ['PATH'], PROMPT_LOG=str(attempt/'prompt.raw'), EVENTS=events, PRODUCER_EXIT=str(producer), task_checkout=str(checkout), round_prompt=str(prompt), round_dir=str(attempt), review_model='cli-default', review_effort='cli-default')
        run(['bash', '-c', recipe], env=env)
        assert (attempt/'prompt.raw').read_bytes() == prompt.read_bytes()
        assert int((attempt/'producer.exit').read_text()) == producer
        actual=int((attempt/'extraction.exit').read_text())
        assert actual == 0 if extraction == 0 else actual != 0
        assert (attempt/'stderr.log').read_bytes() == b'stderr'
    report('posix-consumers', 'pass', 'documented no-Python freshness and CLI recipes: byte preservation, uniform CRLF, changes/missing revision, failed show, raw prompt/stdout/stderr and separate producer/extraction exits; synthetic CLI only')


def posix_child():
    fixture = ARTIFACTS / 'posix-child'; fixture.mkdir()
    bin_dir = fixture / 'bin'; bin_dir.mkdir()
    terminal = bin_dir / 'xterm'
    terminal.write_text('#!/bin/bash\nif [[ $1 == -help ]]; then echo "-e command"; exit; fi\nshift\nexec "$@"\n')
    terminal.chmod(0o700)
    for command in ('bash', 'mkdir', 'grep', 'cksum', 'sleep', 'cat', 'head', 'rm', 'sed'):
        (bin_dir / command).symlink_to(shutil.which(command))
    cli = bin_dir / 'claude'
    cli.write_text('#!/bin/bash\nprintf "%s\\0" "$@" > "$FIXTURE_LOG"\nprintf "%s\\0" "$CODEX_HOME" "$CLAUDE_CONFIG_DIR" "$ORDINARY_CONFIG" "${CLAUDECODE-absent}" > "$FIXTURE_LOG.env"\nif [[ ${FIXTURE_EXIT-} ]]; then exit "$FIXTURE_EXIT"; fi\nif [[ ${FIXTURE_IGNORE_TERM-} ]]; then trap "" TERM; while true; do read -t 1 || true; done; fi\nexec sleep 90\n')
    cli.chmod(0o700)
    checkout = fixture / 'checkout café $;'; checkout.mkdir()
    brief = fixture / 'brief café $; ".md'; brief.write_text('fixture')
    env = {k:v for k,v in os.environ.items() if not k.startswith(('CHILD_SESSION_', 'HERDR_', 'CLAUDE', 'CODEX_'))}
    env.update(PATH=str(bin_dir), CHILD_SESSION_BACKEND='terminal', CHILD_SESSION_RUNTIME_DIR=str(fixture / 'runtime'),
               HERDR_PANE_ID='stale-parent', FIXTURE_LOG=str(fixture / 'args'), CODEX_HOME='config $;', CLAUDE_CONFIG_DIR='claude café', CLAUDECODE='parent', ORDINARY_CONFIG='full environment')
    child = ROOT / 'skills/child-sessions/scripts/child-session'
    def call(*args, want=0): return run([child, *args], env=env, want=want)
    call('runtime-dir')
    model = 'literal " café $HOME; `false`'
    try:
        call('open', '--split', 'right', '--model', model, 'probe', checkout, brief)
        for _ in range(100):
            if (fixture / 'args').exists(): break
            time.sleep(.05)
        argv = (fixture / 'args').read_bytes().split(b'\0')[:-1]
        assert argv == [b'--permission-mode', b'bypassPermissions', b'--model', model.encode(), ('Read the brief at ' + str(brief) + ' completely and carry it out.').encode()]
        assert (fixture / 'args.env').read_bytes().split(b'\0')[:-1] == [b'config $;', 'claude café'.encode(), b'full environment', b'absent']
        caps = json.loads(call('capabilities', 'probe').stdout)
        assert caps['backend'] == 'terminal' and caps['close'] and not caps['peek'] and not caps['send'] and not caps['window_close']
        call('alive', 'probe'); call('send', 'probe', 'never guessed', want=2)
        status = fixture / 'status.md'
        call('wait', 'probe', status, '0', want=124)
        status.write_text('STATUS: done garbage\n')
        call('wait', 'probe', status, '1', want=124)
        status.write_text('STATUS: blocked\nQuestions\n')
        assert call('wait', 'probe', status, '0').stdout == b'STATUS: blocked\n'
        record = next((fixture / 'runtime').glob('*.record'))
        original = record.read_bytes()
        with record.open('ab') as out: out.write(b'agent_start\0mistaken\0')
        call('close', 'probe', want=2)
        record.write_bytes(original)
        call('alive', 'probe')
        call('close', 'probe'); call('alive', 'probe', want=1)
        env['FIXTURE_EXIT'] = '23'
        call('open', 'fast', checkout, brief)
        for _ in range(100):
            if call('alive', 'fast', want=None).returncode == 1: break
            time.sleep(.05)
        else: raise AssertionError('fast agent remained alive')
        record = next(p for p in (fixture / 'runtime').glob('*.record') if b'name\0fast\0' in p.read_bytes())
        assert b'exit_code\x0023\x00' in record.read_bytes()
        call('close', 'fast')
        del env['FIXTURE_EXIT']
        env['FIXTURE_IGNORE_TERM'] = '1'
        call('open', 'stubborn', checkout, brief)
        stubborn = next(p for p in (fixture / 'runtime').glob('*.record') if b'name\0stubborn\0' in p.read_bytes())
        fields = stubborn.read_bytes().split(b'\0')[:-1]
        data = dict(zip(fields[::2], fields[1::2]))
        call('close', 'stubborn', want=2)
        # The launcher may be gone, but the separately recorded agent still
        # must be observed before declaring stop/closing its owned window.
        process_id = int(data[b'agent_pid'])
        current = Path('/proc') / str(process_id) / 'stat'
        actual_start = current.read_text().rsplit(') ', 1)[1].split()[19].encode()
        assert actual_start == data[b'agent_start']
        import signal
        os.kill(process_id, signal.SIGKILL)
        call('close', 'stubborn')
    finally:
        call('close', 'probe', want=None); call('close', 'fast', want=None); call('close', 'stubborn', want=None)
    report('posix-child', 'pass', 'synthetic terminal with actual processes: literal argv, full environment/filter exceptions, capabilities, status, fast exit and PID/start refusal')

    # An unrelated v-NAME session must survive optional WSL view handling.
    tmux = shutil.which('tmux')
    if tmux:
        wrapper = bin_dir / 'tmux'
        wrapper.write_text('#!/bin/bash\nexec ' + tmux + ' -f /dev/null "$@"\n')
        wrapper.chmod(0o700)
        (bin_dir / 'wt.exe').write_text('#!/bin/bash\nexit 0\n')
        (bin_dir / 'wt.exe').chmod(0o700)
        socket_temp = tempfile.TemporaryDirectory(prefix='skills-tmux-')
        env.update(CHILD_SESSION_BACKEND='tmux', CHILD_SESSION_TMUX_SESSION='owned-fixture', CHILD_SESSION_TAB='1', TMUX_TMPDIR=socket_temp.name)
        env.pop('FIXTURE_IGNORE_TERM', None)
        try:
            run([wrapper, 'new-session', '-d', '-s', 'v-viewchild', 'exec sleep 90'], env=env)
            call('open', 'viewchild', checkout, brief)
            call('close', 'viewchild')
            run([wrapper, 'has-session', '-t', '=v-viewchild'], env=env)
            call('open', 'freshview', checkout, brief)
            run([wrapper, 'has-session', '-t', '=v-freshview'], env=env)
            call('close', 'freshview')
            run([wrapper, 'has-session', '-t', '=v-freshview'], env=env, want=1)
            run([wrapper, 'has-session', '-t', '=v-viewchild'], env=env)
        finally:
            run([wrapper, 'kill-server'], env=env, want=None)
            socket_temp.cleanup()
        report('posix-tmux-view-ownership', 'pass', 'unrelated v-NAME retained; only newly owned exact view ID closed; synthetic wt transport')


WINDOWS = r'''
param([string]$Owner,[string]$GitRecipe,[string]$Root,[string]$ReviewerIO,[string]$FreshnessRecipe)
$ErrorActionPreference='Stop'
$PSNativeCommandUseErrorActionPreference=$false
. $Owner
$power=(Get-Process -Id $PID).Path
function Assert($condition,$message) { if (-not $condition) { throw $message } }
function Capture-Git($Label,$CheckoutPath) {
    $checkout=$CheckoutPath;$evidence=Join-Path $Root $Label;[IO.Directory]::CreateDirectory($evidence)|Out-Null
    . $GitRecipe
    return $evidence
}
$checkout=Join-Path $Root 'Git café $;';[IO.Directory]::CreateDirectory($checkout)|Out-Null
& git init -q $checkout;if ($LASTEXITCODE) { throw 'git init failed' }
[IO.File]::WriteAllText((Join-Path $checkout 'tracked'),"before`n")
& git -C $checkout add --all
& git -C $checkout -c user.name=Fixture -c user.email=fixture@example.test commit -qm fixture
if ($LASTEXITCODE) { throw 'fixture commit failed' }
$first=Capture-Git 'before' $checkout;$same=Capture-Git 'same' $checkout
foreach ($name in 'head','status','worktree-diff','cached-diff') {
    Assert ((Get-Content -LiteralPath "$first/$name.exit") -eq '0') 'Git capture failed'
    & fc.exe /b (Join-Path $first ($name+'.stdout')) (Join-Path $same ($name+'.stdout')) > $null
    Assert ($LASTEXITCODE -eq 0) 'unchanged Git bytes differ'
}
[IO.File]::WriteAllText((Join-Path $checkout 'tracked'),"after`n")
$dirty=Capture-Git 'dirty' $checkout
Assert ([IO.File]::ReadAllBytes("$dirty/status.stdout") -contains 0) 'NUL status lost'
Assert ((Get-Item -LiteralPath "$dirty/worktree-diff.stdout").Length -gt 0) 'dirty diff missing'
& git -C $checkout add -- tracked
$staged=Capture-Git 'staged' $checkout
Assert ((Get-Item -LiteralPath "$staged/cached-diff.stdout").Length -gt 0) 'staged diff missing'
$bad=Capture-Git 'failed' (Join-Path $Root 'missing')
foreach ($name in 'head','status','worktree-diff','cached-diff') { Assert ((Get-Content -LiteralPath "$bad/$name.exit") -ne '0') 'Git failure became clean' }


# Native consumer I/O and freshness use their published recipes/owner helper.
. $ReviewerIO
$doc=Join-Path $checkout 'doc café $;.md'
$body=[Text.UTF8Encoding]::new($false).GetBytes("# café  `nSecond`tline`n")
[IO.File]::WriteAllBytes($doc,$body)
& git -C $checkout -c core.autocrlf=false add -- 'doc café $;.md'
& git -C $checkout -c user.name=Fixture -c user.email=fixture@example.test commit -qm document
$sha=(& git -C $checkout rev-parse HEAD).Trim()
$mark="Review: clean, 2026-11-03, reviewer codex, commit $sha`n"
$utf8=[Text.UTF8Encoding]::new($false)
$text=$utf8.GetString($body)+$mark
$cases=@(
    @{name='lf';text=$text;expected=0},
    @{name='crlf';text=$text.Replace("`n","`r`n");expected=0},
    @{name='edit';text=$text.Replace('café  ','café ');expected=1},
    @{name='mixed';text=$text.Replace("Second`tline`n","Second`tline`r`n");expected=1},
    @{name='double';text=($text+$mark);expected=1},
    @{name='missing';text=$text.Replace($sha,('0'*40));expected=1}
)
foreach ($case in $cases) {
    [IO.File]::WriteAllText($doc,$case.text,$utf8)
    $docs_repo=$checkout;$file=$doc;$rel='doc café $;.md'
    $freshness_dir=Join-Path $Root ('fresh-'+$case.name);[IO.Directory]::CreateDirectory($freshness_dir)|Out-Null
    . $FreshnessRecipe
    Assert ($freshness_exit -eq $case.expected) ('native freshness '+$case.name)
}
$script:RealGit=(Get-Command git -CommandType Application).Source
function git {
    if ($args[2] -eq 'show') { & $script:RealGit -C $args[1] show nonexistent-ref }
    else { & $script:RealGit @args }
}
[IO.File]::WriteAllText($doc,$text,$utf8)
$freshness_dir=Join-Path $Root 'fresh-show-failed';[IO.Directory]::CreateDirectory($freshness_dir)|Out-Null
. $FreshnessRecipe
Assert ($freshness_exit -eq 2) 'show producer failure became fresh/stale'
Remove-Item Function:git
$receiver=Join-Path $Root 'reviewer receiver café $;.ps1'
$receiverText=@'
[IO.File]::WriteAllText($env:REVIEW_ARGS,(ConvertTo-Json -InputObject @($args) -Compress))
[Console]::OpenStandardInput().CopyTo([Console]::OpenStandardOutput())
[Console]::OpenStandardError().Write([byte[]]@(101,114,114,0,255))
exit 17
'@
[IO.File]::WriteAllText($receiver,$receiverText,$utf8)
$env:REVIEW_ARGS=Join-Path $Root 'reviewer-args.json'
$prompt=Join-Path $Root 'prompt raw.md';[IO.File]::WriteAllBytes($prompt,[byte[]]@(0,255,13,10,195,169))
$attempt=Join-Path $Root 'reviewer-attempt'
$values=[string[]]@('','quote " slash\','café $; --',"line`nbreak")
$r=Invoke-ReviewerProcess -Executable $receiver -Vector $values -Checkout $checkout -PromptPath $prompt -OutputDirectory $attempt
Assert ($r.ProducerExit -eq 17 -and -not $r.IOFailure) 'reviewer producer exit/I/O lost'
Assert ((Get-Content -LiteralPath (Join-Path $attempt 'producer.exit')) -eq '17') 'saved producer exit wrong'
Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $attempt 'answer.md'))) -ceq [Convert]::ToBase64String([IO.File]::ReadAllBytes($prompt))) 'reviewer prompt/stdout bytes changed'
Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $attempt 'stderr.log'))) -ceq [Convert]::ToBase64String([byte[]]@(101,114,114,0,255))) 'reviewer stderr bytes changed'
$decoded=@(ConvertFrom-Json ([IO.File]::ReadAllText($env:REVIEW_ARGS)))
Assert ($decoded.Count -eq $values.Count) 'reviewer argv count changed'
for ($i=0;$i -lt $values.Count;$i++) { Assert ($decoded[$i] -ceq $values[$i]) 'reviewer literal argv changed' }

# An npm-style text pipeline must not transform the raw prompt. Resolve the
# installed node runtime and the one target named by a copied shim shape.
$npmRoot=Join-Path $Root 'npm fixture';[IO.Directory]::CreateDirectory((Join-Path $npmRoot 'node_modules/fixture'))|Out-Null
$target=Join-Path $npmRoot 'node_modules/fixture/reviewer.js'
[IO.File]::WriteAllText($target,'process.stdin.pipe(process.stdout);process.exitCode=19;',$utf8)
$shim=Join-Path $npmRoot 'reviewer.ps1'
[IO.File]::WriteAllText($shim,'$input | & node "$basedir/node_modules/fixture/reviewer.js" $args; exit $LASTEXITCODE',$utf8)
$attempt=Join-Path $Root 'npm-attempt'
$r=Invoke-ReviewerProcess -Executable $shim -Checkout $checkout -PromptPath $prompt -OutputDirectory $attempt
Assert ($r.ProducerExit -eq 19 -and -not $r.IOFailure) 'npm producer exit lost'
Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $attempt 'answer.md'))) -ceq [Convert]::ToBase64String([IO.File]::ReadAllBytes($prompt))) 'npm text shim changed prompt bytes'
foreach ($case in @(
    @{name='ok';events='{"type":"result","result":"VERDICT: CLEAN"}';expected=0},
    @{name='malformed';events='{bad';expected=1},
    @{name='absent';events='{"type":"system"}';expected=1},
    @{name='multiple';events="{`"type`":`"result`",`"result`":`"a`"}`n{`"type`":`"result`",`"result`":`"b`"}";expected=1}
)) {
    $attempt=Join-Path $Root ('extract-'+$case.name);[IO.Directory]::CreateDirectory($attempt)|Out-Null
    [IO.File]::WriteAllText((Join-Path $attempt 'events.jsonl'),$case.events,$utf8)
    [IO.File]::WriteAllText((Join-Path $attempt 'producer.exit'),'17')
    Assert ((Export-ClaudeReviewAnswer -OutputDirectory $attempt) -eq $case.expected) ('native extraction '+$case.name)
    Assert ((Get-Content -LiteralPath (Join-Path $attempt 'producer.exit')) -eq '17') 'extraction overwrote producer exit'
}

# This fake replaces only the terminal transport. All launched shells/processes,
# literal argv, file/state APIs and ownership checks are actual native Windows.
$script:NativeInvoke=${function:Invoke-ChildSessionNative}
$script:FixtureLaunchers=New-Object 'Collections.Generic.List[Diagnostics.Process]'
function Get-ChildSessionBackend { $script:Terminal='fixture-terminal';return 'terminal' }
function Invoke-ChildSessionNative {
    param([string]$Executable,[string[]]$Vector,[string]$Cwd)
    if ($Executable -eq 'fixture-terminal') {
        $p=Start-ChildSessionProcess $Vector[1] ([string[]]$Vector[2..($Vector.Count-1)]) $Cwd $true
        $script:FixtureLaunchers.Add($p)
        return [pscustomobject]@{Stdout=[byte[]]@();Stderr=[byte[]]@();ExitCode=0}
    }
    & $script:NativeInvoke $Executable $Vector $Cwd
}
$env:CHILD_SESSION_RUNTIME_DIR=Join-Path $Root 'runtime'
$bin=Join-Path $Root 'bin';[IO.Directory]::CreateDirectory($bin)|Out-Null
$env:PATH=$bin+';'+$env:PATH
function Resolve-ChildSessionAgent { param([string]$Agent);return @{script=(Join-Path $bin 'claude.ps1')} }
$env:FIXTURE_LOG=Join-Path $Root 'agent.json'
$env:CODEX_HOME='config $;';$env:CLAUDE_CONFIG_DIR='claude café';$env:CLAUDECODE='parent';$env:ORDINARY_CONFIG='full environment'
$agent=@'
[IO.File]::WriteAllText($env:FIXTURE_LOG,(ConvertTo-Json -InputObject @{argv=@($args);cwd=$PWD.Path;config=$env:ORDINARY_CONFIG;codex=$env:CODEX_HOME;claude=$env:CLAUDE_CONFIG_DIR;metadata=$env:CLAUDECODE} -Depth 8))
if ($env:FIXTURE_EXIT) { exit ([int]$env:FIXTURE_EXIT) }
Start-Sleep -Seconds 90
'@
[IO.File]::WriteAllText((Join-Path $bin 'claude.ps1'),$agent,$script:Utf8)
$brief=Join-Path $Root 'brief café $; quote.md';[IO.File]::WriteAllText($brief,'fixture')
$model='literal " café $HOME; `false`'
try {
    Assert ((Invoke-ChildSessionDispatch @('open','--model',$model,'probe',$checkout,$brief)) -eq 0) 'open failed'
    for ($n=0;$n -lt 100 -and -not [IO.File]::Exists($env:FIXTURE_LOG);$n++) { Start-Sleep -Milliseconds 50 }
    $observed=ConvertFrom-Json ([IO.File]::ReadAllText($env:FIXTURE_LOG))
    Assert ($observed.argv.Count -eq 5 -and $observed.argv[3] -ceq $model -and $observed.argv[4] -ceq ('Read the brief at '+$brief+' completely and carry it out.')) 'literal CLI argv changed'
    Assert ($observed.config -ceq 'full environment' -and $observed.codex -ceq 'config $;' -and $observed.claude -ceq 'claude café' -and -not $observed.metadata) 'environment filtering/config failed'
    Assert ($observed.cwd -ceq $checkout) 'cwd changed'
    $record=Read-ChildSessionRecord 'probe';$caps=Get-ChildSessionCapabilities $record
    Assert ($caps.close -and -not $caps.peek -and -not $caps.send -and -not $caps.window_close) 'terminal capabilities incorrect'
    Assert ((Invoke-ChildSessionDispatch @('alive','probe')) -eq 0) 'agent not alive'
    $refused=$false;try { $null=Invoke-ChildSessionDispatch @('send','probe','never guessed') } catch { $refused=$true };Assert $refused 'unsupported input accepted'
    $status=Join-Path $Root 'status.md'
    Assert ((Invoke-ChildSessionDispatch @('wait','probe',$status,'0')) -eq 124) 'timeout changed'
    [IO.File]::WriteAllText($status,'STATUS: done garbage')
    Assert ((Invoke-ChildSessionDispatch @('wait','probe',$status,'0')) -eq 124) 'malformed status accepted'
    [IO.File]::WriteAllText($status,"STATUS: blocked`r`nQuestions")
    Assert ((Invoke-ChildSessionDispatch @('wait','probe',$status,'0')) -eq 0) 'CRLF status rejected'
    $original=$record.agent.start;$record.agent.start='mistaken';Write-ChildSessionRecord $record
    $refused=$false;try { $null=Invoke-ChildSessionDispatch @('close','probe') } catch { $refused=$true };Assert $refused 'mistaken PID/start was stopped'
    $record.agent.start=$original;Write-ChildSessionRecord $record
    Assert ((Invoke-ChildSessionDispatch @('alive','probe')) -eq 0) 'refusal killed process'
    Assert ((Invoke-ChildSessionDispatch @('close','probe')) -eq 0) 'close failed'
    Assert ((Invoke-ChildSessionDispatch @('alive','probe')) -eq 1) 'closed agent alive'
    $env:FIXTURE_EXIT='23'
    Assert ((Invoke-ChildSessionDispatch @('open','fast',$checkout,$brief)) -eq 0) 'fast open failed'
    for ($n=0;$n -lt 100;$n++) { $r=Read-ChildSessionRecord 'fast';if ($r.phase -eq 'exited') { break };Start-Sleep -Milliseconds 50 }
    Assert ($r.phase -eq 'exited' -and $r.exit_code -eq 23) 'real exit lost'
    $null=Invoke-ChildSessionDispatch @('close','fast')
    # Ordinary native argv also preserves empty strings, quotes, backslashes and newlines.
    $receiver=Join-Path $Root 'receiver.ps1'
    [IO.File]::WriteAllText($receiver,'[Console]::Write((ConvertTo-Json -InputObject @($args) -Compress));exit 17',$script:Utf8)
    $values=[string[]]@('','quote " slash\','café $; --',"line`nbreak")
    $result=& $script:NativeInvoke $power (@('-NoProfile','-ExecutionPolicy','Bypass','-File',$receiver)+$values) $Root
    Assert ($result.ExitCode -eq 17) 'native producer exit lost'
    $decoded=@(ConvertFrom-Json ($script:Utf8.GetString($result.Stdout)))
    Assert ($decoded.Count -eq $values.Count) 'argv count changed'
    for ($i=0;$i -lt $values.Count;$i++) { Assert ($decoded[$i] -ceq $values[$i]) 'native argv changed' }
    [IO.File]::WriteAllText((Join-Path $Root 'passed.json'),(ConvertTo-Json -InputObject @{version=$PSVersionTable.PSVersion.ToString();edition=$PSVersionTable.PSEdition;framework=[Runtime.InteropServices.RuntimeInformation]::FrameworkDescription;executable=$power;cases='ordinary Git, literal argv, status/exit, environment, ownership refusal, capabilities, reviewer raw I/O/producer/extraction, byte freshness/CRLF/failure';terminal='synthetic transport; native processes'}))
} finally {
    foreach ($name in 'probe','fast') { try { $null=Invoke-ChildSessionDispatch @('close',$name) } catch { [Console]::Error.WriteLine($_) } }
    foreach ($p in $script:FixtureLaunchers) {
        if (-not $p.HasExited) { $p.Kill();$p.WaitForExit() }
        $text=$p.StandardError.ReadToEnd();if ($text) { [Console]::Error.WriteLine($text) }
        $p.Dispose()
    }
}
'''


def windows():
    power = shutil.which('pwsh.exe')
    if not power:
        report('windows-pwsh', 'unavailable', 'installed native pwsh not reachable; no installation')
        return
    def encoded(text): return base64.b64encode(text.encode('utf-16-le')).decode()
    temp = run([power, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', encoded('[Console]::Write([IO.Path]::GetTempPath())')]).stdout.decode().strip()
    interop = os.name != 'nt'
    staging = Path(run(['wslpath', '-u', temp]).stdout.decode().strip()) if interop else Path(temp)
    staging = Path(tempfile.mkdtemp(prefix='skills-focused-', dir=staging))
    def native(path): return run(['wslpath', '-w', path]).stdout.decode().strip() if interop else str(path)
    (staging / 'fixture.ps1').write_text(WINDOWS, encoding='utf-8-sig')
    (staging / 'git-recipe.ps1').write_text(recipe('powershell'), encoding='utf-8-sig')
    (staging / 'freshness-recipe.ps1').write_text(consumer_recipe('skills/refining-task-docs/references/review-mark.md', 'powershell'), encoding='utf-8-sig')
    owner = native(ROOT / 'skills/child-sessions/scripts/child-session.ps1')
    script = native(staging / 'fixture.ps1'); git_recipe = native(staging / 'git-recipe.ps1'); root = native(staging)
    # Only fixed, correctly single-quoted paths enter this controller bootstrap.
    quote = lambda value: "'" + value.replace("'", "''") + "'"
    code = '& ' + quote(script) + ' -Owner ' + quote(owner) + ' -GitRecipe ' + quote(git_recipe) + ' -Root ' + quote(root) + ' -ReviewerIO ' + quote(native(ROOT / 'skills/independent-review/scripts/reviewer-process.ps1')) + ' -FreshnessRecipe ' + quote(native(staging / 'freshness-recipe.ps1'))
    run([power, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', encoded(code)])
    passed = json.loads((staging / 'passed.json').read_text(encoding='utf-8-sig'))
    shutil.copy2(staging / 'passed.json', ARTIFACTS / 'windows-passed.json')
    (ARTIFACTS / 'windows-staging.txt').write_text(str(staging))
    report('windows-pwsh', 'pass', passed)
    legacy = shutil.which('powershell.exe')
    if legacy:
        # Useful 5.1 compatibility is narrower than the current 7.6.9 runtime:
        # parse/import the helper, its 5.1 native quoting and status dispatch.
        compatibility = '. ' + quote(owner) + '; $env:CHILD_SESSION_RUNTIME_DIR=' + quote(root + '\\compatibility51') + '; $s=' + quote(root + '\\compatibility-status.md') + "; [IO.File]::WriteAllText($s,'STATUS: done'); if ((Invoke-ChildSessionDispatch @('wait','absent',$s,'0')) -ne 0) { exit 1 }; [Console]::Write($PSVersionTable.PSVersion.ToString())"
        result = run([legacy, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', encoded(compatibility)])
        report('windows-5.1-compatibility', 'pass', result.stdout.decode(errors='replace'))
    else:
        report('windows-5.1-compatibility', 'unavailable', 'legacy shell not reachable')


if __name__ == '__main__':
    try:
        if os.name == 'posix':
            posix_git(); posix_consumers(); posix_child()
        windows()
        report('macos', 'unverified', 'no native macOS host; stock Bash/ps/Terminal path audited only')
    finally:
        (ARTIFACTS / 'results.json').write_text(json.dumps(RESULTS, indent=2))
        print('Artifacts: ' + str(ARTIFACTS), flush=True)
