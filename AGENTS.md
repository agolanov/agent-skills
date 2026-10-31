# agent-skills

Agent-agnostic skills for AI coding agents, following the [agentskills.io](https://agentskills.io) spec.

## Layout

```
skills/<name>/SKILL.md        # skill name == directory name
skills/<name>/references/     # supporting docs shipped with the skill
```

Two more directories exist locally but are gitignored — they are working material, not part of what ships:

```
tests/<name>/                 # fixtures and test notes for that skill
docs/superpowers/specs/       # design specs (YYYY-MM-DD-<slug>-design.md)
docs/superpowers/plans/       # implementation plans (YYYY-MM-DD-<slug>.md)
```

## Conventions

- **Language:** everything is written in English — SKILL.md, references, README, commit messages, and the gitignored fixtures and notes as well.
- **Attribution:** commit messages and pull request descriptions end with their own content, unsigned: no `Co-Authored-By` trailer and no "Generated with" line, even when the agent's harness asks for one. This holds for every agent, subagent and child session.
- **Agent-agnostic:** skills must not rely on Claude-only features — no `context: fork`, no hooks. `allowed-tools` is fine.
- **Frontmatter:** `name` (matching the directory) and `description` are required, and stay under 1024 characters combined. Descriptions are third-person and say when to use the skill, not how it works internally. Mark work-in-progress skills with `metadata.internal: true`.
- **README:** the skills table lists every skill; one still under development is tagged `*(in development)*` until its tests pass.

## Developing a skill

Every spec has a `## Verification` section in free form: what the change could break, the check that covers each risk, and how to run it. The spec's author chooses the checks from the change's risk and asks the user no separate question about them. The section is frozen once the spec is approved, like the rest of the spec.

Two minimums hold for every spec, whatever its author decides:

1. **Behaviour: one RED and one GREEN.** When the change alters what an agent following a skill does (a rule, a step, a stop condition, a brief or prompt the agent acts on, or a script's behaviour), Verification includes:
   - **RED**: a fresh subagent on a copied fixture with the skill text as it is before the edits, run once, before any edit. Its result goes to `tests/<name>/baseline-notes.md`.
   - **GREEN**: a fresh subagent on the same kind of fixture with the edited skill, run once, after all edits of the plan. Its result goes to `tests/<name>/green-notes.md`.

   GREEN runs again only after a failed GREEN, once the failure is fixed; fixes made later by the cross review trigger no further GREEN. A change that alters only wording, with no change in what the agent does, needs neither run, and its spec says why the change is wording only.
2. **One external cross review.** Every delivery ends with one `auto-cross-refine` invocation with its normal round limit; that skill chooses the opposite system as the reviewer. Specs name the skill, not a reviewer system.

Further checks a spec may name, each because a named risk needs it:

- Structural validation (below) of each changed skill directory.
- The scripted suites under `tests/` that exist in the checkout for the touched skills (`tests/<name>/test_*.sh`, `tests/<name>/test_*.py`, `tests/<name>/tools/check-*.sh`) and `tests/refine/test_stub_reviewer.py`. Suites that exercise a skill's script or fakes resolve it from their own location, so from a task worktree run them through a mirror: a temporary directory with `skills` symlinked to the worktree and every `tests/<name>` directory the suite reads copied in (`tests/deliver-task/test_fakes.py` also reads `tests/child-sessions/tools`). Run `tests/refine/test_stub_reviewer.py` in place from the main checkout: one of its cases expects its own repository outside the temporary directory. An absent suite is unavailable coverage, never recreated.
- The installation check (below): `npx -y skills add <checkout> --list`.
- Edge-case fixtures and replay scenarios (see Local behavioral checks).

Subagent tests always run on **copies** of the fixtures in a temp directory (`mktemp -d`), never on the repository files. When a test expects the agent to notice uncommitted changes, `git init` the temp directory and commit the fixture there first.

The reviewer of a spec checks its Verification section for proportion in both directions: a check the named risks do not need is a finding, and so is a risk of the change no check covers, a missing minimum included.

The implementing agent:

- runs exactly the checks Verification names, no fewer. A further check is allowed only with its reason written under Checks in the status file. A named check that cannot run (an absent suite, a missing validator) is reported unavailable, never recreated or replaced by another check;
- follows `superpowers:writing-skills` and `superpowers:test-driven-development` for how to run a RED or GREEN, and Verification for how many: the spec takes precedence over their test-first rules ("no skill without a failing test first", iterate until bulletproof);
- lets the final `auto-cross-refine` replace the execution skill's own final review of the whole implementation (for example the final code review of `superpowers:subagent-driven-development`); per-task reviews inside the execution skill stay at its discretion;
- chooses the execution skill from the plan and names it with the reason in its report: `superpowers:executing-plans` when the plan is a few tasks done in order, where a task builds on an earlier one or edits the same files; `superpowers:subagent-driven-development` when the plan has many tasks independent of each other (separate files, no task needs another's result).

## Installation check

```sh
npx -y skills add <path-to-this-repo> --list
npx -y skills add <path-to-this-repo> --skill <name> -a claude-code -y
```

## Structural validation

Use `quick_validate.py` supplied by the installed skill-creator skill to validate each skill directory. Locate it through that skill rather than assuming a machine-local path. Report unavailable validator or Python dependencies as unavailable validation; do not claim PASS.

## Local behavioral checks

The ignored `tests/refine/` material is available only in a working checkout that has it. A fresh clone may lack these tools, fixtures and notes: report that behavioral coverage unavailable rather than claiming PASS or force-adding the files.

When present, run the controlled reviewer process tests:

```sh
python3 tests/refine/test_stub_reviewer.py
```

Replay scenarios through fresh implementing agents on disposable copied Git checkouts, using `tests/refine/regression-checklist.md` and `tests/refine/stub-scenarios/README.md` for independent grading. Each agent applies the skill, builds actual prompts and records actions; the utility only emits scripted results. Bind the following variables to the copied case, external state/prompt and marked temporary checkout:

```sh
python3 tests/refine/tools/stub_reviewer.py \
  --script "$case_script" --state "$replay_state" \
  --checkout "$test_checkout" < "$round_prompt"
```

Keep synthetic protocol results separate from real reviewer runtime/model/effort proof. Save baseline/green iterations, actual calls, targets, commit/check evidence and limitations in ignored test notes.
