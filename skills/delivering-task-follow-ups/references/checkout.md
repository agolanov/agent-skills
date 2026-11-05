Display copy of `triaging-task-follow-ups/SKILL.md` Input 3, its project-checkout rule; keep equal.

# Project checkout

The project checkout is the top level of the current repository. When that top level is itself a separate docs repository (a `docs/superpowers` directory with its own repository), the project checkout is `git -C <docs-top>/../.. rev-parse --show-toplevel`; when that fails, ask the user.
