// Typed access to edgebar's settings. Rust layers them (the bundled
// config.default.json, then the Nix config.json, then the user's overrides in
// settings.json) and validates every change; this module keeps the latest
// snapshot and the calls that change it. Read with `current()`, change with
// `set` and `reset`, react with `onChange`.
import defaults from "../src-tauri/config.default.json";
import { call, on, type SettingsSnapshot } from "./ipc";

// The effective settings are the bundled defaults with overrides of the same
// JSON types on top, so a key added to config.default.json is typed here with
// no further edit.
export type Settings = typeof defaults;

// Anything a setting can hold. `reset` is the way to drop an override.
export type SettingValue = string | number | boolean | object;

let snapshot: SettingsSnapshot = { effective: defaults, user: {}, error: null };
let heard = false; // a `settings` event has landed, so it is newer than the first read
const listeners = new Set<(settings: Settings) => void>();

function apply(next: SettingsSnapshot): void {
  snapshot = next;
  const settings = current();
  for (const fn of listeners) fn(settings);
}

// Resolves once the first snapshot has loaded. Until then `current()` returns
// the bundled defaults.
export const ready: Promise<void> = (async () => {
  await on("settings", (next) => {
    heard = true;
    apply(next);
  });
  const first = await call("get_settings");
  if (!heard) apply(first);
})();

// Rust merges over the bundled defaults and rejects an override whose JSON type
// differs from the default's, so `effective` has the shape of `Settings`.
export function current(): Settings {
  return snapshot.effective as Settings;
}

// True when the user has changed `key` (a dotted path such as "notch.idle"), or
// something under it, so a row can offer a reset.
export function isSet(key: string): boolean {
  let node: unknown = snapshot.user;
  for (const part of key.split(".")) {
    if (typeof node !== "object" || node === null) return false;
    if (!Object.prototype.hasOwnProperty.call(node, part)) return false;
    node = (node as Record<string, unknown>)[part];
  }
  return true;
}

// Why part of settings.json was not used (it did not parse, or some overrides
// failed validation), one problem per line; null when all of it applies.
export function error(): string | null {
  return snapshot.error;
}

// Rejects with Rust's reason when the key is unknown or the value has the wrong
// type; nothing changes then.
export async function set(key: string, value: SettingValue): Promise<void> {
  apply(await call("set_setting", { key, value }));
}

// Drop the user's override so `key` falls back to the Nix config or the default.
export async function reset(key: string): Promise<void> {
  apply(await call("set_setting", { key, value: null }));
}

// Called with the new settings after every change, from this view or any other.
// Returns a function that stops listening.
export function onChange(fn: (settings: Settings) => void): () => void {
  listeners.add(fn);
  return () => {
    listeners.delete(fn);
  };
}
