# Modules

Template-only. `init` applies modules to the project root, then deletes `modules/`.

The repo root is the `lite` profile and is usable as is. `full` adds every module
(`profiles.json`). Any other mix is allowed: pass module names to `init`.

## Module layout

```
modules/<name>/
  module.json        # name, description, requires (other modules)
  files/             # copied as is into the project root, mirroring its layout
  AGENTS.map.md      # rows inserted at <!-- modules:map --> in AGENTS.md
  AGENTS.rules.md    # bullets inserted at <!-- modules:rules --> in AGENTS.md
```

Template-only tools live in `modules/tools/` (see `TEMPLATE.md`). `modules/tools/` is not a
module: it has no `module.json` and `init` never copies it.

`init` must: resolve `requires`, copy `files/` without overwriting existing files, insert
the non-empty snippets into `AGENTS.md`, and report what it did.

| Module | Adds | Requires |
|---|---|---|
| specs | Task scaling table, spec templates | none |
| roles | planner, spec-author, implementer, reviewer | specs |
| backlog | `backlog.json`, session lifecycle, history | none |
| runtime | Agent loop, tool and model-interface contracts + schemas | none |
| memory | Memory and context contract | runtime |
| observability | Trace events contract + schema | runtime |
| guardrails | Tool policy, budgets, human-in-the-loop | none |
| evals | Case schema, rubrics | none |
