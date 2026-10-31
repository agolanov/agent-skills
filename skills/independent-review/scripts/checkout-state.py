#!/usr/bin/env python3
"""Read-only, byte-safe phase-boundary observations; not an atomic filesystem lock."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile

SCHEMA = 2
LIMITS = ('ignored untracked paths not monitored; submodule/nested-repository content '
          'not recursively monitored; special-file contents not monitored; '
          'submodule resolved HEAD and dirty state not monitored')
_LOCAL_ENV = None


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


def git_bytes(checkout, *args, input=None, allowed_codes=(0,)):
    global _LOCAL_ENV
    if _LOCAL_ENV is None:
        env = {k: v for k, v in os.environ.items() if not k.startswith('GIT_')}
        result = subprocess.run(['git', 'rev-parse', '--local-env-vars'], env=env,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
        _LOCAL_ENV = set(result.stdout.decode('ascii').splitlines())
    env = {k: v for k, v in os.environ.items()
           if k not in _LOCAL_ENV and not k.startswith(('GIT_CONFIG_', 'GIT_DIR', 'GIT_WORK_TREE'))}
    for name in ('GIT_LITERAL_PATHSPECS', 'GIT_GLOB_PATHSPECS', 'GIT_NOGLOB_PATHSPECS', 'GIT_ICASE_PATHSPECS'):
        env.pop(name, None)
    env['GIT_OPTIONAL_LOCKS'] = '0'
    result = subprocess.run([b'git', b'-C', checkout, *[os.fsencode(x) for x in args]],
                            env=env, input=input, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode not in allowed_codes:
        raise OSError(f'git {args!r} exit {result.returncode}: {result.stderr!r}')
    return result.stdout


def nul_items(raw):
    if raw and not raw.endswith(b'\0'):
        raise ValueError('unterminated NUL inventory')
    return raw[:-1].split(b'\0') if raw else []


def safe_path(path):
    if not path or path.startswith(b'/') or any(p in (b'', b'.', b'..', b'.git') for p in path.split(b'/')):
        raise ValueError(f'unsafe Git path {path!r}')
    return path


def inventory(checkout):
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
    status_args = ['status', '--porcelain=v1', '-z', '--untracked-files=all',
                   '--ignore-submodules=all']
    if gitlinks:
        status_args += ['--', *[b':(exclude,literal)' + p for p in gitlinks]]
    status = git_bytes(checkout, *status_args)
    # Validate NUL grammar, including the extra source path of rename/copy records.
    records = iter(nul_items(status))
    for item in records:
        if len(item) < 4 or item[2:3] != b' ':
            raise ValueError('invalid porcelain record')
        if b'R' in item[:2] or b'C' in item[:2]:
            next(records)  # Missing source is an unavailable inventory, not a partial one.
    return {'head': head, 'index': entries, 'flags': flags,
            'untracked': [b64(p) for p in others], 'status': b64(status)}


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
    # Still check Git's own discovery, including failures, without trusting its
    # omissions for special files or its handling of nested metadata boundaries.
    nul_items(git_bytes(checkout, 'ls-files', '--others', '--exclude-standard', '-z'))
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
    required = {'head', 'index', 'flags', 'untracked', 'status'}
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
        elif key == 'status':
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    cap = commands.add_parser('capture')
    cap.add_argument('--checkout', required=True)
    cmp = commands.add_parser('compare')
    cmp.add_argument('--before', required=True)
    cmp.add_argument('--after', required=True)
    for command in (cap, cmp):
        command.add_argument('--output-dir', required=True)
    args = parser.parse_args()
    try:
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
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(f'state verification unavailable: {exc}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
