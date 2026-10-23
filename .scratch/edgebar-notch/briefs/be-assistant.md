# Backend: the Assistant tab's chat

Read `briefs/_backend-common.md` first; its rules apply. Unit name: `assistant`.

The Assistant tab chats with Claude through the Claude Code CLI that is already installed
and logged in (`/Users/brett/.local/bin/claude`, version 2.1.309), so it needs no API key.
Measured: `claude -p "…" --output-format stream-json --verbose --include-partial-messages
--no-session-persistence --tools "" --setting-sources "" --strict-mcp-config --model
haiku` streams its first text in about 0.7 s and finishes a short answer in 2.3 s.

Build `src-tauri/src/assistant.rs`:
- `assistant_send { prompt }` returns a new turn id at once and streams the reply as
  `assistant` events (`AssistantChunk` per ipc.ts): `delta` with each new piece of text,
  then `done`, or `error` with a readable message (CLI missing, not logged in, non-zero
  exit with its stderr). One turn at a time: a send while one runs cancels the old turn.
- Conversation memory: the first turn of a conversation uses `--session-id <new uuid>`,
  later ones `--resume <that uuid>` (so session persistence stays on, unlike the
  measurement above). `assistant_reset` starts a new conversation; `assistant_cancel`
  kills the running turn's process.
- Run the CLI in its own working directory, `~/.cache/edgebar/assistant/`, so its
  sessions don't mix with Brett's projects, without tools, MCP servers or settings
  sources (as above), with `--model` from a new config key `assistant.model` (default
  "haiku" in config.default.json) and an appended system prompt saying it answers in a
  small panel in a macOS menu bar and should be brief. Find the binary from a config key
  `assistant.command` (default "claude"), resolved on PATH, then `~/.local/bin`.
- Parse the stream-json lines with a pure function, unit-tested on literal lines you
  capture from one real run (keep the captured lines in the test, trimmed of anything
  personal). Text deltas come from the partial-message events; the final `result` line
  ends the turn.
- One live ignored test may run one real two-turn conversation (for example "Remember the
  word teapot." then "What word did I ask you to remember?") and assert the second reply
  contains it. That costs a few tokens of Brett's plan; run it once or twice, not in a loop.
