# Status file contract

The child writes this file at the absolute path in its brief when finished or stuck. The root reads it and never edits its contents. Before answering `blocked`, the root renames it to `<file>-blocked-<n>` with an unused number; the child writes a new report at the original path.

The first line is exactly one of:

```text
STATUS: done
STATUS: blocked
STATUS: failed
```

No leading text, indentation, trailing text, or combined alternatives. `wait` exits 0 for any of these three lines; the root must distinguish them. A missing or invalid line is not completion.

Use the following fields and sections in this order. Replace the first line with one of the three exact lines above; `<...>` describes the section content, not literal output.

```text
STATUS: done
BRANCH: <branch>
CHECKOUT: <absolute path>
HEAD: <full SHA>

## Commits
<git log --oneline <base>..HEAD>

## Checks
<command → result>

## Review
<final refine verdict: CLEAN, or CLEAN EXCEPT DISPUTED with the disputed findings listed>

## Out of scope
<one line per finding: what — where (path:line) — why it is out of scope>

## Questions
<for blocked: the question, options, and the child's recommendation>
```

Keep every field and section. Use `None` where empty; if a check or review was not run, say so rather than inventing a verdict. In `blocked` or `failed`, report the current branch/checkout/HEAD, partial commits and checks, and what prevents progress. A `done` report records results; the calling task decides what checks and review are required before completion.

Write the report completely before exposing a terminal first line (for example, write a temporary file beside it, then rename it to the status path). The root may read as soon as that first line appears.

The root reads only the first line to choose a branch, then the named sections needed for that branch. `Questions` explains a block; `Checks` and `Review` carry diagnostic results; `Commits`, `Checks`, `Review`, and `Out of scope` support the calling task's completion checks. The raw final review verdict remains unchanged when findings are deferred.
