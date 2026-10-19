# Open items

Harness design decisions not yet made.

1. **Eval runner.** Contracts only means no runner ships; the first real project builds one.
2. **Hooks.** Claude Code hooks for hard guardrails (`.claude/settings.json`) are not
   defined. Other tools have no equivalent; decide how guardrails are enforced there.
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
11. **Trace events** (`observability`) should follow the OpenTelemetry GenAI conventions,
    which are in Development status and now live in
    `open-telemetry/semantic-conventions-genai`. The `execute_tool` attribute table was not
    read yet. Pin the convention version when filling the module in.
12. **Schema validation in CI.** `modules/tools/validate-examples.cjs` is run by hand. Run it
    in the template repository CI once the repo exists.
13. **No model adapter ships.** `model-interface.md` documents the Anthropic mapping only;
    adapters are written per project.
14. **The template repo is governed by its own `AGENTS.md`**, which tells maintainers to run
    `{{CHECK_CMD}}`, a command that does not exist here. Add a template-only block that
    `init` strips (as it does for `README.md`) pointing maintainers at
    `modules/tools/validate-examples.cjs` instead.
15. **Permanent SKIPs in `full`.** The `backlog`, `eval-case` and `trace-event` stubs show as
    `[SKIP]` in every harness check, and the definition of done asks to justify each skip.
    They go away as those modules are filled in.
