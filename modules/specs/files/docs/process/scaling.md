# Task scaling

A spec costs time, and a trivial change does not need one. This page maps the size of a
task to the spec it needs and the human gates it passes. Every signal below can be checked
by looking at the change, not by judgment, because agents apply it literally.

## 1. Classify

Count **files changed** as every file you expect to edit or add, except tests that only
cover this change, lockfiles and generated files.

A task is **large** if any of these is true:

- More than 5 files change.
- A public interface changes: an API, a schema, a CLI, a tool definition, a file format
  that other code or other people read.
- It adds an external dependency or a new external service.
- The agent gains an action it did not have, or a permission, or an action that cannot be
  undone (deleting data, sending messages, spending money).
- It touches authentication, secrets or personal data.
- It migrates data.

Otherwise it is **medium** if any of these is true:

- 2 to 5 files change.
- A user can see a different behavior.
- A prompt, a tool description or an agent policy changes.
- It fixes a bug whose cause is not yet known.

Otherwise it is **trivial**: one file, no visible behavior change. A typo, a rename inside
one file, a comment, formatting.

**When in doubt between two sizes, take the larger.** Over-specifying a task costs an hour.
Under-specifying one costs a rework.

Write the size and the signal that decided it in `progress/current.md` before starting, for
example `Size: large (public interface changes: schemas/tool.schema.json)`.

## 2. What each size needs

| Size | Spec | Human gate |
|---|---|---|
| Trivial | None. Say what you changed in `progress/current.md` | None |
| Medium | Short spec: `specs/<id>-<slug>/spec.md`, from `specs/_templates/short-spec.md` | None, unless the user asked to review it |
| Large | Full spec in `specs/<id>-<slug>/`: `requirements.md`, `design.md`, `tasks.md` | A person approves the requirements and the design **before** any implementation |

`<id>` is the next free three-digit number (`001`, `002`, ...), or the id of the task when the
`backlog` module is used. `<slug>` is a few lowercase words with dashes. See `specs/README.md` for the life of a spec.

## 3. When the size changes

The size is a claim you can get wrong. Check it again whenever the task grows.

- **A larger signal appears while you work** (a sixth file, a schema you did not expect to
  touch): stop, reclassify, write the spec that size needs, pass its gate, then continue.
- **Never reclassify downward** to avoid a gate. If you think the task is smaller than it
  looked, say so in `progress/current.md` and let the person decide.
- **One task, one size.** If two parts of a request have different sizes, split them into
  two tasks.

## 4. Roles

With only this module installed, one agent does the whole task. It must still check its own
result against the acceptance criteria in a separate step, after the work and before saying
it is done. With the `roles` module installed, each size also says who does what; see the
role definitions in `docs/roles/`.
