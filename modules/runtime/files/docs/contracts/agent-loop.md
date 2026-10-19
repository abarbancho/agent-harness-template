# Contract: agent loop

The loop turns one user input into a result by calling a model and running the tools it
asks for. This contract is language-agnostic. Data shapes are the JSON Schemas in
`schemas/`: `message`, `model-request`, `model-response`, `tool`.

## Algorithm

```
history = [ user message ]
repeat:
    if a limit is reached                    -> stop: limit_reached
    response = model.complete(request(history, tools))      (see model-interface.md)
    append response.message to history, unchanged
    switch response.stopReason:
        end         -> stop: completed
        paused      -> continue: re-request with the history as it is, ending on that
                       assistant message, and add NO new input (see "Pauses" below)
        length      -> stop: truncated        (do NOT run any tool call in this turn)
        refusal     -> stop: refused          (do NOT run any tool call in this turn)
        other       -> stop: failed
        tool_calls  -> results = run every tool_call (see below)
                       append ONE message, role "tool", holding all results
                       continue
```

The stop reason is checked **before** any tool runs. A truncated or refused turn can carry
a tool call cut off mid-input; running it would act on partial arguments.

## Invariants

1. **History is append-only.** Never edit, reorder or delete earlier messages. Some
   providers bind internal blocks (thinking, compaction) to the exact history that
   produced them; an edit silently breaks them. Anything that rewrites history (for
   example compaction) is out of scope here and must keep `opaque` blocks intact.
2. **Append the assistant message whole.** Keep every block, including `opaque` ones, in
   the order received. Do not extract only the text.
3. **Every `tool_call` gets exactly one `tool_result`**, matched by `callId`, in the same
   `tool` message. A call is never dropped, even when it fails. Providers such as
   Anthropic reject a history that contains an unanswered call.
4. **All results of one assistant message go in a single `tool` message**, in the order of
   the calls. Splitting them across messages teaches some models to stop calling tools in
   parallel.
5. **The harness decides what runs, not the model.** Arguments are validated against the
   tool `inputSchema` before execution.

## Running tool calls

For each `tool_call`, in this order:

1. Unknown tool name -> result with `isError: true` and a message naming the available tools.
2. Arguments fail `inputSchema` -> result with `isError: true` and the validation message.
3. The `beforeToolCall` hook denies it -> result with `isError: true` and the reason.
4. Otherwise run it. An exception or failure -> result with `isError: true` and a message
   the model can act on. Never put stack traces or secrets in it.

Steps 1 to 3 are harness-side faults, not tool failures. They still produce an error
result, because invariant 3 requires an answer. Log them separately from tool failures.

**Concurrency.** Calls may run concurrently only if every one of them has `sideEffects` of
`none` or `read`. Otherwise run them one at a time in call order.

**Hook.** `beforeToolCall(call, tool) -> allow | deny(reason)` runs before every tool. It is
the single place where a project plugs in approval, policy or auditing. The loop defines
the hook point; the policy belongs to the project.

## Pauses

A provider can end a turn with `paused` when it has not finished its own server-side work
(for example a long server-side tool run). The turn is incomplete, not over. Continue by
sending the same history back: it ends on the assistant message that was just appended.
Do not add a user message such as "continue"; the provider detects the unfinished turn and
resumes by itself.

This is the only case where a request may end on an assistant message. Ending on an
assistant message otherwise acts as a prefill, which current models reject. An adapter
must accept a history that ends on an assistant message only when the previous
`stopReason` was `paused`.

Bound consecutive pauses with `maxConsecutivePauses`; without a bound a provider that
keeps pausing makes the loop spin. Do not assume a provider SDK helper resumes pauses for
you: some stop at the first pause and return it as if it were the final message.

## Limits

Checked before each model call. Values below are defaults and placeholders. A project sets
its own.

| Parameter | Default | Meaning |
|---|---|---|
| `maxSteps` | 25 | Model calls per run |
| `maxWallSeconds` | 600 | Wall-clock time per run |
| `maxTotalTokens` | 500000 | Sum of `inputTokens + outputTokens` over the run |
| `maxConsecutiveErrors` | 3 | Consecutive turns whose tool results are all errors |
| `maxConsecutivePauses` | 5 | Consecutive `paused` responses without progress |

When a limit is reached the run stops with `limit_reached`. The history is left as it is:
because limits are checked before a model call, it always ends on a complete `tool` or
`assistant` message.

## Result

| Field | Meaning |
|---|---|
| `status` | `completed`, `limit_reached`, `truncated`, `refused`, `failed` |
| `finalMessage` | The last assistant message, if any |
| `steps` | Number of model calls |
| `usage` | Summed usage over the run |
| `history` | The full message list, for resuming or auditing |

## Out of scope

Streaming, how history is persisted, how context is trimmed, and which approval policy a
project applies. Each is a project or module decision built on this contract.
