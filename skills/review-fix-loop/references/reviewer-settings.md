# Reviewer Settings

Settings configure the reviewer, not the implementing session. Accept `--model MODEL`, `--effort LEVEL`, and equivalent prose independently. Current explicit values win; reuse recorded values when continuing the same loop; fill remaining fields with these defaults:

Automatic policy, consolidated 2026-10-29 (family policy, not a pinned version list):

| Reviewer system | Automatic family | Excluded from automatic choice; explicit allowed | Default effort |
| --- | --- | --- | --- |
| Codex | Latest available Sol | Astra | high |
| Claude | Latest available Opus | Fable | high |

CLI configured defaults and the parent's model are not substitutes for this policy. A model must belong to the assigned system. When changing system or launch method, re-resolve incompatible saved defaults.

Resolve the exact account/provider-available version using evidence relevant to the launch method:

- **CLI:** for Codex, use app-server `model/list` with the reviewer's provider and task configuration, following pagination. For Claude, use model-picker/account/provider information and current official model-configuration documentation. Verify alias mappings; `best` can select Fable.
- **Native:** use the current native tool's model options and effective agent settings. A CLI catalog does not establish native availability. Resolve aliases to the actual model; an alias can inherit the parent's older version.

Choose the newest version of the required family that the account can use; a higher version number in another family does not qualify. If the mapping or availability cannot be established, report the unresolved setting rather than guess.

Verify the model/effort pair is supported and permitted. Record the concrete model, effort, and discovery evidence; explicitly apply both settings, including high when it is the default. Silent model fallback or effort coercion does not satisfy the assignment. Asking for CLI defaults is an explicit opt-out; record the effective values and do not claim automatic settings were applied.

Sources: [Codex model discovery](https://learn.chatgpt.com/docs/app-server#list-models-modellist), [Claude model configuration](https://code.claude.com/docs/en/model-config).
