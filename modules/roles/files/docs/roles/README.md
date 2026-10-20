# Roles

Four roles split a task so that the agent that does the work is not the one that approves it.
Each role has a file here (`planner.md`, `spec-author.md`, `implementer.md`, `reviewer.md`)
that is the whole definition: what it reads, what it writes, what it must not do, and when it
is done. A role is a way of working, not a separate product. One agent can play all four in
turn, but then it must keep the review step separate (see Independence).

## Who works on which size

Sizes come from `docs/process/scaling.md`.

| Size | Roles, in order | Human gate |
|---|---|---|
| Trivial | implementer | None |
| Medium | planner (writes the short spec), implementer, reviewer | None, unless the user asked |
| Large | planner, spec-author, a person approves, implementer, reviewer | A person approves requirements and design before the implementer starts |

## Handoffs go through files

A role never passes work on by describing it in chat. It writes a file and returns only the
path.

| From | To | Through |
|---|---|---|
| user | planner | the request |
| planner | spec-author | a brief: the request, the size and signal, paths to read, the output folder |
| spec-author | planner | `specs/<id>-<slug>/` with `Status: draft` |
| planner | person | the spec paths and the open questions |
| planner | implementer | a brief: the task, the spec path, the files expected, the done check |
| implementer | planner | `progress/reports/<id>-implementation.md`: what changed, and the output of the checks |
| planner | reviewer | a brief: the spec path, the report path, how to see the diff |
| reviewer | planner | `progress/reports/<id>-review.md`: verdict and findings |

Every brief states the task, the inputs (paths), the output path and the check that says
the work is done. A brief that cannot say how the work will be checked is not ready to send.

A report is a working file. When the task is done, summarize the result in
`progress/current.md` and delete the reports, or keep them if the project wants them.

## Independence

- **The implementer never approves its own work.** It reports. The reviewer decides.
- **The reviewer starts from a clean context.** It gets the spec, the report path and the way
  to see the diff, and nothing of the implementer's reasoning. It runs the checks itself
  instead of trusting the output in the report.
- **The reviewer never edits code.** Its only output is the review file.
- **Nobody edits a criterion, a case or a grader to make work pass.** The planner decides
  whether a spec change is needed, and a person approves it for a large spec.
- **At most two review rounds.** If the second review still asks for changes, the planner
  stops and reports to a person.

## Parallel work

The planner may run roles in parallel only when their tasks are independent and touch
different files. Two implementers never edit the same file at once.

## What these roles do not enforce

The boundaries above are instructions. Nothing in the repo stops a reviewer from editing a
file. Hard limits (a reviewer that cannot write outside `progress/reports/`) need hooks or
permissions in the coding tool, such as Claude Code hooks in `.claude/settings.json`. Until
a project adds them, the human gate and the independent review are the controls.

## Using a role in each tool

- **Claude Code.** `.claude/agents/<role>.md` is a thin subagent file that points here. Claude
  Code subagents cannot start other subagents, so the **main session** delegates, and the
  `planner` subagent only classifies and writes the plan and the briefs. Ask the main session
  to follow `docs/roles/planner.md` to run the whole flow.
- **Any other tool.** Tell the agent: "Read `docs/roles/<role>.md` and `AGENTS.md`, and work
  as that role." Use a new session for the reviewer.
