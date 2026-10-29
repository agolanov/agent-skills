# Reviewer Settings

Settings configure the reviewer, not the implementing session. Accept `--model MODEL`, `--effort LEVEL`, and equivalent prose independently. Current explicit values win; reuse recorded values when continuing the same loop; fill remaining fields with these defaults:

| Reviewer system | Automatic model family | Effort |
| --- | --- | --- |
| Codex | Latest available Sol | high |
| Claude | Latest available Opus | high |

Automatic selection excludes premium Astra/Fable. Explicit assignments may select them. CLI configured defaults and the parent's model are not substitutes for this policy. A model must belong to the assigned system. When changing system or launch method, re-resolve incompatible saved defaults; preserve current explicit overrides.

Resolve the exact account/provider-available version using evidence relevant to the launch method:

- **CLI:** for Codex, use app-server `model/list` with the reviewer's provider and task configuration, following pagination. For Claude, use model-picker/account/provider information and current official model-configuration documentation. Verify alias mappings; `best` can select Fable.
- **Native:** use the current native tool's model options and effective agent settings. A CLI catalog does not establish native availability. Resolve aliases to the actual model; an alias can inherit the parent's older version.

Choose the newest available version inside the required family, not a different family with a higher version number. If an account excludes the newest version, an available older version of the same family is eligible. If the mapping or availability cannot be established, report the unresolved setting rather than guess.

Verify the model/effort pair is supported and permitted. Record the concrete model, effort, and discovery evidence; explicitly apply both settings, including high when it is the default. Silent model fallback or effort coercion does not satisfy the assignment. Keep the resolved pair for all rounds/retries unless the user changes it. Asking for CLI defaults is an explicit opt-out; record the effective values and do not claim automatic settings were applied.

Sources: [Codex model discovery](https://learn.chatgpt.com/docs/app-server#list-models-modellist), [Claude model configuration](https://code.claude.com/docs/en/model-config).
