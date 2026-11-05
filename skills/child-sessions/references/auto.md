# Autonomous mode

`--auto` lets a chain of skills reach its result without the user. Every skill accepts it. Under it, a question a skill would put to the user is **routed** by [Deciding](#deciding) instead, and the user is asked only when the first session is unsure what to build or an option is [hard to undo](#hard-to-undo). Without `--auto` nothing here applies: each skill asks the user as it says.

## Passing

- The **first session** is the one the user started. It runs under `--auto` when the user gives the key or words that mean it ("decide yourself, don't ask me"), mapped to the key and announced as the [run contract](run-contract.md#places) says for any key. Every other session of the chain is a **child**: it was started from a brief or prompt.
- A parent under `--auto` writes `Auto: yes` into every brief or prompt it gives a child: a run-contract brief, a skill's brief template (planner, splitter, refiner, implementer), a nested call's brief, a reviewer's prompt. Without `--auto` the line says `Auto: no`.
- A child whose brief or prompt says `Auto: yes` runs under `--auto`. It runs every skill of this catalog with `--auto`, so the mode reaches its own children and theirs. While it runs any other skill (superpowers `brainstorming`, an execution skill), it keeps these rules itself: that skill's questions are its own.

## Questions

- A child under `--auto` asks nobody directly, in a window too: every question it cannot settle by [Deciding](#deciding) step 1, those of the skills it runs included, ends its turn with `STATUS: blocked`, its Questions holding the question, the options and its recommendation. Windows still open where a skill opens them, for watching; nobody needs to answer in them.
- A question that reaches a session is routed by [Deciding](#deciding): a child's `blocked` status, a question the session's own skill would ask the user, or a question a window child shows on screen.
- A window whose launch has no `send` cannot receive an answer. The parent still decides it by Deciding and records it, then delivers it as child-sessions' `blocked` row does without `send` ([SKILL.md](../SKILL.md#foreground-wait-loop)): it shows the user that given answer, word for word, to type into the window. The user is asked to type it, never to decide it, and the report names this as the window backend's limitation.
- Permission and folder-trust dialogs in a window follow child-sessions [Dialogs](../SKILL.md#dialogs) unchanged: the root approves what lies in scope; everything else is declined and reported, or left to the user unanswered.

## Deciding

A session that receives a question under `--auto`:

1. answers it itself when the answer follows from its own task, brief or documents (the user's request, the task document, a plan's `**Files:**` block), or from the skill's recommended option (an option the skill's own text recommends, such as queue Input 3's "record it `delivered <sha7>` (recommended)" or the outcomes the triage's Select proposes), unless an option is [hard to undo](#hard-to-undo). A child's recommendation in its Questions is not one: it is shown, never followed by itself;
2. otherwise, when it is itself a child, writes its own `STATUS: blocked` with the question, the options, the child's recommendation and the context its parent needs; its parent routes it by these same steps;
3. as the first session, answers it, unless it is unsure what to build or an option is hard to undo; then it asks the user, showing the question, the options and the recommendation.

**Unsure what to build:** the question asks what the result should do or include (a behaviour, a requirement, the scope), and neither the user's request nor the task's documents settle it.

**`CLEAN EXCEPT DISPUTED`.** Accepting it belongs to the first session alone: a child passes it up by step 2. The first session reads both positions of every disputed finding and accepts only when it judges none of them a defect; otherwise it asks the user.

The consents a skill asks of the user are routed the same way: a commit (the triage's commit question, `review-fix-loop`'s commit consent), accepting `CLEAN EXCEPT DISPUTED`, accepting a launch-settings mismatch, dropping a dependency outside the run or skipping its unit, choosing among a spec's plans. A skill sentence such as "The user decides; never choose for them" reads, under `--auto`, as "the first session decides by these steps".

An answer chooses among the options the skill offers and adds none: no push, no force, nothing outside the paths and branches the skill already works on.

## Hard to undo

An action is hard to undo when it destroys work or state Git cannot restore from the repository's own history (deleting a branch or worktree with unmerged commits, discarding uncommitted changes, untracked files or ignored files, removing files outside the task's own paths), or when it leaves the machine (push, publish). A question with such an action among its options always reaches the user, even with a recommended option and even when the recommendation is another option: each child passes it up by step 2, and the first session asks.

## Decisions

Every answer given without the user is a decision. The session that gave it records it in its report under `## Decisions`, one line each:

```text
- <question> — <answer> — <who answered> — <basis>
```

`<who answered>` names the session, by its skill and role (`delivering-task root, first session`; `implementer child impl-<branch>`). `<basis>` names what settled it: the document and its line, the skill's recommended option, or the first session's judgement with its reason. An answer the user typed into a window without `send` stays the deciding session's decision, its basis ending `typed by the user: no send`.

A child writes the section into its status file ([status-file.md](status-file.md)). Each parent copies its children's decisions under its own, so the first session's final report lists every decision of the chain.
