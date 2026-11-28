# Run elsewhere

Under `--run background` or `window` this session is a thin launcher (run contract [Places](../../child-sessions/references/run-contract.md#places)) and performs none of the sections below: a child of this session's system performs this skill `inline`, its nested calls included, and this session writes its brief, launches it, waits, relays its questions and reports its result.

Follow child-sessions' [Thin launchers](../../child-sessions/references/run-contract.md#thin-launchers) with these local parameters.

- **Inputs.** Only `background` and `window` move the orchestrator outside `inline`. Resolve the project checkout by the first rule of [spec-checks.md](spec-checks.md) and the spec to an absolute path. When the user's words set the implementer's place, announce the mapping now and add `Implementer place: <place> (the user's words)` to the brief. Apply the key list's reviewer refusals before launching, and map the user's words choosing a reviewer to the keys, announced, so that `Arguments:` carries the keys.
- **Worker and arguments.** Role `orchestrator`, with every field taking the role default. Consume only `--run`; `Arguments:` holds the absolute spec and every other key as given, including `--model` and `--effort`, which set the implementer. `Checkout:` is the project checkout.
- **Name.** `stages-<spec-stem>`, with `<spec-stem>` as [state-file.md](state-file.md#names) names it.
- **Authority.** What this skill and its nested calls do with these arguments: windows, documents, commits, merges into main and cleanup, nothing more. The child keeps this skill's nested-call implementation, settings policy and inline fallback.
- **Questions and result.** Stage loop step 1's and every nested call's questions follow the shared window/blocked routing. The child writes `STATUS: done` once it has reported, or `STATUS: failed` with the reason when it stopped, and its End report under `## Report` after the status contract's sections. Report that `## Report` as this skill's End report (after `failed`, the failure and what the status lists), with the shared launch evidence.
