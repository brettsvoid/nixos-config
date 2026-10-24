import { lucide } from "../icons";

const COPY_GLYPHS =
  `<span class="md-copy-idle">${lucide('<rect width="14" height="14" x="8" y="8" rx="2" ry="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/>')}</span>` +
  `<span class="md-copy-done">${lucide('<path d="M20 6 9 17l-5-5"/>')}</span>`;

const FENCE = /^ {0,3}(`{3,}|~{3,})\s*([^`\s]*)/;
const HEADING = /^ {0,3}#{1,6}\s+(.*?)\s*#*\s*$/;
const RULE = /^ {0,3}([-*_])(\s*\1){2,}\s*$/;
const ITEM = /^(\s*)([-*+]|\d{1,9}[.)])\s+(.*)$/;

const INLINE = new RegExp(
  [
    "(`+)([\\s\\S]+?)\\1(?!`)",
    "\\*\\*(?=\\S)([\\s\\S]*?\\S)\\*\\*",
    "__(?=\\S)([\\s\\S]*?\\S)__(?!\\w)",
    "\\*(?=[^\\s*])([\\s\\S]*?[^\\s*])\\*",
    "(?<![\\w])_(?=[^\\s_])([\\s\\S]*?[^\\s_])_(?![\\w])",
    "\\[([^\\]\\n]+)\\]\\(((?:[^()\\s]|\\([^()\\s]*\\))+)\\)",
    "(https?:\\/\\/[^\\s<>]+)",
  ].join("|"),
  "g",
);

function el<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  className?: string,
  ...children: (Node | string)[]
): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  if (className) node.className = className;
  node.append(...children);
  return node;
}

const isWebLink = (url: string) => /^https?:\/\//i.test(url);

function link(text: Node[] | string, url: string): HTMLElement {
  const a = el("a", "md-link", ...(typeof text === "string" ? [text] : text));
  a.dataset.href = url;
  a.title = url;
  return a;
}

function trimUrl(url: string): string {
  let end = url.replace(/[.,;:!?'"]+$/, "");
  while (end.endsWith(")") && (end.match(/\(/g)?.length ?? 0) < (end.match(/\)/g)?.length ?? 0)) {
    end = end.slice(0, -1).replace(/[.,;:!?'"]+$/, "");
  }
  return end;
}

function inline(text: string): Node[] {
  const out: Node[] = [];
  const re = new RegExp(INLINE.source, "g");
  let at = 0;
  for (let m = re.exec(text); m; m = re.exec(text)) {
    let end = m.index + m[0].length;
    let node: Node;
    if (m[2] !== undefined) {
      // One space each side is padding, as in `` `x` ``.
      const code = /^ .* $/.test(m[2]) && m[2].trim() ? m[2].slice(1, -1) : m[2];
      node = el("code", "md-inline", code);
    } else if (m[3] !== undefined || m[4] !== undefined) {
      node = el("strong", undefined, ...inline(m[3] ?? m[4]));
    } else if (m[5] !== undefined || m[6] !== undefined) {
      node = el("em", undefined, ...inline(m[5] ?? m[6]));
    } else if (m[7] !== undefined) {
      node = isWebLink(m[8]) ? link(inline(m[7]), m[8]) : document.createTextNode(m[7]);
    } else {
      const url = trimUrl(m[9]);
      end = m.index + url.length;
      re.lastIndex = end;
      node = link(url, url);
    }
    if (m.index > at) out.push(document.createTextNode(text.slice(at, m.index)));
    out.push(node);
    at = end;
  }
  if (at < text.length) out.push(document.createTextNode(text.slice(at)));
  return out;
}

function codeBlock(lang: string, body: string): HTMLElement {
  const copy = el("button", "md-copy");
  copy.type = "button";
  copy.title = "Copy";
  copy.setAttribute("aria-label", "Copy the code");
  copy.innerHTML = COPY_GLYPHS;
  return el(
    "div",
    "md-code",
    el("div", "md-code-head", el("span", "md-code-lang", lang), copy),
    el("pre", undefined, el("code", undefined, body)),
  );
}

interface Item {
  level: number;
  marker: string;
  text: string[];
}

function list(items: Item[]): HTMLElement {
  const ul = el("ul", "md-list");
  for (const item of items) {
    const li = el(
      "li",
      undefined,
      el("span", "md-mark", item.marker),
      el("span", "md-item", ...inline(item.text.join("\n"))),
    );
    li.style.setProperty("--level", String(item.level));
    ul.append(li);
  }
  return ul;
}

export function renderMarkdown(text: string): DocumentFragment {
  const out = document.createDocumentFragment();
  const lines = text.split("\n");
  let para: string[] = [];
  let items: Item[] = [];
  let indents: number[] = [];

  const flushPara = () => {
    if (para.length) out.append(el("p", undefined, ...inline(para.join("\n"))));
    para = [];
  };
  const flushList = () => {
    if (items.length) out.append(list(items));
    items = [];
    indents = [];
  };

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const fence = FENCE.exec(line);
    if (fence) {
      flushPara();
      flushList();
      const close = new RegExp(`^ {0,3}${fence[1][0]}{${fence[1].length},}\\s*$`);
      const body: string[] = [];
      for (i++; i < lines.length && !close.test(lines[i]); i++) body.push(lines[i]);
      out.append(codeBlock(fence[2], body.join("\n")));
      continue;
    }
    if (!line.trim()) {
      flushPara();
      flushList();
      continue;
    }
    const heading = HEADING.exec(line);
    if (heading) {
      flushPara();
      flushList();
      out.append(el("p", "md-heading", el("strong", undefined, ...inline(heading[1]))));
      continue;
    }
    if (RULE.test(line)) {
      flushPara();
      flushList();
      out.append(el("hr"));
      continue;
    }
    const item = ITEM.exec(line);
    if (item) {
      flushPara();
      const indent = item[1].replace(/\t/g, "    ").length;
      while (indents.length && indent < indents[indents.length - 1]) indents.pop();
      if (!indents.length || indent > indents[indents.length - 1]) indents.push(indent);
      const marker = /\d/.test(item[2]) ? item[2].replace(")", ".") : "•";
      items.push({ level: indents.length - 1, marker, text: [item[3]] });
      continue;
    }
    if (items.length && /^\s/.test(line)) {
      items[items.length - 1].text.push(line.trim());
      continue;
    }
    flushList();
    para.push(line);
  }
  flushPara();
  flushList();
  return out;
}
