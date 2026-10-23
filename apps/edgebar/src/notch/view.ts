// A view is one tab of the open notch: its rail button, its size and its body.
// Each view lives in its own module with its own CSS; `views.ts` lists them in
// rail order, so adding one is a new file and one line there.

export interface NotchView {
  id: string; // also the rail button's data-to
  title: string; // the rail button's tooltip
  icon: string; // inline Lucide SVG for the rail button
  size: { w: number; h: number }; // the open notch's size while this view shows
  // "foot" pins the button to the bottom of the rail, as ambxst does for Settings.
  rail?: "top" | "foot";
  // Builds the view's DOM inside `root`, once, when the notch first opens.
  mount(root: HTMLElement, ctx: ViewContext): ViewHandle;
}

// What a mounted view can do. `show` runs each time it becomes the visible
// view (start polling, refresh), `hide` when it stops being visible or the
// notch closes (stop polling).
export interface ViewHandle {
  show?(): void;
  hide?(): void;
}

// What the notch shell offers its views.
export interface ViewContext {
  // Re-sends the interactive rects, after a view changes what is clickable.
  reportInteractiveRects(): void;
  // Marks a rail button as wanting attention (the amber dot), or clears it.
  setAlert(id: string, reason: string | null): void;
  // Opens another view, e.g. Settings from a widget's "set up" link.
  showView(id: string): void;
}
