// A view is one tab of the open notch: its rail button, its size and its body.
// Each view lives in its own module with its own CSS; `views.ts` lists them in
// rail order, so adding one is a new file and one line there.

// What every rail entry has, whether or not its view exists yet.
export interface RailButton {
  id: string; // also the rail button's data-to
  title: string; // the rail button's tooltip
  icon: string; // inline Lucide SVG for the rail button
  // "foot" pins the button to the bottom of the rail, as ambxst does for Settings.
  rail?: "top" | "foot";
}

export interface NotchView extends RailButton {
  // The view's own area in the open notch; the shell adds the rail and padding.
  size: { w: number; h: number };
  // Builds the view's DOM inside `root`, once, when the notch first opens.
  mount(root: HTMLElement, ctx: ViewContext): ViewHandle;
}

// A rail button whose view is not written yet: drawn muted, not clickable,
// never mounted. Replace it in `views.ts` with the view when it lands.
export interface RailStub extends RailButton {
  stub: true;
}

export type RailEntry = NotchView | RailStub;

export const isView = (entry: RailEntry): entry is NotchView => "mount" in entry;

// What a mounted view can do. `open` runs each time the notch opens, whichever
// view shows (Performance samples once, so its rail dot is right on arrival).
// `show` runs each time the view becomes the visible one (start polling,
// refresh), `hide` when it stops being visible or the notch closes (stop
// polling).
export interface ViewHandle {
  open?(): void;
  show?(): void;
  hide?(): void;
}

// A view's sub-part: the dashboard hands each slot of its grid an element and
// the widget fills it.
export type Widget = (root: HTMLElement, ctx: ViewContext) => ViewHandle;

// What the notch shell offers its views.
export interface ViewContext {
  // Re-sends the interactive rects, after a view changes what is clickable.
  reportInteractiveRects(): void;
  // Marks a rail button as wanting attention (the amber dot), or clears it.
  setAlert(id: string, reason: string | null): void;
  // Opens another view, e.g. Settings from a widget's "set up" link.
  showView(id: string): void;
}
