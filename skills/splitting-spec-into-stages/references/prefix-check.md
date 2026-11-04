# Prefix check

The split may change the spec in two ways only: append a `## Stages` section and, when the spec ended with a `Review:` mark, remove that last line. `prefix_check` proves it on bytes: the spec still starts with everything it held before the split, the mark aside, and the first line after that content, past any line endings, is `## Stages`. It reads nothing inside the section; `stages_parse` does.

## Inputs

The caller binds two absolute paths:

- `file`: the spec as it is now.
- `recorded`: a raw byte copy of the spec's working file, taken at Preflight after the own-paths gate passed. Never a `git show` of the spec: under `core.autocrlf` or `text eol=crlf` its blob can differ from the working file.

## Rule

- **Last line.** The last line of `recorded` is its bytes after the last `\n` that is not its final byte, or the whole content when there is none, without its final `\n` when it has one. A `recorded` that ends in an empty line has an empty last line, so no mark is dropped.
- **Original content.** `R` is the bytes of `recorded` before its last line when that line, one trailing CR removed, matches `^Review: (clean|clean except disputed), [0-9]{4}-[0-9]{2}-[0-9]{2}, reviewer (claude|codex), commit [0-9a-f]{40}$`; otherwise `R` is all of `recorded`.
- **Pass.** `file` starts with the bytes of `R`, and the bytes after them are zero or more line endings (`\n` or `\r\n`; at least one when `R` is not empty and does not end with `\n`), then `## Stages`, then at most one CR, then `\n` or the end of `file`. The bytes after that line are not checked.

The comparison is of bytes only: no normalisation of encoding, line endings or whitespace. `## Stagesx`, `## Stages ` with a trailing space, a NUL byte in that line, and a `## Stages` joined to the last line of `R` all fail.

## Recipes

Bind `file` and `recorded` (`$file` and `$recorded` in pwsh) and run one recipe. Both share this contract. For readable regular files they give the same exit and, for exits 0 and 1, the same bytes, except the text after `prefix_check: `. Any other path (a directory, a device, a FIFO, a file that fails to open) is refused with exit 2 by Bash and may behave differently in pwsh:

- **0**: pass. Stdout and stderr are empty.
- **1**: fail. Stdout is empty; stderr holds one line. `differs from the original content at byte offset N` when `file` does not start with `R`: `N` is 0-based, the number of bytes of `file` before the first one that differs from `R`, or the length of `file` when it ends inside `R`. `no "## Stages" after the original content` when `file` starts with `R` and the bytes after it do not pass.
- **2**: unavailable evidence, neither a pass nor a fail. Stdout is empty; stderr holds `cannot read file: <path>` or `cannot read recorded: <path>` when Bash finds that path is not a readable regular file (`file` is checked first; pwsh gives this line when it cannot read the path), or a line starting `prefix_check: ` when a tool fails.

The Bash recipe gates the last line of `recorded` at 107 bytes before it converts it to text. `Review: clean except disputed, YYYY-MM-DD, reviewer claude, commit <40 hex>` is the longest mark (8 + 21 + 2 + 10 + 2 + 15 + 2 + 7 + 40 = 107 bytes), so a longer last line cannot be a mark and is not converted to text; a change to the mark grammar must change this number and the pwsh pattern together.

Bash, needing `od` and `awk`: `od` turns each file into decimal byte values, so NUL bytes, a missing final newline and long lines reach `awk` as plain numbers. Tested with GNU coreutils od and gawk or mawk, and with busybox od and awk (BSD/macOS od and awk, and bash 3.2, untested):

```bash
prefix_check() {
  local out
  [[ -f $file && -r $file ]] || { printf 'cannot read file: %s\n' "$file" >&2; return 2; }
  [[ -f $recorded && -r $recorded ]] || { printf 'cannot read recorded: %s\n' "$recorded" >&2; return 2; }
  out=$({ od -An -v -tu1 -- "$recorded" && echo - && od -An -v -tu1 -- "$file" && echo .; } | LC_ALL=C awk '
    function fail(m) { print m; exit 3 }
    $0 == "-" { p = 1; next }
    $0 == "." { p = 2; next }
    { for (i = 1; i <= NF; i++) if (p) f[++fn] = $i + 0; else r[++rn] = $i + 0 }
    END {
      if (p != 2) exit 4
      for (i = 32; i < 127; i++) chr[i] = sprintf("%c", i)
      d = "[0-9]"; h = "[0-9a-f]"; h = h h h h h h h h; h = h h h h h
      mark = "^Review: (clean|clean except disputed), " d d d d "-" d d "-" d d ", reviewer (claude|codex), commit " h "$"
      e = rn; if (e && r[e] == 10) e--
      s = e; while (s && r[s] != 10) s--
      if (e > s && r[e] == 13) e--
      x = ""; ok = (e - s <= 107)
      for (i = s + 1; ok && i <= e; i++) if (r[i] in chr) x = x chr[r[i]]; else ok = 0
      n = (ok && x ~ mark) ? s : rn
      for (i = 1; i <= n; i++) if (i > fn || f[i] != r[i]) fail("differs from the original content at byte offset " (i - 1))
      none = "no \"## Stages\" after the original content"
      j = n + 1; nl = 0
      while (j <= fn) {
        if (f[j] == 10) j++
        else if (f[j] == 13 && j < fn && f[j + 1] == 10) j += 2
        else break
        nl++
      }
      if (n && r[n] != 10 && !nl) fail(none)
      if (j + 8 > fn) fail(none)
      split("35 35 32 83 116 97 103 101 115", w, " ")
      for (k = 1; k <= 9; k++) if (f[j + k - 1] != w[k] + 0) fail(none)
      j += 9
      if (j <= fn && f[j] != 10 && !(f[j] == 13 && (j == fn || f[j + 1] == 10))) fail(none)
    }')
  case $? in
    0) return 0 ;;
    3) printf '%s\n' "$out" >&2; return 1 ;;
    *) printf 'prefix_check: od or awk failed\n' >&2; return 2 ;;
  esac
}
prefix_check
prefix_exit=$?
```

Native pwsh 7 (tested with 7.6.9 on Windows) compares the byte arrays directly, reads the last line through a one-byte encoding, and writes its message as UTF-8 ending in `\n` to the raw standard error stream; the script block's value is the exit:

```powershell
$prefix_exit = & {
    $say = { param($m) $b = [Text.UTF8Encoding]::new($false).GetBytes("$m`n"); $o = [Console]::OpenStandardError(); $o.Write($b, 0, $b.Length); $o.Flush() }
    $fail = { param($m) & $say $m; 1 }
    try {
        $ErrorActionPreference = 'Stop'
        try { $f = [IO.File]::ReadAllBytes($file) } catch { & $say "cannot read file: $file"; return 2 }
        try { $r = [IO.File]::ReadAllBytes($recorded) } catch { & $say "cannot read recorded: $recorded"; return 2 }
        $e = $r.Length
        if ($e -gt 0 -and $r[$e - 1] -eq 10) { $e-- }
        $s = if ($e -gt 0) { [Array]::LastIndexOf($r, [byte]10, $e - 1) + 1 } else { 0 }
        if ($e -gt $s -and $r[$e - 1] -eq 13) { $e-- }
        $last = [Text.Encoding]::GetEncoding(28591).GetString($r, $s, $e - $s)
        $mark = '^Review: (clean|clean except disputed), [0-9]{4}-[0-9]{2}-[0-9]{2}, reviewer (claude|codex), commit [0-9a-f]{40}\z'
        $n = if ([regex]::IsMatch($last, $mark)) { $s } else { $r.Length }
        for ($i = 0; $i -lt $n; $i++) {
            if ($i -ge $f.Length -or $f[$i] -ne $r[$i]) { return (& $fail "differs from the original content at byte offset $i") }
        }
        $none = 'no "## Stages" after the original content'
        $j = $n; $nl = 0
        while ($j -lt $f.Length) {
            if ($f[$j] -eq 10) { $j++ }
            elseif ($f[$j] -eq 13 -and $j + 1 -lt $f.Length -and $f[$j + 1] -eq 10) { $j += 2 }
            else { break }
            $nl++
        }
        if ($n -gt 0 -and $r[$n - 1] -ne 10 -and $nl -eq 0) { return (& $fail $none) }
        if ($j + 9 -gt $f.Length) { return (& $fail $none) }
        $w = [Text.Encoding]::ASCII.GetBytes('## Stages')
        for ($k = 0; $k -lt 9; $k++) { if ($f[$j + $k] -ne $w[$k]) { return (& $fail $none) } }
        $j += 9
        if ($j -lt $f.Length -and $f[$j] -ne 10 -and -not ($f[$j] -eq 13 -and ($j + 1 -eq $f.Length -or $f[$j + 1] -eq 10))) { return (& $fail $none) }
        return 0
    } catch {
        try { & $say "prefix_check: $($_.Exception.Message)" } catch { }
        return 2
    }
}
```
