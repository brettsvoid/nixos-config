---
name: procs
description: List and search processes with procs
argument-hint: [keyword] [options]
allowed-tools: Bash(procs:*)
model: haiku
---

Use `procs` to list or search running processes.

The user asked: $ARGUMENTS

**procs key flags:**
- `keyword` — filter processes by keyword (name, command, user)
- `--sortd column` — sort descending by column (cpu, mem, pid, etc.)
- `--sorta column` — sort ascending
- `--tree` — show process tree
- `--insert column` — add extra columns

Present the results and highlight any processes consuming unusual resources.
