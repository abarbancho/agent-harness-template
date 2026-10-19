# Scripts

## check

The harness check. It validates this repo layout, not the project code (the project check
in `AGENTS.md` does that). Two variants with the same output:

```sh
sh scripts/check.sh
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1
```

| Check | Fails when | Skipped when |
|---|---|---|
| placeholders | `AGENTS.md`, `README.md` or `CLAUDE.md` still contain a `{{NAME}}` placeholder | `modules/` exists (template not initialized) |
| repo map | a path in the first column of the repository map in `AGENTS.md` does not exist | no table under `## 3. Repository map` |
| schema examples | a schema in `schemas/` has no `examples/<name>.valid.json` or `examples/<name>.invalid.json` | no `schemas/` directory; a schema is a stub (contains `TODO`) |

Each line is `[PASS]`, `[FAIL]` or `[SKIP]`. A skip means the check did not run. The exit
code is 1 only if something fails.

Limits, on purpose: it checks that examples exist, not that they validate. Validating
needs a JSON Schema validator, which this stack-agnostic template does not assume.
Projects that add one can call it from their own project check.
