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

export interface Config {
  colors: Record<string, string>;
  geometry: {
    innerRadius: number;
    lineThickness: number;
    pillHeight: number;
    pillRadius: number;
    concave: number;
    windowHeight: number;
  };
  appearance: string; // "light" | "dark" | "auto"
  scheme: string; // active matugen scheme (e.g. "scheme-tonal-spot")
  ink: InkInfo;
  notchIdle: string; // "handle" | "clock" | literal text
}

// How the on-pill ink (colors.base) was chosen; see ThemeState::resolve in lib.rs.
export interface InkInfo {
  source: "config" | "contrast" | "override";
  ratio: number; // contrast of the ink in effect against the pill
  configured: string; // the role map's ink, before any correction
  configuredRatio: number;
  mode: "light" | "dark"; // the scheme it belongs to; an override edits this one
}

export interface ThemePayload {
  colors: Record<string, string>;
  appearance: string;
  scheme: string;
  ink: InkInfo;
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
  input: number;
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

export type ToggleId = "wifi" | "bluetooth" | "focus" | "nightShift" | "airdrop";

// One quick toggle. `available: false` means macOS gives edgebar no way to
// read or set it; `detail` then says why, and the button opens the matching
// System Settings pane instead.
export interface ToggleState {
  id: ToggleId;
  on: boolean;
  available: boolean;
  detail: string; // a short status line: the SSID, "2 devices", "Contacts only"…
}

// Access to a source macOS guards with a privacy permission.
export type Access = "granted" | "denied" | "notDetermined" | "unavailable";

export interface CalendarEvent {
  title: string;
  start: string; // ISO 8601, local time
  end: string;
  allDay: boolean;
  calendar: string;
  colour: string; // the calendar's colour, #rrggbb
}

export interface CalendarEvents {
  access: Access;
  events: CalendarEvent[];
}

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

// edgebar's settings: `effective` is the Nix config.json with the user's
// overrides (settings.json) applied, `user` the overrides alone, so a row can
// tell whether it has been changed. `error` is set when settings.json can't be
// parsed; Rust then ignores the file.
export interface SettingsSnapshot {
  effective: Record<string, unknown>;
  user: Record<string, unknown>;
  error: string | null;
}

type NoArgs = Record<string, never>;

export interface Commands {
  get_config: { args: NoArgs; result: Config };
  set_appearance: { args: { mode: string }; result: void };
  set_ink: { args: { colour: string | null }; result: void };
  pick_colour: { args: { initial: string }; result: string | null };
  aerospace_workspaces: { args: NoArgs; result: Workspace[] };
  aerospace_focus: { args: { name: string }; result: void };
  set_bar_size: { args: { width: number; height: number }; result: void };
  set_interactive_rects: { args: { rects: number[][] }; result: void };
  network: { args: NoArgs; result: Network };
  launcher_action: { args: { action: string }; result: void };
  battery: { args: NoArgs; result: Battery };
  metrics_sample: { args: NoArgs; result: Metrics };
  metrics_history: { args: NoArgs; result: MetricsHistory };
  cpu_state: { args: NoArgs; result: CpuSnapshot };
  get_volume: { args: NoArgs; result: Volume };
  set_volume: { args: { output: number }; result: void };
  set_input_volume: { args: { input: number }; result: void };
  get_brightness: { args: NoArgs; result: number }; // 0..1
  set_brightness: { args: { value: number }; result: void };
  list_wallpapers: { args: NoArgs; result: Wallpaper[] };
  current_wallpaper: { args: NoArgs; result: string };
  set_wallpaper: { args: { path: string }; result: void };
  pick_wallpaper_file: { args: NoArgs; result: string | null };
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
  calendar_events: { args: { from: string; to: string }; result: CalendarEvents };
  notification_history: { args: NoArgs; result: NotificationHistory };
  assistant_send: { args: { prompt: string }; result: string }; // the turn id
  assistant_cancel: { args: NoArgs; result: void };
  assistant_reset: { args: NoArgs; result: void };
  get_settings: { args: NoArgs; result: SettingsSnapshot };
  // `value: null` drops the override, so the key falls back to config.json.
  set_setting: { args: { key: string; value: unknown }; result: SettingsSnapshot };
}

export interface Events {
  theme: ThemePayload;
  notch: NotchItem | null;
  media: MediaState | null;
  workspaces: Workspace[];
  network: Network;
  cpu: CpuStat;
  toggles: ToggleState[];
  assistant: AssistantChunk;
  settings: SettingsSnapshot;
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
