const spring = (ratio: number, stiffness: number) =>
  ({
    type: "spring",
    stiffness,
    damping: 2 * ratio * Math.sqrt(stiffness),
    mass: 1,
  }) as const;

export const SPRING = {
  drawer: spring(0.8, 380),
  move: spring(0.6, 800),
  fade: spring(1, 1600),
} as const;
