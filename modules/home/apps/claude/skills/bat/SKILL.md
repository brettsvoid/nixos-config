---
name: bat
description: View file contents with syntax highlighting using bat
argument-hint: <file> [options]
allowed-tools: Bash(bat:*)
model: haiku
---

Use `bat` to display file contents with syntax highlighting.

The user asked: $ARGUMENTS

**bat key flags:**
- `-l language` — force syntax highlighting language
- `-n` — show line numbers only (no decorations)
- `-p` — plain output (no decorations at all)
- `--range N:M` — show only lines N to M
- `--diff` — show git diff for file
- `-A` — show non-printable characters
- `--style components` — control decorations (full, plain, numbers, grid, header)
- `--theme name` — set colour theme
- `--list-themes` / `--list-languages` — list available options

Run `bat` with the appropriate flags. For large files, use `--range` to show relevant sections.
