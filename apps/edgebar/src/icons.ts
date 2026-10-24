// Inline Lucide SVGs take the colour of the text around them. Pass the inner
// shapes; this adds the shared wrapper.
export const lucide = (shapes: string) =>
  `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${shapes}</svg>`;
