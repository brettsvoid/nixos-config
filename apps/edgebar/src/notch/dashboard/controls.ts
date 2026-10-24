import "./controls.css";
import { lucide } from "../../icons";
import type { Widget } from "../view";

// Column 4 (ambxst control rail): a tall brightness slider over volume and mic
// dials. The controls popup already has working sliders for all three.
export const controls: Widget = (root) => {
  root.innerHTML =
    '<div class="ph ph-vslider" data-for="Brightness">' +
    `<span class="ph-icon icon">${lucide(
      '<circle cx="12" cy="12" r="4"/><path d="M12 2v2"/><path d="M12 20v2"/><path d="m4.93 4.93 1.41 1.41"/><path d="m17.66 17.66 1.41 1.41"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="m6.34 17.66-1.41 1.41"/><path d="m19.07 4.93-1.41 1.41"/>',
    )}</span>` +
    '<span class="ph-name">Brightness</span></div>' +
    '<div class="ph ph-dial" title="Volume — CircularControl">' +
    `<span class="ph-icon icon">${lucide(
      '<path d="M11 4.702a.705.705 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.705.705 0 0 0 11 19.298z"/><path d="M16 9a5 5 0 0 1 0 6"/>',
    )}</span></div>` +
    '<div class="ph ph-dial" title="Mic — CircularControl">' +
    `<span class="ph-icon icon">${lucide(
      '<path d="M12 19v3"/><path d="M19 10v2a7 7 0 0 1-14 0v-2"/><rect x="9" y="2" width="6" height="13" rx="3"/>',
    )}</span></div>`;
  return {};
};
