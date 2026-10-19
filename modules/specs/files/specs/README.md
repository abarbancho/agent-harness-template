# Specs

One folder per task that needs a spec (medium and large; see `docs/process/scaling.md`):

```
specs/
  _templates/            copy from here
  001-add-retry/
    spec.md              medium: one page
  002-new-payment-tool/
    requirements.md      large: what and why, as testable requirements
    design.md            large: how, and what was rejected
    tasks.md             large: the steps, each traced to requirements
```

## Life of a spec

Every spec file starts with a `Status` line.

| Status | Meaning | Who sets it |
|---|---|---|
| `draft` | Being written. No code yet | the author |
| `approved` | Agreed. Implementation may start | a **person**, with their name and the date in `Approved by` |
| `implemented` | Done and checked against its criteria | the author, once the checks pass |
| `abandoned` | Dropped. Say why in one line | whoever drops it |

- A medium spec needs no approval, but it must exist and be `draft` or later before code.
- A large spec needs `approved` on requirements **and** design before implementation. An
  agent never writes `approved` itself.
- Open questions must be empty before approval. A question you cannot answer is a reason
  to ask, not to guess.

## Rules for writing

- **Criteria are checks.** An acceptance criterion says what to run or observe and what
  result counts as passing. "Works well" is not a criterion. Include at least one failure
  case: what must happen when the input is wrong or the dependency is down.
- **Change the spec first.** If the work shows the spec is wrong, update the spec, say so
  in `progress/current.md`, and (for a large spec) get the change approved. Do not let
  code and spec drift apart.
- **Never weaken a criterion to make a task pass.** If a criterion turns out to be wrong,
  propose the change and say why.
- **Keep it short.** A short spec fits on one page. A large spec is as long as its
  decisions need, not longer.
- **Behavior of an agent is checked by evals.** A criterion about what the agent does names
  the case in `evals/cases/` that checks it, and adds it if it is missing.
- **Trace everything.** Each requirement has a number (`R1`, `R2`, ...). Each task in
  `tasks.md` says which requirements it covers, and each requirement has at least one task
  and one check.
