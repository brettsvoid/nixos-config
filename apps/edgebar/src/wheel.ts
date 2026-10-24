// Gap that ends one wheel gesture, so the next event starts a fresh one.
const PAUSE_MS = 250;

// Turns wheel events into whole steps. A mouse wheel steps once per notch, so
// the first event after a pause steps at once; a trackpad's stream of small
// deltas steps every `px` of travel. `travel` reads one event's movement.
export function wheelStepper(
  px: number,
  travel: (e: WheelEvent) => number,
): (e: WheelEvent) => number {
  let acc = 0;
  let last = -Infinity;
  return (e) => {
    const t = travel(e);
    const fresh = e.timeStamp - last > PAUSE_MS;
    last = e.timeStamp;
    if (fresh) {
      acc = 0;
      return Math.sign(t);
    }
    acc += t;
    const steps = Math.trunc(acc / px);
    acc -= steps * px;
    return steps;
  };
}

// + for up: the way the fingers or the wheel moved, so natural scrolling
// doesn't turn a level down.
export function fingersUp(e: WheelEvent): number {
  const inverted = (e as WheelEvent & { webkitDirectionInvertedFromDevice?: boolean })
    .webkitDirectionInvertedFromDevice;
  return inverted ? e.deltaY : -e.deltaY;
}
