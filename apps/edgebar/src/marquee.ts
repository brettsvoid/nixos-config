import "./marquee.css";

// Scroll speed and the dwell at each end, as a fraction of one pass.
const MARQUEE = { pxPerSec: 26, minSec: 4, pause: 0.18 } as const;

// Set a `.marquee` line's text and scroll it if it overflows its box; an
// ellipsis would hide the half of a title that tells tracks apart. The box
// holds one span, which is what moves. Call it while the box is laid out: a
// hidden box measures 0 and never scrolls.
export function setLine(box: HTMLElement, text: string) {
  const inner = box.firstElementChild as HTMLElement;
  if (inner.textContent !== text) inner.textContent = text;
  box.classList.remove("scroll");
  box.style.removeProperty("--marquee-shift");
  box.style.removeProperty("--marquee-dur");
  // Measured after the text lands; scrollWidth is the unclipped content.
  const overflow = inner.scrollWidth - box.clientWidth;
  if (overflow <= 1) return;
  const travel = Math.max(MARQUEE.minSec, overflow / MARQUEE.pxPerSec);
  box.style.setProperty("--marquee-shift", `${overflow}px`);
  // Two passes plus a dwell at each end, so one cycle is there-and-back.
  box.style.setProperty("--marquee-dur", `${(travel + MARQUEE.pause * travel) * 2}s`);
  box.classList.add("scroll");
}
