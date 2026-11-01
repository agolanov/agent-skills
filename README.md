# agent-skills

Agent-agnostic skills for AI coding agents (Claude Code, Codex, and any agent supporting the [Agent Skills](https://agentskills.io) spec).

## Skills

| Skill | Description |
|-------|-------------|
| `consolidating-plans` | Consolidate over-atomized implementation plans into larger dispatch units for subagent execution. |
| `child-sessions` | Run Claude Code or Codex in a visible herdr/tmux window from a brief and wait for its status. |
| `executing-task-docs` | Implement one task document in a child session with cross review, ending with a reviewed branch ready to merge and its follow-ups recorded. |
| `writing-task-follow-ups` | Create, replace or clear a task branch's section in the follow-ups file beside its task document. |
| `delivering-task` | Execute one task document through `executing-task-docs`, then merge it into the main branch and clean up. |
| `planning-task-docs` | Turn one task (a task text, a brief, a spec without a plan, or a follow-ups file) into a superpowers spec and plan in a child session. |
| `refining-task-docs` | Cross-review one task's spec and plan in a child session, fix the findings, and mark the documents that pass with a `Review:` line. |
| `delivering-task-queue` | Deliver several task documents, a list or a directory, through `delivering-task`, ordered by their `**Depends on:**` headers, in parallel up to a limit. |
| `review-fix-loop` | Shared review/fix protocol; requires an assigned reviewer. |
| `independent-review` | One validated review by a separate Codex or Claude reviewer, without fixes. |
| `dual-review` | Codex and Claude review in parallel; findings only one raised are cross-checked; one severity-ranked list of confirmed findings, without fixes. |
| `refine-with-dual-review` | Run the cycle with both reviewers in every round. |
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

After upgrading, uninstall old installed copies of `deliver-task`, `prepare-tasks`, `deliver-queue` and `reviewing-task-docs`: `delivering-task` replaces `deliver-task`, `planning-task-docs` with `refining-task-docs` replace `prepare-tasks`, `delivering-task-queue` replaces `deliver-queue`, and `refining-task-docs` replaces `reviewing-task-docs`.

The refinement skills share dependencies. Install the complete bundle together:

```sh
npx skills add agolanov/agent-skills --skill \
  review-fix-loop independent-review dual-review refine-with-codex \
  refine-with-claude refine-with-a-subagent refine-with-dual-review \
  auto-cross-refine
```

## Refinement

In Codex, invoke a skill with `$`; in Claude Code, use `/`. For example:

```text
$refine-with-codex
$refine-with-claude --effort xhigh
$refine-with-a-subagent
$refine-with-dual-review
$auto-cross-refine
$dual-review
$independent-review --codex
```

The independent reviewer reviews; the implementing session decides findings and fixes them. The cycle commits task state and fixes per round on the task branch; the user squashes afterwards. See [review-fix-loop](skills/review-fix-loop/SKILL.md) for the cycle, skill composition, scope and completion rules, and the [review prompt](skills/independent-review/references/review-prompt.md) of `independent-review` for the reviewer's capabilities.

[Reviewer settings](skills/independent-review/references/reviewer-settings.md) defines automatic model/effort defaults and independent overrides. Native mode requires controls and runtime evidence for both settings; it never silently switches to CLI.

`review-fix-loop` can also be invoked directly with an assignment, such as `$review-fix-loop --codex`. Without one it asks which method to use. Only `auto-cross-refine` chooses the opposite system automatically. Launchers require `review-fix-loop` and `independent-review`; `refine-with-dual-review` also requires `dual-review`, and the automatic selector additionally requires its selected CLI launcher. A missing dependency is reported and stops the cycle before review or fixes; the cycle does not install skills automatically.

## License

[MIT](LICENSE)
