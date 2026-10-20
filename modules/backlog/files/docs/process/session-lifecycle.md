# Session lifecycle

An AI session has no memory of the last one. Work carries across sessions only through
files: `backlog.json` says what is to be done, `progress/current.md` says where the active
task stands, and `progress/history.md` says what earlier sessions did. This page says how to
keep the three in step.

| File | Holds | Changes |
|---|---|---|
| `backlog.json` | Every task and its status. Shape: `schemas/backlog.schema.json` | When a task starts, blocks, ends or is added |
| `progress/current.md` | The active task: plan, decisions, blockers, next step | All through the session |
| `progress/history.md` | One entry per session end | Appended at the end, never edited |

## The backlog

- **The order is the priority.** The first `todo` task whose `dependsOn` are all `done` is next.
- **Ids are unique.** The next id is the highest id in the file plus one, with at least three
  digits (`007`). The spec folder of a task starts with the same id: `specs/007-add-retry/`.
- **Statuses.** `todo`, `in_progress`, `blocked` (with a `reason`), `done` (with an
  `outcome` and `closedAt`) and `dropped` (with a `reason` and `closedAt`). Dates are `YYYY-MM-DD`,
  from the machine clock, not guessed.
- **At most one task is `in_progress`.** Finish it, block it or pause it before starting
  another.
- **New work goes in the backlog, not into the task.** If you find something else that needs
  doing, add it as a `todo` task and carry on with the current one. Do it now only if the user
  asks, or if the current task cannot be finished without it. In that case say so in
  `progress/current.md`.
- **Never delete a task.** A task nobody will do is `dropped`, with the reason.
- Keep `dependsOn` pointing at ids that exist, and never in a cycle. The schema cannot check
  that; check it when you edit the file.

## Start of a session

1. Read `progress/current.md`, then `backlog.json`.
2. Run the project check and the harness check from `AGENTS.md`. If either fails, record it
   in `progress/current.md` and stop. Do not start new work on a broken base.
3. **Pick the task.**
   - If one task is `in_progress`, **resume it**. Do not start another.
   - Otherwise take the first eligible `todo` task. If the user named a task, take that one,
     and say if it skips ahead of others.
4. Classify it (`docs/process/scaling.md`) when the specs module is used. Write `size` in
   the backlog, and for a medium or large task write the spec and set `spec` before any code.
5. Set the task `in_progress` in the same edit. Then fill in `progress/current.md`:

```
- Task: 007 Retry transient model errors
- Size: medium (user-visible behavior change)
- Status: spec written, starting the implementation
- Plan:
  - [ ] step one
  - [ ] step two
- Decisions: (each one with its reason)
- Blockers: (none)
- Next: the first thing to do when the session resumes
```

## During a session

- Update `progress/current.md` as you go: tick plan steps, write each decision with its
  reason, write blockers the moment they appear. Do not wait for the end. A session can stop
  at any time, and what is not on disk is lost.
- Keep `Next:` current. It is the first line the next session acts on.
- Commit in small steps if the project uses version control.

## End of a session

A session ends in one of three ways.

**Done.**
1. Both checks pass, and the definition of done in `AGENTS.md` is met. Have the output ready.
2. In `backlog.json`: `status` `done`, `outcome` (one line), `closedAt`.
3. Append an entry to `progress/history.md`.
4. Reset `progress/current.md` to its empty form (`Task: (none)`).

**Paused** (out of time or context, but not blocked).
1. Leave the task `in_progress`.
2. Make `progress/current.md` complete enough for someone with no memory: what is done, what
   is not, the exact next step, and any command that is half run.
3. Append an entry to `progress/history.md`.

**Blocked** (cannot continue without something outside the session).
1. In `backlog.json`: `status` `blocked`, with the `reason`.
2. Write the blocker, and what would unblock it, in `progress/current.md`.
3. Append an entry to `progress/history.md`. Do not start another task to fill the time
   unless the user says so.

Do not mark a task `done` to end the session. A task that is not done and not blocked is
paused.

## History entries

Append at the end of `progress/history.md`. Never edit or delete an earlier entry; a
correction is a new entry that refers to the old one. Keep each entry to a few lines.

```
## 2026-10-20 | 007 Retry transient model errors | done
- Did: added bounded retries to the agent loop; updated the loop contract.
- Evidence: project check and harness check pass.
- Next: nothing. Task 009 is next in the backlog.
```

The last field of the heading is how the session ended: `done`, `paused` or `blocked`.
