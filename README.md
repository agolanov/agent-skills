# agent-skills

Agent-agnostic skills for AI coding agents (Claude Code, Codex, and any agent supporting the [Agent Skills](https://agentskills.io) spec).

## Skills

| Skill | Description |
|-------|-------------|
| `consolidating-plans` | Consolidate over-atomized implementation plans into larger dispatch units for subagent execution. |
| `child-sessions` | Run Claude Code or Codex in a visible herdr/tmux/terminal window from a brief and wait for its status. |
| `executing-task-docs` | Implement one task document in a child session with cross review, ending with a reviewed branch ready to merge and its follow-ups recorded. |
| `writing-task-follow-ups` | Create, replace or clear a task branch's section in the follow-ups file beside its task document. |
| `triaging-task-follow-ups` | Recheck follow-ups files against the current code, fix the small findings directly in the current session, group the findings that need design into task briefs, and remove settled findings from the files. |
| `delivering-task-follow-ups` | Settle a task's follow-ups from one invocation: triage them, then plan, review and deliver each resulting task brief to the main branch. |
| `delivering-task` | Execute one task document through `executing-task-docs`, then merge it into the main branch and clean up. |
| `planning-task-docs` | Turn one task (a task text, a brief, a spec without a plan or a staged spec with an unplanned stage, or a follow-ups file) into a superpowers spec and plan in a child session. |
| `splitting-spec-into-stages` | Split one large spec into stages in a child session, appending a `## Stages` section for staged planning and delivery. |
| `delivering-spec-stages` | Take one staged spec to the main branch stage by stage: plan, review and deliver each stage in order through the existing skills. A spec without stages is split first with `splitting-spec-into-stages`. |
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

After upgrading, uninstall old installed copies of `deliver-task`, `prepare-tasks`, `deliver-queue`, `reviewing-task-docs` and `resolving-task-follow-ups`: `delivering-task` replaces `deliver-task`, `planning-task-docs` with `refining-task-docs` replace `prepare-tasks`, `delivering-task-queue` replaces `deliver-queue`, `refining-task-docs` replaces `reviewing-task-docs`, and `triaging-task-follow-ups` replaces `resolving-task-follow-ups`.

The refinement skills share dependencies. Install the complete bundle together:

```sh
npx skills add agolanov/agent-skills --skill \
  review-fix-loop independent-review dual-review refine-with-codex \
  refine-with-claude refine-with-a-subagent refine-with-dual-review \
  auto-cross-refine
```

## Runtime support

Use existing Git, agent CLIs and shells; the skills do not install runtimes or change profiles. Resolve the installed child-sessions helper by absolute path: its Bash entrypoint is self-contained, while native Windows uses `child-session.ps1` through installed PowerShell (see [platform runtime](skills/child-sessions/references/platform-runtime.md)). `runtime-dir` supplies artifact paths and `capabilities NAME` supplies supported controls. Plain terminals keep brief/status waiting; questions need direct attention in the visible window, and dialog counts are not observable.

Current focused checks use Linux Git 2.43.0, Bash 5.2.21 and tmux 3.4, and actual native PowerShell 7.6.9 Core/.NET 10.0.14 processes on Windows. Windows PowerShell 5.1 import/status compatibility is checked separately; it is not a universal floor. Synthetic terminal transports exercise process/argv/status behavior, not visible terminal or paid-agent acceptance. Native macOS and native Windows herdr remain unverified here; stock macOS shell/ps/Terminal interfaces are audited. See the ignored local test notes when available for exact commands and acceptance coverage.

Review and delivery gates use [ordinary Git evidence](skills/independent-review/references/checkout-state.md): HEAD, raw NUL status and both binary diffs, real exits and byte comparisons before/after. Failed evidence never means clean. These checks have ignored-file, untracked-content, Git flags/normalization, nested-repository and transient-write limits; they do not prove every filesystem byte stayed unchanged. The retained Python helper is optional compatibility. Native Windows reviewer I/O uses ordinary PowerShell process/file APIs and JSON parsing, with producer exit separate from extraction errors; no jq or Python is required there.

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

[Launch settings](skills/independent-review/references/launch-settings.md) defines the automatic model/effort defaults for every launched agent role (planner, refiner and reviewer: latest available Opus for Claude, latest available Sol for Codex, effort `high`; implementer: the same models with effort `xhigh`; inline implementer, the implementer in `inline` execution mode: latest available Sonnet for Claude, latest available Sol for Codex, effort `medium` or `high`) and independent per-field overrides; the value `cli-default` opts a field out to the CLI's configured default. `refining-task-docs`, `executing-task-docs`, `delivering-task` and `delivering-task-queue` also accept `--reviewer-model` and `--reviewer-effort` for the reviewer of their cross review. Native mode requires controls and runtime evidence for both settings; it never silently switches to CLI.

`review-fix-loop` can also be invoked directly with an assignment, such as `$review-fix-loop --codex`. Without one it asks which method to use. Only `auto-cross-refine` chooses the opposite system automatically. Launchers require `review-fix-loop` and `independent-review`; `refine-with-dual-review` also requires `dual-review`, and the automatic selector additionally requires its selected CLI launcher. A missing dependency is reported and stops the cycle before review or fixes; the cycle does not install skills automatically.

## License

[MIT](LICENSE)
