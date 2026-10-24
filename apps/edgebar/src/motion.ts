// The custom shell's Material 3 springs (modules/home/desktop/quickshell
// theme/Theme.qml), given by damping ratio and stiffness at mass 1. Motion takes
// a damping coefficient, which is 2 × ratio × √stiffness.
const spring = (ratio: number, stiffness: number) =>
  ({
    type: "spring",
    stiffness,
    damping: 2 * ratio * Math.sqrt(stiffness),
    mass: 1,
  }) as const;

export const SPRING = {
  // Default spatial: drawers opening, closing and resizing.
  drawer: spring(0.8, 380),
  // Fast spatial: small moves, such as the collapsed notch changing width.
  move: spring(0.6, 800),
  // Default effects: colour and opacity, which never overshoot.
  fade: spring(1, 1600),
} as const;
