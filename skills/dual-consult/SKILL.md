---
name: dual-consult
description: "Has Claude and Codex each study an open question independently, argue it out and write one decision file: a joint recommendation, the points they still disagree on, the questions only the user can answer and next steps, without changing the project. Use when a question, a vague idea, open follow-ups or a doubtful aspect of a project needs two independent views and a recommendation before the user decides."
---

# Dual Consult

```text
dual-consult <"question"|file>... [--run background|window] [--name <slug>]
             [--claude=<command>] [--codex=<command>]
             [--claude-model M] [--codex-model M] [--claude-effort E] [--codex-effort E] [--effort E]
```

`--effort` sets both efforts; `--claude=` and `--codex=` are child-sessions launch commands; `--name` sets the slug of the file names, otherwise derive it from the question. The user's words override like keys.

| Consultant | Model | Effort |
| --- | --- | --- |
| Claude | Fable 5.2 | `high` |
| Codex | GPT-6.2 Astra | `high` |

1. **Role.** You orchestrate, whichever system you run on, and take no side. The consultants are one Claude and one Codex. Nothing in the project changes and nobody acts on the result: the user decides.
2. **Question.** Read what the user gave: text, files, a delivered task, a mix. Write the question down in a file outside the project: the question, where to look (paths, commit ranges, the task's documents), what the user has already decided. Give no answer of your own. Ask the user one question, and only when you cannot tell what is being asked.
3. **Positions.** Start both consultants with the same brief through [child-sessions](../child-sessions/SKILL.md), in parallel, in the background or in windows under `--run window`. A consultant that cannot be started stops the run: say so and write no file. Each studies the project alone and writes its position to a file: options, a recommendation with evidence, questions only the user can answer, next steps. They may run anything; they change nothing in the project and nothing outside this machine, and they ask nobody.
4. **Argument.** Give each consultant the other's position in its own conversation, to challenge and to answer with an updated position. Repeat until they agree, with no round limit. When both only repeat themselves on a point, close it: both decisions go into the file, no winner named, and the user chooses.
5. **Decision file.** Draft the decision outside the project with the sections Question, Options considered, Recommendation, Disagreements, Questions for you, Next steps. Add nothing of your own. Have both consultants confirm that it says what they concluded, correcting the draft until both do. Then write it as `docs/superpowers/decisions/YYYY-MM-DD-<slug>-decision.md` in the project, and their positions, in order, beside it as `YYYY-MM-DD-<slug>-transcript.md`, only when neither file exists yet. Never overwrite an existing file; commit nothing.
6. **Report.** Give the path and the recommendation in two sentences, and stop.

Next steps name a skill and its argument where a skill performs the step ("turn this into a task: `planning-task-docs <this file>`"); for a follow-ups file each finding gets one of `delivering-task-follow-ups`' outcomes: fix, drop, brief, keep.
