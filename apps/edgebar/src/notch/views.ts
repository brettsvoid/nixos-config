import { assistantView } from "./assistant";
import { dashboardView } from "./dashboard";
import { performanceView } from "./performance";
import { settingsView } from "./settings";
import type { NotchView } from "./view";
import { wallpapersView } from "./wallpapers";

// The notch's rail, top to bottom; Settings pins itself to the foot.
export const views: NotchView[] = [
  dashboardView,
  wallpapersView,
  performanceView,
  assistantView,
  settingsView,
];

// The view the notch opens on, as ambxst does.
export const home = dashboardView;
