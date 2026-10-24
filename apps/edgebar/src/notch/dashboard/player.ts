import "./player.css";
import { lucide } from "../../icons";
import type { Widget } from "../view";

// Column 1 (ambxst FullPlayer): art, title, transport and a seek bar, reusing
// the collapsed notch's media data when it lands.
export const player: Widget = (root) => {
  root.classList.add("ph");
  root.dataset.for = "FullPlayer";
  root.innerHTML =
    `<span class="ph-icon icon">${lucide(
      '<path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>',
    )}</span>` +
    '<span class="ph-name">FullPlayer</span>' +
    '<span class="ph-note">art · title · transport · seek</span>';
  return {};
};
