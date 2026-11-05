Display copy of `splitting-spec-into-stages/SKILL.md` Input, from its first paragraph through spec check 3 (the project checkout and docs repository rules, the "no such file" stop, classification rules 1–3 and spec checks 1–3); keep equal.

# Spec checks

The project checkout is the top level of the current repository. When that top level is a separate docs repository (a `docs/superpowers` directory with its own repository), the project checkout is `git -C <docs-top>/../.. rev-parse --show-toplevel`; when that fails, ask the user for the project checkout (under `--auto`, routed by [auto.md](../../child-sessions/references/auto.md#deciding)). Project-relative paths such as `**Spec:**` headers resolve against the project checkout, never the docs repository. Docs repository = `git -C <project>/docs/superpowers rev-parse --show-toplevel` when that directory exists, else the project checkout. Resolve the input; every stop happens before any window. An input naming no existing regular file (a missing path, a directory or other non-regular file, a task text) stops, naming it: "no such file; only an existing design spec is split into stages". Read the file completely and classify it by the first rule that matches:

1. **Plan**: it carries the superpowers plan header (`> **For agentic workers:** REQUIRED SUB-SKILL:`) or lies in a `plans/` directory of a superpowers docs dir (`docs/superpowers/plans/`). Refuse, naming it: "a plan, not a spec; only a design spec is split into stages".
2. **Spec**: named `*-design.md` or lying in a `specs/` directory. Run the spec checks below.
3. **Anything else** (a brief, a follow-ups file, any other file): refuse, naming it: "not a spec; only a design spec is split into stages".

Spec checks, in order:

1. `git -C <spec dir> rev-parse --show-toplevel` prints the docs repository; `<rel>` is the spec's path relative to it. Any other result stops, naming the spec's repository and the docs repository.
2. Locate the installed `planning-task-docs/references/stages-section.md` (the sibling [stages-section.md](../../planning-task-docs/references/stages-section.md#recipes)) by absolute path. Missing: stop, naming `planning-task-docs` for the user to install. The brief's `Stage convention:` line names this path.
3. Run `stages_parse` from that file's Recipes on the spec, then follow its exit:
   - Exit 1 with stderr exactly `no "## Stages"`: the spec is unstaged; a `## Stages` line inside a fenced code block is no heading. Then check that a section appended at its end would be read: copy the spec to a temporary file outside Git, append the probe text `\n\n## Stages\n\n### Stage 01: Probe\n\n**Scope:** probe\n**Done when:** probe\n\n### Stage 02: Probe\n\n**Scope:** probe\n**Done when:** probe\n` (each `\n` one line feed), run `stages_parse` on the copy and remove it. Exit 0: continue. Exit 1: the spec ends inside a code fence that never closes (the Lines rule of the [display copy](stages-section.md#parsing-rules)), which would hide the appended section; stop: "the spec ends inside an unclosed code fence; close it and rerun". Exit 2: stop, reporting the stages evidence unavailable with the stderr reason.
   - Exit 2: stop, reporting the stages evidence unavailable with the stderr reason.
   - Any other exit (0, or exit 1 naming a broken section): the spec has a `## Stages` heading. Refuse: "already staged; edit the section by hand or run `delivering-spec-stages`".
