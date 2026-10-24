export interface NotchView {
  id: string;
  title: string;
  icon: string;
  rail?: "top" | "foot";
  size: { w: number; h: number };
  mount(root: HTMLElement, ctx: ViewContext): ViewHandle;
}

export interface ViewHandle {
  open?(): void;
  show?(): void;
  hide?(): void;
}

export type Widget = (root: HTMLElement, ctx: ViewContext) => ViewHandle;

export interface ViewContext {
  reportInteractiveRects(): void;
  setAlert(id: string, reason: string | null): void;
  showView(id: string): void;
}
