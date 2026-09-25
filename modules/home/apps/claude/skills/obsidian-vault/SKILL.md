---
name: obsidian-vault
description: Search, create, and manage notes in the Obsidian vault, including recipes. Use when user wants to find, create, save, or organise notes in Obsidian or "my vault".
---

# Obsidian Vault

## Vault location

`~/Documents/Obsidian Vault/`, synced with Syncthing.

## Layout

- Topic folders (`Recipes/`, `Cheatsheets/`, `Learning/`, `Baldur's Gate 3/`, …) plus
  loose notes at the root. Put a new note in the matching folder; otherwise the root.
- Hidden folders to leave alone: `.obsidian/`, `.stfolder/`, `.stversions/` (Syncthing's
  old copies of notes — duplicates, never edit or cite them), `.trash/`.
- `.inbox/` is also hidden and holds a few kebab-case notes.
- Attachments go in `_assets/` beside the note (`attachmentFolderPath: ./_assets`), e.g.
  `Recipes/_assets/`. Embed with `![[file.jpg]]`.
- No index notes. `Recipes/_recipe-index.base` is an Obsidian Base that lists everything
  in `Recipes/` automatically. The Dataview plugin is installed.

## Conventions

- **Title Case** filenames for new notes, spaces allowed. Existing names are mixed; don't
  rename them.
- Tags in frontmatter as a YAML list, lowercase kebab-case:
  ```yaml
  ---
  tags:
    - food
    - recipe
  ---
  ```
- Link related notes with `[[wikilinks]]` where a real relationship exists. Links are
  used sparingly; don't invent them.

## Recipes

- Save to `Recipes/`, tagged `food`, `recipe` and one category (`curry`, `pasta`,
  `korean`, …).
- Follow the layout of `Recipes/Butter Chicken (Air Fryer).md`: H1 title, a short intro,
  a `**Serves** · **Active**` line, `## Ingredients` with `###` groups, a numbered
  `## Method` with a bold name per step, `## Notes`, then sources after a `---` rule.
- Metric quantities (g, ml, tbsp, tsp, °C).
- Air fryer: Ninja Dual Zone AF300UK. No preheat; split between both drawers and press
  MATCH for larger batches. Give a doneness temperature, not only a time.

## Workflows

`fd` and `rg` skip hidden folders by default, which keeps `.stversions/` out of results.

```bash
V="$HOME/Documents/Obsidian Vault"

# Search by filename
fd -e md -i "keyword" "$V"

# Search by content
rg -l -i "keyword" "$V" --type md

# Backlinks to a note
rg -l -F "[[Note Title" "$V" --type md
```

Before creating a note, search for an existing one on the same topic (including
`Draft - …` notes) and update it instead of making a duplicate.
