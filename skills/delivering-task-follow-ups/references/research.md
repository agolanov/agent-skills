# Difficult findings

Launch a fresh native research subagent in the fixer's own system when Recheck or Fix cannot establish the cause or safe correction after initial investigation. Group findings that share the same suspected cause into one investigation. Use these researcher settings unless the user explicitly overrides them for this role; fixer and reviewer settings stay unchanged:

| Fixer's system | Researcher model |
| --- | --- |
| Claude | Fable 5.2 |
| Codex | GPT-6.2 Astra |

The effort is chosen per investigation by launch-settings' [Effort by task](../../independent-review/references/launch-settings.md#effort-by-task), from the most demanding finding of the group: `high` for a cause local to one module that the evidence points to, `xhigh` when the suspected cause spans modules, involves concurrency or ordering, or has no reproducer yet. It is the rule's policy value, which an explicit user override of the researcher's effort replaces.

Resolve the exact native model identifier and supported effort through [launch settings](../../independent-review/references/launch-settings.md#resolution), using this table as the caller's explicit policy. Pass both settings through the host's controls with a fresh context, and record its settings evidence through its [Child settings check](../../independent-review/references/launch-settings.md#child-settings-check). If native launch or the requested pair cannot be selected, report that investigation blocked, continue independent findings, and obtain an explicit alternative assignment; do not silently downgrade or switch to a CLI.

Give the researcher the absolute checkout, finding text, intended behavior, relevant evidence and attempted investigation, and any current owned edits. Its scope is read-only investigation: return the cause with code/trace evidence, the smallest sufficient correction, a reproducer or regression check, and remaining uncertainty, or the decision the finding requires with the alternatives the evidence leaves open. It does not edit, commit or start the planning chain. Wait for its completed result, check its evidence against the checkout, then have the fixer implement and verify the correction. A hypothesis alone leaves investigation open; identify and obtain the missing evidence. A research report alone does not settle the finding. Record the researcher's model and effort with the finding that justified the effort in the fixer's report of that investigation.
