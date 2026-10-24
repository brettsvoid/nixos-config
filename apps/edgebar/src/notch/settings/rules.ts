// The editor for `notch.workspaces`: what the collapsed notch says on each
// AeroSpace workspace (README.md, "The notch"; `Rule` in notch.rs). One row per
// rule, and every change writes that rule's whole override.
import { lucide } from "../../icons";
import { isSet, reset, set, type Settings } from "../../settings";
import { button, el, field, segmented, type Option, type Part } from "./rows";

// notch.rs's `Rule`, as the settings carry it. Rust deserialises the whole
// config before it accepts a change, so what arrives here has this shape.
type Rule =
  | { source: "focusedWindow" }
  | { source: "command"; run: string; everyMs?: number; glyph?: string }
  | { source: "none" };

const SOURCES: Option[] = [
  { value: "focusedWindow", label: "Window" },
  { value: "command", label: "Command" },
  { value: "none", label: "Media" },
];

const NOTE: Record<Rule["source"], string> = {
  focusedWindow: "The focused window's title, its app beneath.",
  command: "The command's first line, its second beneath. Runs on every focus change, and on its interval.",
  none: "What's playing, as on a workspace with no rule.",
};

// The keyboard row's workspaces (WS_ORDER in lib.rs), tried in turn for a new
// rule, then the fallback for every other workspace.
const NAMES = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "*"];

const PLUS = lucide('<path d="M5 12h14"/><path d="M12 5v14"/>');
const TRASH = lucide(
  '<path d="M10 11v6"/><path d="M14 11v6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/><path d="M3 6h18"/><path d="M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>',
);

const keyOf = (ws: string) => `notch.workspaces.${ws}`;
const rulesOf = (s: Settings) => s.notch.workspaces as Record<string, Rule>;

// Keyboard order, names AeroSpace made up after them, the fallback last.
function sorted(names: string[]): string[] {
  const rank = (n: string) => (n === "*" ? 2 : NAMES.includes(n) ? 0 : 1);
  return [...names].sort((a, b) => rank(a) - rank(b) || NAMES.indexOf(a) - NAMES.indexOf(b) || a.localeCompare(b));
}

function withSource(rule: Rule, source: string): Rule {
  if (source === "command") {
    const prev = rule.source === "command" ? rule : { run: "" };
    return { ...prev, source: "command" };
  }
  return { source: source === "none" ? "none" : "focusedWindow" };
}

interface RuleRow {
  el: HTMLElement;
  draw(rule: Rule, rules: Record<string, Rule>): void;
}

function ruleRow(ws: string): RuleRow {
  const row = el("div", "st-rule");
  const line = el("div", "st-rule-line");
  const why = el("span", "st-why");
  why.hidden = true;
  const note = el("span", "st-note");
  let rule: Rule = { source: "focusedWindow" };
  let all: Record<string, Rule> = {};

  const fail = (reason: string | null) => {
    why.hidden = reason === null;
    why.textContent = reason ?? "";
  };
  async function write(next: Rule) {
    try {
      await set(keyOf(ws), next);
      fail(null);
    } catch (e) {
      fail(String(e));
    }
  }

  // Renaming writes the rule under its new name, then drops the old one.
  const name = field({ placeholder: "1" }, async (text) => {
    if (text === ws) return;
    const refuse = (reason: string) => {
      fail(reason);
      name.input.value = ws;
    };
    if (!text) return refuse("A rule needs a workspace name, or * for every other workspace.");
    if (text.includes(".")) return refuse("A workspace name can't hold a dot.");
    if (text in all) return refuse(`Workspace ${text} already has a rule.`);
    try {
      await set(keyOf(text), rule);
      await reset(keyOf(ws));
    } catch (e) {
      refuse(String(e));
    }
  });
  name.el.classList.add("st-rule-name");
  name.input.title = "AeroSpace workspace, or * for the rest";

  const source = segmented(SOURCES, (value) => {
    if (value !== rule.source) void write(withSource(rule, value));
  });
  const remove = button("st-icon-btn", `<span class="icon">${TRASH}</span>`, "Remove this rule");
  remove.addEventListener("click", async () => {
    try {
      await reset(keyOf(ws));
    } catch (e) {
      fail(String(e));
    }
  });
  line.append(name.el, source.el, remove);

  const cmdLine = el("div", "st-rule-line");
  const run = field({ mono: true, placeholder: "a shell command" }, (text) => {
    if (rule.source === "command") void write({ ...rule, run: text });
  });
  run.el.classList.add("st-rule-run");
  const every = field({ placeholder: "–" }, (text) => {
    if (rule.source !== "command") return;
    const { everyMs: _, ...rest } = rule;
    if (text === "") return void write(rest);
    const secs = Number(text);
    if (!Number.isFinite(secs) || secs < 1) {
      fail("The interval is a number of seconds, at least 1.");
      every.input.value = rule.everyMs ? String(rule.everyMs / 1000) : "";
      return;
    }
    void write({ ...rest, everyMs: Math.round(secs * 1000) });
  });
  every.el.classList.add("st-rule-every");
  every.input.title = "Seconds between runs while this workspace is focused; empty runs it on focus changes only";
  cmdLine.append(run.el, el("span", "st-note", "every"), every.el, el("span", "st-note", "s"));

  row.append(line, cmdLine, note, why);
  return {
    el: row,
    draw(next, rules) {
      rule = next;
      all = rules;
      name.show(ws);
      source.mark(rule.source);
      note.textContent = NOTE[rule.source];
      cmdLine.hidden = rule.source !== "command";
      if (rule.source === "command") {
        run.show(rule.run);
        every.show(rule.everyMs ? String(rule.everyMs / 1000) : "");
      }
      // A rule the Nix config sets can be changed here but not removed.
      remove.hidden = !isSet(keyOf(ws));
    },
  };
}

export function rulesPart(): Part {
  const box = el("div", "st-rules");
  const list = el("div", "st-rule-list");
  const empty = el("p", "st-note st-rules-empty", "No rules: every workspace shows what's playing.");
  const add = button("st-btn", `<span class="icon">${PLUS}</span><span>Add a rule</span>`);
  box.append(list, empty, add);
  const rows = new Map<string, RuleRow>();
  let rules: Record<string, Rule> = {};

  add.addEventListener("click", () => {
    const free = NAMES.find((n) => !(n in rules));
    if (free) void set(keyOf(free), { source: "focusedWindow" }).catch(() => {});
  });

  return {
    el: box,
    update(s) {
      rules = rulesOf(s);
      const names = sorted(Object.keys(rules));
      for (const [ws, row] of rows) {
        if (!(ws in rules)) {
          row.el.remove();
          rows.delete(ws);
        }
      }
      names.forEach((ws, i) => {
        let row = rows.get(ws);
        if (!row) {
          row = ruleRow(ws);
          rows.set(ws, row);
        }
        row.draw(rules[ws], rules);
        // Moved only when out of place: moving a row blurs a field typed in.
        if (list.children[i] !== row.el) list.insertBefore(row.el, list.children[i] ?? null);
      });
      empty.hidden = names.length > 0;
      add.disabled = NAMES.every((n) => n in rules);
    },
  };
}
