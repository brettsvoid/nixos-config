import { el } from "../../dom";
import { call, type SetupItem } from "../../ipc";
import { lucide } from "../../icons";
import { button, whyLine, type Part } from "./rows";

const ICON: Record<SetupItem["state"], string> = {
  ready: lucide('<circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/>'),
  missing: lucide('<circle cx="12" cy="12" r="10"/><path d="M12 8v4"/><path d="M12 16h.01"/>'),
  unknown: lucide('<circle cx="12" cy="12" r="10"/><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/><path d="M12 17h.01"/>'),
};
const REFRESH = lucide(
  '<path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/><path d="M8 16H3v5"/>',
);

const STATE_NAME: Record<SetupItem["state"], string> = {
  ready: "Ready",
  missing: "Missing",
  unknown: "Unknown",
};

export function alertFor(items: SetupItem[]): string | null {
  const missing = items.filter((i) => i.state === "missing").length;
  if (missing === 0) return null;
  return missing === 1 ? "1 thing to set up" : `${missing} things to set up`;
}

interface CheckRow {
  el: HTMLElement;
  draw(item: SetupItem): void;
  why(reason: string | null): void;
}

function checkRow(onAction: () => void): CheckRow {
  const row = el("div", "st-check");
  const icon = el("span", "st-check-icon icon");
  const text = el("div", "st-text");
  const name = el("span", "st-name");
  const detail = el("span", "st-note st-selectable");
  const why = whyLine();
  text.append(name, detail, why.el);
  const action = button("pill st-btn", "");
  action.addEventListener("click", onAction);
  row.append(icon, text, action);
  return {
    el: row,
    draw(item) {
      row.dataset.state = item.state;
      icon.innerHTML = ICON[item.state];
      icon.title = STATE_NAME[item.state];
      name.textContent = item.label;
      detail.textContent = item.detail;
      action.hidden = item.action === null;
      action.textContent = item.action ?? "";
      action.classList.toggle("filled", item.state === "missing");
    },
    why: why.show,
  };
}

export function setupPart(onItems: (items: SetupItem[]) => void): Part {
  const box = el("section", "st-group st-setup");
  const head = el("div", "st-setup-head");
  head.append(el("p", "st-note", "What edgebar needs from this Mac to work fully. Nothing here asks for anything until you press its button."));
  const again = button("st-icon-btn", `<span class="icon">${REFRESH}</span>`, "Check again");
  head.append(again);
  const card = el("div", "st-card");
  box.append(head, card);
  const rows = new Map<string, CheckRow>();

  function draw(items: SetupItem[]) {
    for (const item of items) {
      let row = rows.get(item.id);
      if (!row) {
        const id = item.id;
        row = checkRow(() => void runAction(id));
        rows.set(item.id, row);
        card.append(row.el);
      }
      row.draw(item);
    }
    onItems(items);
  }

  async function refresh() {
    again.classList.add("busy");
    const items = await call("setup_status").catch(() => null);
    again.classList.remove("busy");
    if (items) draw(items);
  }

  async function runAction(id: string) {
    const row = rows.get(id)!;
    row.el.classList.add("busy");
    try {
      draw(await call("setup_run", { id }));
      row.why(null);
    } catch (e) {
      row.why(String(e));
    } finally {
      row.el.classList.remove("busy");
    }
  }

  again.addEventListener("click", () => void refresh());
  return { el: box, show: () => void refresh() };
}
