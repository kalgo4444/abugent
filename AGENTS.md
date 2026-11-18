# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`abugent-skills`: a Claude Code plugin containing only skills, and its own marketplace (`abugent`). There is no build step.

- `.claude-plugin/plugin.json`: plugin manifest. `skills` points at `skills/`.
- `.claude-plugin/marketplace.json`: marketplace listing this repo (`source: "./"`) as the single plugin. Keep its name, description and keywords in sync with `plugin.json`.
- `skills/<name>/SKILL.md`: one skill per folder. The frontmatter `name` must match the folder name. Supporting files (`references/`, `assets/`, `*-FORMAT.md`) sit next to the skill and are linked from `SKILL.md`.

## Skill conventions

- The `description` controls when the skill triggers. Say both when to use it and when *not* to (see `security-audit`, `geradot`).
- Skills that should only run when the user invokes them (`grill-me`, `handoff`, `teach`) set `disable-model-invocation: true` and, when they take input, `argument-hint`.

## Tests

The only code is the `security-audit` validators (Node CommonJS, no dependencies):

```sh
node --test skills/security-audit/*.test.cjs  # all tests (passing the bare directory fails)
node --test skills/security-audit/validate-findings.test.cjs
```

`validate-findings.cjs` checks `findings.json` against `report-schema.json`. Update both together.
