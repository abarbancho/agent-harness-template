# Guardrails: tool policy for the agent you are building

**Scope.** This is the policy that decides which tool calls the agent being built may make
at runtime. It is not the permission setup of the AI coding assistant that edits this
repo (for example Claude Code hooks and settings). It builds on the agent loop and tool
contracts in `docs/contracts/`: the policy runs inside the `beforeToolCall` hook and
decides from the tool `sideEffects` and `external` facts.

The policy lives in `config/guardrails.policy.json` (schema: `schemas/policy.schema.json`).
This document explains how to evaluate it.

## Principles

1. **Enforce in code, not in the prompt.** An instruction in the system prompt is the
   weakest layer: a model can be talked out of it. Anything that matters is checked by
   the harness before the tool runs.
2. **Deny by default.** A tool nobody classified does not run unchecked. `default` is
   `deny` or `confirm`, never `allow`.
3. **Least privilege.** Give the agent only the tools the task needs, with credentials
   scoped to those tools and as short-lived as possible.
4. **The most restrictive decision wins.** Order of rules does not matter, and an `allow`
   cannot carve an exception out of a `deny`.
5. **Everything is recorded.** Every evaluated call produces a decision record.

## Deciding a call

The hook receives the call, the tool declaration and the run context (see
`docs/contracts/agent-loop.md`). It decides in this order:

1. **Facts.** Tool name, `sideEffects` and `external`. A tool with no `external` counts as
   `false`.
2. **Rules.** Collect the decision of every rule that matches. A rule matches when every
   field it has matches: `tool` (a name, or a pattern where `*` matches any run of
   characters), `sideEffects` (one of the listed values), `external`. If no rule
   matches, the decision is `default`.
3. **Rule of Two escalation.** Add the `ruleOfTwo` decision when all of these hold:
   - a result from a tool matching `untrustedSources` is already in the run history
     (find it by matching each `tool_result` `callId` to its `tool_call`),
   - the run has a tool matching `sensitiveTools` available,
   - this call changes state or reaches outside: `sideEffects` is `write` or
     `irreversible`, or `external` is true.
4. **Budgets.** If `maxToolCalls` or the tool entry of `perToolMaxCalls` is already
   reached (use `toolCallCounts` from the run context), the decision is `deny`.
5. **Combine.** The result is the most restrictive of all the decisions above:
   `deny` beats `confirm` beats `allow`.
6. **Resolve `confirm`.** If `mode` is `unattended`, it becomes `deny`: nobody can answer.
   Otherwise ask a human (next section). Rejection and timeout both become `deny`.
7. **Record and return.** Write the decision record, then return `allow` or
   `deny(reason)` to the loop. The reason tells the model what it can do instead, and
   never exposes policy internals more than needed.

Example: a project wants the agent to send email, with a human approving each one. It adds
`{ "tool": "send_email", "decision": "confirm" }`. `send_email` is `irreversible`, which
the shipped rule does not match, so only the new rule matches and the result is `confirm`.
Without the rule the result would be `default`, `deny`.

**Loosening and tightening.** Because the most restrictive decision wins, an `allow` rule
cannot override a broader `confirm` or `deny`. So the shipped policy has one narrow
`allow` rule (read-only tools that stay inside the project) and relies on `default: deny`
for everything else. To permit a tool, add a rule for it: nothing broader gets in the way.
To tighten, add a `confirm` or `deny` rule: it wins. Write a broad `confirm` or `deny`
rule only when you want it to be permanent, because a project cannot loosen it without
editing it. A tool that needs a different decision from the rest of its class gets its own
rule, and the broad rule goes.

## Human approval

When the decision is `confirm` and the run is attended, the approver sees:

- the tool name and title, and the exact arguments;
- `sideEffects` and `external`;
- why approval is needed: the `reason` of the rules that matched, and whether the Rule of
  Two escalation applied;
- a way to approve or reject, with an optional reason.

An approval covers **that one call with those exact arguments**. The decision record keeps
`argumentsDigest`, so a changed argument is a new call and asks again. Waiting more than
`confirmTimeoutSeconds` means `deny`.

"Always allow this tool" is not a runtime flag in this contract. If a project wants it,
it is a new rule in `config/guardrails.policy.json`, which is visible in code review.

## The Rule of Two

Meta describes a heuristic for limiting the damage of prompt injection: within one session
an agent should satisfy no more than two of these properties.

- **A.** it can process untrustworthy inputs;
- **B.** it can have access to sensitive systems or private data;
- **C.** it can change state or communicate externally.

If an agent needs all three in the same session, Meta says it should not run autonomously
and needs at least supervision, such as human approval. It is a heuristic that targets the
highest-impact consequences, not a guarantee.

The policy turns this into configuration. You list which tools are `untrustedSources`
(A) and which are `sensitiveTools` (B); property C comes from `sideEffects` and
`external`. When A and B are both present, calls with C get the `ruleOfTwo` decision,
`confirm` or `deny`. Lists are maintained by hand: when you add a tool, classify it.

## Limits

`limits` overrides the agent loop limits. A value you leave out keeps the loop default; do
not copy the defaults here. `maxToolCalls`, `perToolMaxCalls` and `confirmTimeoutSeconds`
are enforced by the policy and have no loop equivalent. There is no cost-in-currency limit:
no contract supplies prices. Token and step limits cover the same ground.

## Decision record

Every evaluated call writes one record (schema: `schemas/policy-decision.schema.json`),
including calls the policy allowed. Store the arguments as a digest, not in clear:
arguments can carry secrets or personal data. `decision` is what the policy decided before
any human; `outcome` is what happened. The schema enforces that they are consistent: an
`allow` is `allowed`, a `deny` is `denied`, and a `confirm` ends `approved`, `rejected`,
`timed_out` or `denied` (unattended). An approval or rejection names the `approver`.

## Prompt injection: controls the harness enforces

Indirect prompt injection means hidden instructions in content the model reads, such as a
web page, a file or an email, change what it does. No single control stops it. The ones
below are enforced in code, and they work together:

- **Least privilege and scoped credentials.** What the agent cannot do, an injection
  cannot make it do.
- **Human approval for high-risk actions,** driven by `sideEffects` and the Rule of Two.
- **Label untrusted content as data.** Return it as a tool result, mark where it came from,
  and never place it in the system prompt or treat it as an instruction. Labeling helps
  but does not guarantee the model ignores it.
- **Constraints inside the tool.** A tool validates its own arguments: a file tool refuses
  paths outside the workspace, a network tool refuses hosts outside an allowlist. Do not
  rely on the model to pick safe values. The policy is coarse; the tool is exact.
- **Egress allowlist.** Block outbound network access except to the hosts the agent needs.
  A request to a model-chosen URL can carry data out in the address.
- **No secrets in the context.** Do not put credentials in prompts, tool arguments or tool
  results the model sees; inject them inside the tool.
- **Treat the model as an untrusted user** (OWASP) and test it: add injection attempts to
  your evals.

Not enough alone: detection and refusal of injected instructions is not reliable, and
system-prompt instructions are the first thing an attack overrides.

Unsourced but common practice: do not render model output that auto-loads remote images or
links without checking the target, since a rendered URL can leak data.

## Sources

- [OWASP LLM01:2025 Prompt Injection](https://genai.owasp.org/llmrisk/llm01-prompt-injection/):
  least privilege, human approval for high-risk actions, segregating untrusted content,
  adversarial testing.
- Meta, "Agents Rule of Two" (October 2025), <https://ai.meta.com/blog/practical-ai-agent-security/>.
  The page returned 403 when the template was written; the wording above was taken from
  two articles that quote it. Read the original before relying on the details.
- [MCP specification, Tools: security considerations](https://modelcontextprotocol.io/specification/latest/server/tools):
  keep a human in the loop with the ability to deny, treat tool annotations as untrusted,
  validate inputs, rate limit, log usage.
- [Claude Code permissions](https://code.claude.com/docs/en/permissions): the model of
  evaluating deny, then ask, then allow, where the most restrictive match wins, which this
  policy copies.
