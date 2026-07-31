---
name: tree
description: Show directory tree structure
argument-hint: [path] [options]
allowed-tools: Bash(lsd:*)
model: haiku
---

Use `lsd --tree -AF` to display directory tree structure. On this system `tree` is aliased to `lsd -AF --tree`, so use `lsd` directly.

The user asked: $ARGUMENTS

**lsd --tree key flags:**
- `--depth N` — max display depth
- `--ignore-glob pattern` — ignore matching entries
- `-a` — show hidden files
- `-l` — long format with details
- `--group-directories-first` — directories first
- `-S` — sort by size
- `-t` — sort by time
- `-r` — reverse sort

If no path is specified, default to the current directory. Use `--depth` to keep output manageable for large directories.
