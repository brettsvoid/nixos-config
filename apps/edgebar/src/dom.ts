export function el<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  className?: string,
  ...children: (Node | string)[]
): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  if (className) node.className = className;
  node.append(...children);
  return node;
}

export function whyLine(): { el: HTMLElement; show(reason: string | null): void } {
  const line = el("span", "why");
  line.hidden = true;
  return {
    el: line,
    show(reason) {
      line.hidden = reason === null;
      line.textContent = reason ?? "";
    },
  };
}
