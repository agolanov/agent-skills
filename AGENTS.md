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

Every change to a skill has a delivery mode. **Full** is the default: every new skill and every change to what a skill or script does. **Light** is for small changes to the text of existing skills. The spec declares the mode in its header, beside the date and status: `**Delivery mode:** light` or `**Delivery mode:** full`; no line means full. The agent that writes the spec decides against the criteria below and takes full when in doubt; it tells the user the mode and its reason inside the spec and asks no separate question; the spec's cross review checks the decision as a requirement. Once the spec is approved the mode is frozen: a planning or implementing agent that finds the criteria violated does not change the header or widen the change, it ends `STATUS: blocked` with the question (widen to full, or narrow the change). In full mode the plan carries the test-first process below; an implementing agent whose plan leaves it out ends `STATUS: blocked` with the question (stop so the plan can be revised with the test-first steps and delivered again, or deliver as planned) instead of running the plan as written or adding the steps itself.

### Light mode

A change is light when all of the following hold:

- it adds no new skill and no new script command;
- it adds no new state: no new status field or section, no new labelled brief line, no new queue state, no new runtime or test file that a skill reads or writes;
- it changes only wording or a few rules of existing skills (`SKILL.md`, files under `references/`, `README.md`, `AGENTS.md`); a script only where the edit changes no behaviour (a message, a usage line, a comment).

"A few rules" is not a line count: the test is whether a reviewer can check the change against the spec by reading the diff. A change that needs a fixture to be understood is full.

A light change is the edit, the checks that already exist for the touched skills, and one review:

1. Structural validation (below) for each changed skill directory.
2. The scripted suites under `tests/` that exist in the checkout for the touched skills (`tests/<name>/test_*.sh`, `tests/<name>/test_*.py`, `tests/<name>/tools/check-*.sh`) and `tests/refine/test_stub_reviewer.py`. Suites that exercise a skill's script or fakes resolve it from their own location, so from a task worktree run them through a mirror: a temporary directory with `skills` symlinked to the worktree and every `tests/<name>` directory the suite reads copied in (`tests/deliver-task/test_fakes.py` also reads `tests/child-sessions/tools`). Run `tests/refine/test_stub_reviewer.py` in place from the main checkout: one of its cases expects its own repository outside the temporary directory. An absent suite is unavailable coverage, never recreated; no suite is edited for a light change.
3. The installation check (below): `npx -y skills add <checkout> --list`.
4. One `auto-cross-refine` invocation with its normal round limit.

Not part of a light change: new fixtures, fake-agent scenarios, replay cases, RED or GREEN runs with fresh subagents, reruns of the existing subagent replays, and entries in `baseline-notes.md` or `green-notes.md`.

### Full mode

Skills are developed test-first, following `superpowers:writing-skills`:

1. **RED** — run a fresh subagent on a fixture *without* the skill and write down what it gets wrong (`tests/<name>/baseline-notes.md`).
2. **GREEN** — write SKILL.md against those observed failures, then verify with fresh subagents until they pass.
3. **REFACTOR** — add edge-case fixtures, close the loopholes they expose, confirm installation via the skills CLI.

Every iteration (what failed → what changed in the skill → rerun result) is recorded in `tests/<name>/green-notes.md`.

Subagent tests always run on **copies** of the fixtures in a temp directory (`mktemp -d`), never on the repository files. When a test expects the agent to notice uncommitted changes, `git init` the temp directory and commit the fixture there first.

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
