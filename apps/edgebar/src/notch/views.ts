import { lucide } from "../icons";
import { assistantView } from "./assistant";
import { dashboardView } from "./dashboard";
import { performanceView } from "./performance";
import { isView, type NotchView, type RailEntry } from "./view";
import { wallpapersView } from "./wallpapers";

// The notch's rail, top to bottom. Settings has no view yet: swap its stub for
// the view when it lands.
export const rail: RailEntry[] = [
  dashboardView,
  wallpapersView,
  performanceView,
  assistantView,
  {
    id: "settings",
    title: "Settings",
    icon: lucide(
      '<path d="M9.671 4.136a2.34 2.34 0 0 1 4.659 0 2.34 2.34 0 0 0 3.319 1.915 2.34 2.34 0 0 1 2.33 4.033 2.34 2.34 0 0 0 0 3.831 2.34 2.34 0 0 1-2.33 4.033 2.34 2.34 0 0 0-3.319 1.915 2.34 2.34 0 0 1-4.659 0 2.34 2.34 0 0 0-3.32-1.915 2.34 2.34 0 0 1-2.33-4.033 2.34 2.34 0 0 0 0-3.831A2.34 2.34 0 0 1 6.35 6.051a2.34 2.34 0 0 0 3.319-1.915"/><circle cx="12" cy="12" r="3"/>',
    ),
    rail: "foot",
    stub: true,
  },
];

export const views: NotchView[] = rail.filter(isView);

// The view the notch opens on, as ambxst does.
export const home = dashboardView;
