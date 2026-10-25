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
  theme?(): void;
}

export type Widget = (root: HTMLElement) => ViewHandle;

export interface ViewContext {
  setAlert(reason: string | null): void;
}
