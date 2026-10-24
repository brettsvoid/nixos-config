import "./dashboard.css";
import { lucide } from "../../icons";
import type { NotchView, ViewHandle, Widget } from "../view";
import { calendar } from "./calendar";
import { controls } from "./controls";
import { notifications } from "./notifications";
import { player } from "./player";
import { toggles } from "./toggles";

const div = (className: string, parent: HTMLElement) => {
  const el = document.createElement("div");
  el.className = className;
  parent.append(el);
  return el;
};

// Four columns after ambxst's WidgetsTab: the player, the toggles over the
// calendar, notification history, and the control rail. The grid only places
// each widget's slot; what a slot shows is the widget's own business.
export const dashboardView: NotchView = {
  id: "dashboard",
  title: "Dashboard",
  icon: lucide(
    '<rect width="7" height="9" x="3" y="3" rx="1"/><rect width="7" height="5" x="14" y="3" rx="1"/><rect width="7" height="9" x="14" y="12" rx="1"/><rect width="7" height="5" x="3" y="16" rx="1"/>',
  ),
  // The width is the grid's columns and gaps.
  size: { w: 680, h: 352 },
  mount(root, ctx) {
    const handles: ViewHandle[] = [];
    const fill = (name: string, widget: Widget, parent: HTMLElement) => {
      handles.push(widget(div(`dash-${name}`, parent), ctx));
    };
    fill("player", player, root);
    const column = div("dash-col dash-widgets", root);
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
