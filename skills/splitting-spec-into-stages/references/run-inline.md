# Run inline

This session is the splitter: no child, brief, status file or window.

1. Perform the Work of [splitter-brief.md](splitter-brief.md), with the Stage convention file Input located and the brief's rules after Work: Boundaries and out-of-scope findings. Work in the project checkout and talk to the user directly in this session, asking only where a boundary cannot be derived from the spec and the code; under `--auto` such a question is routed by [auto.md](../../child-sessions/references/auto.md#deciding) instead. Where the brief says to write STATUS: blocked, stop and report that to the user. Note each stage larger than criterion 2's guideline, with its reason, for the report.
2. Verify 2–8 hold with the spec as the Artifacts path and this session's own commits as Commits; Verify 1, the status format, and Verify 9, the settings check, do not apply. Exit 2 of `prefix_check` or `stages_parse` stops as Verify says. Correct a mismatch of your own once and verify again; a user commit changing the spec goes to the user per Verify 2, and so does a repeated mismatch.
3. Report as Report says, the larger stages being those of step 1; after a verified run remove the recorded file, with no window to close. The settings line says `inline: current session` and names this session's system.
