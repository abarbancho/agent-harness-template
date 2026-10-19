# Task scaling

> Maps task size to spec level and roles, so trivial work does not go through the full chain.
> Agents apply this literally, so every criterion must be objectively checkable.

DRAFT — thresholds are proposals to confirm.

| Size | Signals (any of the "large" or "medium" signals applies) | Spec | Roles | Human gate |
|---|---|---|---|---|
| Trivial | Single file, no behavior change visible to users, no contract/schema change, no new dependency | None | implementer | None |
| Medium | 2–5 files, or user-visible behavior change, or new tool/prompt change | Short spec (`specs/_templates/short-spec.md`) | planner, implementer, reviewer | Optional |
| Large | More than 5 files, or contract/schema change, or new external dependency, or new autonomous action | Full spec (requirements, design, tasks) | all four | Required before implementation |

TODO: confirm thresholds; define tie-breaking (when unsure, size up one level).
