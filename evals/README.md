# Evals

> Changes to prompts, tools or agent policy are measured here before they are accepted.

Put golden cases in `cases/`, one JSON file each, named `<id>.json`. A case has:

- `id`, and a `description` of the one behavior it checks;
- `tags`, where the first tag is the main group; tag cases where the agent must **not** act
  as `negative`, so an agent that always acts cannot score perfectly;
- `input`: the conversation so far, as the user would report the symptom;
- how to judge it: the expected outcome, as one or more independent checks (exact value,
  end state of the environment, a rubric of concrete claims).

Rules that keep an eval honest:

- Grade the outcome, not the exact path the agent took.
- Run each trial from a clean state, several times, and report the spread. One run has no
  error bar.
- Keep failed runs (timeouts, crashes, rate limits) out of the scores; they are not model
  failures.
- Never change a case or an expected answer to make a failing run pass.

Run the cases with the project's own runner (the harness ships none). Write results to
`results/`, which is not committed.
