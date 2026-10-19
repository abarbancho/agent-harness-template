# AGENTS.md — {{PROJECT_NAME}}

> Single source of truth for every AI coding tool in this repo (Claude Code, Cursor,
> Copilot, Codex, ...). It is a **map, not a manual**: read only what the task needs.
> Tool-specific files (`CLAUDE.md`, `.cursor/rules/`, `.github/copilot-instructions.md`)
> are thin pointers to this file. Never duplicate rules there.

## 1. Before you start

1. Read `progress/current.md` — where the last session stopped.
2. Run the project check and the harness check (§2). If either fails, stop and fix the
   environment first.

## 2. Commands

| Purpose | Command |
|---|---|
| Install | `{{INSTALL_CMD}}` |
| Run | `{{RUN_CMD}}` |
| Project check (tests, lint, types) | `{{CHECK_CMD}}` |
| Harness check (repo invariants: placeholders, map paths, schema examples) | `sh scripts/check.sh`, or on Windows `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1` |

The two checks are different. The project check tests the code. The harness check tests
this repo layout. A `[SKIP]` line in the harness check means that check did not run.

## 3. Repository map

| Path | What it holds | Read it when |
|---|---|---|
| `progress/current.md` | Live state of the active session | Always, at start |
| `evals/` | Golden cases that measure agent behavior | Changing prompts, tools, or agent behavior |
<!-- modules:map -->

## 4. Hard rules

- **State lives on disk, not in chat.** Plans, decisions and results go in `progress/`.
- **Behavior changes need evals.** A change to a prompt, tool or agent policy is not done
  until `evals/` shows no regression.
- **No done without evidence.** Show the output of both checks, not a claim.
- **Unsure? Look in the repo first**, then ask. Do not invent a workaround; record the
  blocker in `progress/current.md` and stop.
<!-- modules:rules -->

## 5. Definition of done

1. The project check passes.
2. The harness check has no `[FAIL]`, and you can say why each `[SKIP]` is acceptable.
3. Evals pass, if behavior changed.
4. `progress/current.md` reflects what was done and what remains.
5. No stray files, debug output, or unexplained TODOs.
