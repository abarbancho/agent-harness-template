# Contract: tools

A tool is a typed action the model can request. Shapes: `schemas/tool.schema.json` (what the
harness knows) and `schemas/tool-definition.schema.json` (the part the model sees).

## Declaration

| Field | Required | Who sets it | Meaning |
|---|---|---|---|
| `name` | yes | harness author | 1 to 128 characters of `A-Z a-z 0-9 _ . -`. Unique within one agent |
| `title` | no | harness author | Display name |
| `description` | yes | harness author | What the tool does and when to use it. The model reads this: write it as a prompt |
| `inputSchema` | yes | harness author | JSON Schema of the arguments. The root must be `type: object`. For no arguments use `{ "type": "object", "additionalProperties": false }` |
| `outputSchema` | no | harness author | JSON Schema of `structuredContent` in the result |
| `sideEffects` | yes | harness author | `none`, `read`, `write` or `irreversible` (see below) |
| `external` | no | harness author | True if it reaches outside the project environment. Default false |
| `annotations` | no | the tool author | Open object. Untrusted hints |

Only `name`, `title`, `description`, `inputSchema` and `outputSchema` are sent to the model.
`sideEffects`, `external` and `annotations` stay in the harness.

### Side effects belong to the harness

`sideEffects` is a fact the harness author states. It is **never** derived from
`annotations`. A tool imported from a third party (for example an MCP server) arrives with
hints chosen by its author; MCP itself says clients must treat them as untrusted unless the
server is trusted. Whoever integrates the tool decides its `sideEffects`.

| Value | Meaning | Example |
|---|---|---|
| `none` | Pure computation | `calculate_sum` |
| `read` | Reads state, changes nothing | `read_file`, `search` |
| `write` | Changes state in a way that can be undone | `edit_file` in a repository |
| `irreversible` | Cannot be undone | `delete_record`, `send_email`, `pay` |

The value is a fact, not a policy. What to do with it (allow, ask, deny) is decided by the
project, through the `beforeToolCall` hook of the agent loop.

## Calls and results

A call is a `tool_call` block: `id`, `name`, `arguments`. The answer is a `tool_result`
block: `callId`, `content` (text blocks), optional `structuredContent` (a value that
matches `outputSchema` when one is declared), and `isError`.

There are two kinds of failure:

| Kind | Examples | Handling |
|---|---|---|
| **Tool execution error** | The API failed, the date is in the past, the file does not exist | Result with `isError: true` and a message the model can use to correct itself |
| **Harness error** | Unknown tool, arguments that do not match `inputSchema`, call denied by the hook | Also an `isError: true` result (every call needs an answer), but logged as a harness fault |

Error messages must say what went wrong and what to try. They must not contain stack
traces, credentials or internal paths.

## Design rules

- **Promote an action to a dedicated tool when it needs gating, auditing or parallelism.**
  A generic shell tool gives the harness one opaque string for every action. A
  `send_email` tool can be gated and logged; `shell("curl -X POST ...")` cannot. Start
  generic for breadth, split out the actions that matter.
- **Mark read-only tools honestly.** `none` and `read` tools may run concurrently; a
  wrong value turns that into a race.
- **Keep the tool set stable within a run.** Adding or removing tools mid-conversation
  invalidates provider caches and confuses the model.
- **Names are scoped to one agent.** When you aggregate tools from several sources, prefix
  the names with the source to avoid collisions.

## Mapping to other formats

| This contract | MCP | Anthropic API |
|---|---|---|
| `name`, `title`, `description` | same | `name`, `description` (no title) |
| `inputSchema` | `inputSchema` | `input_schema` |
| `outputSchema` | `outputSchema` | no equivalent |
| `annotations` | `annotations` | no equivalent |
| `sideEffects`, `external` | no equivalent | no equivalent |
| `tool_call` (`id`, `arguments`) | `tools/call` (`name`, `arguments`) | `tool_use` block (`id`, `input`) |
| `tool_result` (`callId`, `isError`) | result (`isError`) | `tool_result` block (`tool_use_id`, `is_error`) |

An MCP tool becomes a valid declaration once the integrator adds `sideEffects`.
Field names here follow MCP (camelCase) because it is the most common cross-provider
format; adapters translate (see `model-interface.md`).
