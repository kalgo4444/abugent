# abugent

A plugin of skills for Claude Code and OpenCode.

## Install

### Claude Code

```
/plugin marketplace add kalgo4444/abugent
/plugin install abugent@abugent
```

### OpenCode

Add the plugin to `opencode.json` (or `opencode.jsonc`). OpenCode 2.x uses the `plugins` key; 1.x uses `plugin`.

```jsonc
{
  "plugins": ["abugent@git+https://github.com/kalgo4444/abugent.git"]
}
```

To use a local clone instead, give the absolute path of the repo directory (`~` is not expanded):

```jsonc
{
  "plugins": ["/path/to/abugent"]
}
```

Restart OpenCode (`opencode service restart` on 2.x). The skills load through OpenCode's native `skill` tool.

Skills are written for Claude Code, so Claude-specific tool names such as `AskUserQuestion` or `Agent` are interpreted by the model as the closest OpenCode equivalent (for example `task`/`subagent` for subagents).

## Skills

| Skill | What it does |
| --- | --- |
| `diagram-maker` | SVG/HTML or Excalidraw diagrams: flowcharts, architecture, sequences, mind maps |
| `geradot` | Decision review using Herodotus's "drunk and sober" two-state method |
| `security-audit` | Source-first vulnerability review of a codebase, API, service or CLI |
| `grill-me`* | Stress-tests a plan, decision or idea with relentless questions |
| `handoff`* | Compacts the conversation into a handoff doc for the next agent |
| `teach`* | Teaches a skill or concept within the workspace |

\* Manual only: run as `/abugent:<name>` in Claude Code, or load by name with the `skill` tool in OpenCode. The others also trigger automatically.


## License

MIT
