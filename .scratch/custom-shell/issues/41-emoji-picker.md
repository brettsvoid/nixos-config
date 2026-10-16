# Launcher emoji picker

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

An emoji mode in the launcher. Its prefix, then a word, searches emoji by name and
keyword. Choosing one types it into the focused window and copies it. Recent emoji come
first, and skin tones are offered.

- ambxst has this as `ee`, with its own `assets/emojis.json`
  (`modules/widgets/dashboard/emoji/EmojiTab.qml`). Ideas only; the data here comes
  from nixpkgs. It builds on the launcher's modes, as `ClipboardMode` does.

## Proposed choices

1. **Prefix `:`**, as in Slack, Discord and GitHub (`:wave`). Alternative: `ee`
   (ambxst), in the style of `cc`. Setting `launcher.emojiPrefix`.
2. **Data from nixpkgs' `unicode-emoji` (17.0.0) and `cldr-annotations` (48.2)**, both
   checked. `emoji-test.txt` gives each emoji's name, group, Emoji version and skin-tone
   variants (3,944 fully-qualified). CLDR's `annotations/en.xml` and
   `annotationsDerived/en.xml` give keywords ("hello", "wave" for 👋). A Python script
   of ours makes one `emoji.json` at build time, without versions that Noto Color Emoji
   2.051 cannot draw (unchecked which). Alternative: a picker's list (rofimoji, smile).
3. **The shell finds the file through `QS_EMOJI_DATA`**, exported by `toggle-shell` and
   `qs-dev` as they export `QS_ICON_THEME`. Alternative: copy it into the shell's
   config in `shellConfig` (then `qs-dev` lacks it). The mode reads it when it first
   opens, not at start.
4. **Enter copies the emoji (wl-copy) and types it with wtype**, once the drawer has
   closed and the window has the keyboard again (ambxst waits 250 ms; measure it).
   wtype comes from ambxst's package set today; after issue 23 only `qs-test` has it,
   so add `pkgs.wtype` to the shell's packages. Setting `emoji.action`: `type` (types
   and copies) or `copy`. Alternative: copy and send Ctrl+V (ambxst), which fails in
   terminals, where paste is Ctrl+Shift+V.
5. **Setting `emoji.skinTone`**: `none` (yellow) or one of the five tones, used where
   an emoji has a variant. A tone word in the query shows that variant (`:wave dark`).
   Alternative: Tab lists the variants, through issue 47.
6. **Search by word starts**: each query word must start a word of the name or a
   keyword. `fuzzy.js` would match nearly anything over 3,944 names. Recent emoji rank
   higher among equal matches.
7. **Recent: the last 32 chosen**, in `Quickshell.statePath("emoji-recent.json")`,
   first when the query is empty. A "Forget recent emoji" button, like "Use so far".
8. **Rows, as in the other modes**, with the emoji (Noto Color Emoji, installed on both
   hosts by NixOS's graphical-desktop defaults) where the icon goes. A result gets an
   optional `glyph` for this. Alternative: a grid, which needs a view of its own.
- The settings go under an Emoji heading on the Launcher page. No process runs until
  an emoji is chosen, so nothing runs in game mode.

## Acceptance criteria

- [ ] `:wave` lists 👋 first. Enter types it into a text field and copies it.
- [ ] Typing works in Firefox, kitty and Cursor (on the desktop; unchecked so far).
- [ ] With `emoji.skinTone` at medium, 👋 comes out as 👋🏽. `:wave dark` offers 👋🏿.
- [ ] Recent emoji come first and survive a restart. The button forgets them.
- [ ] Emoji draw in colour, with no empty boxes. `emoji.action` at `copy` only copies.
- [ ] The apps placeholder, or issue 44's prefix list, names the prefix.

## Blocked by

- None
