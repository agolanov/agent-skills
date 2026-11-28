# Find delivered branches

For one listing, resolve the selected project's `refs/heads/<main>` to a full commit SHA. Retain the ref name and SHA. Run one read-only scan bound to that commit:

```sh
git log --first-parent --merges --format='%H%x09%cs%x09%s' <main-sha>
```

Run it in the project main checkout. Retain Git's actual exit and raw stdout/stderr. A failed ref or log read stops the dependent decision. A successful empty history has no matches.

Read the records newest first, splitting each line at the first two tabs into SHA, date and whole subject. For each requested branch, take the first subject exactly equal to `Merge branch '<branch>'` or `Merge branch '<branch>' into <main>`, with case, quoting and every character preserved. Return its SHA and date, or no match. Match every branch locally against the same scan, including dependencies outside the queue. Use fixed-string comparison (PowerShell ordinal equality), with no shell interpolation of subjects.

A listing describes its pinned SHA. Resolve and scan anew for a live stage decision, a post-refinement re-read that checks delivered stages, or a resumed listing. Acceptance still takes its own current-main and merge gates.
