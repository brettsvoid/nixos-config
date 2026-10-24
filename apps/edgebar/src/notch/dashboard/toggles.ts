import "./toggles.css";
import { lucide } from "../../icons";
import type { Widget } from "../view";

// Top of the widgets column (ambxst QuickControls): five square toggles.
const TOGGLES = [
  {
    title: "Wi-Fi",
    shapes:
      '<path d="M12 20h.01"/><path d="M8.5 16.429a5 5 0 0 1 7 0"/><path d="M5 12.859a10 10 0 0 1 14 0"/><path d="M2 8.82a15 15 0 0 1 20 0"/>',
  },
  { title: "Bluetooth", shapes: '<path d="m7 7 10 10-5 5V2l5 5L7 17"/>' },
  {
    title: "Do Not Disturb",
    shapes:
      '<path d="M20.985 12.486a9 9 0 1 1-9.473-9.472c.405-.022.617.46.402.803a6 6 0 0 0 8.268 8.268c.344-.215.825-.004.803.401"/>',
  },
  {
    title: "Night Shift",
    shapes:
      '<path d="M12 10V2"/><path d="m4.93 10.93 1.41 1.41"/><path d="M2 18h2"/><path d="M20 18h2"/><path d="m19.07 10.93-1.41 1.41"/><path d="M22 22H2"/><path d="m16 6-4 4-4-4"/><path d="M16 18a4 4 0 0 0-8 0"/>',
  },
  {
    title: "AirDrop",
    shapes:
      '<path d="M5 17H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2h-1"/><path d="m12 15 5 6H7Z"/>',
  },
];

export const toggles: Widget = (root) => {
  root.innerHTML = TOGGLES.map(
    (t) =>
      `<button class="qc-btn wip" title="${t.title} — not implemented"><span class="icon">${lucide(t.shapes)}</span></button>`,
  ).join("");
  return {};
};
