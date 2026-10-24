// The Settings view's rows: a label, its control and a reset button, bound to
// one setting. A row draws only from the settings it is handed (`update`), and
// every change goes through `set` or `reset`, so what it shows is always what
// Rust accepted.
import { lucide } from "../../icons";
import { keyboardField } from "../../keyboard";
import { current, isSet, reset, set, type Settings, type SettingValue } from "../../settings";

export const UNDO = lucide('<path d="M9 14 4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 5.5 5.5a5.5 5.5 0 0 1-5.5 5.5H11"/>');

// A piece of a section. `update` runs with the settings after every change,
// `show` and `hide` when its section comes and goes.
export interface Part {
  el: HTMLElement;
  update?(s: Settings): void;
  show?(): void;
  hide?(): void;
}

// The dotted keys whose setting has type V: KeyOf<boolean> takes "oled" and
// "clock.seconds" and refuses "notch.idle".
type KeysTo<T, V, P extends string = ""> = {
  [K in keyof T & string]: T[K] extends V
    ? `${P}${K}`
    : T[K] extends Record<string, unknown>
      ? KeysTo<T[K], V, `${P}${K}.`>
      : never;
}[keyof T & string];
export type KeyOf<V> = KeysTo<Settings, V>;

export function valueAt<V>(s: Settings, key: KeyOf<V>): V {
  let node: unknown = s;
  for (const part of key.split(".")) node = (node as Record<string, unknown>)[part];
  return node as V;
}

export function el<K extends keyof HTMLElementTagNameMap>(tag: K, className: string, text = "") {
  const node = document.createElement(tag);
  node.className = className;
  if (text) node.textContent = text;
  return node;
}

export function button(className: string, html: string, title = ""): HTMLButtonElement {
  const b = el("button", className);
  b.type = "button";
  b.innerHTML = html;
  if (title) b.title = title;
  return b;
}

// The frame every row shares. `why` shows Rust's reason under the label when a
// change was refused, until the next change lands.
export interface Frame {
  el: HTMLElement;
  why(reason: string | null): void;
  // set or reset, with a refusal shown under the label
  commit(key: string, value: SettingValue | null): Promise<void>;
  // the reset button follows whether `key` is overridden
  sync(): void;
}

export function frame(label: string, note: string, control: HTMLElement, key: string | null): Frame {
  const row = el("div", "st-row");
  const text = el("div", "st-text");
  text.append(el("span", "st-name", label));
  if (note) text.append(el("span", "st-note", note));
  const why = el("span", "st-why");
  why.hidden = true;
  text.append(why);
  const undo = button("st-reset", UNDO, "Back to the default");
  row.append(text, control, undo);

  const showWhy = (reason: string | null) => {
    why.hidden = reason === null;
    why.textContent = reason ?? "";
  };
  const commit = async (k: string, value: SettingValue | null) => {
    try {
      await (value === null ? reset(k) : set(k, value));
      showWhy(null);
    } catch (e) {
      showWhy(String(e));
    }
  };
  undo.addEventListener("click", () => {
    if (key) void commit(key, null);
  });
  return {
    el: row,
    why: showWhy,
    commit,
    sync: () => {
      undo.classList.toggle("shown", key !== null && isSet(key));
    },
  };
}

// ---- switch ----

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

// ---- segmented choice ----

export interface Option {
  value: string;
  label: string;
  icon?: string; // drawn instead of the label, which becomes the tooltip
}

// Full-round pills; the one matching the value is --primary.
export function segmented(options: Option[], pick: (value: string) => void) {
  const box = el("div", "st-seg");
  box.setAttribute("role", "group");
  const pills = options.map((o) => {
    const b = button("st-pill", o.icon ? `<span class="icon">${o.icon}</span>` : "", o.icon ? o.label : "");
    if (!o.icon) b.textContent = o.label;
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

// ---- slider ----

export interface Range {
  min: number;
  max: number;
  step: number;
  format: (value: number) => string;
}

// The value shows while dragging; the setting changes once, on release.
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

// ---- text field ----

export interface Field {
  el: HTMLElement;
  input: HTMLInputElement;
  // shows `value` unless the field is being typed in
  show(value: string): void;
}

// A full-round field that commits on Enter or when it loses focus; Escape puts
// the shown value back. Pressing it takes the keyboard (keyboard.ts).
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

// An empty field drops the override when `emptyResets`, rather than saving "".
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

// A folder: its path in a field, and Browse… for Finder's folder picker.
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

// ---- read-only ----

export function infoRow(label: string, value: (s: Settings) => string, note = ""): Part {
  const shown = el("span", "st-value");
  const f = frame(label, note, shown, null);
  return {
    el: f.el,
    update(s) {
      shown.textContent = value(s);
      f.sync();
    },
  };
}

// ---- grouping ----

// A card of rows under an optional heading.
export function group(title: string, parts: Part[]): Part {
  const box = el("section", "st-group");
  if (title) box.append(el("h3", "st-group-title", title));
  const card = el("div", "st-card");
  card.append(...parts.map((p) => p.el));
  box.append(card);
  return fanOut(box, parts);
}

// One part standing for several: each hook runs on every child that has it.
export function fanOut(el: HTMLElement, parts: Part[]): Part {
  return {
    el,
    update: (s) => parts.forEach((p) => p.update?.(s)),
    show: () => parts.forEach((p) => p.show?.()),
    hide: () => parts.forEach((p) => p.hide?.()),
  };
}
