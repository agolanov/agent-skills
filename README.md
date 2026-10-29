# agent-skills

Agent-agnostic skills for AI coding agents (Claude Code, Codex, and any agent supporting the [Agent Skills](https://agentskills.io) spec).

## Skills

| Skill | Description |
|-------|-------------|
| `consolidating-plans` | Consolidate over-atomized implementation plans into larger dispatch units for subagent execution. |
| `child-sessions` | Run Claude Code or Codex in a visible herdr/tmux window from a brief and wait for its status. |
| `deliver-task` | Execute one reviewed plan in a child session with cross review, then merge and record leftovers. |
| `prepare-tasks` | Prepare ideas, specs and plans for delivery in visible child sessions and write an ordered queue file. |
| `review-fix-loop` | Shared review/fix protocol; requires an assigned reviewer. |
| `refine-with-codex` | Run the cycle with a separate Codex reviewer process. |
| `refine-with-claude` | Run the cycle with a separate Claude reviewer process. |
| `refine-with-a-subagent` | Run the cycle with a built-in subagent of the implementing system. |
| `auto-cross-refine` | Choose the opposite reviewer system: Codex to Claude, Claude to Codex. |

## Installation

Install all skills:

```sh
npx skills add agolanov/agent-skills
```

Install a single skill:

```sh
npx skills add agolanov/agent-skills --skill consolidating-plans
```

The refinement skills share dependencies. Install the complete bundle together:

```sh
npx skills add agolanov/agent-skills --skill \
  review-fix-loop refine-with-codex refine-with-claude \
  refine-with-a-subagent auto-cross-refine
```

## Refinement

In Codex, invoke a skill with `$`; in Claude Code, use `/`. For example:

```text
$refine-with-codex
$refine-with-claude --effort xhigh
$refine-with-a-subagent
$auto-cross-refine
```

The independent reviewer reviews; the implementing session decides findings and fixes them. The cycle commits task state and fixes per round on the task branch; the user squashes afterwards. See [review-fix-loop](skills/review-fix-loop/SKILL.md) for the cycle, capabilities, skill composition, scope, and completion rules.

[Reviewer settings](skills/review-fix-loop/references/reviewer-settings.md) defines automatic model/effort defaults and independent overrides. Native mode requires controls and runtime evidence for both settings; it never silently switches to CLI.

`review-fix-loop` can also be invoked directly with an assignment, such as `$review-fix-loop --codex`. Without one it asks which method to use. Only `auto-cross-refine` chooses the opposite system automatically. Launchers require `review-fix-loop`; the automatic selector additionally requires its selected CLI launcher. A missing dependency is reported and stops the cycle before review or fixes; the cycle does not install skills automatically.

## License

[MIT](LICENSE)
