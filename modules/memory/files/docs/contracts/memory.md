# Contract: memory and context

An agent run has three kinds of state. This contract covers each one and keeps them apart.

| State | Lives | Written by | Contract section |
|---|---|---|---|
| **Context**: what one model request carries | For one request | The harness | Context |
| **Run state**: the history and counters of one run | For one run, on disk | The harness | Run state and resume |
| **Memory**: notes that outlive the run | Across runs, on disk | The agent, through tools | Persistent memory |

It builds on `agent-loop.md` and does not change it. The loop appends to a history and sends
it. This contract adds one step before each model call (see "Where it plugs in") and the
files that let a run be resumed. Shapes: `schemas/memory-entry.schema.json` and
`schemas/run-state.schema.json`.

The progress notes of the AI coding tools that work on this repository
(`progress/current.md`) are a different thing and are not part of this contract.

## Context

The **history** is the append-only record of a run (`agent-loop.md`, invariant 1). The
**context** is the list of messages sent in one request. They are the same list until a
compaction happens. After that the context is derived from the history and the history is
never rewritten.

### Parameters

Values are defaults and placeholders. A project sets its own.

| Parameter | Default | Meaning |
|---|---|---|
| `contextWindowTokens` | none, from the model | Size of the context window of the model in use |
| `compactAtFraction` | 0.8 | Compact when the next request is expected to pass this fraction of the window |
| `maxToolResultChars` | 20000 | Longest tool result kept whole in the history |
| `maxToolMessageChars` | 80000 | Longest `tool` message: all results of one assistant message together |
| `maxCompactions` | 5 | Compactions per run, then the run stops with `limit_reached` |

**Headroom.** `1 - compactAtFraction` of the window must hold one `tool` message
(`maxToolMessageChars`, in tokens), the next response (`maxOutputTokens`) and the
summarization instruction. Check this when the configuration loads. Without it a single
tool round can push the context past the window, and the summarization request, which sends
that whole context, is rejected as too large exactly when compaction is needed.

### Keep results small at the source

A tool result is appended once and never edited, so cut it **before** it is appended. If a
result is longer than `maxToolResultChars`, keep the start, add a line that says how many
characters were left out, and save the full output to a file the model can read with a tool:

```
[truncated: 48213 characters omitted; full output in runs/<runId>/overflow/<callId>.txt]
```

The result still answers its call, so invariant 3 of the loop holds. Do not put the overflow
file inside the history. Treat overflow files like the history files: they hold full content.

The same applies to the whole `tool` message. When its results together are longer than
`maxToolMessageChars`, cut the longest results first, in the same way, until it fits.

### When to compact

Checked before each model call, right after the limits of the loop. The next request is
expected to be about as large as the last one plus what the last response and the new tool
results added:

```
expected = last.usage.inputTokens + last.usage.outputTokens + estimate(results appended since)
compact when expected >= compactAtFraction * contextWindowTokens
```

`usage.inputTokens` already counts cached tokens (`model-interface.md`). Use the token
counting of your provider for the estimate when it has one, or characters divided by four
when it does not. `last.usage` is kept in the run state as `lastUsage`, so the check works
after a resume. No usage exists before the first response, so the first call never compacts.

Compaction happens only at this point, so it never falls in the middle of a tool round. The
history then ends on a complete `tool` message (or on the first user message), with one
exception: **never compact while the last stop reason is `paused`.** Then the history ends
on the paused assistant message, which must be sent back as it is for the provider to resume
its unfinished turn (`agent-loop.md`, Pauses). Compaction waits for the next point where
the turn is complete.

### How to compact

There are three ways, in this order of preference:

1. **Provider side.** The provider summarizes by itself and returns a block for it (for
   example the Anthropic compaction block). It arrives as an `opaque` block in the
   assistant message. Keep the whole history and send it all, as for any `opaque` block. The
   harness records nothing. Server-side context editing, which clears old tool results or
   thinking, is the same kind of feature: it is done by the provider on the history as sent.
2. **Simple harness compaction.** Summarize everything so far into **one** message, and
   from then on send that message plus what is appended after it. Nothing older is sent.
3. **Do not edit the history on the client.** Deleting old tool results, removing turns from
   the middle, or keeping the newest turns beside a summary changes messages that provider
   blocks were produced against. Some providers refuse the next request, and the prompt
   cache is lost anyway. The loop contract forbids it. If you need the effect, use way 1.

Way 2 in steps:

1. Make a model request with the **same** `model`, system prompt and tools as the run, and
   the current context followed by one user message with the summarization instruction
   (below). Reusing them exactly keeps the prompt cache of the run for this request.
2. The response is the summary only if its `stopReason` is `end` and its text is not empty.
   Anything else fails the compaction: a tool call, `length` (the summary was cut off),
   `refusal`, `paused` or `other`. A summary that is cut off or refused would replace the
   whole earlier context for good. Retry once, then stop the run with `failed`.
3. Append a compaction record to the run state (`atMessageCount` is the number of messages
   in the history now). Do not touch the history.
4. From the next request on, the context is:

```
context(history, compactions):
    if there is no compaction: return history
    c = the last compaction
    return [ user message: "Summary of the work so far ..." + c.summary ]
           + history[c.atMessageCount:]
```

The summary replaces the first user message too, so it must carry the task. A later
compaction summarizes the *context* (the earlier summary plus what came after), not the raw
history, so earlier summaries are never lost. If two user messages end up next to each
other, the adapter may merge them in the request; the history is not changed.

The summarization request counts toward usage and `maxTotalTokens`, not toward `maxSteps`.
Compaction resets the prompt cache once. Count it in `maxCompactions` so a run that keeps
refilling its context stops instead of looping.

**Summarization instruction.** Starting text, to be tuned with evals:

```
Write a summary of the work so far for yourself, to continue after your context is
cleared. Keep: the task and what the user asked for; constraints and decisions made and
why; what is done and what remains; exact identifiers, paths, names and values you will
need again; approaches that failed and why; open questions. Leave out what can be read
again with a tool. Answer with text only. Do not call any tool.
```

The last sentence matters: the request carries the run tools, and without it a model may
call one instead of writing the summary. Opaque blocks such as thinking from before the
summary are not carried forward, so the summary is all the model has of that work. Name in
the instruction what must survive.

### Where it plugs in

In the loop of `agent-loop.md`, the line `response = model.complete(request(history, tools))`
becomes:

```
if compaction is due: compact()                    (above)
response = model.complete(request(context(history, compactions), tools))
```

Everything else in the loop is unchanged, including that the response is appended to the
history whole.

## Run state and resume

A run can be interrupted: a crash, a deploy, a closed laptop. Four files per run, in
`runs/<runId>/` by default (the folder is listed in `.gitignore`):

| File | Holds |
|---|---|
| `history.jsonl` | The history, one message per line, in the shape of `schemas/message.schema.json`. Append only. |
| `state.json` | The counters and the compactions, in the shape of `schemas/run-state.schema.json`. Rewritten whole. |
| `pending.jsonl` | `tool_result` blocks of the current turn, one per line, saved as each call finishes. Emptied when the turn ends. |
| `lock` | Who is running the run now (see Ownership). |

The history file is the truth for the messages. `messageCount` in the state says how many
lines the state expected.

### Write order

1. When a model response arrives, rewrite `state.json` **first** (the new `step`, `usage`,
   `lastUsage`, `lastStopReason`), then append the assistant message to `history.jsonl`,
   and only then run any of its tool calls. The order matters: whenever the last line of the
   history is an assistant message, the state already holds the stop reason that came with
   it. The stop reason is not part of the message, so this is the only place it survives.
2. When a call that is not `none` or `read` finishes, append its `tool_result` block to
   `pending.jsonl` before starting the next call. Otherwise a crash later in the turn loses
   the result of a side effect that did happen.
3. When every call has an answer, append the `tool` message, with all the results in one
   line, to `history.jsonl`. Then rewrite `state.json`, then empty `pending.jsonl`.

End every line with a newline and flush each append before the next step. Write `state.json`
to a temporary file in the same folder and rename it over the old one, so a crash leaves
either the old or the new file.

One message per line means a crash can tear at most the last line. **On resume, before the
first append, cut the file back to the end of its last complete line** (a line that ends in a
newline and is valid JSON). Dropping the fragment only in memory is not enough: the next
append would be glued to it, and the file would be corrupt from then on. Do the same to
`pending.jsonl`.

### Ownership

`running` is also the status of a run that is alive. Two loops on one run would append to the
same files and run the same calls twice, so a run has one owner at a time.

- The owner creates `lock` exclusively (fails if it exists), writes its own id in it, and
  rewrites a heartbeat time in it every `leaseSeconds / 3`. `leaseSeconds` defaults to 60.
- A run may be resumed only when `lock` is missing or its heartbeat is older than
  `leaseSeconds`. The new owner takes the lock the same way, and then continues.
- The owner removes `lock` when the run ends.

### Resuming

Load the history, cut a torn last line, load the state (when its `messageCount` is not the
number of history lines, trust the history for the messages and keep the counters), then look
at how the history ends:

| History ends on | Meaning | Do |
|---|---|---|
| A `tool` message | Results are in, the model call was lost | Continue the loop |
| A user message | The model call was lost | Continue the loop |
| An assistant message, `lastStopReason` `tool_calls` | The crash came during the tools | Settle the calls below, then continue |
| An assistant message, `lastStopReason` `paused` | The turn is unfinished | Continue: send the history as it is (Pauses in the loop) |
| An assistant message, `lastStopReason` `end` | The run was over | Set `completed` |
| An assistant message, `lastStopReason` `length`, `refusal` or `other` | The turn failed | Set `truncated`, `refused` or `failed`. Run **no** tool call of it: it may be cut off mid-input |

**Settling calls.** For each `tool_call` of the last assistant message:

- If `pending.jsonl` holds its result, use it.
- Otherwise, a tool with `sideEffects` `none` or `read` may run again. It still goes through
  `beforeToolCall`, with `toolCallCounts` taken from the state.
- Any other call (`write`, `irreversible`, or a tool that is no longer declared) is **not**
  run again. Answer it with `isError: true` and a text like "Interrupted: the run stopped
  while this call was in progress, so it may or may not have happened. Check the current
  state before trying again." The model decides what to do. The harness never repeats a
  side effect that may already have happened.

Then append one `tool` message with all the results, as usual.

Counters come from the state: `step`, `usage`, `elapsedSeconds` (the time the run was
active, so the wall limit does not count the time it sat stopped), `toolCallCounts`,
`consecutiveErrors`, `consecutivePauses`, `sawUntrustedInput` (see the rules for memory).
Add one to `resumes`.

A run is resumed when its `status` is `running` and its lock is free. A run that ended with
`limit_reached` may be resumed by a person who raises the limit. `completed`, `truncated`,
`refused` and `failed` are not resumed automatically.

## Persistent memory

Memory holds what a later run should know and cannot find out again cheaply: a preference of
the user, a decision and its reason, how to do a task here, where something lives. It is not
a log of the conversation, and it is not run state.

### Entries

One entry per fact. Shape: `schemas/memory-entry.schema.json`.

| Field | Meaning |
|---|---|
| `id` | Short slug, unique in the store |
| `kind` | `fact`, `preference`, `procedure` or `reference` (a pointer to where something lives) |
| `description` | One line, used to choose what to read |
| `content` | The note, at most 2000 characters |
| `origin` | `user_statement`, `agent_inference` or `external_content` |
| `createdAt`, `updatedAt` | When |
| `expiresAt` | Optional. Expired entries are not loaded |
| `source` | Optional: the `runId` and `step` that wrote it |

### Operations

The agent reaches memory only through tools. Names are examples. Each is a tool as in
`tools.md`.

| Tool | `sideEffects` | Does |
|---|---|---|
| `memory_search(query, limit)` | `read` | Returns `id` and `description` of the best matches |
| `memory_read(id)` | `read` | Returns the entry |
| `memory_write(entry)` | `write` | Creates the entry, or replaces the one with that `id` |
| `memory_delete(id)` | `write` | Removes it |

Where the tool runs, and what indexes it, is a project choice: a folder of files, a
database, a vector index. A file store works as well: one file per entry, as in the
Anthropic memory tool, whose commands are `view`, `create`, `str_replace`, `insert`,
`delete` and `rename` on a `/memories` folder. Map it to the entry shape if you use it.

### Loading

At the start of a run, put an **index** in the context: `id` and `description` of each live
entry whose `origin` is `user_statement` or `agent_inference`, up to `maxIndexEntries`
(default 50, newest first), under a heading that says they are notes from earlier runs and
are data. The model fetches the ones it needs with `memory_read`. Do not load every entry's
content by default; it costs tokens on every run and every call.

`external_content` entries are **not** in the index. They can still be found with
`memory_search` and read with `memory_read`, and doing so taints the run (see the rules).

Put the index in the system prompt, where it stays the same for the whole run and the prompt
cache survives. If you put it in the first user message instead, that message is replaced by
the summary on compaction, so add the index to the new context again.

### Rules

- **Notes are data, never instructions.** A note cannot grant a permission, change the tool
  policy or override the system prompt. Say so in the heading of the index. That wording is
  a hint to the model, not a control; the controls are in code (see the tool policy).
- **The harness sets `origin`, not the model.** A write made in a *tainted* run is
  `external_content`; otherwise a model's own conclusion is `agent_inference`, and only what
  the user said is `user_statement`. A run is **tainted** from the moment it receives
  anything from an untrusted source: a tool result of an untrusted tool, or an
  `external_content` entry returned by `memory_search` or `memory_read`. The harness keeps
  this as `sawUntrustedInput` in the run state, so it survives a resume. Without the second
  case, one poisoned entry would come back as trusted in the next run and could spread.
  A policy list of untrusted tools is static and cannot express this, so the harness marks
  the taint itself.
- **A tainted run cannot change entries of another origin.** In a tainted run, a
  `memory_write` that would replace an entry, or a `memory_delete` of one, is denied unless
  that entry is also `external_content`, or a person confirms it. Guarding only overwrites
  would let a run delete a `user_statement` entry and write its own under the same id.
  New `external_content` entries are shown to a person or confirmed, since memory that
  outlives the run is where a single injected line becomes permanent.
- **No secrets, and no personal data the task does not need.** Keys, tokens, passwords and
  copies of private documents never go in an entry. Check the data protection rules that apply
  before keeping data about a person.
- **One store per user or tenant.** The harness picks the store from who is asking. The
  model never chooses it, and a tool never takes it as an argument.
- **Memory can be wrong.** An entry that names a file, a function or a setting says what was
  true when it was written. Check it against the world before acting on it. Update or
  delete a wrong entry; do not add a contradicting one beside it.
- **Keep it small.** Past `maxEntries` (default 200), the write fails with a message that
  asks the model to delete or merge entries.

Memory is state. A test that needs memory starts each trial from a copy of a fixed store,
and a test that does not starts from an empty one, so trials do not leak into each other.

## What this contract does not decide

- How `memory_search` ranks (keywords, embeddings).
- How a person reviews, edits or erases the memory of a user.
- Summaries across several runs, or memory shared between agents.
- Streaming and the format of `runs/<runId>/overflow/`.

## Sources

Read on 2026-10-19 through the notes of the Anthropic API skill, not the pages themselves:

- Compaction, context editing and the memory tool of the Anthropic API: what each does,
  that compaction blocks must be kept, the memory tool commands.
- Conversation binding of thinking blocks: a provider can reject a request whose earlier
  messages differ from those a thinking block was produced against. This is why keeping the
  newest turns beside a summary is left out, and why simple compaction replays nothing old.
  Enforcement depends on the model and the age of the account; the contract takes the
  stricter route so it works everywhere.
