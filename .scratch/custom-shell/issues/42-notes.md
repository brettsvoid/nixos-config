# Launcher notes

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

A notes mode in the launcher. It finds a note by title or text and opens it, makes a
new note, or adds a line to an inbox note without opening anything.

- ambxst has notes as `nn`, with its own rich-text and Markdown editor
  (`modules/widgets/dashboard/notes/NotesTab.qml`). Ideas only.
- brett-desktop already has Markdown notes: the Obsidian vault at
  `~/Documents/Obsidian Vault` (about 200 notes), synced with the Macs by Syncthing and
  edited in Neovim with obsidian.nvim. Obsidian is not installed on Linux. The laptop
  does not import Syncthing (`modules/system/nixos/syncthing.nix`).

## Proposed choices

1. **Markdown, as plain `.md` files.** Alternative: rich text kept as HTML (ambxst).
   Reason: the vault, obsidian.nvim and Obsidian on the Macs all read Markdown.
2. **Notes are the `.md` files under `notes.folder`, default
   `~/Documents/Obsidian Vault`**, newest first, without dot folders (`.obsidian`,
   `.stversions`, `.trash`, `.inbox`). Alternative: a folder of the shell's own,
   `~/.local/share/custom-shell/notes`. Question: should the laptop get the vault
   through Syncthing, or a local folder set from Nix?
3. **Enter opens the note in Neovim in the terminal** (`launcher.terminal` plus
   `notes.editor`, default `nvim`). Alternative: a dashboard Notes tab with a
   plain-text editor and a preview in Qt's Markdown text format. Reason: Neovim already
   handles the vault, and long typing in a drawer takes the keyboard from every window.
4. **A query that no title matches offers two rows.** "New note '<text>'" makes
   `<text>.md` at the folder's root (the vault's convention) and opens it. "Add
   '<text>' to Inbox" appends `- <text>` to `notes.inbox` (default `Inbox.md`) and
   opens nothing. Alternative: only the new note.
5. **Titles match at once; text matches after typing pauses.** One
   `grep -rilF --include='*.md'` runs per pause, only in this mode (as the calculator
   runs qalc), and its matches list under the title matches. Alternative: titles only.
6. **Prefix `nn`** (ambxst's), setting `launcher.notesPrefix`. Alternative: `#`.
- Settings: `launcher.notesPrefix`, `notes.folder` (`~` is the home folder, as in
  `wallpaper.folder`), `notes.editor` and `notes.inbox`, under a Notes heading on the
  Launcher page.
- Cost: one `find` when the mode opens and one `grep` per pause in it. Nothing runs
  otherwise, so nothing in game mode.

## Acceptance criteria

- [ ] `nn` lists the notes newest first, and typing filters them by title.
- [ ] A word found only inside a note finds it, below the title matches.
- [ ] Enter opens the note in Neovim in kitty, and obsidian.nvim loads for it.
- [ ] "New note" makes the file and opens it. "Add to Inbox" appends one line only.
- [ ] A folder that does not exist gives a hint row. The first new note makes it.
- [ ] Nothing runs while the launcher is in another mode.
- [ ] Tests use a scratch folder, never the vault (Syncthing would copy test notes to
      the Macs).
- [ ] The apps placeholder, or issue 44's prefix list, names the prefix.

## Blocked by

- None
