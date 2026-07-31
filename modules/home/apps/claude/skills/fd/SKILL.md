---
name: fd
description: Find files and directories using fd
argument-hint: <pattern> [path] [options]
allowed-tools: Bash(fd:*)
model: haiku
---

Use `fd` to find files matching the user's criteria.

The user asked: $ARGUMENTS

**fd key flags:**
- `-e ext` — filter by extension
- `-t f` / `-t d` — files only / directories only
- `-H` — include hidden files
- `-I` — skip .gitignore rules
- `-d N` — max depth
- `-x cmd` — execute command per result
- `-E pattern` — exclude pattern
- `-g` — glob pattern instead of regex
- `--changed-within duration` — recently modified (e.g. `1d`, `2h`)

Run `fd` with the appropriate flags for what the user wants. Present the results clearly. If the result set is large, suggest ways to narrow it down.
