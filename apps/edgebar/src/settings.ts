import defaults from "../src-tauri/config.default.json";
import { call, on, type SettingsSnapshot } from "./ipc";

export type Settings = typeof defaults;

export type SettingValue = string | number | boolean | object;

let snapshot: SettingsSnapshot = { effective: defaults, user: {}, errors: [] };
let heard = false;
const listeners = new Set<(settings: Settings) => void>();

function apply(next: SettingsSnapshot): void {
  snapshot = next;
  const settings = current();
  for (const fn of listeners) fn(settings);
}

void (async () => {
  await on("settings", (next) => {
    heard = true;
    apply(next);
  });
  const first = await call("get_settings");
  if (!heard) apply(first);
})();

export function current(): Settings {
  return snapshot.effective;
}

export function isOverridden(key: string): boolean {
  let node: unknown = snapshot.user;
  for (const part of key.split(".")) {
    if (typeof node !== "object" || node === null) return false;
    if (!Object.prototype.hasOwnProperty.call(node, part)) return false;
    node = (node as Record<string, unknown>)[part];
  }
  return true;
}

export function errors(): string[] {
  return snapshot.errors;
}

export async function set(key: string, value: SettingValue): Promise<void> {
  apply(await call("set_setting", { key, value }));
}

export async function reset(key: string): Promise<void> {
  apply(await call("set_setting", { key, value: null }));
}

export function onChange(fn: (settings: Settings) => void): () => void {
  listeners.add(fn);
  return () => {
    listeners.delete(fn);
  };
}
