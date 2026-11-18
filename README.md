# abugent

A Claude Code plugin of skills.

## Install

```
/plugin marketplace add kalgo4444/abugent
/plugin install abugent-skills@abugent
```

## Skills

| Skill | What it does |
| --- | --- |
| `diagram-maker` | SVG/HTML or Excalidraw diagrams: flowcharts, architecture, sequences, mind maps |
| `geradot` | Decision review using Herodotus's "drunk and sober" two-state method |
| `security-audit` | Source-first vulnerability review of a codebase, API, service or CLI |
| `grill-me`* | Stress-tests a plan, decision or idea with relentless questions |
| `handoff`* | Compacts the conversation into a handoff doc for the next agent |
| `teach`* | Teaches a skill or concept within the workspace |

\* Manual only: run as `/abugent-skills:<name>`. The others also trigger automatically.

## Development

No build step. Each skill lives in `skills/<name>/SKILL.md`. Run tests with:

```sh
node --test skills/security-audit/*.test.cjs
```

## License

MIT
