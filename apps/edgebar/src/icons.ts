// Inline Lucide SVGs take the colour of the text around them. Pass the inner
// shapes; this adds the shared wrapper.
export const lucide = (shapes: string) =>
  `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${shapes}</svg>`;

// Solid transport glyphs: Lucide's outlines read as hollow on a small button.
const solid = (d: string) =>
  `<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="${d}"/></svg>`;
export const TRANSPORT = {
  play: solid("M8 5.14v13.72a1 1 0 0 0 1.54.84l10.1-6.86a1 1 0 0 0 0-1.68L9.54 4.3A1 1 0 0 0 8 5.14z"),
  pause: solid("M7 4h3.2v16H7zm6.8 0H17v16h-3.2z"),
  next: solid("M5 6.14v11.72a1 1 0 0 0 1.54.84l8.6-5.86a1 1 0 0 0 0-1.68L6.54 5.3A1 1 0 0 0 5 6.14zM16.6 5h2.4v14h-2.4z"),
  previous: solid("M19 6.14v11.72a1 1 0 0 1-1.54.84l-8.6-5.86a1 1 0 0 1 0-1.68l8.6-5.86A1 1 0 0 1 19 6.14zM5 5h2.4v14H5z"),
} as const;
