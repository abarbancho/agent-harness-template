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
3. **Size thresholds** in `modules/specs/files/docs/process/scaling.md` (more than 5 files, the
   large and medium signals) are reasoned defaults, not measured. Revisit after real use.
4. **Cursor/Copilot role adapters.** Roles have Claude Code subagent adapters only.
5. **Role toggling** is covered by modules; confirm `roles` should stay out of `lite`.
6. **`init` JSON parsing.** `init.sh` reads `profiles.json` and `module.json` with `sed`, so
   arrays must stay on one line. Revisit if the metadata grows.
7. **`init` re-runs.** `init` deletes itself, so adding a module later means copying it by
   hand from the template. Decide whether to keep `modules/` and `init.*` instead.
8. **Cross-platform verification.** `init` and `check` were only tested on Windows (see
   `TEMPLATE.md`).
9. **Tool annotations.** `annotations` is an open object because the MCP annotation field
    names could not be confirmed against the current spec revision. Name them once verified.
10. **OpenTelemetry GenAI conventions are in Development status** and live in
    `open-telemetry/semantic-conventions-genai`. `trace-events.md` was written from the main
    branch on 2026-10-19; no release was pinned. The base `execute_tool` section of the spans
    page was read only in part (attributes came from the skill refinements in the agent spans
    page), and the nesting of `chat` and `execute_tool` under `invoke_agent` is this
    template own rule, not a convention. Re-read and pin when the repository publishes
    releases. The value of `gen_ai.tool.type` is not constrained for the same reason.
11. **Schema validation in CI.** `modules/tools/validate-examples.cjs` is run by hand. Run it
    in the template repository CI once the repo exists.
12. **No model adapter ships.** `model-interface.md` documents the Anthropic mapping only;
    adapters are written per project.
13. **The template repo is governed by its own `AGENTS.md`**, which tells maintainers to run
    `{{CHECK_CMD}}`, a command that does not exist here. Add a template-only block that
    `init` strips (as it does for `README.md`) pointing maintainers at
    `modules/tools/validate-examples.cjs` instead.
14. **No policy engine ships.** `guardrails.md` gives the evaluation algorithm and the
    schemas; a project writes the hook. The `sensitiveTools` and `untrustedSources` lists
    are maintained by hand, so an unclassified tool silently weakens the Rule of Two check.
15. **Meta Rule of Two source.** The original page returned 403; the wording comes from two
    articles that quote it. Re-read the original and adjust `guardrails.md` if it differs.
16. **Memory contract is untested against a real provider.** The compaction flow, the
    summarization instruction and the `compactAtFraction` default are drafts. Anthropic
    compaction, context editing and the memory tool were read through the notes of the
    Anthropic API skill, not the documentation pages. Tune with evals and re-read the pages.
17. **Memory retrieval and review.** `memory.md` leaves ranking of `memory_search`, human
    review or erasure of a user memory, and memory shared between agents to the project.
    The taint rule (a run that received untrusted input writes `external_content` and cannot
    change entries of another origin) is coarse, and the harness must track the taint itself:
    the static `untrustedSources` list of `guardrails` cannot express "an `external_content`
    entry was read".
18. **No run store ships.** The write order and resume rules are a contract only. A project
    writes the code that appends `history.jsonl`, saves `state.json` and settles
    interrupted calls. Tool "re-run" safety depends on `sideEffects` being declared right.
19. **Spec conventions are unverified and unenforced.** The folder layout, the status
    lifecycle and the EARS phrasing in `specs/` follow common spec-driven workflows and were
    written from general knowledge, not from the current documentation of any tool. Nothing
    checks that a medium or large task has a spec, or that `approved` was written by a person.
20. **Claude Code subagent details are unverified.** The adapters use a `tools` line in the
    frontmatter, and `docs/roles/README.md` says subagents cannot start other subagents, so the
    main session delegates. Both were written from general knowledge, not from the current
    Claude Code documentation. The read-only reviewer is a convention: it needs `Write` for its
    review file, and `Bash` can edit files, so nothing enforces it until hooks exist (item 2).
21. **Backlog rules are only partly checked.** `schemas/backlog.schema.json` enforces one task in
    progress and the fields each status needs. Unique ids, `dependsOn` naming existing ids, and
    a spec folder that starts with its task id are checked only by `modules/tools/validate-examples.cjs`,
    which does not ship to projects. `scripts/check.*` cannot parse JSON without a dependency.
    Nothing checks that `progress/history.md` was appended to, or that it was not edited.
