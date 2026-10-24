import "./marquee.css";

const MARQUEE = { pxPerSec: 26, minSec: 4, dwellFraction: 0.18 } as const;

const resized = new ResizeObserver((entries) => {
  for (const entry of entries) measure(entry.target as HTMLElement);
});

export function setLine(box: HTMLElement, text: string) {
  const inner = box.firstElementChild as HTMLElement;
  if (inner.textContent !== text) inner.textContent = text;
  resized.observe(box);
  measure(box);
}

function measure(box: HTMLElement) {
  const inner = box.firstElementChild as HTMLElement;
  box.classList.remove("scroll");
  box.style.removeProperty("--marquee-shift");
  box.style.removeProperty("--marquee-dur");
  const overflow = inner.scrollWidth - box.clientWidth;
  if (overflow <= 1) return;
  const travel = Math.max(MARQUEE.minSec, overflow / MARQUEE.pxPerSec);
  box.style.setProperty("--marquee-shift", `${overflow}px`);
  box.style.setProperty("--marquee-dur", `${(travel + MARQUEE.dwellFraction * travel) * 2}s`);
  box.classList.add("scroll");
}
