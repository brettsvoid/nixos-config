# AI assistant chat with a shell tool that asks before it runs

Status: ready-for-human
Type: HITL (needs an API key from you, added to the private nix-secrets repo)

## Parent

.scratch/custom-shell/PRD.md

## What to build

A chat with an AI model in a drawer. The model can propose a shell command; the shell
shows it and runs it only after you press Run. ambxst has one (`modules/services/Ai.qml`,
`modules/widgets/dashboard/assistant/`: providers through `curl`, keys from environment
variables put on curl's command line, Approve and Reject); ideas only.

No provider or key is set up; Ollama is not installed. Secrets use agenix
(`modules/flake/agenix.nix`): `.age` files in the private `nix-secrets` repo, decrypted at
activation with the host's SSH key, on both NixOS hosts. Native code is Rust (PRD), and
Anthropic has no official Rust SDK, so the helper calls the HTTP API directly.

## Proposed choices

1. **Provider: Anthropic's API (Claude),** billed per token, key from the Anthropic
   Console. Default model `claude-opus-5-5` ($4 in, $20 out per million tokens);
   `claude-sonnet-5-5` ($2/$10) and `claude-haiku-5-5` ($0.10/$0.50 for prompts up to
   100K tokens) are cheaper and faster. Alternatives: a local model through llama.cpp or Ollama (nothing leaves the
   machine; it holds much of the 3080 Ti's 12 GB and must unload in game mode; how well
   it uses the tool is unchecked); an OpenAI-compatible endpoint such as OpenRouter.
   Reason: tool use and streaming in one API, from a provider you already use.
2. **The key: an agenix secret `assistant-api-key`** (`owner = "brett"`, `mode = "0400"`,
   at `/run/agenix/assistant-api-key`), named for its use, not the provider: file names
   in the public repo are public (`docs/SECRETS.md`). Only the helper reads it, and
   sends it only as the `x-api-key` header: never in QML, a command line, a log or the
   settings. Alternative: a file you write by hand, mode 600.
3. **`shell-assistant`, a Rust helper run per request:** it takes the conversation as
   JSON on stdin, streams `POST /v1/messages`, and prints JSON lines (text, a command
   request, usage, done, error). The shell keeps the conversation. Requests use adaptive
   thinking (Opus 5.5 cannot turn it off) and the refusal fallback (`fallbacks: "default"`
   with the `server-side-fallback-2026-07-01` beta header).
4. **One custom tool, `run_command { command, reason }`** (`strict: true`). Each command
   runs in a new `bash -c` in `~`, as you, with a timeout; stdout, stderr (cut to 10,000
   characters) and the exit code go back. Alternative: Anthropic's `bash_20250124` tool,
   which expects one shell kept open between commands.
5. **Asking first:** a card shows the reason and the command (editable), with Run and
   Don't run; what runs is what it shows. Enter in the chat never runs a command, and
   there is no "always allow": a command can do anything you can, and output it reads
   (a web page) can steer the next proposal.
6. **What leaves the machine** (said in the drawer): what you type, the whole
   conversation again with each request, each proposed command and the output of each
   one you run, and a short fixed system prompt (a NixOS desktop, bash as the user). No
   screen, clipboard, files or window list unless a command you run prints them. How
   long the provider keeps it is not checked here.
7. **Where:** its own drawer from the bar's edge on **Super+A** (free in the repo's binds
   today), and a launcher action "Assistant". Alternative: a dashboard tab (ambxst).
   Reason: a chat needs height and keeps focus in its text field. The drawer needs a
   frame shape: all 8 are in use, so issue 67's change comes first.
8. **History in memory only;** New chat clears it. Alternative: the last 20 chats in the
   state folder. The drawer shows each chat's token count.
9. **Settings** (a new **Assistant** page): `assistant.model` (`"claude-opus-5-5"`, any
   string), `assistant.keyFile` (`"/run/agenix/assistant-api-key"`),
   `assistant.commandTimeout` (30 s, 5–300, step 5).
10. **Cost:** no package beyond the helper. Nothing runs at rest: one helper per request
    and one `bash` per command you run. Game mode closes the drawer.

## Acceptance criteria

- [ ] You: create a key, `agenix -e assistant-api-key.age` in `nix-secrets` with the
      hosts in `secrets.nix`, push, then `nix flake update secrets` here.
- [ ] A question gets a streamed answer. "How much disk is free?" proposes a command;
      Run feeds its output to the answer; Don't run and edits are reported to the model.
- [ ] A command past the timeout is stopped; no key, a wrong key and no network each
      show a plain error.
- [ ] The key is in no command line (`ps`), log or shell file.
- [ ] Nothing runs while the drawer is closed; it costs nothing in game mode.

## Blocked by

- None
