---
name: dust
description: Analyse disk usage with dust
argument-hint: [path] [options]
allowed-tools: Bash(dust:*)
model: haiku
---

Use `dust` to analyse disk usage for the user's query.

The user asked: $ARGUMENTS

**dust key flags:**
- `-n N` — number of lines to show
- `-d N` — max depth
- `-r` — reverse sort order
- `-s` — use apparent size
- `-b` — no percent bars
- `-f` — show filecount instead of size
- `-i` — ignore hidden files
- `-e regex` — exclude matching paths

If no path is specified, default to the current directory. Present the output and highlight any notably large directories or files.
