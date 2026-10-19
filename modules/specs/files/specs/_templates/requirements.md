# <id> <task name>: requirements

Status: draft
Approved by: (a person writes their name and the date here; an agent never does)
Size: large (signal: <the signal from docs/process/scaling.md>)

## Problem

<What is wrong or missing today, and who is affected. Facts, not a solution.>

## Requirements

One requirement per line, numbered, each checkable. Use the EARS patterns when they fit:

- Always: `The <system> shall <response>.`
- Event: `When <trigger>, the <system> shall <response>.`
- State: `While <state>, the <system> shall <response>.`
- Error: `If <unwanted condition>, then the <system> shall <response>.`
- Option: `Where <feature is present>, the <system> shall <response>.`

| Id | Requirement | Check |
|---|---|---|
| R1 | When <trigger>, the <system> shall <response>. | `<command or observation, and the passing result>` |
| R2 | If <failure>, then the <system> shall <response>. | `<...>` |

Include at least one error requirement. Write a non-functional requirement (speed, cost,
size) only with a number and a way to measure it.

## Out of scope

- <What this task does not do, so nobody assumes it does.>

## Open questions

- <Anything not settled. This list must be empty before approval.>
