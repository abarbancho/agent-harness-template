# Contract: model interface

The loop talks to a model through one operation. Each provider is an **adapter** that
implements it. Shapes: `schemas/model-request.schema.json`,
`schemas/model-response.schema.json`, `schemas/message.schema.json`.

```
complete(request) -> response        (or raises ModelError)
```

## Request

| Field | Required | Meaning |
|---|---|---|
| `model` | yes | Opaque provider model id. The contract never depends on a specific id |
| `system` | no | System prompt |
| `messages` | yes | History, oldest first. Roles: `user`, `assistant`, `tool` |
| `tools` | no | Tool definitions (model-visible part only) |
| `maxOutputTokens` | no | Output limit for this call |
| `providerOptions` | no | Opaque object handed to the adapter as is |

Anything specific to one provider goes in `providerOptions`: reasoning or thinking
settings, effort levels, caching hints, fallback models. Sampling parameters
(temperature and similar) are deliberately not in the neutral request: some current models
reject non-default values, so treat them as provider options.

## Response

| Field | Meaning |
|---|---|
| `id` | Provider response id, if any |
| `model` | The model that answered |
| `message` | The assistant message, **all blocks, unchanged** |
| `stopReason` | `end`, `tool_calls`, `length`, `refusal`, `paused`, `other` |
| `stopDetail` | Provider detail, for example a refusal category |
| `usage` | See below |

### Opaque blocks

Providers may return blocks the loop cannot interpret (reasoning, compaction, server-side
tool results). The adapter wraps each one as `{ "type": "opaque", "provider": ..., "data": ... }`.
The loop keeps them in order, never edits them, and the adapter unwraps them when the same
provider is called again. Sending an opaque block to a different provider is an error to
avoid: drop it, or have the adapter drop it.

### Usage

| Field | Definition |
|---|---|
| `inputTokens` | **All** input tokens processed, cached ones included |
| `outputTokens` | Output tokens |
| `cachedInputTokens` | The part of `inputTokens` served from cache (optional) |
| `raw` | The provider usage object, unmodified (optional) |

Providers count differently, so the adapter normalizes. Always keep `raw`.

## Errors

`ModelError` has a `kind`:

| Kind | Examples | Loop behavior |
|---|---|---|
| `transient` | Rate limit, overload, timeout, network | The adapter may retry a bounded number of times; if it still fails the run ends `failed` |
| `invalid_request` | Malformed request, unsupported option, oversized prompt | End `failed`. Retrying unchanged cannot help |
| `auth` | Missing or rejected credentials | End `failed` |

## Provider mapping: Anthropic Messages API

One reference adapter. Add a column per provider your project supports.

| Neutral | Anthropic |
|---|---|
| `system` | top-level `system` |
| `messages[].role` `user`, `assistant` | same |
| `messages[].role` `tool` | a `user` message holding `tool_result` blocks |
| `tool_call` `id`, `name`, `arguments` | `tool_use` block `id`, `name`, `input` |
| `tool_result` `callId`, `isError` | `tool_result` block `tool_use_id`, `is_error` |
| `tools[].inputSchema` | `tools[].input_schema` |
| `maxOutputTokens` | `max_tokens` (required there: the adapter must set a default) |
| `opaque` blocks | thinking and compaction blocks, passed back unchanged |
| `stopReason` `end` | `end_turn`, `stop_sequence` |
| `stopReason` `tool_calls` | `tool_use` |
| `stopReason` `length` | `max_tokens` |
| `stopReason` `paused` | `pause_turn` |
| `stopReason` `refusal` | `refusal` (`stopDetail` from `stop_details.category`) |
| `stopReason` `other` | anything else |
| `usage.inputTokens` | `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` |
| `usage.cachedInputTokens` | `cache_read_input_tokens` |
| `usage.raw` | the `usage` object |

Resuming after `paused` (`pause_turn`): send the same messages again, ending on the
assistant message, with no extra user message. The provider resumes from the trailing
server-side tool block. This is the one accepted case of a request ending on an assistant
message (see `agent-loop.md`, "Pauses").

Notes for this adapter, taken from the provider documentation at the time of writing:
`input_tokens` there counts only the uncached remainder, hence the sum above; some current
models reject forced tool choice and non-default sampling parameters, so do not expose them
in the neutral request.

## Out of scope

Streaming (an adapter may stream internally and return the final response), batching, and
provider features with no neutral form. Use `providerOptions` for those.
