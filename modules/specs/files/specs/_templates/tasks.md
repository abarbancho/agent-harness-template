# <id> <task name>: tasks

Status: draft
Requirements: `requirements.md`. Design: `design.md`.

Start only when requirements and design are `approved`. Each task is small enough to finish
and check in one sitting. Tick a box only when its check has passed, with the output in
`progress/current.md`.

- [ ] **T1. <what to do>**
  Covers: R1
  Files: <expected files>
  Done when: `<command or observation, and the passing result>`
- [ ] **T2. <what to do>**
  Covers: R1, R2
  Files: <expected files>
  Done when: `<...>`

## Traceability

| Requirement | Tasks | Check passed |
|---|---|---|
| R1 | T1, T2 | [ ] |
| R2 | T2 | [ ] |

Every requirement has at least one task. Every task covers at least one requirement. If a
task needs a file or an interface the design does not mention, stop and update the design
first.
