# agent-skills

Agent-agnostic skills for AI coding agents (Claude Code, Codex, and any agent supporting the [Agent Skills](https://agentskills.io) spec).

## Skills

| Skill | Description |
|-------|-------------|
| `consolidating-plans` | Consolidate over-atomized implementation plans into larger dispatch units for subagent execution. |

## Installation

Install all skills:

```sh
npx skills add agolanov/agent-skills
```

Install a single skill:

```sh
npx skills add agolanov/agent-skills --skill consolidating-plans
```

## License

[MIT](LICENSE)
