const PAUSE_MS = 250;

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

export function fingersUp(e: WheelEvent): number {
  const inverted = (e as WheelEvent & { webkitDirectionInvertedFromDevice?: boolean })
    .webkitDirectionInvertedFromDevice;
  return inverted ? e.deltaY : -e.deltaY;
}
