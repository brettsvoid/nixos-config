import "./dashboard.css";
import { el } from "../../dom";
import { lucide } from "../../icons";
import type { NotchView, ViewHandle, Widget } from "../view";
import { calendar } from "./calendar";
import { controls } from "./controls";
import { notifications } from "./notifications";
import { player } from "./player";
import { toggles } from "./toggles";

export const dashboardView: NotchView = {
  id: "dashboard",
  title: "Dashboard",
  icon: lucide(
    '<rect width="7" height="9" x="3" y="3" rx="1"/><rect width="7" height="5" x="14" y="3" rx="1"/><rect width="7" height="9" x="14" y="12" rx="1"/><rect width="7" height="5" x="3" y="16" rx="1"/>',
  ),
  size: { w: 680, h: 352 },
  mount(root) {
    const handles: ViewHandle[] = [];
    const fill = (name: string, widget: Widget, parent: HTMLElement) => {
      handles.push(widget(parent.appendChild(el("div", `dash-${name}`))));
    };
    fill("player", player, root);
    const column = root.appendChild(el("div", "dash-col dash-widgets"));
    fill("toggles", toggles, column);
    fill("calendar", calendar, column);
    fill("notifications", notifications, root);
    fill("controls", controls, root);
    return {
      open: () => handles.forEach((h) => h.open?.()),
      show: () => handles.forEach((h) => h.show?.()),
      hide: () => handles.forEach((h) => h.hide?.()),
    };
  },
};
