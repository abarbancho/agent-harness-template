# Open items

Harness design decisions not yet made.

1. **Eval runner and judge.** Contracts only means no runner, no judge prompt and no
   calibration tooling ship; the first real project builds them. `docs/evals.md` lists
   what they must do. Pairwise comparison (useful for migrations) is not in the case
   format yet, and `endState` checks are named functions each project writes.
2. **Coding-assistant permissions.** The `guardrails` module covers the tool policy of the
   agent being built. The permissions of the AI coding assistants that edit the repo (Claude
   Code hooks in `.claude/settings.json`) are not defined, and other tools have no
   equivalent; decide how they are enforced.
3. **Size thresholds** in `modules/specs/files/docs/process/scaling.md` are drafts.
4. **Cursor/Copilot role adapters.** Roles have Claude Code subagent adapters only.
5. **Role toggling** is covered by modules; confirm `roles` should stay out of `lite`.
6. **`init` JSON parsing.** `init.sh` reads `profiles.json` and `module.json` with `sed`, so
   arrays must stay on one line. Revisit if the metadata grows.
7. **`init` re-runs.** `init` deletes itself, so adding a module later means copying it by
   hand from the template. Decide whether to keep `modules/` and `init.*` instead.
8. **`scaling.md` assumes `roles`.** Its roles column names planner, implementer and
   reviewer, which do not exist if only `specs` is installed. Fix when filling in `specs`.
9. **Cross-platform verification.** `init` and `check` were only tested on Windows (see
   `TEMPLATE.md`).
10. **Tool annotations.** `annotations` is an open object because the MCP annotation field
    names could not be confirmed against the current spec revision. Name them once verified.
11. **OpenTelemetry GenAI conventions are in Development status** and live in
    `open-telemetry/semantic-conventions-genai`. `trace-events.md` was written from the main
    branch on 2026-10-19; no release was pinned. The base `execute_tool` section of the spans
    page was read only in part (attributes came from the skill refinements in the agent spans
    page), and the nesting of `chat` and `execute_tool` under `invoke_agent` is this
    template own rule, not a convention. Re-read and pin when the repository publishes
    releases. The value of `gen_ai.tool.type` is not constrained for the same reason.
12. **Schema validation in CI.** `modules/tools/validate-examples.cjs` is run by hand. Run it
    in the template repository CI once the repo exists.
13. **No model adapter ships.** `model-interface.md` documents the Anthropic mapping only;
    adapters are written per project.
14. **The template repo is governed by its own `AGENTS.md`**, which tells maintainers to run
    `{{CHECK_CMD}}`, a command that does not exist here. Add a template-only block that
    `init` strips (as it does for `README.md`) pointing maintainers at
    `modules/tools/validate-examples.cjs` instead.
15. **Permanent SKIP in `full`.** The `backlog` stub shows as `[SKIP]` in every harness
    check, and the definition of done asks to justify each skip. It goes away when the
    module is filled in.
16. **No policy engine ships.** `guardrails.md` gives the evaluation algorithm and the
    schemas; a project writes the hook. The `sensitiveTools` and `untrustedSources` lists
    are maintained by hand, so an unclassified tool silently weakens the Rule of Two check.
17. **Meta Rule of Two source.** The original page returned 403; the wording comes from two
    articles that quote it. Re-read the original and adjust `guardrails.md` if it differs.
