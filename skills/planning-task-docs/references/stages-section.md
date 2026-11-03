Authoritative copy. `refining-task-docs/references/stages-section.md` holds a display copy of the Parsing rules; keep them equal in both.

# Stages section

A staged spec carries its split into stages in itself: a `## Stages` section, the spec's last, before an optional trailing `Review:` line. It is approved and reviewed with the spec, and `plans/` holds plans only. Parsing does not depend on the section's place.

## Format

```markdown
## Stages

### Stage 01: Independent credential registration

**Scope:** Move the registration of the existing PlatformApiClient instances out of ChatNotifierProvider into an unconditional PlatformCredentialsProvider registered before it. Registries, token API, scopes and the refresh algorithm do not change.
**Done when:** The product works as before; credential clients no longer need the chat notifier initialised; the double-registration test fails loudly instead of being masked.

### Stage 02: Separate role catalogues

**Scope:** …
**Done when:** …

**Coverage:** R01 → 01, 03; R02 → 02; … (every numbered requirement of the spec names at least one stage)
```

The Parsing rules define every part of it, what Scope and Done when say included.

## Parsing rules

- **Lines.** Every rule reads lines with one trailing CR removed and skips fenced code blocks. A fence opens on a line starting, after at most three spaces, with three or more `` ` `` or three or more `~`; it closes on a line holding only the same character, at least as many times, after at most three spaces and before optional spaces or tabs; an unclosed fence runs to the end of the file. Fence lines and the lines between them are skipped, so a `## Stages` or `### Stage NN:` line shown in a fence, such as an example, is not a heading.
- **Section.** The section heading is the line `## Stages`, exactly, and the file holds one (failures `no "## Stages"`; `two "## Stages"` for two or more). The section runs to the next line starting with `## `, or to the end of the file.
- **Stage headings.** In the section, every line starting with `### ` matches `^### Stage ([0-9]{2}): (.+)$` (failure `heading not a stage: <line>`): group 1 is the stage number `NN`, group 2 the stage name. The name holds at least one character of `[A-Za-z0-9]`, so its stage slug is not empty and nothing guesses a plan path; a whitespace-only or all-Cyrillic name fails (failure `stage NN: name gives an empty slug`). A slug that is `follow-ups` or `tails`, or ends with `-follow-ups` or `-tails`, fails too, since its plan would be taken for a follow-ups file (failure `stage NN: name gives a reserved slug`). A stage runs to the next line starting with `## ` or `### `, or to the end of the section. Other lines, before the first stage or inside one, are free text.
- **Fields.** Each stage holds exactly one `**Scope:**` line and exactly one `**Done when:**` line. A field line starts with its label and one space, followed by text holding a character other than space or tab; that text is the field's value. Failures `stage NN: missing **Scope:**`, `stage NN: two **Scope:**` for two or more, and the same for `**Done when:**`.
- **Numbering.** Stage numbers are two digits, `01`, `02`, … consecutively in file order, with at least two stages. Failures `stage NN after MM` (`MM` the previous stage's number, `00` before the first stage) and `fewer than two stages`.
- **Order.** Order is the only dependency: stage NN may rely on every lower-numbered stage and on nothing else. There is no `Depends on` per stage.
- **Content.** `**Scope:**` says what the stage changes and what it leaves alone; `**Done when:**` is an observable result on main, not a list of tasks. The section describes the stages only: protocol, handoff and "how to run a stage" text belong to the skills.
- **Coverage.** `**Coverage:**` is one line of the section, after the last stage, naming the stages of each unit (`R01 → 01, 03; R02 → 02`). The unit is the spec's numbered requirements when it has them (`R01`, `3.2`), else the headings of the spec's sections that state requirements (Goals, decisions, behaviour sections). Every unit names at least one stage; a unit with none is a review finding. The line is required when `splitting-spec-into-stages` wrote the section, optional in a hand-written one.
- **Stage slug.** `<stage-slug>`: lower-case the stage name, replace each run of characters outside `[a-z0-9]` with `-`, trim leading and trailing `-` (`Split catalogues` → `split-catalogues`).
- **Spec stem.** `<spec-stem>` is the spec's file stem without `-design` (`specs/2026-09-20-product-layer-separation-design.md` → `2026-09-20-product-layer-separation`).
- **Stage plan.** The plan of stage NN is an ordinary superpowers plan at `plans/<spec-stem>-NN-<stage-slug>.md`, its header carrying `**Spec:** <spec path relative to the project checkout>` and `**Stage:** NN`.
- **Candidates.** The candidates are the Markdown files of the spec's sibling `plans/` directory, except follow-ups files (`*-follow-ups.md`, and the older `*-tails.md`), which are never plans.
- **Stage matching.** A candidate matches stage NN when its stem starts with `<spec-stem>-NN-`, or its `**Spec:**` header names the spec and its `**Stage:**` line says `NN`. A candidate matching two stages (its stem says NN, its headers MM) stops, naming the plan and both stages. Two candidates matching one stage stop, naming both. Nothing guesses.
- **Unstaged plan.** Stage matching comes first. A plan of the spec (the naming pair `plans/<spec-stem>.md`, or a candidate whose `**Spec:**` header names the spec) that matches no stage is unstaged: for example the naming pair without `**Stage:**`, or a `**Spec:**` plan without `**Stage:**` whose stem does not start with `<spec-stem>-NN-`. The naming pair whose `**Spec:**` names the spec and whose `**Stage:**` says a stage's number, such as `01`, or a stem-matching plan with `**Spec:**` and no `**Stage:**`, is a stage plan. An unstaged plan stops `planning-task-docs`, naming it: "staged spec with an unstaged plan; remove or stage the plan".
- **Next stage.** The next stage is the lowest-numbered stage with no matching plan; when every stage has one, there is none.
- **Delivered.** Stage NN is delivered when the first-parent history of main holds a merge commit with the subject `Merge branch '<branch>'` or `Merge branch '<branch>' into <main>`, `<branch>` being the branch `executing-task-docs` Preflight 2 derives from the stage plan's stem. No document is edited to record progress.

## Recipes

`stages_parse` checks one spec against the Lines, Section, Stage headings, Fields and Numbering rules; Coverage is left to the reviewer, plan matching to the caller. Bind `file` to the spec's absolute path and run one recipe; both share this contract:

- **0**: the section parses. Stdout holds one `NN<TAB>name` line per stage in file order, the name as the heading's bytes without CR.
- **1**: a rule failed. Stdout is empty; stderr holds one line, the failure as the Parsing rules word it. Exit 1 with `no "## Stages"` means the spec is not staged; any other exit 1 means its section is broken.
- **2**: the file could not be read or the recipe could not run; stderr says why. This is unavailable evidence, neither a staged nor an unstaged spec.

Only the first failure is reported, in this order: the count of `## Stages` lines in the whole file; then the section from top to bottom, each heading when it is reached (pattern, number, empty slug, then reserved slug) and each stage's fields when the stage ends (Scope before Done when); then the stage count.

Bash, tested with gawk, mawk and busybox awk (BWK/macOS awk and bash 3.2 untested):

```bash
stages_parse() {
  [[ -f $file && -r $file ]] || { printf 'cannot read: %s\n' "$file" >&2; return 2; }
  stages_out=$(LC_ALL=C awk '
    function fail(m) { print m; exit 3 }
    function close_stage() {
      if (num == "") return
      if (sc == 0) fail("stage " num ": missing **Scope:**")
      if (sc > 1) fail("stage " num ": two **Scope:**")
      if (dw == 0) fail("stage " num ": missing **Done when:**")
      if (dw > 1) fail("stage " num ": two **Done when:**")
    }
    {
      line = $0
      if (substr(line, length(line), 1) == "\r") line = substr(line, 1, length(line) - 1)
      s = line; k = 0
      while (k < 3 && substr(s, 1, 1) == " ") { s = substr(s, 2); k++ }
      c = substr(s, 1, 1); r = 0
      if (c == "`" || c == "~") while (substr(s, r + 1, 1) == c) r++
      if (fc != "") { if (c == fc && r >= fn && substr(s, r + 1) !~ /[^ \t]/) fc = ""; next }
      if (r >= 3) { fc = c; fn = r; next }
      L[++n] = line
    }
    END {
      for (i = 1; i <= n; i++) if (L[i] == "## Stages") { h++; if (!at) at = i }
      if (h == 0) fail("no \"## Stages\"")
      if (h > 1) fail("two \"## Stages\"")
      for (i = at + 1; i <= n; i++) {
        x = L[i]
        if (substr(x, 1, 3) == "## ") break
        if (substr(x, 1, 4) == "### ") {
          close_stage()
          if (x !~ /^### Stage [0-9][0-9]: ./) fail("heading not a stage: " x)
          num = substr(x, 11, 2)
          if (num + 0 != prev + 1) fail(sprintf("stage %s after %02d", num, prev))
          if (substr(x, 15) !~ /[A-Za-z0-9]/) fail("stage " num ": name gives an empty slug")
          slug = tolower(substr(x, 15)); gsub(/[^a-z0-9]+/, "-", slug); sub(/^-/, "", slug); sub(/-$/, "", slug)
          if (slug == "follow-ups" || slug == "tails" || slug ~ /-(follow-ups|tails)$/) fail("stage " num ": name gives a reserved slug")
          prev = num + 0; sc = 0; dw = 0; st++
          out = out num "\t" substr(x, 15) "\n"
        } else if (num != "") {
          if (index(x, "**Scope:** ") == 1 && substr(x, 12) ~ /[^ \t]/) sc++
          if (index(x, "**Done when:** ") == 1 && substr(x, 16) ~ /[^ \t]/) dw++
        }
      }
      close_stage()
      if (st < 2) fail("fewer than two stages")
      printf "%s", out
    }' "$file")
  case $? in
    0) printf '%s\n' "$stages_out" || return 2 ;;
    3) printf '%s\n' "$stages_out" >&2; return 1 ;;
    *) return 2 ;;
  esac
}
stages_parse
stages_exit=$?
```

Native pwsh 7 reads the bytes through a one-byte encoding, so names keep the file's bytes, and writes the stage lines and the message to the raw standard streams; the script block's value is the exit:

```powershell
$stages_exit = & {
    $ErrorActionPreference = 'Stop'
    try {
        $byteText = [Text.Encoding]::GetEncoding(28591)
        try { $text = $byteText.GetString([IO.File]::ReadAllBytes($file)) }
        catch { [Console]::Error.WriteLine("cannot read: $file ($($_.Exception.Message))"); return 2 }
        $emit = { param($stream, $s) $b = $byteText.GetBytes($s); $stream.Write($b, 0, $b.Length); $stream.Flush() }
        $fail = { param($m) & $emit ([Console]::OpenStandardError()) "$m`n"; 1 }
        $kept = [Collections.Generic.List[string]]::new()
        $fc = ''; $fn = 0
        foreach ($raw in $text.Split([char]10)) {
            $line = if ($raw.EndsWith("`r", [StringComparison]::Ordinal)) { $raw.Substring(0, $raw.Length - 1) } else { $raw }
            $f = [regex]::Match($line, '^ {0,3}(`+|~+)(.*)$')
            $c = if ($f.Success) { $f.Groups[1].Value.Substring(0, 1) } else { '' }
            $r = if ($f.Success) { $f.Groups[1].Length } else { 0 }
            if ($fc) {
                if ($c -ceq $fc -and $r -ge $fn -and [regex]::IsMatch($f.Groups[2].Value, '^[ \t]*$')) { $fc = '' }
                continue
            }
            if ($r -ge 3) { $fc = $c; $fn = $r; continue }
            $kept.Add($line)
        }
        $at = $kept.IndexOf('## Stages')
        if ($at -lt 0) { return (& $fail 'no "## Stages"') }
        if ($kept.LastIndexOf('## Stages') -ne $at) { return (& $fail 'two "## Stages"') }
        $stages = [Collections.Generic.List[string]]::new()
        $num = ''; $prev = 0; $sc = 0; $dw = 0
        for ($i = $at + 1; $i -le $kept.Count; $i++) {
            $x = if ($i -lt $kept.Count) { $kept[$i] } else { '## ' }
            $h2 = $x.StartsWith('## ', [StringComparison]::Ordinal)
            $h3 = $x.StartsWith('### ', [StringComparison]::Ordinal)
            if (($h2 -or $h3) -and $num) {
                if ($sc -eq 0) { return (& $fail "stage ${num}: missing **Scope:**") }
                if ($sc -gt 1) { return (& $fail "stage ${num}: two **Scope:**") }
                if ($dw -eq 0) { return (& $fail "stage ${num}: missing **Done when:**") }
                if ($dw -gt 1) { return (& $fail "stage ${num}: two **Done when:**") }
            }
            if ($h2) { break }
            if ($h3) {
                $m = [regex]::Match($x, '^### Stage ([0-9]{2}): (.+)$')
                if (-not $m.Success) { return (& $fail "heading not a stage: $x") }
                $num = $m.Groups[1].Value
                if ([int]$num -ne $prev + 1) { return (& $fail ('stage {0} after {1:d2}' -f $num, $prev)) }
                if (-not [regex]::IsMatch($m.Groups[2].Value, '[A-Za-z0-9]')) { return (& $fail "stage ${num}: name gives an empty slug") }
                $slug = [regex]::Replace($m.Groups[2].Value.ToLowerInvariant(), '[^a-z0-9]+', '-').Trim('-')
                if ([regex]::IsMatch($slug, '(^|-)(follow-ups|tails)$')) { return (& $fail "stage ${num}: name gives a reserved slug") }
                $prev = [int]$num; $sc = 0; $dw = 0
                $stages.Add($num + "`t" + $m.Groups[2].Value)
            } elseif ($num) {
                if ([regex]::IsMatch($x, '^\*\*Scope:\*\* .*[^ \t]')) { $sc++ }
                if ([regex]::IsMatch($x, '^\*\*Done when:\*\* .*[^ \t]')) { $dw++ }
            }
        }
        if ($stages.Count -lt 2) { return (& $fail 'fewer than two stages') }
        & $emit ([Console]::OpenStandardOutput()) (($stages -join "`n") + "`n")
        return 0
    } catch {
        [Console]::Error.WriteLine("stages_parse: $($_.Exception.Message)")
        return 2
    }
}
```
