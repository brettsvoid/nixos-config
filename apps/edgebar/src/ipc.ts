// The WebView's whole contract with Rust: every command it calls and every
// event it hears, with their payload types. `call` and `on` only accept names
// listed here, so a renamed or retyped command fails the type check.
import { invoke } from "@tauri-apps/api/core";
import { listen, type UnlistenFn } from "@tauri-apps/api/event";

export interface Workspace {
  name: string;
  focused: boolean;
  has_windows: boolean;
  app: string; // app name for the dot's tooltip ("" if empty)
  icon: string; // PNG data URL, or "" when the workspace is empty
}

// The colour roles, resolved to hex for the active scheme (Colors in lib.rs).
export interface Colors {
  surface: string; // the band, the frame, the notch and every drawer
  text: string; // ink on the surface
  subtext: string; // dim ink on the surface
  accent: string; // every active or selected state
  batteryCharging: string;
  batteryLow: string;
  vpn: string;
  cpuSys: string;
  cpuUser: string;
}

// The frame's shape in logical px (Geometry in lib.rs).
export interface Geometry {
  barHeight: number; // the band, which is also the frame's top edge
  frameThickness: number; // the frame's sides and bottom
  frameRadius: number; // corners of the hole inside the frame
  windowHeight: number; // the bar window while no drawer is open
}

export interface Config {
  colors: Colors;
  geometry: Geometry;
  appearance: string; // "light" | "dark" | "auto"
  scheme: string; // active matugen scheme (e.g. "scheme-tonal-spot")
  ink: InkInfo;
  notchIdle: string; // "handle" | "clock" | literal text
}

// How the ink (colors.text) was chosen; see ThemeState::resolve in lib.rs.
export interface InkInfo {
  source: "config" | "contrast" | "override";
  ratio: number; // contrast of the ink in effect against the surface
  configured: string; // the role map's ink, before any correction
  configuredRatio: number;
  mode: "light" | "dark"; // the scheme it belongs to; an override edits this one
}

// One line of collapsed-notch content. Rust picks the winner (an OSD flash
// beats workspace context beats whatever is playing); null means the idle look.
export interface NotchItem {
  tier: "transient" | "workspace" | "media";
  glyph: string; // icon name, used when `icon` is empty
  icon: string; // app icon PNG data URL, or ""
  art: string; // album art data URL, or "": the media pill's backdrop
  primary: string;
  secondary: string;
  progress: number | null; // 0..1 hairline fill
  duration: number; // track length in seconds, 0 when unknown
  controls: boolean; // transport commands reach this source
  active: boolean; // false dims it (paused player)
}

// The media slot on its own, whatever wins the collapsed notch: the
// dashboard's player shows it even while an OSD flash or a workspace rule
// holds the notch.
export interface MediaState {
  app: string; // "Spotify", or the audible app's name
  icon: string; // app icon PNG data URL, or ""
  title: string;
  artist: string;
  album: string;
  // Changes when the cover does, "" when there is none. Fetch the image once per
  // key with media_art, so a position update doesn't resend it.
  artKey: string;
  position: number; // seconds, as of when Rust published it
  duration: number; // seconds, 0 when unknown
  playing: boolean;
  controls: boolean; // transport commands reach this source
}

export interface Battery {
  present: boolean; // false on desktops: the readout is hidden entirely
  percent: number;
  state: string;
  time: string | null;
}

export interface Metrics {
  cpu: number;
  memUsed: number;
  memTotal: number;
  swapUsed: number;
  swapTotal: number;
  diskUsed: number;
  diskTotal: number;
}

// One point on the CPU graph: fractions of total capacity, 0..1.
export interface CpuSample {
  sys: number;
  user: number;
}

export interface CpuStat extends CpuSample {
  total: number;
  mem: number; // used fraction of RAM, 0..1, sampled with the CPU
  topProc: string;
  topProcPct: number; // percent of one core, so >100 for a threaded process
  topPid: number; // 0 before the first process walk lands
}

export interface CpuSnapshot {
  history: CpuSample[];
  latest: CpuStat;
}

// The performance chart's series, oldest first, one sample per `intervalMs`.
export interface MetricsHistory {
  intervalMs: number;
  cpu: CpuSample[];
  mem: number[]; // used fraction of RAM, 0..1
}

export interface Volume {
  output: number;
  // While edgebar holds the mic muted (macOS has no input mute, so it sets the
  // mic to 0), the level unmuting restores.
  input: number;
  outputMuted: boolean;
  inputMuted: boolean;
}

export interface Network {
  state: string; // "wifi" | "vpn" | "off"
  label: string;
  rssi: number | null; // Wi-Fi signal in dBm when connected, else null
  online: boolean; // false = connected but no internet (only meaningful for "wifi")
}

export interface Wallpaper {
  name: string;
  path: string;
  thumb: string; // data:image/png;base64,…
  folder: string; // subfolder under the wallpapers folder, "" at its root
  kind: string; // lower-case file extension: "png", "jpg", "heic"…
}

export type ToggleId = "wifi" | "bluetooth" | "focus" | "nightShift" | "caffeine";

// One quick toggle. `available: false` means macOS gives edgebar no way to
// read or set it; `detail` then says why, and the button opens the matching
// System Settings pane instead.
export interface ToggleState {
  id: ToggleId;
  on: boolean;
  available: boolean;
  detail: string; // a short status line: the SSID, "2 devices", "Contacts only"…
}

// The System Settings panes edgebar can open (SettingsPane in lib.rs).
export type SettingsPane =
  | "wifi"
  | "bluetooth"
  | "focus"
  | "displays" // Night Shift lives here
  | "fullDiskAccess"
  | "privacyBluetooth"
  | "privacyAutomation"
  | "shortcuts"; // not a pane: opens the Shortcuts app

// Whether edgebar may read macOS's notification history. "off" means the
// `notifications.history` setting is off, so Rust never opened the store.
export type Access = "granted" | "denied" | "unavailable" | "off";

export interface NotificationEntry {
  id: string;
  app: string;
  icon: string; // app icon PNG data URL, or ""
  title: string;
  subtitle: string;
  body: string;
  time: string; // ISO 8601
}

export interface NotificationHistory {
  access: Access;
  items: NotificationEntry[]; // newest first
}

// One streamed piece of an assistant reply, keyed by the turn it answers.
export interface AssistantChunk {
  turn: string;
  kind: "delta" | "done" | "error";
  text: string; // the new text for "delta", the message for "error"
}

// edgebar's settings: `effective` is the bundled defaults, the Nix config.json
// and the user's overrides (settings.json) merged, `user` the valid overrides
// alone, so a row can tell whether it has been changed. `error` is set when
// settings.json can't be parsed (Rust then ignores the file) or when some of its
// overrides failed validation (Rust leaves those out); one problem per line.
export interface SettingsSnapshot {
  effective: Record<string, unknown>;
  user: Record<string, unknown>;
  error: string | null;
}

// One row of the Settings view's Setup checklist (setup.rs). `action` is the
// label of the button that runs `setup_run` for it, null when edgebar can do
// nothing about it.
export interface SetupItem {
  id: string;
  label: string;
  state: "ready" | "missing" | "unknown";
  detail: string;
  action: string | null;
}

// Where one of the settings layers lives, for the Settings view's About.
export interface SettingsLayer {
  name: string;
  path: string;
  detail: string;
}

export interface SettingsFiles {
  version: string;
  layers: SettingsLayer[]; // bundled defaults, the Nix config.json, settings.json
}

type NoArgs = Record<string, never>;

export interface Commands {
  get_config: { args: NoArgs; result: Config };
  // The `appearance` setting under its own name; rejects anything but
  // "light" | "dark" | "auto".
  set_appearance: { args: { mode: string }; result: void };
  set_ink: { args: { colour: string | null }; result: void };
  pick_colour: { args: { initial: string }; result: string | null };
  aerospace_workspaces: { args: NoArgs; result: Workspace[] };
  aerospace_focus: { args: { name: string }; result: void };
  set_bar_size: { args: { width: number; height: number }; result: void };
  set_interactive_rects: { args: { rects: number[][] }; result: void };
  network: { args: NoArgs; result: Network };
  launcher_action: { args: { action: string }; result: void };
  open_settings_pane: { args: { pane: SettingsPane }; result: void };
  battery: { args: NoArgs; result: Battery };
  metrics_sample: { args: NoArgs; result: Metrics };
  metrics_history: { args: NoArgs; result: MetricsHistory };
  cpu_state: { args: NoArgs; result: CpuSnapshot };
  get_volume: { args: NoArgs; result: Volume };
  set_volume: { args: { output: number }; result: void }; // also unmutes
  set_input_volume: { args: { input: number }; result: void }; // also unmutes
  set_output_muted: { args: { muted: boolean }; result: void };
  set_input_muted: { args: { muted: boolean }; result: void };
  // The built-in display's, 0..1. Rejects with the reason when there is none.
  get_brightness: { args: NoArgs; result: number };
  set_brightness: { args: { value: number }; result: void };
  list_wallpapers: { args: NoArgs; result: Wallpaper[] };
  current_wallpaper: { args: NoArgs; result: string };
  set_wallpaper: { args: { path: string }; result: void };
  pick_wallpaper_file: { args: NoArgs; result: string | null };
  // The wallpaper folder, `~/…` under the home folder; null on cancel.
  pick_folder: { args: NoArgs; result: string | null };
  set_scheme: { args: { scheme: string }; result: void };
  precompute_palettes: { args: NoArgs; result: void };
  notch_state: { args: NoArgs; result: NotchItem | null };
  media_state: { args: NoArgs; result: MediaState | null };
  media_art: { args: { key: string }; result: string }; // cover data URL, "" if gone
  media_toggle: { args: NoArgs; result: void };
  media_next: { args: NoArgs; result: void };
  media_previous: { args: NoArgs; result: void };
  media_seek: { args: { fraction: number }; result: void };
  toggles: { args: NoArgs; result: ToggleState[] };
  set_toggle: { args: { id: ToggleId; on: boolean }; result: ToggleState };
  notification_history: { args: NoArgs; result: NotificationHistory };
  // macOS's store is read-only to edgebar, so these hide entries in edgebar only.
  notification_dismiss: { args: { ids: string[] }; result: void };
  notification_clear: { args: NoArgs; result: void };
  assistant_send: { args: { prompt: string }; result: string }; // the turn id
  assistant_cancel: { args: NoArgs; result: void };
  assistant_reset: { args: NoArgs; result: void };
  // Opens a link from a reply in the browser; rejects anything but http(s).
  assistant_open_link: { args: { url: string }; result: void };
  // The calling bar window takes the keyboard until release_keyboard, which
  // hands it back to the app that was in front (keyboard.ts).
  take_keyboard: { args: NoArgs; result: void };
  release_keyboard: { args: NoArgs; result: void };
  get_settings: { args: NoArgs; result: SettingsSnapshot };
  // `value: null` drops the override, so the key falls back to config.json.
  set_setting: { args: { key: string; value: unknown }; result: SettingsSnapshot };
  settings_files: { args: NoArgs; result: SettingsFiles };
  // Opens settings.json in the default text editor, creating it as {} first.
  open_settings_file: { args: NoArgs; result: void };
  setup_status: { args: NoArgs; result: SetupItem[] };
  // Runs that row's action, then answers with every row probed again.
  setup_run: { args: { id: string }; result: SetupItem[] };
}

export interface Events {
  // The whole resolved config, sent again on every re-theme or geometry change.
  theme: Config;
  notch: NotchItem | null;
  media: MediaState | null;
  workspaces: Workspace[];
  network: Network;
  cpu: CpuStat;
  toggles: ToggleState[];
  assistant: AssistantChunk;
  settings: SettingsSnapshot;
  // A desktop pass has finished (a pick with Tint on, or a re-tint after a
  // palette or Tint change): the original the desktop now stands for, null
  // when unknown.
  desktop: string | null;
}

export function call<K extends keyof Commands>(
  cmd: K,
  ...args: Commands[K]["args"] extends NoArgs ? [] : [Commands[K]["args"]]
): Promise<Commands[K]["result"]> {
  return invoke<Commands[K]["result"]>(cmd, args[0]);
}

export function on<K extends keyof Events>(
  event: K,
  handler: (payload: Events[K]) => void,
): Promise<UnlistenFn> {
  return listen<Events[K]>(event, (e) => handler(e.payload));
}
