import { el } from "../../dom";
import { lucide } from "../../icons";
import { keyboardField } from "../../keyboard";
import { current, isOverridden, reset, set, type Settings, type SettingValue } from "../../settings";

const UNDO = lucide('<path d="M9 14 4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 5.5 5.5a5.5 5.5 0 0 1-5.5 5.5H11"/>');

export interface Part {
  el: HTMLElement;
  update?(s: Settings): void;
  show?(): void;
  hide?(): void;
}

type KeysTo<T, V, P extends string = ""> = {
  [K in keyof T & string]: T[K] extends V
    ? `${P}${K}`
    : T[K] extends Record<string, unknown>
      ? KeysTo<T[K], V, `${P}${K}.`>
      : never;
}[keyof T & string];
type KeyOf<V> = KeysTo<Settings, V>;

export function valueAt<V>(s: Settings, key: KeyOf<V>): V {
  let node: unknown = s;
  for (const part of key.split(".")) node = (node as Record<string, unknown>)[part];
  return node as V;
}

export function button(className: string, html: string, title = ""): HTMLButtonElement {
  const b = el("button", className);
  b.type = "button";
  b.innerHTML = html;
  if (title) b.title = title;
  return b;
}

export function whyLine(): { el: HTMLElement; show(reason: string | null): void } {
  const line = el("span", "st-why");
  line.hidden = true;
  return {
    el: line,
    show(reason) {
      line.hidden = reason === null;
      line.textContent = reason ?? "";
    },
  };
}

export interface Frame {
  el: HTMLElement;
  why(reason: string | null): void;
  commit(key: string, value: SettingValue | null): Promise<void>;
  sync(): void;
}

export function frame(label: string, note: string, control: HTMLElement, key: string | null): Frame {
  const row = el("div", "st-row");
  const text = el("div", "st-text");
  text.append(el("span", "st-name", label));
  if (note) text.append(el("span", "st-note", note));
  const why = whyLine();
  text.append(why.el);
  const undo = button("st-reset", UNDO, "Back to the default");
  row.append(text, control, undo);

  const commit = async (k: string, value: SettingValue | null) => {
    try {
      await (value === null ? reset(k) : set(k, value));
      why.show(null);
    } catch (e) {
      why.show(String(e));
    }
  };
  undo.addEventListener("click", () => {
    if (key) void commit(key, null);
  });
  return {
    el: row,
    why: why.show,
    commit,
    sync: () => {
      undo.classList.toggle("shown", key !== null && isOverridden(key));
    },
  };
}

export function switchRow(key: KeyOf<boolean>, label: string, note = ""): Part {
  const sw = button("st-switch", '<span class="st-knob"></span>');
  sw.setAttribute("role", "switch");
  const f = frame(label, note, sw, key);
  sw.addEventListener("click", () => void f.commit(key, !valueAt<boolean>(current(), key)));
  return {
    el: f.el,
    update(s) {
      const on = valueAt<boolean>(s, key);
      sw.classList.toggle("on", on);
      sw.setAttribute("aria-checked", String(on));
      f.sync();
    },
  };
}

export interface Option {
  value: string;
  label: string;
}

export function segmented(options: Option[], pick: (value: string) => void) {
  const box = el("div", "st-seg");
  box.setAttribute("role", "group");
  const pills = options.map((o) => {
    const b = button("st-pill", "");
    b.textContent = o.label;
    b.dataset.value = o.value;
    b.addEventListener("click", () => pick(o.value));
    box.append(b);
    return b;
  });
  return {
    el: box,
    mark(value: string | null) {
      for (const b of pills) {
        const on = b.dataset.value === value;
        b.classList.toggle("active", on);
        b.setAttribute("aria-pressed", String(on));
      }
    },
  };
}

export function choiceRow(key: KeyOf<string>, label: string, options: Option[], note = ""): Part {
  let f: Frame;
  const seg = segmented(options, (value) => void f.commit(key, value));
  f = frame(label, note, seg.el, key);
  return {
    el: f.el,
    update(s) {
      seg.mark(valueAt<string>(s, key));
      f.sync();
    },
  };
}

interface Range {
  min: number;
  max: number;
  step: number;
  format: (value: number) => string;
}

export function sliderRow(key: KeyOf<number>, label: string, range: Range, note = ""): Part {
  const box = el("div", "st-slider");
  const input = el("input", "s-range");
  input.type = "range";
  input.min = String(range.min);
  input.max = String(range.max);
  input.step = String(range.step);
  const shown = el("span", "st-value");
  box.append(input, shown);
  const f = frame(label, note, box, key);
  const paint = () => {
    const v = Number(input.value);
    input.style.setProperty("--fill", `${((v - range.min) / (range.max - range.min)) * 100}%`);
    shown.textContent = range.format(v);
  };
  let dragging = false;
  input.addEventListener("pointerdown", () => (dragging = true));
  input.addEventListener("input", paint);
  input.addEventListener("change", () => {
    dragging = false;
    void f.commit(key, Number(input.value));
  });
  return {
    el: f.el,
    update(s) {
      if (!dragging) {
        input.value = String(valueAt<number>(s, key));
        paint();
      }
      f.sync();
    },
  };
}

interface Field {
  el: HTMLElement;
  input: HTMLInputElement;
  show(value: string): void;
}

export function field(opts: { placeholder?: string; mono?: boolean }, commit: (text: string) => void): Field {
  const box = el("label", "st-field");
  box.classList.toggle("mono", !!opts.mono);
  const input = el("input", "st-input");
  input.type = "text";
  input.spellcheck = false;
  input.autocomplete = "off";
  input.placeholder = opts.placeholder ?? "";
  box.append(input);
  keyboardField(box);
  let shown = "";
  let cancelled = false;
  input.addEventListener("keydown", (e) => {
    if (e.key === "Enter") input.blur();
    if (e.key === "Escape") {
      e.preventDefault();
      cancelled = true;
      input.value = shown;
      input.blur();
    }
  });
  input.addEventListener("blur", () => {
    if (!cancelled && input.value !== shown) commit(input.value.trim());
    cancelled = false;
  });
  return {
    el: box,
    input,
    show(value) {
      shown = value;
      if (document.activeElement !== input) input.value = value;
    },
  };
}

export function textRow(
  key: KeyOf<string>,
  label: string,
  opts: { note?: string; placeholder?: string; mono?: boolean; emptyResets?: boolean },
): Part {
  let f: Frame;
  const fld = field(opts, (text) => void f.commit(key, text === "" && opts.emptyResets ? null : text));
  f = frame(label, opts.note ?? "", fld.el, key);
  return {
    el: f.el,
    update(s) {
      fld.show(valueAt<string>(s, key));
      f.sync();
    },
  };
}

export function folderRow(key: KeyOf<string>, label: string, browse: () => Promise<string | null>, note = ""): Part {
  let f: Frame;
  const box = el("div", "st-folder");
  const fld = field({ mono: true }, (text) => void f.commit(key, text === "" ? null : text));
  const pick = button("st-btn", "Browse…");
  pick.addEventListener("click", async () => {
    const chosen = await browse().catch(() => null);
    if (chosen) void f.commit(key, chosen);
  });
  box.append(fld.el, pick);
  f = frame(label, note, box, key);
  return {
    el: f.el,
    update(s) {
      fld.show(valueAt<string>(s, key));
      f.sync();
    },
  };
}

export function infoRow(label: string, value: (s: Settings) => string, note = ""): Part {
  const shown = el("span", "st-value");
  const f = frame(label, note, shown, null);
  return {
    el: f.el,
    update(s) {
      shown.textContent = value(s);
    },
  };
}

export function group(title: string, parts: Part[]): Part {
  const box = el("section", "st-group");
  if (title) box.append(el("h3", "st-group-title", title));
  const card = el("div", "st-card");
  card.append(...parts.map((p) => p.el));
  box.append(card);
  return fanOut(box, parts);
}

export function fanOut(el: HTMLElement, parts: Part[]): Part {
  return {
    el,
    update: (s) => parts.forEach((p) => p.update?.(s)),
    show: () => parts.forEach((p) => p.show?.()),
    hide: () => parts.forEach((p) => p.hide?.()),
  };
}
