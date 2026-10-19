# Evals: measuring the agent behavior

An eval answers one question: did this change make the agent better or worse? Tests of the
code cannot answer it, because the behavior comes from prompts, tools, a model and a
policy. Any change to those is measured here before it is accepted.

This document is a contract: formats and rules. The template ships no runner. A project
writes one in its own language, to the rules in "Running". Data shapes are the schemas in
`schemas/`: `eval-case`, `eval-suite`, `eval-result`, `eval-error`. Conversation messages
use `schemas/message.schema.json` from the runtime contracts.

## Layout

```
evals/
  suite.json              settings shared by all cases (schema: eval-suite)
  cases/<id>.json         one case per file (schema: eval-case)
  fixtures/               files that seed the environment of each run
  rubrics/                judge prompts and the human-labeled set that calibrates them
  results/<runId>/        written by the runner, not committed
    results.jsonl         one line per scored trial (schema: eval-result)
    errors.jsonl          one line per failed attempt (schema: eval-error)
    transcripts/<caseId>_rep<k>.json
```

## Cases

A case is the input, where it came from, and the graders that decide the result.

Rules for a good case, each one a common way evals mislead:

- **One capability per case.** A case that needs retrieval, reasoning and formatting scores
  zero whenever any of them breaks, and does not say which.
- **Cover both directions.** For every "the agent should act" there is a case where it should
  not, tagged `negative`. Otherwise an agent that always acts scores perfectly.
- **Give the symptom, not the investigation.** If the input already contains the failing
  test or the log line, the case measures reading a hint, not finding one.
- **Unambiguous success.** Two experts shown the same output should agree on pass or fail.
  Write a reference solution and run it through the graders: a case nothing passes is
  usually broken, not hard.
- **The expected answer is out of reach of the model.** Not in the prompt, not in a
  fixture, not in a tool description. This has to hold structurally; "do not look" in a
  prompt is not a defense.
- **Say where the ground truth came from** (`origin`). Gold taken from a model rewards
  imitating that model, and in a model migration it makes the incumbent win by
  construction; the schema requires naming the model. Prefer a rubric over reference
  similarity in that case.
- **Real before synthetic.** Start from production failures and reported bugs. Twenty to
  fifty real cases beat hundreds invented from the prompt. Every new failure seen in use
  becomes a case before it is fixed.
- **Keep facts fresh.** Cases that depend on live facts carry `verifiedOn`, so a stale
  expected answer does not mark a correct output as wrong.

## Graders

Each grader is an independent check with its own `id`, and that id is its metric. Prefer
several atomic checks (`correct`, `formatted`, `concise`) over one blended score: they are
reproducible, easier to calibrate, and tell you what broke.

**Grade the outcome, not the path.** Requiring an exact sequence of tool calls fails an
agent that solved the task another valid way. For an agent that acts on an environment,
run each trial in a disposable workspace and grade what it left behind: files, rows, tests
that pass, nothing off-limits touched. A transcript only shows what the agent said it did.

| Kind | Use when | Cost |
|---|---|---|
| `check` | The output space is constrained, or the end state can be inspected | Deterministic, free |
| `rubric` | Open-ended output with clear quality criteria | A model call per case |
| `human` | Even a rubric is hard to write; and to calibrate judges | Slow, small subsets only |

### Checks

| `check` | `params` | Reads | Passes when |
|---|---|---|---|
| `equals` | `value` | final assistant text | equals `value` after trimming whitespace |
| `contains` | `value` | final assistant text | contains the string |
| `notContains` | `value` | final assistant text | does not contain the string |
| `matches` | `pattern` | final assistant text | matches the regular expression |
| `jsonSchema` | `schema` | final assistant text | parses as JSON and validates against `schema` |
| `endState` | `name` | the environment after the run | the project function called `name` returns true |
| `toolCalled` | `tool` | the trajectory | the tool was called at least once |
| `toolNotCalled` | `tool` | the trajectory | the tool was never called |
| `maxToolCalls` | `max` | the trajectory | total tool calls are at most `max` |
| `maxSteps` | `max` | the trajectory | model calls are at most `max` |

Normalize before comparing text: casing, whitespace, `4` against `4.0`, markdown fences.
Use trajectory checks for process guardrails (it did not call a forbidden tool, it stayed
within a budget), not to dictate how to solve the task. A run that produced no answer is
not a negative answer: do not let an empty or crashed run satisfy `notContains` or
`toolNotCalled` by accident.

### Rubrics

- Each criterion is one concrete, checkable claim ("the answer cites at least one source
  from the context"), not a scale ("rate helpfulness from 1 to 5").
- The judge is not the model under test, and a judge from the same family prefers outputs
  that look like its own. Name it in `suite.json` under `judge`.
- Treat the candidate text as data, not instructions. Ask the judge for structured output
  so parsing is deterministic. Do not tell it which answer is the reference.
- Tell the judge not to reward length for its own sake.
- Calibrate against human labels: label a few dozen clear-cut cases by hand, measure
  agreement, and record it in `calibrationAgreement`. Well below about 90% means the judge
  prompt needs another iteration before its scores can steer decisions.
- Test it on known negatives: an empty answer, "I do not know", and a confident answer to
  the wrong question must all fail.

## Aggregating

`suite.json` sets how each metric is aggregated. `perCase` combines the reps of one case,
`overall` combines the cases.

| `perCase` | Meaning | Choose it for |
|---|---|---|
| `mean` | Average pass rate over the reps | Typical-case quality |
| `all` | Every rep must pass (pass^k) | Behavior that must be consistent |
| `any` | One passing rep is enough (pass@k) | Cases where one good result is enough |

| `overall` | Meaning | Choose it for |
|---|---|---|
| `mean` | Pass rate over cases | Most metrics |
| `all` | Every case must pass | Rare high-stakes behavior, such as irreversible actions, where an average over easy cases hides the failure |

A metric with no entry uses `mean` and `mean`. Do not let partial credit make doing nothing
the best policy: if penalties for trying outweigh the reward for succeeding, a lazy agent
wins.

## Running

The runner is project code. It must:

- **Call the real entry point** with the real system prompt, tools, model and policy. A
  re-implementation measures a different system.
- **Start every trial clean.** Fresh environment, no files or state left by an earlier trial.
  Shared state leaks side effects between cases and makes results depend on order.
- **Be deterministic where it can.** Pin seeds and sort anything whose order reaches the
  model or a grader.
- **Run `reps` trials per case** and report results with an interval. One trial has no
  error bar.
- **Keep failed attempts out of the scores.** A trial that produced no scorable output
  (timeout, rate limit after retries, grader crash, wrong served model, harness fault)
  appends a line to `errors.jsonl` and never to `results.jsonl`. A zero in the results
  would score plumbing as a model failure and would block resume.
- **Flag truncation.** A response cut at the output limit gets `status: truncated`. It is
  counted and shown but left out of the means; a clipped answer is not a wrong one.
- **Treat a refusal as a result.** `status: refused`, with its own metric, so refusal
  zeros and capability zeros are not added together.
- **Assert the model.** Read `model` from the response, and fail the attempt when it is not
  the requested one (an alias resolving to a snapshot is fine). A score from the wrong
  model measures nothing.
- **Retry with jittered backoff,** cap the attempts, record `attempts`, and count every
  attempt toward cost. By default a trial that passed only on retry is a failure.
- **Set a hard wall-clock ceiling per attempt** (`caseTimeoutSeconds`), independent of
  whether a stream is still sending data. A timeout is an error, not a zero.
- **Save the full trajectory** of every trial: each message, tool call, result and error,
  plus the grader inputs and outputs. It is what makes a surprising score explainable
  without running again.
- **Record usage from the provider,** never estimated from text length, and record the
  judge usage apart from the usage of the model under test.
- **Make resume idempotent** on `(caseId, rep)`: a restart skips what is already written and
  never produces a duplicate.
- **Test the harness itself** before the first full pass: an oracle (the reference answers)
  must pass and a null baseline (empty output) must fail. If not, the harness or a grader
  is broken.

## Reading results

- **Recompute the headline from the raw rows.** Do not trust an aggregate field.
- **Know the noise floor.** For a pass rate it is about `1/sqrt(cases x reps)`: 25 cases
  with 2 reps is about plus or minus 14 points, 100 cases with 2 reps about 7. A difference
  below it is not a result. Keep `regressionTolerance` above it.
- **Check headroom.** At 95% or more the eval cannot separate variants at the top; at near
  0% suspect a broken case or grader first. A weaker variant that beats a stronger one on a
  case is more often a bug in the case than a real inversion.
- **Read transcripts.** Read the graded trajectories of many trials, and the failures in
  particular. If more than about one in ten failures looks like a grader error, fix the
  grader before trusting any number.
- **Hold out a set.** Split at random, stratified by `tags[0]`, with the seed in
  `suite.json`. Never choose the split by score: a training slice made of the worst cases
  improves on a re-run by chance alone.
- **Compare like with like.** Scores from different `version` values are not comparable.
  Bump `version` whenever a case or a grader changes.

## Keeping the suite alive

New failure modes become cases. Saturated cases are made harder. The judge is recalibrated
when it drifts. Now and then, have a strong model read the cases, the rubrics and a few
graded transcripts and ask where a reasonable person would disagree with the label.

Include prompt-injection cases (content the agent reads that tries to redirect it) and
cases where it must not act, so that a change to the agent that weakens its safeguards
shows up as a regression.

## Sources

- [Demystifying evals for AI agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)
  (Anthropic, January 2026): code, model and human graders, grading outcomes over steps,
  pass@k and pass^k, reading transcripts, building the set from real failures, covering
  both directions.
- The eval health checklist in the Anthropic guidance shipped with the Claude API skill
  (not a public page): infrastructure failures kept apart from model failures, "no answer"
  against "negative answer", clean state per trial, judge calibration, noise floor, splits
  drawn at random.
