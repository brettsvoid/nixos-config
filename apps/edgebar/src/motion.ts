// Spring and timing constants shared by the bar and the notch's views.
export const SPRING = {
  panelOpen: { type: "spring", stiffness: 280, damping: 26 },
  panelClose: { type: "spring", stiffness: 320, damping: 30 },
  reveal: { type: "spring", stiffness: 420, damping: 26 },
  hide: { type: "spring", stiffness: 520, damping: 34 },
  popup: { type: "spring", stiffness: 300, damping: 26 },
} as const;
export const FADE = { in: 0.25, inDelay: 0.08, out: 0.12 } as const; // seconds
export const STAGGER = { reveal: 0.05, hide: 0.03 } as const; // seconds between pills
