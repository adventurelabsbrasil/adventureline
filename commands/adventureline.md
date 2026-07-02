---
description: Switch or preview the adventureline statusline theme
argument-hint: "[adventure|aurora|starcommand|minimal|preview|list]"
allowed-tools: Bash(~/.claude/adventureline:*)
---

Control the **adventureline** statusline theme. The argument is: `$ARGUMENTS`

Rules:
- If the argument is one of `adventure`, `aurora`, `starcommand`, `minimal` (or `star`, `min`):
  run `~/.claude/adventureline theme $ARGUMENTS`, then reply in one line confirming the
  active theme and that it applies on the next statusline render.
- If the argument is `preview`, `list`, `current`, or **empty**:
  run `~/.claude/adventureline $ARGUMENTS` (use `preview` when empty) and show the output.
- Any other value: run `~/.claude/adventureline list` and tell the user the valid options.

Keep it terse. Do not edit files by hand — always go through the `~/.claude/adventureline` CLI.
