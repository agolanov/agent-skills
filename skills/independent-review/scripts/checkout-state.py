#!/usr/bin/env python3
"""Read-only, byte-safe phase-boundary observations; not an atomic filesystem lock."""
import argparse
import base64
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile

SCHEMA = 3
LIMITS = ('ignored untracked paths not monitored; submodule/nested-repository content '
          'not recursively monitored; special-file contents not monitored; '
          'submodule resolved HEAD and dirty state not monitored')
_VIEWS = {}


def b64(value):
    return base64.b64encode(value).decode('ascii')


def unb64(value):
    if not isinstance(value, str):
        raise ValueError('expected base64 string')
    raw = base64.b64decode(value, validate=True)
    if b64(raw) != value:
        raise ValueError('noncanonical base64')
    return raw


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=True).encode('utf-8')


def isolated_env():
    env = {k: v for k, v in os.environ.items() if not k.startswith('GIT_')}
    env.update(GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_SYSTEM=os.devnull,
               GIT_CONFIG_GLOBAL=os.devnull, GIT_OPTIONAL_LOCKS='0',
               GIT_NO_REPLACE_OBJECTS='1', GIT_TERMINAL_PROMPT='0', GIT_ATTR_NOSYSTEM='1')
    return env


def admin_open(path, directory=False):
    """Open every component without following links, including absolute parents."""
    parts = os.path.abspath(path).split(b'/')[1:]
    fd = os.open(b'/', os.O_RDONLY | os.O_DIRECTORY)
    try:
        for i, part in enumerate(parts):
            flags = os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK
            if directory or i < len(parts)-1:
                flags |= os.O_DIRECTORY
            elif not stat.S_ISREG(os.stat(part, dir_fd=fd, follow_symlinks=False).st_mode):
                raise OSError('administrative file must be ordinary and not a link')
            child = os.open(part, flags, dir_fd=fd)
            os.close(fd)
            fd = child
        result, fd = fd, None
        return result
    finally:
        if fd is not None:
            os.close(fd)


def admin_read(path, optional=False, limit=256*1024*1024, with_mtime=False):
    try:
        fd = admin_open(path)
    except FileNotFoundError:
        if optional:
            return None
        raise
    try:
        before = os.fstat(fd)
        if not stat.S_ISREG(before.st_mode) or before.st_size > limit:
            raise OSError('unsafe or oversized administrative file')
        chunks, size = [], 0
        while True:
            chunk = os.read(fd, min(1024*1024, limit+1-size))
            if not chunk:
                break
            chunks.append(chunk)
            size += len(chunk)
            if size > limit:
                raise OSError('administrative file exceeded size bound')
        if identity(before) != identity(os.fstat(fd)):
            raise OSError('administrative file changed during read')
        data = b''.join(chunks)
        return (data, before.st_mtime_ns) if with_mtime else data
    finally:
        os.close(fd)


def admin_directory(path):
    fd = admin_open(path, directory=True)
    try:
        info = os.fstat(fd)
        return [info.st_dev, info.st_ino]
    finally:
        os.close(fd)


def administration(checkout):
    dotgit = os.path.join(checkout, b'.git')
    info = os.lstat(dotgit)
    pointer = None
    if stat.S_ISDIR(info.st_mode):
        gitdir = dotgit
    elif stat.S_ISREG(info.st_mode):
        pointer = admin_read(dotgit, limit=65536)
        if not pointer.startswith(b'gitdir: ') or b'\0' in pointer:
            raise OSError('invalid outer gitfile')
        gitdir = os.path.abspath(os.path.join(checkout, pointer[8:].rstrip(b'\r\n')))
    else:
        raise OSError('outer .git must be an ordinary directory or gitfile')
    git_identity = admin_directory(gitdir)
    common_pointer = admin_read(os.path.join(gitdir, b'commondir'), optional=True, limit=65536)
    common = gitdir if common_pointer is None else os.path.abspath(
        os.path.join(gitdir, common_pointer.rstrip(b'\r\n')))
    return gitdir, common, {'gitfile': b64(pointer) if pointer is not None else None,
        'location': [info.st_dev, info.st_ino], 'gitdir': b64(gitdir),
        'gitdir_identity': git_identity, 'commondir': b64(common),
        'common_pointer': b64(common_pointer) if common_pointer is not None else None,
        'common_identity': admin_directory(common)}


@contextmanager
def private_git(checkout):
    if checkout in _VIEWS:
        yield _VIEWS[checkout]
        return
    gitdir, common, selected = administration(checkout)
    temp_root = os.path.realpath(os.fsencode(next((os.environ[k] for k in ('TMPDIR', 'TEMP', 'TMP') if os.environ.get(k)), '/tmp')))
    if any(os.path.commonpath((temp_root, protected)) == protected for protected in (checkout, gitdir, common)):
        raise OSError('temporary administration must be outside checkout and source metadata')
    with tempfile.TemporaryDirectory(prefix='checkout-state-admin-', dir=os.fsdecode(temp_root)) as temp:
        target = Path(temp)
        config = admin_read(os.path.join(common, b'config'), optional=True, limit=8*1024*1024) or b''
        source = target/'source-config'
        source.write_bytes(config)
        parsed = subprocess.run(['git', 'config', '--file', str(source), '--no-includes', '--null', '--list'],
            cwd=temp, env={**isolated_env(), 'GIT_CEILING_DIRECTORIES': os.path.dirname(temp)}, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10)
        if parsed.returncode:
            raise OSError('unreadable repository config')
        object_format = 'sha1'
        for item in nul_items(parsed.stdout):
            key, _, value = item.partition(b'\n')
            if key == b'extensions.objectformat':
                object_format = value.decode('ascii')
            elif key.startswith(b'extensions.') and key != b'extensions.worktreeconfig':
                raise OSError('unsupported repository extension: ' + repr(key))
        if object_format not in ('sha1', 'sha256'):
            raise OSError('unsupported object format')
        (target/'config').write_text('[core]\nrepositoryformatversion = '+
            ('1' if object_format == 'sha256' else '0')+
            '\nbare = false\nhooksPath = '+os.devnull+'\nfsmonitor = false\n'
            'excludesFile = '+os.devnull+'\nattributesFile = '+os.devnull+'\n'
            'autocrlf = false\nsafecrlf = false\n'+
            ('[extensions]\nobjectformat = sha256\n' if object_format == 'sha256' else ''))
        def copy_file(root, relative, optional=True):
            observed = admin_read(os.path.join(root, relative), optional=optional, with_mtime=True)
            if observed is not None:
                data, mtime = observed
                dest = target/os.fsdecode(relative)
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(data)
                # Git's racy-clean check depends on index/shared-index mtime.
                os.utime(dest, ns=(mtime, mtime))
        copy_file(gitdir, b'HEAD', optional=False)
        copy_file(gitdir, b'index')
        copy_file(common, b'packed-refs')
        copy_file(common, b'info/exclude')
        fd = admin_open(gitdir, directory=True)
        try:
            shared = [os.fsencode(n) for n in os.listdir(fd) if re.fullmatch(r'sharedindex\.[0-9a-f]+', n)]
        finally:
            os.close(fd)
        for name in shared:
            copy_file(gitdir, name, optional=False)
        count = 0
        def copy_refs(relative=b'refs', depth=0):
            nonlocal count
            if depth > 32 or count > 100000:
                raise OSError('reference inventory exceeds bound')
            try:
                fd = admin_open(os.path.join(common, relative), directory=True)
            except FileNotFoundError:
                return
            try:
                for name in os.listdir(fd):
                    count += 1
                    name = os.fsencode(name)
                    path = relative+b'/'+name
                    info = os.stat(name, dir_fd=fd, follow_symlinks=False)
                    if stat.S_ISDIR(info.st_mode):
                        copy_refs(path, depth+1)
                    else:
                        copy_file(common, path, optional=False)
            finally:
                os.close(fd)
        (target/'refs').mkdir()
        copy_refs()
        # Objects are data, never configuration. Bound Git calls even when
        # damaged objects/alternates point at streams or external storage.
        objects = os.path.join(common, b'objects')
        admin_directory(objects)
        (target/'objects'/'info').mkdir(parents=True)
        # Git accepts C-quoted alternate pathnames. Escape bytes rather than
        # decoding arbitrary POSIX filenames or requiring symlink privileges.
        quoted = b'"' + b''.join(
            bytes((c,)) if 32 <= c < 127 and c not in (34, 92)
            else ('\\%03o' % c).encode('ascii') for c in objects) + b'"\n'
        (target/'objects'/'info'/'alternates').write_bytes(quoted)
        view = (os.fsencode(temp), selected)
        _VIEWS[checkout] = view
        try:
            yield view
        finally:
            del _VIEWS[checkout]


def git_bytes(checkout, *args, input=None, allowed_codes=(0,), with_code=False):
    checkout = os.path.realpath(os.fsencode(checkout))
    with private_git(checkout) as (gitdir, _):
        env = isolated_env()
        env.update(GIT_DIR=os.fsdecode(gitdir), GIT_WORK_TREE=os.fsdecode(checkout))
        result = subprocess.run([b'git', b'-C', gitdir, *[os.fsencode(x) for x in args]],
            env=env, input=input, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10)
    if result.returncode not in allowed_codes:
        raise OSError(f'git {args!r} exit {result.returncode}: {result.stderr!r}')
    return (result.returncode, result.stdout) if with_code else result.stdout


def nul_items(raw):
    if raw and not raw.endswith(b'\0'):
        raise ValueError('unterminated NUL inventory')
    return raw[:-1].split(b'\0') if raw else []


def safe_path(path):
    if not path or path.startswith(b'/') or any(p in (b'', b'.', b'..', b'.git') for p in path.split(b'/')):
        raise ValueError(f'unsafe Git path {path!r}')
    return path


def inventory(checkout):
    with private_git(checkout) as (_, selected):
        return {'administration': selected, **private_inventory(checkout)}


def private_inventory(checkout):
    head = git_bytes(checkout, 'rev-parse', '--verify', 'HEAD').strip().decode('ascii')
    if not re.fullmatch(r'[0-9a-f]{40}|[0-9a-f]{64}', head):
        raise ValueError('invalid HEAD')
    entries = []
    for item in nul_items(git_bytes(checkout, 'ls-files', '--stage', '-z')):
        header, path = item.split(b'\t', 1)
        mode, oid, stage = header.decode('ascii').split(' ')
        entries.append({'path': b64(safe_path(path)), 'mode': mode, 'oid': oid, 'stage': int(stage)})
    flags = []
    for item in nul_items(git_bytes(checkout, 'ls-files', '-v', '-z')):
        if item[1:2] != b' ':
            raise ValueError('invalid index flag record')
        flags.append({'path': b64(safe_path(item[2:])), 'flag': item[:1].decode('ascii')})
    gitlinks = sorted({unb64(e['path']) for e in entries if e['mode'] == '160000'})
    # Git omits special files and may traverse invalid nested gitfiles. Discover
    # nonignored leaves ourselves, pruning only untracked nested boundaries.
    root_fd = os.open(checkout, os.O_RDONLY | os.O_DIRECTORY)
    try:
        others = discover_untracked(checkout, root_fd, {unb64(e['path']) for e in entries},
                                    set(gitlinks))
    finally:
        os.close(root_fd)
    # Ignoring recursion alone still lets Git refresh gitlink HEAD in-process.
    # Exclude the enumerated gitlinks literally, retaining index/location evidence.
    status_args = ['status', '--porcelain=v1', '-z', '--untracked-files=no',
                   '--ignore-submodules=all']
    replaced = []
    for path in {unb64(e['path']) for e in entries} - set(gitlinks):
        try:
            if stat.S_ISDIR(os.lstat(os.path.join(checkout, path)).st_mode):
                replaced.append(path)
        except (FileNotFoundError, NotADirectoryError):
            pass
    excluded = sorted(set(gitlinks) | set(replaced))
    if excluded:
        status_args += ['--', *[b':(exclude,literal)' + p for p in excluded]]
    # Inspect present files even if the source index asks Git to skip them.
    # Mutate only this inventory's private index; retain original flags above.
    index_path = os.path.join(_VIEWS[checkout][0], b'index')
    index_time = os.stat(index_path).st_mtime_ns if entries else None
    stage_zero = {unb64(e['path']) for e in entries if e['stage'] == 0}
    for option, paths in (
        ('--no-assume-unchanged', [unb64(e['path']) for e in flags if e['flag'].islower()]),
        ('--no-skip-worktree', [unb64(e['path']) for e in flags if e['flag'].upper() == 'S'
                              and os.path.lexists(os.path.join(checkout, unb64(e['path'])))])):
        selected = sorted(set(paths) & stage_zero)
        if selected:
            git_bytes(checkout, 'update-index', option, '-z', '--stdin',
                      input=b''.join(p+b'\0' for p in selected))
    if index_time is not None:
        os.utime(index_path, ns=(index_time, index_time))
    status = git_bytes(checkout, *status_args)
    status += b''.join(b' D '+p+b'\0' for p in sorted(replaced))
    status += b''.join(b'?? '+p+b'\0' for p in others)
    staged = git_bytes(checkout, 'diff-index', '--cached', '--raw', '-z',
                       '--no-ext-diff', '--no-textconv', '--no-renames', '--ignore-submodules=dirty', head, '--')
    # Validate NUL grammar, including the extra source path of rename/copy records.
    records = iter(nul_items(status))
    for item in records:
        if len(item) < 4 or item[2:3] != b' ':
            raise ValueError('invalid porcelain record')
        if b'R' in item[:2] or b'C' in item[:2]:
            next(records)  # Missing source is an unavailable inventory, not a partial one.
    return {'head': head, 'index': entries, 'flags': flags,
            'untracked': [b64(p) for p in others], 'status': b64(status), 'staged': b64(staged)}


def discover_untracked(checkout, root_fd, tracked, gitlinks):
    found = set()
    tracked_dirs = {b'/'.join(path.split(b'/')[:i]) for path in tracked
                    for i in range(1, len(path.split(b'/')))}
    def walk(fd, prefix):
        names = sorted(os.fsencode(n) for n in os.listdir(fd) if os.fsencode(n) != b'.git')
        paths = [prefix + n for n in names]
        # check-ignore rejects literal-pathspec mode. A ./ prefix prevents a
        # leading :(...) filename being parsed as magic; its output keeps ./ .
        ignored = {p[2:] for p in nul_items(git_bytes(checkout, 'check-ignore', '--stdin', '-z',
                            input=b''.join(b'./'+p+b'\0' for p in paths), allowed_codes=(0, 1)))} if paths else set()
        for name, path in zip(names, paths):
            if path in gitlinks:
                continue  # Literal location/metadata is owned by submodule_record.
            if path in ignored and path not in tracked:
                continue
            info = os.stat(name, dir_fd=fd, follow_symlinks=False)
            if stat.S_ISDIR(info.st_mode):
                child = os.open(name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
                try:
                    try:
                        os.stat(b'.git', dir_fd=child, follow_symlinks=False)
                    except FileNotFoundError:
                        walk(child, path+b'/')
                    else:
                        if path not in tracked:
                            found.add(path)  # Preserve literal metadata too.
                        if path in tracked_dirs:
                            walk(child, path+b'/')
                finally:
                    os.close(child)
            elif path not in tracked:
                found.add(path)
        if names != sorted(os.fsencode(n) for n in os.listdir(fd) if os.fsencode(n) != b'.git'):
            raise OSError('directory inventory changed during discovery')
    walk(root_fd, b'')
    return sorted(found)


def identity(s):
    return (s.st_dev, s.st_ino, s.st_mode, s.st_size, s.st_mtime_ns, s.st_ctime_ns, s.st_rdev)


def entry_record(parent, name, *, missing_ok, literal=False):
    try:
        before = os.stat(name, dir_fd=parent, follow_symlinks=False)
    except FileNotFoundError:
        if not missing_ok:
            raise OSError(f'enumerated path disappeared: {name!r}')
        try:
            os.stat(name, dir_fd=parent, follow_symlinks=False)
        except FileNotFoundError:
            return {'kind': 'missing'}
        raise OSError(f'path appeared during observation: {name!r}')
    mode = before.st_mode
    if stat.S_ISREG(mode):
        fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=parent)
        try:
            opened = os.fstat(fd)
            if not stat.S_ISREG(opened.st_mode) or identity(opened) != identity(before):
                raise OSError(f'path changed before read: {name!r}')
            digest = hashlib.sha256()
            chunks = []
            while True:
                chunk = os.read(fd, 1024 * 1024)
                if not chunk:
                    break
                digest.update(chunk)
                if literal:
                    chunks.append(chunk)
            if identity(os.fstat(fd)) != identity(before):
                raise OSError(f'path changed during read: {name!r}')
            record = {'kind': 'file', 'sha256': digest.hexdigest(), 'executable': bool(mode & 0o111)}
            if literal:
                record['literal'] = b64(b''.join(chunks))
        finally:
            os.close(fd)
    elif stat.S_ISLNK(mode):
        record = {'kind': 'symlink', 'target': b64(os.readlink(name, dir_fd=parent))}
    elif stat.S_ISDIR(mode):
        record = {'kind': 'directory'}
    else:
        kind = next((label for check, label in ((stat.S_ISFIFO, 'fifo'), (stat.S_ISSOCK, 'socket'),
                    (stat.S_ISCHR, 'character'), (stat.S_ISBLK, 'block')) if check(mode)), 'other')
        record = {'kind': kind, 'rdev': before.st_rdev}
    if identity(os.stat(name, dir_fd=parent, follow_symlinks=False)) != identity(before):
        raise OSError(f'path changed after read: {name!r}')
    return record


def path_record(root_fd, relative, *, tracked, literal=False):
    """A blocked parent is represented literally; descendants are never followed."""
    parts = relative.split(b'/')
    fd = os.dup(root_fd)
    try:
        for i, part in enumerate(parts):
            record = entry_record(fd, part, missing_ok=tracked, literal=literal and i == len(parts)-1)
            at = b'/'.join(parts[:i+1])
            if i == len(parts)-1 or record['kind'] != 'directory':
                return {'at': b64(at), **record}
            old = fd
            fd = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=old)
            os.close(old)
    finally:
        os.close(fd)


def nested_record(root_fd, path):
    metadata = path_record(root_fd, path + b'/.git', tracked=True, literal=True)
    if metadata['at'] != b64(path + b'/.git') or metadata['kind'] == 'missing':
        return None
    if metadata['kind'] == 'directory':
        metadata = {'entry': metadata, 'head': path_record(root_fd, path + b'/.git/HEAD', tracked=True, literal=True)}
    return metadata


def submodule_record(root_fd, path):
    location = path_record(root_fd, path, tracked=True)
    result = {'location': location, 'metadata_present': False}
    if location['at'] != b64(path) or location['kind'] != 'directory':
        return result
    metadata_path = path + b'/.git'
    metadata = path_record(root_fd, metadata_path, tracked=True, literal=True)
    if metadata['at'] != b64(metadata_path):
        raise OSError(f'submodule location changed: {path!r}')
    result['metadata'] = metadata
    result['metadata_present'] = metadata['kind'] != 'missing'
    if metadata['kind'] == 'directory':
        head_path = metadata_path + b'/HEAD'
        head = path_record(root_fd, head_path, tracked=True, literal=True)
        if head['at'] != b64(head_path):
            raise OSError(f'submodule metadata changed: {path!r}')
        result['embedded_head'] = head
    if path_record(root_fd, path, tracked=True) != location:
        raise OSError(f'submodule location changed: {path!r}')
    if path_record(root_fd, metadata_path, tracked=True, literal=True) != metadata:
        raise OSError(f'submodule metadata changed: {path!r}')
    return result


def observe(checkout, root_fd, fields):
    inv = inventory(checkout)
    fields.update(inv)
    tracked = {unb64(e['path']) for e in inv['index']}
    gitlinks = {unb64(e['path']) for e in inv['index'] if e['mode'] == '160000'}
    others = {unb64(p) for p in inv['untracked']}
    for path in sorted(tracked | others):
        key = 'path:' + b64(path)
        if path in gitlinks:
            fields[key] = {'submodule': submodule_record(root_fd, path)}
        else:
            record = path_record(root_fd, path, tracked=path in tracked)
            if record['kind'] == 'directory' and record['at'] == b64(path):
                nested = nested_record(root_fd, path)
                if nested is not None:
                    record = {**record, 'kind': 'repository-directory', 'metadata': nested}
            fields[key] = record


def capture(checkout):
    checkout = os.path.realpath(checkout)
    fields, errors = {}, []
    root_fd = None
    try:
        top = git_bytes(checkout, 'rev-parse', '--show-toplevel').rstrip(b'\n')
        if os.path.realpath(top) != os.path.realpath(checkout):
            raise OSError('checkout must be the repository top-level')
        root_fd = os.open(checkout, os.O_RDONLY | os.O_DIRECTORY)
        observe(checkout, root_fd, fields)
        second = {}
        observe(checkout, root_fd, second)
        if fields != second:
            raise OSError('observable state changed during capture')
    except (OSError, ValueError, StopIteration, subprocess.SubprocessError) as exc:
        errors.append(f'{type(exc).__name__}: {exc}')
    finally:
        if root_fd is not None:
            os.close(root_fd)
    record = {'schema': SCHEMA, 'checkout': b64(os.path.realpath(checkout)),
              'complete': not errors, 'fields': fields, 'errors': errors, 'limits': LIMITS}
    return (record if not errors else None), record


def validate_observation(value):
    if not isinstance(value, dict) or not isinstance(value.get('kind'), str):
        raise ValueError('invalid path observation')
    if 'at' in value:
        unb64(value['at'])
    kind = value['kind']
    expected = {'file', 'symlink', 'directory', 'missing', 'fifo', 'socket', 'character', 'block', 'other', 'repository-directory'}
    if kind not in expected:
        raise ValueError('invalid file kind')
    if kind == 'file':
        if not re.fullmatch('[0-9a-f]{64}', value.get('sha256', '')) or type(value.get('executable')) is not bool:
            raise ValueError('invalid file digest/mode')
        if 'literal' in value:
            if hashlib.sha256(unb64(value['literal'])).hexdigest() != value['sha256']:
                raise ValueError('literal digest mismatch')
    if kind == 'symlink':
        unb64(value['target'])
    if kind in {'fifo', 'socket', 'character', 'block', 'other'} and type(value.get('rdev')) is not int:
        raise ValueError('invalid device identity')
    if kind == 'repository-directory':
        validate_metadata(value['metadata'])


def validate_metadata(value):
    if 'entry' in value:
        validate_observation(value['entry'])
        validate_observation(value['head'])
    else:
        validate_observation(value)


def validate_submodule(sub, path):
    if not isinstance(sub, dict):
        raise ValueError('invalid submodule record')
    required = {'location', 'metadata_present'}
    if not required <= set(sub) or not set(sub) <= required | {'metadata', 'embedded_head'}:
        raise ValueError('invalid submodule fields')
    validate_observation(sub['location'])
    location = sub['location']
    at = unb64(location['at'])
    if at != path and not path.startswith(at + b'/'):
        raise ValueError('invalid submodule location')
    if type(sub['metadata_present']) is not bool:
        raise ValueError('invalid metadata presence')
    actual_directory = at == path and location['kind'] == 'directory'
    if not actual_directory:
        if sub['metadata_present'] or set(sub) != required:
            raise ValueError('metadata through blocked location')
        return
    metadata = sub['metadata']
    validate_observation(metadata)
    if metadata['at'] != b64(path + b'/.git'):
        raise ValueError('invalid metadata location')
    if sub['metadata_present'] != (metadata['kind'] != 'missing'):
        raise ValueError('metadata presence mismatch')
    observations = [metadata]
    if metadata['kind'] == 'directory':
        head = sub['embedded_head']
        validate_observation(head)
        if head['at'] != b64(path + b'/.git/HEAD'):
            raise ValueError('invalid embedded HEAD location')
        observations.append(head)
    elif 'embedded_head' in sub:
        raise ValueError('HEAD outside embedded metadata directory')
    if any(o['kind'] == 'file' and 'literal' not in o for o in observations):
        raise ValueError('missing literal metadata')


def validate_record(record):
    if not isinstance(record, dict) or record.get('schema') != SCHEMA or type(record.get('complete')) is not bool:
        raise ValueError('invalid schema/completeness')
    if not os.path.isabs(unb64(record['checkout'])) or record.get('limits') != LIMITS:
        raise ValueError('invalid checkout/limits')
    if set(record) != {'schema', 'checkout', 'complete', 'fields', 'errors', 'limits'}:
        raise ValueError('unexpected record fields')
    fields, errors = record['fields'], record['errors']
    if not isinstance(fields, dict) or not isinstance(errors, list) or any(not isinstance(e, str) for e in errors):
        raise ValueError('invalid fields/errors')
    required = {'head', 'index', 'flags', 'untracked', 'status', 'staged', 'administration'}
    if record['complete'] and (errors or not required <= fields.keys()):
        raise ValueError('incomplete successful snapshot')
    if not record['complete'] and not errors:
        raise ValueError('diagnostic without errors')
    for key, value in fields.items():
        if key in {'index', 'flags', 'untracked'} and not isinstance(value, list):
            raise ValueError('invalid inventory list')
        if key == 'head':
            if not isinstance(value, str) or not re.fullmatch('[0-9a-f]{40}|[0-9a-f]{64}', value):
                raise ValueError('invalid commit')
        elif key == 'index':
            for e in value:
                safe_path(unb64(e['path']))
                if e['mode'] not in {'100644', '100755', '120000', '160000'} or type(e['stage']) is not int or not 0 <= e['stage'] <= 3 or not re.fullmatch('[0-9a-f]{40}|[0-9a-f]{64}', e['oid']):
                    raise ValueError('invalid index entry')
        elif key == 'flags':
            for e in value:
                safe_path(unb64(e['path']))
                if not isinstance(e['flag'], str) or len(e['flag']) != 1 or not e['flag'].isalpha():
                    raise ValueError('invalid index flag')
        elif key == 'untracked':
            for p in value:
                safe_path(unb64(p))
        elif key == 'administration':
            if not isinstance(value, dict) or set(value) != {'gitfile', 'location', 'gitdir', 'gitdir_identity', 'commondir', 'common_pointer', 'common_identity'}:
                raise ValueError('invalid administration identity')
            for name in ('gitdir', 'commondir'):
                if not os.path.isabs(unb64(value[name])):
                    raise ValueError('invalid administration path')
            for name in ('gitfile', 'common_pointer'):
                if value[name] is not None:
                    unb64(value[name])
            for name in ('location', 'gitdir_identity', 'common_identity'):
                if not isinstance(value[name], list) or len(value[name]) != 2 or any(type(n) is not int or n < 0 for n in value[name]):
                    raise ValueError('invalid administration file identity')
        elif key in ('status', 'staged'):
            nul_items(unb64(value))
        elif key.startswith('path:'):
            path = safe_path(unb64(key[5:]))
            if 'submodule' in value:
                if set(value) != {'submodule'}:
                    raise ValueError('invalid submodule wrapper')
                validate_submodule(value['submodule'], path)
            else:
                validate_observation(value)
        else:
            raise ValueError('unknown field')
    if record['complete']:
        paths = {e['path'] for e in fields['index']} | set(fields['untracked'])
        if {'path:' + p for p in paths} != {k for k in fields if k.startswith('path:')}:
            raise ValueError('incomplete path inventory')
    return record


def read_record(directory):
    snapshot, diagnostic = Path(directory)/'snapshot.json', Path(directory)/'diagnostic.json'
    if snapshot.exists() == diagnostic.exists():
        raise ValueError('expected exactly one snapshot or diagnostic')
    path = snapshot if snapshot.exists() else diagnostic
    data = path.read_bytes()
    record = validate_record(json.loads(data.decode('utf-8')))
    if record['complete'] != (path == snapshot):
        raise ValueError('record filename/completeness mismatch')
    return record, {'path': str(path.resolve()), 'sha256': hashlib.sha256(data).hexdigest()}


def preflight(record):
    """Derive a conservative clean/path gate entirely from one complete capture."""
    validate_record(record)
    if not record['complete']:
        raise ValueError('preflight capture unavailable')
    fields = record['fields']
    paths = {unb64(p) for p in fields['untracked']}
    flags = {e['path']: e['flag'].upper() for e in fields['flags']}
    for entry in fields['index']:
        if entry['mode'] != '160000':
            continue
        location = fields['path:'+entry['path']]['submodule']['location']
        if location['kind'] != 'directory' and not (location['kind'] == 'missing' and flags.get(entry['path']) == 'S'):
            paths.add(unb64(entry['path']))
    records = iter(nul_items(unb64(fields['status'])))
    for item in records:
        if len(item) < 4 or item[2:3] != b' ':
            raise ValueError('invalid status grammar')
        paths.add(safe_path(item[3:]))
        if b'R' in item[:2] or b'C' in item[:2]:
            paths.add(safe_path(next(records)))
    staged = iter(nul_items(unb64(fields['staged'])))
    for header in staged:
        if not re.fullmatch(rb':[0-7]{6} [0-7]{6} [0-9a-f]+ [0-9a-f]+ [A-Z]', header):
            raise ValueError('invalid staged grammar')
        paths.add(safe_path(next(staged)))
    return {'uncommitted': bool(paths), 'paths': [b64(p) for p in sorted(paths)],
            'status': fields['status'], 'staged': fields['staged'], 'limits': record['limits']}


def compare_records(before_dir, after_dir):
    records, identities, errors = [], [], []
    for directory in (before_dir, after_dir):
        try:
            record, ident = read_record(directory)
            records.append(record)
            identities.append(ident)
            errors.extend(record['errors'])
        except (OSError, ValueError, KeyError, TypeError, AttributeError) as exc:
            records.append(None)
            identities.append({'path': str(Path(directory).absolute()), 'unavailable': str(exc)})
            errors.append(str(exc))
    differences = []
    a, b = records
    if a and b:
        if a['checkout'] != b['checkout']:
            errors.append('checkout identity mismatch')
        else:
            for key in sorted(a['fields'].keys() & b['fields'].keys()):
                if a['fields'][key] != b['fields'][key]:
                    differences.append({'field': key, 'before': a['fields'][key], 'after': b['fields'][key]})
    code = 1 if differences else (0 if a and b and a['complete'] and b['complete'] and not errors else 2)
    return code, {'schema': SCHEMA, 'outcome': ('identical' if code == 0 else 'changed' if code == 1 else 'unavailable'),
                  'inputs': identities, 'differences': differences, 'errors': errors, 'limits': LIMITS}


def outside(output, checkout):
    if os.path.commonpath((os.path.realpath(output), os.path.realpath(checkout))) == os.path.realpath(checkout):
        raise ValueError('output directory must be outside checkout')


def publish(directory, name, value):
    fd, tmp = tempfile.mkstemp(prefix='.publish-', dir=directory)
    try:
        with os.fdopen(fd, 'wb') as f:
            f.write(canonical(value) + b'\n')
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, Path(directory)/name)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def read_git(directory, arguments):
    allowed = {'rev-parse', 'log', 'show', 'diff', 'merge-base', 'check-ignore', 'symbolic-ref', 'cat-file', 'worktree', 'check-ref-format'}
    if not arguments or arguments[0] not in allowed:
        raise ValueError('git-read requires an allowed read-only command')
    unsafe = ('--output', '--ext-diff', '--textconv', '--no-index', '--remerge-diff', '--diff-merges')
    if any(a.startswith('--') and a != '--' and any(option.startswith(a.split('=', 1)[0]) for option in unsafe) for a in arguments):
        raise ValueError('unsafe git-read option')
    if arguments[0] in ('diff', 'log', 'show'):
        for argument in arguments[1:]:
            key, separator, value = argument.partition('=')
            if not key.startswith('--') or key == '--':
                continue
            if '--ignore-submodules'.startswith(key):
                if key != '--ignore-submodules' or not separator or value not in ('dirty', 'all'):
                    raise ValueError('git-read requires ignore-submodules=dirty or all')
            elif '--submodule'.startswith(key):
                if key != '--submodule' or not separator or value != 'short':
                    raise ValueError('git-read requires submodule=short')
            elif any(option.startswith(key) for option in ('--no-ignore-submodules', '--no-submodule')):
                raise ValueError('git-read cannot disable submodule safety options')
    if arguments[0] == 'check-ref-format' and (len(arguments) != 3 or arguments[1] != '--branch'):
        raise ValueError('git-read check-ref-format requires --branch and one name')
    if arguments[0] == 'cat-file' and (len(arguments) != 3 or arguments[1] not in ('-e', '-p', '-t', '-s')):
        raise ValueError('git-read cat-file requires one object and -e/-p/-t/-s')
    if arguments[0] == 'worktree' and arguments[1:] != ['list', '--porcelain', '-z']:
        raise ValueError('git-read worktree requires list --porcelain -z')
    if arguments[0] == 'symbolic-ref' and (len([a for a in arguments[1:] if not a.startswith('-')]) != 1 or '--delete' in arguments or '-d' in arguments):
        raise ValueError('git-read symbolic-ref accepts one read target')
    root = os.path.realpath(os.fsencode(directory))
    if not os.path.isdir(root):
        raise ValueError('git-read checkout must be a directory')
    while not os.path.lexists(os.path.join(root, b'.git')):
        parent = os.path.dirname(root)
        if parent == root:
            raise ValueError('no containing checkout')
        root = parent
    args = list(arguments)
    if args[0] == 'diff':
        operands = False
        for argument in args[1:]:
            if argument == '--':
                operands = True
                continue
            if not operands and argument.startswith('-'):
                continue
            joined = os.path.join(root, os.fsencode(argument))
            paths = (os.path.normpath(joined), os.path.realpath(joined))
            if any(os.path.commonpath((root, path)) != root for path in paths):
                raise ValueError('git-read diff refuses outside-checkout paths')
    if args[0] in ('log', 'show', 'diff'):
        args[1:1] = ['--no-ext-diff', '--no-textconv',
                     '--ignore-submodules=dirty', '--submodule=short']
    if args[0] == 'check-ref-format':
        code, output = git_bytes(root, *args, allowed_codes=(0, 1, 128), with_code=True)
        return (1 if code == 128 else code), output
    if args[0] != 'worktree':
        return git_bytes(root, *args, allowed_codes=(0, 1), with_code=True)
    with private_git(root) as (private, selected):
        common = unb64(selected['commondir'])
        if os.path.basename(common) != b'.git':
            raise ValueError('worktree listing needs an ordinary main .git directory')
        source = os.path.join(common, b'worktrees')
        try:
            fd = admin_open(source, directory=True)
        except FileNotFoundError:
            names = []
        else:
            try:
                names = [os.fsencode(n) for n in os.listdir(fd)]
            finally:
                os.close(fd)
        for name in names:
            dest = Path(os.fsdecode(private))/ 'worktrees'/os.fsdecode(name)
            dest.mkdir(parents=True)
            for leaf in (b'HEAD', b'gitdir', b'locked'):
                data = admin_read(os.path.join(source, name, leaf), optional=leaf == b'locked', limit=65536)
                if data is not None:
                    (dest/os.fsdecode(leaf)).write_bytes(data)
            (dest/'commondir').write_text('../..\n')
        # The view's main entry must describe the real main, even when the
        # caller is a linked worktree with its own HEAD.
        Path(os.fsdecode(private), 'HEAD').write_bytes(admin_read(os.path.join(common, b'HEAD'), limit=65536))
        code, output = git_bytes(root, *args, allowed_codes=(0, 1), with_code=True)
        rows = output.split(b'\0')
        if not rows or not rows[0].startswith(b'worktree '):
            raise ValueError('invalid worktree inventory')
        rows[0] = b'worktree '+os.path.dirname(common)
        return code, b'\0'.join(rows)


def main():
    if os.name == 'nt':
        # Compatibility CLI uses the same native consumer boundary. Only fixed
        # PowerShell source is encoded; arbitrary argv remains JSON data.
        helper = str(Path(__file__).with_suffix('.ps1').resolve())
        payload = b64(canonical({'script': helper, 'arguments': sys.argv[1:]}))
        source = (
            "$ErrorActionPreference='Stop'; try { "
            "$p=ConvertFrom-Json ([Text.Encoding]::UTF8.GetString("
            "[Convert]::FromBase64String('" + payload + "'))); "
            ". $p.script; $roots=[string[]]@(); "
            "$i=[Array]::IndexOf([string[]]$p.arguments,'--checkout'); "
            "if($i -ge 0 -and $i+1 -lt $p.arguments.Count) { $roots=[string[]]@($p.arguments[$i+1]) }; "
            "Initialize-CheckoutStateEngine $p.script $roots; "
            "$j=ConvertTo-Json -InputObject ([string[]]$p.arguments) -Compress; "
            "$r=[CheckoutState.Engine]::InvokeJson((Get-Process -Id $PID).Path,$p.script,$j,$roots); "
            "[Console]::OpenStandardOutput().Write($r.Stdout,0,$r.Stdout.Length); "
            "[Console]::OpenStandardError().Write($r.Stderr,0,$r.Stderr.Length); exit $r.ExitCode "
            "} catch { [Console]::Error.WriteLine($_.Exception.Message); exit 2 }")
        command = [os.path.join(os.environ.get('SystemRoot', r'C:\Windows'),
                                'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe'),
                   '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand',
                   base64.b64encode(source.encode('utf-16-le')).decode('ascii')]
        return subprocess.call(command)
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    cap = commands.add_parser('capture')
    cap.add_argument('--checkout', required=True)
    cmp = commands.add_parser('compare')
    cmp.add_argument('--before', required=True)
    cmp.add_argument('--after', required=True)
    for command in (cap, cmp):
        command.add_argument('--output-dir', required=True)
    pre = commands.add_parser('preflight')
    pre.add_argument('--capture-dir', required=True)
    read = commands.add_parser('git-read')
    read.add_argument('--checkout', required=True)
    read.add_argument('arguments', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    try:
        if args.command == 'preflight':
            record, _ = read_record(args.capture_dir)
            sys.stdout.buffer.write(canonical(preflight(record)) + b'\n')
            return 0
        if args.command == 'git-read':
            arguments = args.arguments[1:] if args.arguments[:1] == ['--'] else args.arguments
            code, output = read_git(args.checkout, arguments)
            sys.stdout.buffer.write(output)
            return code
        if args.command == 'capture':
            if not os.path.isabs(args.checkout):
                raise ValueError('checkout must be absolute')
            outside(args.output_dir, args.checkout)
        else:
            for directory in (args.before, args.after):
                try:
                    record, _ = read_record(directory)
                except (OSError, ValueError, KeyError, TypeError, AttributeError):
                    continue
                outside(os.fsencode(args.output_dir), unb64(record['checkout']))
        os.mkdir(args.output_dir)  # Exclusive: never reuse even an empty directory.
        if args.command == 'capture':
            snapshot, diagnostic = capture(os.fsencode(args.checkout))
            publish(args.output_dir, 'snapshot.json' if snapshot else 'diagnostic.json', diagnostic)
            return 0 if snapshot else 2
        code, result = compare_records(args.before, args.after)
        publish(args.output_dir, 'result.json', result)
        return code
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as exc:
        print(f'state verification unavailable: {exc}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
