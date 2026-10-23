# UI: the Assistant view

Read `briefs/_ui-common.md` first; its rules apply. Unit name: `ui-assistant`. You add
`src/notch/assistant.ts` (and CSS) and turn the Assistant rail button into a real view in
`src/notch/views.ts`. Backend merged: `assistant_send`, `assistant_cancel`,
`assistant_reset`, the `assistant` event (`src-tauri/src/assistant.rs`, which runs the
Claude Code CLI; no API key involved).

- Layout (ambxst's AssistantTab, trimmed): the conversation scrolls above a full-round
  input pill pinned to the bottom that grows to about four lines. Enter sends, Shift+Enter
  is a newline, Escape cancels a running reply. A send button appears once there's text;
  while a reply streams it becomes a stop button.
- Empty state: a short greeting in the middle ("Ask Claude anything") with the model name
  under it; clicking the model name cycles haiku → sonnet → opus through the
  `assistant.model` setting.
- Messages: yours right-aligned on `--primary` with `--on-primary` text; Claude's left on
  `--surface-container`. Text streams in as deltas arrive, with a three-dot typing
  indicator before the first one. Render a safe subset of Markdown yourself (paragraphs,
  `inline code`, fenced code blocks in the mono font on `--surface-container-high`, bold,
  lists, links opened in the browser); escape everything else, never inject HTML from the
  reply. Each code block gets a copy button. An `error` chunk shows inline in an error
  style with a retry.
- A "New chat" button in the view's header calls `assistant_reset` and clears the view.
  The conversation survives closing and reopening the notch; it's lost on relaunch.
- Typing: the bar window is not focusable. Make typing work while this view shows and
  the notch is open, and give focus back when it closes, without letting the closed bar
  steal focus (check `focusable` in tauri.conf.json and how the Wallpapers search did it:
  share one helper if it exists). Prove a real keystroke reaches the field, not only
  `el.value = …` through eval: say how you proved it.
- Size: the view can be taller than the others if it needs to be; keep the notch
  centred.

Prove one real round-trip (one short prompt through the real CLI, a few tokens of
Brett's plan), plus literal-data renders for streaming, code block, error and empty states.
