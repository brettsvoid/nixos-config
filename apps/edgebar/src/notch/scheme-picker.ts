import "./scheme-picker.css";
import { el } from "../dom";
import { lucide } from "../icons";
import SCHEMES from "../schemes.json";

const CHEVRON = lucide('<path d="m6 9 6 6 6-6"/>');

export function schemePicker(): { el: HTMLElement; select: HTMLSelectElement } {
  const select = el("select");
  for (const scheme of SCHEMES) {
    const option = el("option", "", scheme.replace("scheme-", "").replace(/-/g, " "));
    option.value = scheme;
    select.append(option);
  }
  const box = el("span", "scheme-picker", select);
  box.insertAdjacentHTML("beforeend", `<span class="icon">${CHEVRON}</span>`);
  return { el: box, select };
}
