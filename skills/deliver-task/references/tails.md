# Tails and follow-up brief

After merge, gather the child's Out of scope plus deferred minor, outside-scope and disputed review findings. Append one line per finding to `<plan-path-without-extension>-tails.md` in the main checkout:

```text
- <branch> <merge-sha7>: <what> — <where> — <why>
```

Use the merge commit's seven-character SHA, a concrete `path:line` location, and the scope/deferral reason. For a dispute, preserve both positions and the unresolved question. Preserve prior entries; do not invent a finding for zero tails. Report the count.

When the plans directory contains tracked files, commit only this tails file on main immediately after merge, as `tails: <branch>`. When ignored, append locally without force-adding. Do not put tails on the reviewed child branch. With no findings there is no tails commit. Stop for unexpected main dirt rather than include unrelated files.

Write `${XDG_RUNTIME_DIR:-/tmp}/child-sessions/<branch>-tails-brief.md` outside Git even when there are no tails. Fill this ready follow-up template with absolute paths and actual findings:

```text
Follow up on leftovers from <branch>, merge <full-merge-sha>.

Main checkout: <absolute-main-checkout>
Source plan: <absolute-plan>
Source spec: <absolute-spec>
Project rules: <absolute-rules-paths>
Recorded tails: <absolute-tails-path, or None: no findings>

Findings:
<one line per finding, including provenance, location, scope reason and both positions for disputes; or None>

Read the source inputs, project rules and findings. Establish current code locations and ask the user to select scope/resolve disputes before implementation. The original delivery did not authorize fixing these leftovers. Prepare a reviewed follow-up spec/plan for selected work; use a fresh branch for separately authorized implementation. Do not alter the completed task branch or assume merge/push/deploy authority.

Original review: <final refine mode and unchanged raw reviewer verdict>
```

Print the absolute follow-up brief path. The user chooses whether to open it with child-sessions; deliver-task never launches it automatically.
