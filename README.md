# agent-skills

Agent-agnostic skills for AI coding agents (Claude Code, Codex, and any agent supporting the [Agent Skills](https://agentskills.io) spec).

## Skills

| Skill | Description |
|-------|-------------|
| `consolidating-plans` | Consolidate over-atomized implementation plans into larger dispatch units for subagent execution. |
| `refine` | Shared review/fix protocol; requires an assigned reviewer. |
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
  refine refine-with-codex refine-with-claude \
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

The implementing session validates findings and applies fixes. The reviewer only reviews. Each follow-up round checks previous fixes first, then the complete task, until a valid clean review and passing checks or a reported blocker/round limit.

Reviewers keep their normal tools, installed skills, plugins, and MCP access under existing permissions. They may use shell commands, browsers, checks, and temporary diagnostic artifacts when useful. The review role prohibits changing reviewed files and Git state; it does not disable tools. Unexpected writes into the reviewed state pause the loop for implementing-session adjudication before another snapshot.

Both implementing and reviewer sessions retain normal skill discovery and automatic invocation. They read and apply matching installed skills during reviews and fixes without repeated user requests, composing their methods and style with refine's required verdict, evidence, and coverage. Actual availability and automatic selection depend on the host runtime.

Model defaults are the latest available Sol for Codex or Opus for Claude, with high effort in every mode. `--model` and `--effort` override those fields independently; explicit premium models such as Astra or Fable are allowed. Native mode needs runtime controls or an existing agent definition that can apply and verify the settings; it never silently becomes a CLI launch.

`refine` can also be invoked directly with an assignment, such as `$refine --codex`. Without one it asks which method to use. Only `auto-cross-refine` chooses the opposite system automatically. Launchers require `refine`; the automatic selector additionally requires its selected CLI launcher. A missing dependency is reported and stops the cycle before review or fixes; the cycle does not install skills automatically.

## License

[MIT](LICENSE)
