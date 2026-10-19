# <id> <task name>: design

Status: draft
Approved by: (a person writes their name and the date here; an agent never does)
Requirements: `requirements.md`

## Approach

<Two or three sentences: how the requirements will be met.>

## Decisions

Record each choice that someone could reasonably have made differently.

| Decision | Options considered | Chosen, and why |
|---|---|---|
| <what is being decided> | <A; B; C> | <B, because ...> |

## Interfaces and data

<What public interface, schema, tool definition or file format changes, and how. Say what
is backward compatible and what is not. If a contract or schema changes, it is edited
before the code.>

## Failure modes

| What fails | What the user or the agent sees | What the system does |
|---|---|---|
| <dependency down, bad input, timeout> | <...> | <retry, stop, report> |

## Security and privacy

<Secrets, personal data, permissions, new actions the agent can take, and how each is
limited. Write "no impact" only after checking.>

## Verification plan

| Requirement | How it is checked |
|---|---|
| R1 | <test, eval case, manual step> |

## Rollout and rollback

<How it is released, and how to undo it. If it cannot be undone, say so here and in the
gate.>

## Risks

- <Remaining risks after the decisions above.>
