# Review Wrapper

Every review attempt runs the reviewer system's native review tool: Codex `codex review -`, Claude `/code-review`. The tool finds the defects. The session that runs the review gives it a short wrapper, which says what is under review and where the task's data is, and a context file, which holds that data. After the attempt the session turns the native report into findings and derives the verdict. Nothing here tells the reviewer how to review, and no prompt of this skill replaces the native tool, not even when the tool is unavailable ([Validate](../SKILL.md#validate)).

Below, **the session** is whoever runs `independent-review` for the attempt: the loop owner, the dual review's controller, or the direct-use session.

## The wrapper

Exact text, with the range form of the target:

```text
Review the changes <base>..<head> in this checkout (git diff <base>..<head>).
Read the context file <absolute path> first: it holds what is under review, the requirements this change must satisfy, the prior findings with their decisions, and the check commands.
Report each finding with its path:line and name the requirement it violates. When a finding repeats a prior finding, start its text with that finding's ID.
Do not change the checkout. Write the report in English.
```

With the files form the first line is instead:

```text
Review these files in full, as they are at <head> in this checkout: <repository-relative paths, separated by spaces>
```

`<absolute path>` is the attempt's `context.md` ([The context file](#the-context-file)). Every SHA is a full SHA.

### Target

The caller supplies one of two forms; direct use always has the range form.

- **Range**, for a task that is the changes of a commit range. A complete task (round 1, final pass, disposition round, direct use) is `<fixed base>..<reviewed commit>`; a scoped round is `<fix commit>^..<fix commit>`.
- **Files**, for a task that is named whole files whose history is no single task range: the documents `refining-task-docs` reviews, already committed between other tasks' commits when the loop starts. The complete passes (round 1, final pass, disposition round) name the files as they are at the reviewed commit, by repository-relative path; a scoped round is still the range of its fix commit.

The reviewed commit is the HEAD of the tree the attempt runs in: the task checkout, or the clone in direct use. For a document review that tree is the docs repository, the one holding the task's commits; the context file names the project checkout as related code.

### Added lines

These lines follow the four lines above, in this order, each only when its row applies:

| When | Line |
| --- | --- |
| Round 1, final pass, direct use | `This pass also covers security: report vulnerabilities this change introduces.` |
| Disposition round | `This round re-examines decisions only: report again only the rejected prior findings you still hold, each with its ID and your evidence.` |
| Dual review, review phase | `Another reviewer works in this checkout at the same time: run no complete test suite, and report a check that fails in a way a concurrent run could explain as such, not as a defect.` |
| A resolved requirement makes the reviewer run a check itself ([What the session owns](../SKILL.md#review-wrapper)) | `Run these required checks yourself in this checkout and report each command with its exit code: <commands with cwd>` |

Nothing else goes into the wrapper: no `Auto:` line (a non-interactive reviewer asks nobody; a window's driver brief carries it), no rule on output-style skills, no tool guidance. A wrapper line states what is under review, where the data is, or what the report must carry for the session's bookkeeping; a line that tells the reviewer how to review is a defect of the wrapper. English is asked for so that the ledger and the dual review's matching read one language.

### Carrying the wrapper

- **Codex:** the whole wrapper is `<attempt dir>/prompt.md`, sent on stdin to `codex review <settings> -` ([CLI guide](cli-reviewers.md#codex-reviewer)).
- **Claude:** stdin is one line, `<attempt dir>/prompt.md`:

  ```text
  /code-review <level> --max-findings all <target> <wrapper lines 2 to the end, joined by single spaces>
  ```

  `<target>` is `<base>..<head>` for a range, or the repository-relative paths, separated by spaces, for files. A bare commit SHA is never the target: the command reads it as "review this commit". `--max-findings all` is always explicit.
- **Window:** the driver brief carries the same arguments ([window guide](window-reviewers.md#prepare)).

**Claude level.** The `/code-review` level is the review's effort, so it equals the resolved reviewer effort: `medium`, `high` or `xhigh`. Effort `low` for a Claude reviewer is refused before launch as an unsupported pair, naming `medium`: at `low` the command reads the diff only. Level `max` is used only when the user set the reviewer effort to `max` explicitly, never by policy; `ultra` never. Under the effort opt-out (`cli-default`) the level is omitted and the command uses the level it remembers; the observed effort is recorded, and an observed `low` makes the attempt `invalid: /code-review ran at low`. The level, or `none (cli-default)`, is recorded in the attempt's `Assignment:` line.

### Empty target

Before the before-evidence of **Launch**, the session checks that the target holds something:

- range: `git -C <tree> diff --quiet <base> <head>` exits 1 (exit 0 is an empty range; any other exit is unavailable evidence and launches nothing);
- files: `git -C <tree> cat-file -e <head>:<path>` exits 0 for each path.

An empty target launches nothing and spends no attempt. Direct use asks for the target as **Direct use** says; `review-fix-loop` reports `blocked: empty review target`.

## The context file

`<attempt dir>/context.md`, outside every checked tree, written by the session before the launch. It holds data only, under these headings in this order:

```markdown
# Review context

## Under review
<one line on the task; the review kind: complete task | fix commit <sha> of round <n> | decisions only; task-owned paths and exclusions; for a document review, `Related code: <absolute project checkout>`>

## Requirements
<requirement documents as paths with the exact relevant sections, or the task text verbatim; applicable project rule files; in direct use, the stated only sources>

## Prior findings
<one line per ledger finding: ID; severity; path:line; scenario and violated requirement; evidence; decision with its basis; fix commit>
<or> None. This is the first review round.

## Candidates
<outside-round candidates carried to the final pass, with their evidence> | None.

## Check commands
<resolved complete-suite and targeted commands with cwd; for each, the last result and the commit it ran on; `no complete suite defined`; merge-candidate checks as `pending: merge candidate`> | None.

## Limits
<clone limits in direct use; unavailable coverage> | None.
```

The session selects requirement files and sections by [Review coverage](../SKILL.md#review-coverage). Run and acceptance record paths are not passed: the reviewer gets the commands and their results as data, and may run targeted checks itself. In a dual review both reviewers get context files with the same content.

## Findings and derived verdict

Native reports carry no verdict, no IDs and no report sections of ours. After a valid attempt the session reads the answer and writes `<attempt dir>/findings.md`, one entry per finding in report order. It neither rewrites nor merges findings.

```markdown
# Findings
Answer: <absolute answer path>; engine: native: codex review | native: /code-review <level>
- F1; native P1; important; ratelimit/limiter.py:26; requirement Q3; repeats: none; class: in scope
  Text: <the finding verbatim>
```

- **Source ID:** `F<n>` by report order, per attempt. It is provenance, not a ledger identity: the dual review qualifies source IDs by reviewer (`codex F1`, `claude F1`) and gives ledger IDs `D<n>`; a single-system loop gives a new finding the ledger ID `R<round>-F<n>` (for example `R1-F2`) and a repeat keeps the ledger ID it repeats. Prior findings in the context file carry ledger IDs.
- **Severity**, native as given and normalized:

  | Native | Normalized |
  | --- | --- |
  | Codex `P0` | critical |
  | Codex `P1`, `P2` | important |
  | Codex `P3` | minor |
  | Claude `important` | important |
  | Claude `nit` | minor |
  | Claude `pre_existing` | no severity: an outside-task candidate |
  | anything else | recorded as given, `unrated` |

- **Location** as given, made relative to the repository.
- **Text** verbatim.
- **Requirement** the finding names, if any.
- **Repeats:** the prior ID the finding starts with, or the ledger finding it matches by the dual review's rule: the same failure scenario against the same requirement ([matching](dual.md#4-matching)).
- **Class:** in scope, outside-round candidate, or outside-task candidate. In a scoped round a finding is in scope when it concerns a prior finding's fix or a defect the fix commit introduced, wherever its line lies; anything else is an outside-round candidate. In a disposition round every finding that repeats no rejected prior finding is an outside-round candidate. A Claude `pre_existing` finding is an outside-task candidate in every review kind.

**Derived verdict** of an attempt: `CHANGES` when an in-scope finding is critical, important or `unrated`; otherwise `CLEAN`. It is written `Derived verdict: CLEAN|CHANGES` and always named as derived by the session from the native report, never as the reviewer's statement. It takes the place of a raw reviewer verdict wherever the loop, the dual review, the records and the status contract read or show one.

The loop adjudicates as before. Two things a reviewer used to state are now read by the session:

- **New evidence** of a repeated finding: the report gives a reproduction, a code reference or a requirement quote that the ledger entry does not hold.
- **A fix's check:** an accepted finding fixed in the reviewed range and not raised again is recorded `not re-raised`, never as verified by the reviewer.
