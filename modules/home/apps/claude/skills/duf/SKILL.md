---
name: duf
description: Show disk usage and filesystem info with duf
argument-hint: [options]
allowed-tools: Bash(duf:*)
model: haiku
---

Use `duf` to show disk usage and mounted filesystem information.

The user asked: $ARGUMENTS

**duf key flags:**
- `--all` — show all filesystems
- `--hide type` — hide specific filesystem types (e.g. `special`, `loops`, `binds`)
- `--only type` — show only specific types (e.g. `local`, `network`)
- `--json` — JSON output
- `--sort column` — sort by column (size, used, avail, usage, type, mount)
- `--output fields` — select columns to display

Run `duf` and summarise the filesystem status. Flag any volumes that are running low on space.
