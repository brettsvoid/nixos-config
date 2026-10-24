import "./toggles.css";
import type { Widget } from "../view";
import { note, ORDER, refreshToggles, toggleButton } from "./quick-toggle";

export const toggles: Widget = (root) => {
  const hint = note(root);
  root.prepend(...ORDER.map((id) => toggleButton(id, hint)));
  return { show: refreshToggles, hide: hint.hide };
};
