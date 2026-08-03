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
- **Agent-agnostic:** skills must not rely on Claude-only features — no `context: fork`, no hooks. `allowed-tools` is fine.
- **Frontmatter:** `name` (matching the directory) and `description` are required, and stay under 1024 characters combined. Descriptions are third-person and say when to use the skill, not how it works internally. Mark work-in-progress skills with `metadata.internal: true`.
- **README:** the skills table lists every skill; one still under development is tagged `*(in development)*` until its tests pass.

## Developing a skill

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