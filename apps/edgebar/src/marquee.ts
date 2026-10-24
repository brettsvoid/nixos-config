import "./marquee.css";

const MARQUEE = { pxPerSec: 26, minSec: 4, pause: 0.18 } as const;

export function setLine(box: HTMLElement, text: string) {
  const inner = box.firstElementChild as HTMLElement;
  if (inner.textContent !== text) inner.textContent = text;
  box.classList.remove("scroll");
  box.style.removeProperty("--marquee-shift");
  box.style.removeProperty("--marquee-dur");
  const overflow = inner.scrollWidth - box.clientWidth;
  if (overflow <= 1) return;
  const travel = Math.max(MARQUEE.minSec, overflow / MARQUEE.pxPerSec);
  box.style.setProperty("--marquee-shift", `${overflow}px`);
  box.style.setProperty("--marquee-dur", `${(travel + MARQUEE.pause * travel) * 2}s`);
  box.classList.add("scroll");
}
