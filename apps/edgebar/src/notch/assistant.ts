import "./assistant.css";
import { call, on, type AssistantChunk } from "../ipc";
import { lucide } from "../icons";
import { keyboardField, releaseKeyboard, takeKeyboard } from "../keyboard";
import { current, onChange, set as setSetting } from "../settings";
import { renderMarkdown } from "./markdown";
import type { NotchView } from "./view";

// The empty state's model name steps through these `--model` aliases.
const MODELS: readonly string[] = ["haiku", "sonnet", "opus"];
const COPIED_MS = 1500;
// Within this many px of the bottom, the log keeps a streaming reply in view.
const FOLLOW_PX = 24;

const ICON = {
  sparkles: lucide(
    '<path d="m12 3-1.912 5.813a2 2 0 0 1-1.275 1.275L3 12l5.813 1.912a2 2 0 0 1 1.275 1.275L12 21l1.912-5.813a2 2 0 0 1 1.275-1.275L21 12l-5.813-1.912a2 2 0 0 1-1.275-1.275Z"/><path d="M5 3v4"/><path d="M19 17v4"/><path d="M3 5h4"/><path d="M17 19h4"/>',
  ),
  newChat: lucide(
    '<path d="M22 17a2 2 0 0 1-2 2H6.828a2 2 0 0 0-1.414.586l-2.202 2.202A.71.71 0 0 1 2 21.286V5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2z"/><path d="M12 8v6"/><path d="M9 11h6"/>',
  ),
  send: lucide('<path d="m5 12 7-7 7 7"/><path d="M12 19V5"/>'),
  stop: lucide('<rect width="12" height="12" x="6" y="6" rx="2" fill="currentColor"/>'),
  alert: lucide(
    '<circle cx="12" cy="12" r="10"/><line x1="12" x2="12" y1="8" y2="12"/><line x1="12" x2="12.01" y1="16" y2="16"/>',
  ),
  retry: lucide('<path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/>'),
} as const;

const TEMPLATE =
  '<div class="view-head"><span class="view-title">Assistant</span>' +
  `<button class="as-new" type="button" disabled><span class="icon">${ICON.newChat}</span><span>New chat</span></button></div>` +
  `<div class="as-empty"><span class="as-empty-icon icon">${ICON.sparkles}</span>` +
  '<span class="as-greeting">Ask Claude anything</span>' +
  '<button class="as-model" type="button"></button></div>' +
  '<div class="as-log" hidden></div>' +
  '<div class="as-input">' +
  '<textarea class="as-field" rows="1" placeholder="Message Claude…" spellcheck="false" aria-label="Message Claude"></textarea>' +
  '<button class="as-send" type="button" hidden></button></div>';

type ReplyState =
  | { kind: "running"; stopping: boolean }
  | { kind: "done"; stopped: boolean }
  | { kind: "error"; message: string };

interface Reply {
  prompt: string; // what it answers, so a failed one can be sent again
  text: string;
  state: ReplyState;
  el: HTMLElement;
}

// The conversation's one live turn. A turn's first chunks can land before
// assistant_send answers with its id, so they wait in `early` until then.
type Phase =
  | { kind: "idle" }
  | { kind: "sending"; reply: Reply; early: AssistantChunk[] }
  | { kind: "live"; turn: string; reply: Reply };

const modelName = (id: string) => (MODELS.includes(id) ? id[0].toUpperCase() + id.slice(1) : id);

function bubble(kind: "as-user" | "as-claude", text = ""): HTMLElement {
  const el = document.createElement("div");
  el.className = `as-msg ${kind}`;
  el.textContent = text;
  return el;
}

function span(className: string, text = ""): HTMLElement {
  const el = document.createElement("span");
  el.className = className;
  el.textContent = text;
  return el;
}

function typingDots(): HTMLElement {
  const dots = span("as-typing");
  dots.setAttribute("aria-label", "Claude is replying");
  dots.append(document.createElement("i"), document.createElement("i"), document.createElement("i"));
  return dots;
}

// ambxst's AssistantTab, trimmed: the conversation over an input pill.
export const assistantView: NotchView = {
  id: "assistant",
  title: "Assistant",
  icon: ICON.sparkles,
  size: { w: 520, h: 400 },
  mount(root) {
    root.innerHTML = TEMPLATE;
    const log = root.querySelector<HTMLElement>(".as-log")!;
    const empty = root.querySelector<HTMLElement>(".as-empty")!;
    const field = root.querySelector<HTMLTextAreaElement>(".as-field")!;
    const sendBtn = root.querySelector<HTMLButtonElement>(".as-send")!;
    const newBtn = root.querySelector<HTMLButtonElement>(".as-new")!;
    const modelBtn = root.querySelector<HTMLButtonElement>(".as-model")!;

    let phase: Phase = { kind: "idle" };
    const dirty = new Set<Reply>();
    let frame = 0;

    // ---- drawing a reply ----
    function errorBlock(reply: Reply, message: string): Node[] {
      const line = span("as-error-line");
      line.innerHTML = `<span class="icon">${ICON.alert}</span>`;
      line.append(span("as-error-text", message));
      const retry = document.createElement("button");
      retry.type = "button";
      retry.className = "as-retry";
      retry.innerHTML = `<span class="icon">${ICON.retry}</span><span>Retry</span>`;
      retry.addEventListener("click", (e) => {
        e.stopPropagation();
        if (phase.kind === "idle") startTurn(reply);
      });
      return [line, retry];
    }

    function paintReply(reply: Reply) {
      const { text, state } = reply;
      const parts: Node[] = [];
      if (text) parts.push(renderMarkdown(text));
      if (state.kind === "running" && !text) parts.push(typingDots());
      if (state.kind === "done" && (state.stopped || !text)) {
        parts.push(span("as-note", state.stopped ? "Stopped" : "No reply"));
      }
      if (state.kind === "error") parts.push(...errorBlock(reply, state.message));
      reply.el.classList.toggle("as-error", state.kind === "error");
      reply.el.replaceChildren(...parts);
    }

    // Deltas arrive faster than frames, so a reply redraws at most once a frame.
    function flush() {
      frame = 0;
      const follow = log.scrollHeight - log.scrollTop - log.clientHeight < FOLLOW_PX;
      for (const reply of dirty) paintReply(reply);
      dirty.clear();
      if (follow) log.scrollTop = log.scrollHeight;
    }
    function paint(reply: Reply) {
      dirty.add(reply);
      if (!frame) frame = requestAnimationFrame(flush);
    }

    // ---- the input pill ----
    function fit() {
      field.style.height = "auto";
      field.style.height = `${field.scrollHeight}px`;
    }

    // The send button shows once there's text; while a reply runs it stops it.
    function showControls() {
      const mode = phase.kind !== "idle" ? "stop" : field.value.trim() ? "send" : null;
      sendBtn.hidden = mode === null;
      if (mode && sendBtn.dataset.mode !== mode) {
        sendBtn.dataset.mode = mode;
        sendBtn.innerHTML = ICON[mode];
        sendBtn.title = mode === "stop" ? "Stop (Esc)" : "Send (Return)";
      }
      const talking = log.hasChildNodes();
      log.hidden = !talking;
      empty.hidden = talking;
      newBtn.disabled = !talking;
    }

    // ---- turns ----
    function settle(reply: Reply, state: ReplyState) {
      reply.state = state;
      phase = { kind: "idle" };
      paint(reply);
      showControls();
    }

    function receive(chunk: AssistantChunk) {
      if (phase.kind === "sending") {
        phase.early.push(chunk);
        return;
      }
      if (phase.kind !== "live" || chunk.turn !== phase.turn) return; // a turn this view has left
      const reply = phase.reply;
      switch (chunk.kind) {
        case "delta":
          reply.text += chunk.text;
          paint(reply);
          return;
        case "done":
          settle(reply, {
            kind: "done",
            stopped: reply.state.kind === "running" && reply.state.stopping,
          });
          return;
        case "error":
          settle(reply, { kind: "error", message: chunk.text });
          return;
        default: {
          const unknown: never = chunk.kind;
          return unknown;
        }
      }
    }

    function startTurn(reply: Reply) {
      reply.text = "";
      reply.state = { kind: "running", stopping: false };
      phase = { kind: "sending", reply, early: [] };
      paint(reply);
      showControls();
      call("assistant_send", { prompt: reply.prompt }).then(
        (turn) => {
          if (phase.kind !== "sending" || phase.reply !== reply) {
            // A new chat began before Rust registered this turn, so the reset
            // may have missed it. Nothing else is running, so reset again.
            if (phase.kind === "idle") call("assistant_reset").catch(() => {});
            return;
          }
          const { early } = phase;
          phase = { kind: "live", turn, reply };
          if (reply.state.kind === "running" && reply.state.stopping) {
            call("assistant_cancel").catch(() => {});
          }
          for (const chunk of early) if (chunk.turn === turn) receive(chunk);
        },
        (err) => {
          if (phase.kind === "sending" && phase.reply === reply) {
            settle(reply, { kind: "error", message: String(err) });
          }
        },
      );
    }

    function send() {
      const prompt = field.value.trim();
      if (!prompt || phase.kind !== "idle") return;
      field.value = "";
      fit();
      // Only the last reply can be retried: the CLI's session runs in order.
      for (const old of log.querySelectorAll(".as-retry")) old.remove();
      const reply: Reply = {
        prompt,
        text: "",
        state: { kind: "running", stopping: false },
        el: bubble("as-claude"),
      };
      log.append(bubble("as-user", prompt), reply.el);
      startTurn(reply);
      log.scrollTop = log.scrollHeight;
    }

    // A cancelled turn still ends with `done`, which settles the reply.
    function stop() {
      if (phase.kind === "idle") return;
      const { reply } = phase;
      if (reply.state.kind === "running") reply.state = { kind: "running", stopping: true };
      if (phase.kind === "live") call("assistant_cancel").catch(() => {});
    }

    on("assistant", receive);

    keyboardField(root.querySelector<HTMLElement>(".as-input")!);
    field.addEventListener("input", () => {
      fit();
      showControls();
    });
    field.addEventListener("keydown", (e) => {
      if (e.isComposing) return;
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault();
        send();
      } else if (e.key === "Escape" && phase.kind !== "idle") {
        e.preventDefault();
        stop();
      }
    });
    sendBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      if (phase.kind === "idle") send();
      else stop();
      field.focus();
    });

    newBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      phase = { kind: "idle" };
      dirty.clear();
      log.replaceChildren();
      call("assistant_reset").catch(() => {});
      showControls();
      field.focus();
    });

    // ---- links and code blocks in replies (markdown.ts draws them) ----
    log.addEventListener("click", (e) => {
      const target = e.target as Element;
      const copy = target.closest<HTMLButtonElement>(".md-copy");
      const anchor = target.closest<HTMLElement>(".md-link");
      if (!copy && !anchor) return;
      e.stopPropagation();
      if (anchor) {
        call("assistant_open_link", { url: anchor.dataset.href! }).catch(() => {});
        return;
      }
      const code = copy!.closest(".md-code")?.querySelector("pre")?.textContent ?? "";
      navigator.clipboard.writeText(code).then(
        () => {
          copy!.classList.add("copied");
          setTimeout(() => copy!.classList.remove("copied"), COPIED_MS);
        },
        () => {},
      );
    });

    // ---- the model, cycled from the empty state ----
    function showModel() {
      const id = current().assistant.model;
      modelBtn.textContent = modelName(id);
      modelBtn.title = `Replies come from ${id}. Click for the next model.`;
    }
    modelBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      const next = MODELS[(MODELS.indexOf(current().assistant.model) + 1) % MODELS.length];
      setSetting("assistant.model", next).catch(() => {});
    });
    onChange(showModel);
    showModel();
    showControls();

    return {
      show() {
        root.classList.remove("asleep");
        // The tab was clicked to type here, so it takes the keyboard at once;
        // main.ts gives it back when the notch closes.
        takeKeyboard();
        field.focus();
        log.scrollTop = log.scrollHeight;
      },
      hide() {
        root.classList.add("asleep");
        releaseKeyboard();
      },
    };
  },
};
