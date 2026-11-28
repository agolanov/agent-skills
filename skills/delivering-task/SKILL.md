---
name: delivering-task
description: Takes one or more task documents (a plan, a spec with one plan, a task brief, or a directory of them) through implementation and cross review to a merge into the main branch and cleanup, recording follow-ups, several documents as a dependency-ordered queue. Use when tasks are ready to implement and should be executed, reviewed and merged, or, with `--no-merge`, left as reviewed branches.
---

# Delivering Task

`delivering-task <document | directory>... [--no-merge] [--checkout worktree|branch|main] [--parallel N] [--independent] [--run window|inline|subagent|background] [--agent <claude|codex>[:<command>]] [--impl solo|subagents|direct] [--model M|cli-default] [--effort E|cli-default] [--reviewer-run background|window] [--reviewer-model M|cli-default] [--reviewer-effort E|cli-default] [--reviewer-agent <claude|codex>[:<command>]] [--reviewer-dual] [--spec S] [--branch B] [--resume] [--auto]`

Deliver a document through implementation and review. The worker implements, refines and commits tracked follow-ups. The root checks status and Git evidence, records other follow-ups, and integrates when authorized. `--no-merge` leaves a ready branch. A refusal or failed Execute preserves the reported artifacts and ends before integration.

One document uses the phases below. Several documents or a directory use [Queue](references/queue.md) with one wait holder. Refuse `--spec`, `--branch`, `--resume` and any checkout mode except `worktree` for queue input, and `--independent` for one document, naming the key. `--parallel` applies to queue input. Checkout defaults to a worktree. The worker place defaults to `window`.

For every clean/path or continuation gate use [direct-use checkout evidence](../independent-review/references/checkout-state.md#direct-use-preflight), with actual Git exits, process-local `GIT_OPTIONAL_LOCKS=0` and raw outputs. Require successful commands and empty status/diffs for clean gates. Compare exact repository-relative NUL-delimited paths including both rename paths. Unavailable evidence stops the dependent action. Stage and commit owned paths only.

With `--auto`, apply [Deciding](../child-sessions/references/auto.md#deciding) to questions, set `Auto: yes` in the brief and include `## Decisions` in the report.

## Phases

- **`Phase: prepare`.** Open [Prepare](references/prepare.md) only. Launch a window or write the deferred non-window start. Publish the phase result with its handoff path, then end for the caller.
- **`Phase: accept`.** Open [Accept](references/accept.md) only. Start from the record and current worker evidence. Publish a wait after a reopen or return, a blocked question or the terminal result, then end for the caller. The caller owns the wait and starts or continues non-window workers.
- **Direct.** In this session perform [Prepare](references/prepare.md), [Wait](references/wait.md) and [Accept](references/accept.md). When the worker place resolves to `inline`, follow [Inline](references/inline.md) instead.
- **Queue.** Follow [Queue](references/queue.md), including its [phase-agent path](references/queue.md#phase-agents) when the prompt names a phase.

A continuing phase keeps its run and answers from the caller. For phase calls follow the [phase endings](../child-sessions/references/nested-calls.md#phase-endings). Arguments, answers and integration authority come from the current session's context and the caller's phase prompt. The [delivery record](references/delivery-record.md) carries facts. Accept compares authority before taking action.

## Preflight

[Prepare Preflight](references/prepare.md#preflight) resolves the document and validates dependencies before checkout or launch.

## Implementation mode

[Prepare Implementation mode](references/prepare.md#implementation-mode) chooses the execution skill and role.

## Checkout mode

[Checkout modes](references/checkout-modes.md#checkout-mode) defines branch and main modes and their refusals.

## Worktree

[Prepare Worktree](references/prepare.md#worktree) creates the checkout or hands off to resume.

## Brief

[Prepare Brief](references/prepare.md#brief) writes the worker's instructions and identity.

## Launch

[Prepare Launch](references/prepare.md#launch) starts the worker or gives the caller its launch recipe.

### Window

[Launch a window](references/prepare.md#window).

### Subagent and background

[Start or defer a non-window worker](references/prepare.md#subagent-and-background).

### Record

[Complete the launch record](references/prepare.md#record).

## Wait

[Wait](references/wait.md#wait) routes questions and passes an event to Accept.

## Events

[Accept Events](references/accept.md#events) reads evidence and routes the event.

## Verify

[Accept Verify](references/accept.md#verify) verifies the worker's completed report.

## End

[Accept End](references/accept.md#end) handles follow-ups and reports a ready branch or proceeds to Merge.

## Merge

[Accept Merge](references/accept.md#merge) checks the live base, integration authority and affected paths.

## Cleanup

[Accept Cleanup](references/accept.md#cleanup) closes and removes owned resources after integration.

## Inline

[Inline delivery](references/inline.md#inline) applies the worker brief in this session.
