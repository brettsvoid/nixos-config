import { el } from "../../dom";
import { lucide } from "../../icons";
import { call } from "../../ipc";
import { isOverridden, reset, set } from "../../settings";
import { button, field, segmented, whyLine, type Option, type Part } from "./rows";

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

const PLUS = lucide('<path d="M5 12h14"/><path d="M12 5v14"/>');
const TRASH = lucide(
  '<path d="M10 11v6"/><path d="M14 11v6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/><path d="M3 6h18"/><path d="M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>',
);

const keyOf = (ws: string) => `notch.workspaces.${ws}`;

function sorted(keys: string[], order: string[]): string[] {
  const rank = (n: string) => (n === "*" ? 2 : order.includes(n) ? 0 : 1);
  return [...keys].sort((a, b) => rank(a) - rank(b) || order.indexOf(a) - order.indexOf(b) || a.localeCompare(b));
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
  const why = whyLine();
  const note = el("span", "st-note");
  let rule: Rule = { source: "focusedWindow" };
  let all: Record<string, Rule> = {};

  async function write(next: Rule) {
    try {
      await set(keyOf(ws), next);
      why.show(null);
    } catch (e) {
      why.show(String(e));
    }
  }

  const name = field({ placeholder: "1" }, async (text) => {
    if (text === ws) return;
    const refuse = (reason: string) => {
      why.show(reason);
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
      why.show(String(e));
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
      why.show("The interval is a number of seconds, at least 1.");
      every.input.value = rule.everyMs ? String(rule.everyMs / 1000) : "";
      return;
    }
    void write({ ...rest, everyMs: Math.round(secs * 1000) });
  });
  every.el.classList.add("st-rule-every");
  every.input.title = "Seconds between runs while this workspace is focused; empty runs it on focus changes only";
  cmdLine.append(run.el, el("span", "st-note", "every"), every.el, el("span", "st-note", "s"));

  row.append(line, cmdLine, note, why.el);
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
      remove.hidden = !isOverridden(keyOf(ws));
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
  let names: string[] = [];

  function draw() {
    const shown = sorted(Object.keys(rules), names);
    for (const [ws, row] of rows) {
      if (!(ws in rules)) {
        row.el.remove();
        rows.delete(ws);
      }
    }
    shown.forEach((ws, i) => {
      let row = rows.get(ws);
      if (!row) {
        row = ruleRow(ws);
        rows.set(ws, row);
      }
      row.draw(rules[ws], rules);
      // Moved only when out of place: moving a row blurs a field typed in.
      if (list.children[i] !== row.el) list.insertBefore(row.el, list.children[i] ?? null);
    });
    empty.hidden = shown.length > 0;
    add.disabled = names.every((n) => n in rules);
  }

  add.addEventListener("click", () => {
    const free = names.find((n) => !(n in rules));
    if (free) void set(keyOf(free), { source: "focusedWindow" }).catch(() => {});
  });
  call("get_config")
    .then((cfg) => {
      names = [...cfg.workspaceNames, "*"];
      draw();
    })
    .catch(() => {});

  return {
    el: box,
    update(s) {
      rules = s.notch.workspaces;
      draw();
    },
  };
}
