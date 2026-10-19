# Using this template

Template-only: `init` deletes this file, `modules/` and `scripts/init.*`.

A template for starting AI agent projects: a development process for working with AI
coding tools, plus language-agnostic contracts for the agent runtime.

## Profiles

- **lite** (the repo root as is): `AGENTS.md`, tool adapters, `progress/`, `evals/`.
  Enough for a small project. This is the default.
- **full**: lite plus every module in `modules/` (specs, roles, backlog, runtime
  contracts, memory, observability, guardrails, evals). Pick modules individually with
  `--modules`; see `modules/README.md` for the module format and dependencies.

Status: skeleton. Files marked `TODO` are stubs. Open design decisions are in
`modules/OPEN_ITEMS.md`.

## Running init

Existing files are never overwritten. Run `--dry-run` first to see what would change.

```sh
sh scripts/init.sh --name "My Agent" --profile full --check-cmd "uv run pytest"
sh scripts/init.sh --name "My Agent" --modules roles,evals --dry-run
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\init.ps1 -Name "My Agent" -Profile full -CheckCmd "uv run pytest"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\init.ps1 -Name "My Agent" -Modules roles,evals -DryRun
```

| Option (sh / PowerShell) | Meaning |
|---|---|
| `--name` / `-Name` | Required. Project name |
| `--profile` / `-Profile` | `lite` (default) or `full`, from `modules/profiles.json` |
| `--modules` / `-Modules` | Extra modules, comma-separated; dependencies are added |
| `--install-cmd`, `--run-cmd`, `--check-cmd` / `-InstallCmd`, `-RunCmd`, `-CheckCmd` | Fill the commands table in `AGENTS.md`. `--check-cmd` is the **project** check (tests, lint), not `scripts/check`. If omitted, the placeholder stays and is reported, and `scripts/check` fails on it |
| `--dry-run` / `-DryRun` | Print what would change, touch nothing |
| `--keep` / `-Keep` | Keep `modules/`, `init.*` and this file (for testing the template) |

## Maintaining the template

Schemas ship with a valid and an invalid example in `schemas/examples/`. To prove they
behave, run the maintenance tool. It needs Node and Ajv 2020 (the default `Ajv` class
rejects the 2020-12 `$schema`, so the tool uses `ajv/dist/2020`). Install Ajv outside the
project:

```sh
npm install --prefix /some/dir ajv@8
AJV_DIR=/some/dir node modules/tools/validate-examples.cjs
```

It skips stub schemas, requires every other schema to have both examples, and prints the
first error of each invalid example so you can confirm it fails for the intended reason.
`scripts/check.*` only checks that the example files exist.

## What was verified

Checked on Windows only: Git Bash (GNU tools) and Windows PowerShell 5.1. The two `init`
variants produced identical trees for `lite`, `full` and a module subset, with LF and CRLF
inputs. The two `check` variants produced identical output on the template, on generated
`lite` and `full` projects, and on three injected failures (an unresolved placeholder, a
repository map row pointing to a missing path, a schema without an example). The `runtime`
schemas were validated against their examples with Ajv 2020. Not tested: macOS (BSD
`sed`/`awk`), Linux with `dash`, PowerShell 7.

Known quirk: on Windows, Git Bash `sed` and `awk` drop carriage returns, so `init.sh`
rewrites `AGENTS.md` and `README.md` with LF endings. `.gitattributes` (`text=auto`)
normalizes this in git; use `init.ps1` if you want CRLF preserved.
