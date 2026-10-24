import "./toggles.css";
import type { Widget } from "../view";
import { note, ORDER, refreshToggles, toggleButton } from "./quick-toggle";

// Top of the widgets column (ambxst QuickControls): Wi-Fi, Bluetooth, Focus,
// Night Shift and Caffeine.
export const toggles: Widget = (root) => {
  const hint = note(root);
  root.prepend(...ORDER.map((id) => toggleButton(id, hint)));
  return { show: refreshToggles, hide: hint.hide };
};
