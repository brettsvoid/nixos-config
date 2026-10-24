import { assistantView } from "./assistant";
import { dashboardView } from "./dashboard";
import { performanceView } from "./performance";
import { settingsView } from "./settings";
import type { NotchView } from "./view";
import { wallpapersView } from "./wallpapers";

export const views: NotchView[] = [
  dashboardView,
  wallpapersView,
  performanceView,
  assistantView,
  settingsView,
];

export const home = dashboardView;
