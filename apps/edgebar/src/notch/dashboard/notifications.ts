import "./notifications.css";
import { animate } from "motion";
import { el } from "../../dom";
import { call, type NotificationEntry, type NotificationHistory } from "../../ipc";
import { lucide } from "../../icons";
import { current, onChange, set } from "../../settings";
import type { Widget } from "../view";
import { note, openPane, toggleButton } from "./quick-toggle";

const POLL_MS = 15_000;
const CASCADE_S = 0.08;

const BELL = lucide(
  '<path d="M10.268 21a2 2 0 0 0 3.464 0"/><path d="M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326"/>',
);
const BELL_OFF = lucide(
  '<path d="M10.268 21a2 2 0 0 0 3.464 0"/><path d="M17 17H4a1 1 0 0 1-.74-1.673C4.59 13.956 6 12.499 6 8a6 6 0 0 1 .258-1.742"/><path d="m2 2 20 20"/><path d="M8.668 3.01A6 6 0 0 1 18 8c0 2.687.77 4.653 1.707 6.05"/>',
);
const LOCK = lucide('<rect width="18" height="11" x="3" y="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>');
const BROOM = lucide(
  '<path d="m16 22-1-4"/><path d="M19 13.99a1 1 0 0 0 1-1V12a2 2 0 0 0-2-2h-3a1 1 0 0 1-1-1V4a2 2 0 0 0-4 0v5a1 1 0 0 1-1 1H6a2 2 0 0 0-2 2v.99a1 1 0 0 0 1 1"/><path d="M5 14h14l1.973 6.767A1 1 0 0 1 20 22H4a1 1 0 0 1-.973-1.233z"/><path d="m8 22 1-4"/>',
);
const X = lucide('<path d="M18 6 6 18"/><path d="m6 6 12 12"/>');
const CHEVRON = lucide('<path d="m6 9 6 6 6-6"/>');

type Column =
  | { kind: "off" }
  | { kind: "loading" }
  | { kind: "denied" }
  | { kind: "unavailable" }
  | { kind: "history"; items: NotificationEntry[] };

interface Group {
  app: string;
  icon: string;
  items: NotificationEntry[];
}

function groupByApp(items: NotificationEntry[]): Group[] {
  const groups = new Map<string, Group>();
  for (const item of items) {
    const group = groups.get(item.app) ?? { app: item.app, icon: item.icon, items: [] };
    group.items.push(item);
    groups.set(item.app, group);
  }
  return [...groups.values()];
}

function ago(iso: string, now: number): string {
  const s = Math.max(0, (now - Date.parse(iso)) / 1000);
  if (s < 60) return "now";
  if (s < 3600) return `${Math.floor(s / 60)}m`;
  if (s < 86400) return `${Math.floor(s / 3600)}h`;
  return `${Math.floor(s / 86400)}d`;
}

function message(icon: string, text: string, action?: { label: string; run: () => void }) {
  const box = el("div", "nf-message");
  box.innerHTML = `<span class="icon">${icon}</span>`;
  box.append(el("p", "", text));
  if (action) {
    const btn = el("button", "pill filled nf-action", action.label);
    btn.type = "button";
    btn.addEventListener("click", action.run);
    box.append(btn);
  }
  return box;
}

export const notifications: Widget = (root) => {
  root.innerHTML =
    '<div class="nf-head"><span class="nf-title">Notifications</span>' +
    `<button class="nf-clear" type="button" title="Clear all" aria-label="Clear all"><span class="icon">${BROOM}</span></button></div>` +
    '<div class="nf-body scroll-y"></div>';
  const head = root.querySelector<HTMLElement>(".nf-head")!;
  const clear = root.querySelector<HTMLButtonElement>(".nf-clear")!;
  const body = root.querySelector<HTMLElement>(".nf-body")!;
  const hint = note(root);
  const bell = toggleButton("focus", hint, { on: BELL_OFF, off: BELL });
  bell.classList.add("nf-bell");
  head.insertBefore(bell, clear);

  let column: Column = { kind: "off" };
  let visible = false;
  let poll = 0;
  let clearing = false;
  const expanded = new Set<string>();
  const dismissed = new Set<string>();
  let clearedBefore = 0;
  let drawn = "";

  const enabled = () => current().notifications.history;

  function columnOf(h: NotificationHistory): Column {
    switch (h.access) {
      case "granted": {
        const items = h.items.filter((i) => !dismissed.has(i.id) && Date.parse(i.time) > clearedBefore);
        for (const id of dismissed) if (!h.items.some((i) => i.id === id)) dismissed.delete(id);
        return { kind: "history", items };
      }
      case "denied":
        return { kind: "denied" };
      case "unavailable":
        return { kind: "unavailable" };
      case "off":
        return { kind: "off" };
    }
  }

  async function read() {
    if (!enabled()) return;
    const h = await call("notification_history").catch(() => null);
    if (!h || !visible || clearing || !enabled()) return;
    setColumn(columnOf(h));
  }

  function startPolling() {
    if (poll) return;
    void read();
    poll = window.setInterval(read, POLL_MS);
  }
  function stopPolling() {
    clearInterval(poll);
    poll = 0;
  }

  function sync() {
    if (!visible) return;
    if (enabled()) {
      if (column.kind === "off") setColumn({ kind: "loading" });
      startPolling();
    } else {
      stopPolling();
      setColumn({ kind: "off" });
    }
  }

  function setColumn(next: Column) {
    column = next;
    const items = next.kind === "history" ? next.items : [];
    clear.disabled = items.length === 0;
    const key = next.kind === "history" ? `history:${items.map((i) => i.id).join(",")}` : next.kind;
    if (key !== drawn) {
      drawn = key;
      body.replaceChildren(...build(next));
    }
    updateTimes();
  }

  function build(c: Column): HTMLElement[] {
    switch (c.kind) {
      case "loading":
        return [];
      case "off":
        return [
          message(
            BELL,
            "macOS notification history can show here. Reading it opens macOS's notification store, which needs Full Disk Access.",
            { label: "Turn on", run: () => void set("notifications.history", true).catch(() => {}) },
          ),
        ];
      case "denied":
        return [
          message(LOCK, "edgebar needs Full Disk Access to read macOS's notification history.", {
            label: "Open Full Disk Access",
            run: () => void openPane("fullDiskAccess"),
          }),
        ];
      case "unavailable":
        return [message(BELL_OFF, "macOS's notification history store wasn't found.")];
      case "history":
        return c.items.length ? groupByApp(c.items).map(groupEl) : [message(BELL_OFF, "No notifications")];
    }
  }

  function groupEl(g: Group): HTMLElement {
    const section = el("section", "nf-group");
    const many = g.items.length > 1;
    section.classList.toggle("many", many);
    section.classList.toggle("expanded", !many || expanded.has(g.app));
    const header = el("button", "nf-ghead");
    header.type = "button";
    header.disabled = !many;
    const icon = el("img", "nf-icon");
    icon.alt = "";
    if (g.icon) icon.src = g.icon;
    icon.hidden = !g.icon;
    header.append(icon, el("span", "nf-app", g.app || "Unknown app"), el("span", "nf-count", String(g.items.length)));
    if (many) header.insertAdjacentHTML("beforeend", `<span class="nf-chevron icon">${CHEVRON}</span>`);
    header.addEventListener("click", () => {
      const open = !section.classList.contains("expanded");
      section.classList.toggle("expanded", open);
      if (open) expanded.add(g.app);
      else expanded.delete(g.app);
    });
    section.append(header, ...g.items.map((item) => entryEl(item, section, g)));
    return section;
  }

  function entryEl(item: NotificationEntry, section: HTMLElement, g: Group): HTMLElement {
    const entry = el("article", "nf-entry");
    entry.dataset.time = item.time;
    const line = el("div", "nf-line");
    line.append(el("b", "nf-etitle", item.title || g.app), el("span", "nf-time"));
    entry.append(line);
    if (item.subtitle) entry.append(el("div", "nf-sub", item.subtitle));
    if (item.body) entry.append(el("div", "nf-text", item.body));
    const dismiss = el("button", "nf-dismiss");
    dismiss.type = "button";
    dismiss.title = "Dismiss";
    dismiss.innerHTML = `<span class="icon">${X}</span>`;
    dismiss.addEventListener("click", () => void dismissOne(item, g.items.length === 1 ? section : entry));
    entry.append(dismiss);
    return entry;
  }

  async function dismissOne(item: NotificationEntry, target: HTMLElement) {
    dismissed.add(item.id);
    call("notification_hide", { ids: [item.id] }).catch(() => {});
    await animate(target, { x: 48, opacity: 0 }, { duration: 0.18, ease: "easeIn" }).finished;
    await animate(target, { height: 0, marginTop: 0, paddingTop: 0, paddingBottom: 0 }, { duration: 0.14 })
      .finished;
    if (column.kind === "history") setColumn({ kind: "history", items: column.items.filter((i) => i.id !== item.id) });
  }

  async function clearAll() {
    if (column.kind !== "history" || !column.items.length || clearing) return;
    clearing = true;
    const groups = [...body.querySelectorAll<HTMLElement>(".nf-group")];
    await Promise.all(
      groups.map(
        (g, i) => animate(g, { x: 48, opacity: 0 }, { duration: 0.2, delay: i * CASCADE_S, ease: "easeIn" }).finished,
      ),
    );
    clearedBefore = Date.now();
    await call("notification_hide_all").catch(() => {});
    clearing = false;
    setColumn({ kind: "history", items: [] });
  }
  clear.addEventListener("click", () => void clearAll());

  function updateTimes() {
    const now = Date.now();
    for (const entry of body.querySelectorAll<HTMLElement>(".nf-entry")) {
      const t = entry.querySelector(".nf-time")!;
      const text = ago(entry.dataset.time!, now);
      if (t.textContent !== text) t.textContent = text;
    }
  }

  onChange(sync);
  setColumn(column);

  return {
    show() {
      visible = true;
      sync();
    },
    hide() {
      visible = false;
      stopPolling();
      hint.hide();
    },
  };
};
