import { lucide } from "../icons";
import { dashboardView } from "./dashboard";
import { performanceView } from "./performance";
import { isView, type NotchView, type RailEntry } from "./view";
import { wallpapersView } from "./wallpapers";

// The notch's rail, top to bottom. Assistant and Settings have no view yet:
// swap each stub for its view when it lands.
export const rail: RailEntry[] = [
  dashboardView,
  wallpapersView,
  performanceView,
  {
    id: "assistant",
    title: "Assistant",
    icon: lucide(
      '<path d="m12 3-1.912 5.813a2 2 0 0 1-1.275 1.275L3 12l5.813 1.912a2 2 0 0 1 1.275 1.275L12 21l1.912-5.813a2 2 0 0 1 1.275-1.275L21 12l-5.813-1.912a2 2 0 0 1-1.275-1.275Z"/><path d="M5 3v4"/><path d="M19 17v4"/><path d="M3 5h4"/><path d="M17 19h4"/>',
    ),
    stub: true,
  },
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
