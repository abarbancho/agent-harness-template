# Contract: trace events

Every run of the agent leaves a trace: a tree of spans that shows what the agent did, how
long it took and what it used. This contract says which spans exist and which attributes
they carry. It follows the OpenTelemetry GenAI semantic conventions, so any OpenTelemetry
backend understands the data. Shape: `schemas/trace-event.schema.json`.

**Status of the conventions.** They are in *Development* status in
`open-telemetry/semantic-conventions-genai`, and attribute names may change. This contract
was written from that repository (main branch) on 2026-10-19. Re-read the pages listed under
Sources before depending on a name, and pin the version your project emits.

## Two ways to emit

- **OpenTelemetry SDK.** Create the spans below with an SDK for your language and export
  them over OTLP. This is the normal route.
- **JSON lines.** Write one finished span per line to `traces.jsonl`, using the schema. The
  record maps one to one onto an OpenTelemetry span, so it is easy to replay into a backend,
  and it needs no SDK for local runs and for eval transcripts.

## Span tree

```
invoke_agent <agent name>             one per run          (internal)
  chat <model>                        one per model call   (client)
  execute_tool <tool name>            one per tool call    (internal)
```

`chat` and `execute_tool` spans are children of the `invoke_agent` span, in the order they
happened. The conventions read for this contract do not fix this nesting; this contract does.
All spans of a run share one `traceId`.

## Attributes

Level: **R** required here, **C** required when the condition holds, **Rec** recommended,
**Opt-in** off unless a project turns it on. "OTel" marks names defined by OpenTelemetry;
"harness" marks names defined by this template.

### `invoke_agent`

| Attribute | Level | Source |
|---|---|---|
| `gen_ai.operation.name` = `invoke_agent` | R | OTel |
| `gen_ai.agent.name` | R | OTel |
| `harness.run.id` | R | harness |
| `harness.run.status`: `completed`, `limit_reached`, `truncated`, `refused`, `failed` | Rec | harness |
| `harness.steps` | Rec | harness |
| `gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens` (sums over the run) | Rec | OTel |
| `gen_ai.conversation.id` | C: only if the application already has one | OTel |

Do not invent a conversation id from a UUID, the trace id or a hash. `harness.run.id` is the
run, which is not necessarily a conversation.

### `chat`

| Attribute | Level | Source |
|---|---|---|
| `gen_ai.operation.name` = `chat` | R | OTel |
| `gen_ai.provider.name` (for example `anthropic`) | R | OTel |
| `gen_ai.request.model` | R | OTel |
| `harness.step` | R | harness |
| `gen_ai.request.max_tokens` | Rec | OTel |
| `gen_ai.response.id`, `gen_ai.response.model` | Rec | OTel |
| `gen_ai.response.finish_reasons` | Rec | OTel |
| `gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens` | Rec | OTel |
| `gen_ai.usage.cache_read.input_tokens`, `gen_ai.usage.cache_write.input_tokens` | Rec, when available and not zero | OTel |
| `error.type` | C: on error | OTel |

### `execute_tool`

| Attribute | Level | Source |
|---|---|---|
| `gen_ai.operation.name` = `execute_tool` | R | OTel |
| `gen_ai.tool.name` | R | OTel |
| `gen_ai.tool.call.id` | R (the loop always has the call id) | OTel |
| `harness.step` | R | harness |
| `gen_ai.tool.type`, `gen_ai.tool.description` | Rec | OTel |
| `harness.tool.side_effects`, `harness.tool.external` | Rec | harness |
| `harness.policy.decision`, `harness.policy.outcome` | Rec, when a tool policy is used | harness |
| `gen_ai.tool.call.arguments`, `gen_ai.tool.call.result` | Opt-in | OTel |
| `error.type` | C: on error | OTel |

The `execute_tool` attribute list above comes from the refinements of that span in the agent
spans page (loading a skill, reading a skill resource, running a command). The base
`execute_tool` section was read only in part, so check it before relying on a requirement
level.

## Mapping from the runtime contracts

| Source (`docs/contracts/`) | Attribute |
|---|---|
| model request `model` | `gen_ai.request.model` |
| model request `maxOutputTokens` | `gen_ai.request.max_tokens` |
| model response `id`, `model` | `gen_ai.response.id`, `gen_ai.response.model` |
| model response `stopReason` | `gen_ai.response.finish_reasons`, as a one-element array |
| model response `usage.inputTokens` | `gen_ai.usage.input_tokens` |
| model response `usage.outputTokens` | `gen_ai.usage.output_tokens` |
| model response `usage.cachedInputTokens` | `gen_ai.usage.cache_read.input_tokens` |
| model response `usage.cacheWriteInputTokens` | `gen_ai.usage.cache_write.input_tokens` |
| tool call `id`, `name` | `gen_ai.tool.call.id`, `gen_ai.tool.name` |
| tool declaration `sideEffects`, `external` | `harness.tool.side_effects`, `harness.tool.external` |
| loop result `status`, `steps` | `harness.run.status`, `harness.steps` |
| policy decision `decision`, `outcome` | `harness.policy.decision`, `harness.policy.outcome` |

Notes:

- `usage.inputTokens` already counts cached tokens, as `gen_ai.usage.input_tokens` does, so it
  is copied as is. The cache attributes are parts of that total, not additions to it.
  Providers differ in what their own `input_tokens` means; the adapter normalizes before
  the value reaches the span (see `model-interface.md`).
- `finish_reasons` carries the neutral stop reason of this contract, not the provider's own
  word. When a model call fails and no finish reason arrives, use `error`.

## Failures and `error.type`

A span that failed has `status.code` `error` and an `error.type`. Keep the values few and
stable, since backends group by them. Use these:

| `error.type` | Span | Meaning |
|---|---|---|
| `transient`, `invalid_request`, `auth` | `chat` | The `ModelError` kind |
| `tool_error` | `execute_tool` | The tool ran and failed |
| `unknown_tool`, `invalid_arguments` | `execute_tool` | Harness-side fault before the tool ran |
| `policy_denied` | `execute_tool` | The policy denied the call, or a human rejected it or did not answer |
| `limit_reached`, `truncated`, `refused` | `invoke_agent` | The run did not complete |

A denied call still gets an `execute_tool` span, with the policy outcome, so a run that was
blocked can be seen as such.

OpenTelemetry suggests the provider error code or the exception name for `error.type`. This
contract uses the small fixed set above instead, because backends group by it and a provider
code that varies per call splits the groups. Put the provider own code or message in
`status.message`.

## What not to record

- **Content is off by default.** Messages, system prompts, tool definitions, tool arguments
  and tool results are the Opt-in attributes. They hold personal data, secrets and customer
  text. Turn them on per environment, never in production by default.
- **If content is on,** redact secrets before it reaches the span, cap the size, and set
  `harness.content.truncated` to true when it was cut.
- **No cost on spans.** Record tokens and the model; compute cost at analysis time from the
  prices of that moment. A price stored on a span goes stale.
- **No secrets in any attribute,** including `app.*` ones. The policy decision record keeps
  a digest of the arguments for the same reason.

## Custom attributes

Keys must be in the `gen_ai`, `harness`, `error`, `server` or `app` namespaces. Put project
specific attributes under `app.`, for example `app.customer.tier`. Keep their cardinality low.

## Out of scope

Metrics, logs and sampling. Token and latency metrics can be derived from the spans. Decide
sampling and retention with your backend, and keep full traces for failed and refused runs.

## Sources

Read on 2026-10-19, all in Development status:

- [GenAI spans](https://github.com/open-telemetry/semantic-conventions-genai/blob/main/docs/gen-ai/gen-ai-spans.md):
  operation names, `execute_tool`, `error.type`, `gen_ai.conversation.id`.
- [GenAI agent spans](https://github.com/open-telemetry/semantic-conventions-genai/blob/main/docs/gen-ai/gen-ai-agent-spans.md):
  `invoke_agent`, internal against client spans.
- [Client inference](https://github.com/open-telemetry/semantic-conventions-genai/blob/main/docs/gen-ai/client-inference.md):
  inference span attributes, token and cache usage, opt-in content.
- [Anthropic](https://github.com/open-telemetry/semantic-conventions-genai/blob/main/docs/gen-ai/anthropic.md):
  `gen_ai.provider.name` is `anthropic`; its `input_tokens` excludes cached tokens.
