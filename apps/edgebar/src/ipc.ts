import { invoke } from "@tauri-apps/api/core";
import { listen, type UnlistenFn } from "@tauri-apps/api/event";

export interface Workspace {
  name: string;
  focused: boolean;
  has_windows: boolean;
  app: string;
  icon: string;
}

export interface Colors {
  surface: string;
  text: string;
  subtext: string;
  accent: string;
  batteryCharging: string;
  batteryLow: string;
  vpn: string;
  cpuSys: string;
  cpuUser: string;
}

export interface Geometry {
  barHeight: number;
  frameThickness: number;
  frameRadius: number;
  windowHeight: number;
}

export interface Config {
  colors: Colors;
  geometry: Geometry;
  appearance: string;
  scheme: string;
  ink: InkInfo;
  notchIdle: string;
}

export interface InkInfo {
  source: "config" | "contrast" | "override";
  ratio: number;
  configured: string;
  configuredRatio: number;
  mode: "light" | "dark";
}

export interface NotchItem {
  tier: "transient" | "workspace" | "media";
  glyph: string;
  icon: string;
  art: string;
  primary: string;
  secondary: string;
  progress: number | null;
  duration: number;
  controls: boolean;
  active: boolean;
}

export interface MediaState {
  app: string;
  icon: string;
  title: string;
  artist: string;
  album: string;
  artKey: string;
  position: number;
  duration: number;
  playing: boolean;
  controls: boolean;
}

export interface Battery {
  present: boolean;
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

export interface CpuSample {
  sys: number;
  user: number;
}

export interface CpuStat extends CpuSample {
  total: number;
  mem: number;
  topProc: string;
  topProcPct: number;
  topPid: number;
}

export interface CpuSnapshot {
  history: CpuSample[];
  latest: CpuStat;
}

export interface MetricsHistory {
  intervalMs: number;
  cpu: CpuSample[];
  mem: number[];
}

export interface Volume {
  output: number;
  outputMuted: boolean;
  input: number;
  inputRestore: number | null;
}

export interface Network {
  state: string;
  label: string;
  rssi: number | null;
  online: boolean;
}

export interface Wallpaper {
  name: string;
  path: string;
  thumb: string;
  folder: string;
  kind: string;
}

export type ToggleId = "wifi" | "bluetooth" | "focus" | "nightShift" | "caffeine";

export interface ToggleState {
  id: ToggleId;
  on: boolean;
  available: boolean;
  detail: string;
}

export type SettingsPane =
  | "wifi"
  | "bluetooth"
  | "focus"
  | "displays"
  | "fullDiskAccess"
  | "privacyBluetooth"
  | "privacyAutomation";

export type Access = "granted" | "denied" | "unavailable" | "off";

export interface NotificationEntry {
  id: string;
  app: string;
  icon: string;
  title: string;
  subtitle: string;
  body: string;
  time: string;
}

export interface NotificationHistory {
  access: Access;
  items: NotificationEntry[];
}

export interface AssistantChunk {
  turn: string;
  kind: "delta" | "done" | "error";
  text: string;
}

export interface SettingsSnapshot {
  effective: Record<string, unknown>;
  user: Record<string, unknown>;
  errors: string[];
}

export interface SetupItem {
  id: string;
  label: string;
  state: "ready" | "missing" | "unknown";
  detail: string;
  action: string | null;
}

export interface SettingsLayer {
  name: string;
  path: string;
  detail: string;
}

export interface SettingsFiles {
  version: string;
  layers: SettingsLayer[];
}

type NoArgs = Record<string, never>;

export interface Commands {
  get_config: { args: NoArgs; result: Config };
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
  set_volume: { args: { output: number }; result: void };
  set_input_volume: { args: { input: number }; result: void };
  set_output_muted: { args: { muted: boolean }; result: void };
  set_input_muted: { args: { muted: boolean }; result: void };
  get_brightness: { args: NoArgs; result: number };
  set_brightness: { args: { value: number }; result: void };
  list_wallpapers: { args: NoArgs; result: Wallpaper[] };
  current_wallpaper: { args: NoArgs; result: string };
  set_wallpaper: { args: { path: string }; result: void };
  pick_wallpaper_file: { args: NoArgs; result: string | null };
  pick_folder: { args: NoArgs; result: string | null };
  set_scheme: { args: { scheme: string }; result: void };
  precompute_palettes: { args: NoArgs; result: void };
  notch_state: { args: NoArgs; result: NotchItem | null };
  media_state: { args: NoArgs; result: MediaState | null };
  media_art: { args: { key: string }; result: string };
  media_toggle: { args: NoArgs; result: void };
  media_next: { args: NoArgs; result: void };
  media_previous: { args: NoArgs; result: void };
  media_seek: { args: { fraction: number }; result: void };
  toggles: { args: NoArgs; result: ToggleState[] };
  set_toggle: { args: { id: ToggleId; on: boolean }; result: ToggleState };
  notification_history: { args: NoArgs; result: NotificationHistory };
  notification_hide: { args: { ids: string[] }; result: void };
  notification_hide_all: { args: NoArgs; result: void };
  assistant_send: { args: { prompt: string }; result: string };
  assistant_cancel: { args: NoArgs; result: void };
  assistant_reset: { args: NoArgs; result: void };
  assistant_open_link: { args: { url: string }; result: void };
  take_keyboard: { args: NoArgs; result: void };
  release_keyboard: { args: NoArgs; result: void };
  get_settings: { args: NoArgs; result: SettingsSnapshot };
  set_setting: { args: { key: string; value: unknown }; result: SettingsSnapshot };
  settings_files: { args: NoArgs; result: SettingsFiles };
  open_settings_file: { args: NoArgs; result: void };
  setup_status: { args: NoArgs; result: SetupItem[] };
  setup_run: { args: { id: string }; result: SetupItem[] };
}

export interface Events {
  theme: Config;
  notch: NotchItem | null;
  media: MediaState | null;
  workspaces: Workspace[];
  network: Network;
  cpu: CpuStat;
  toggles: ToggleState[];
  assistant: AssistantChunk;
  settings: SettingsSnapshot;
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
