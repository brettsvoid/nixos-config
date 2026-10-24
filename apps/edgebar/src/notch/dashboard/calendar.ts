import "./calendar.css";
import { lucide } from "../../icons";
import { current, onChange, type Settings } from "../../settings";
import { wheelStepper } from "../../wheel";
import type { Widget } from "../view";

const WHEEL_PX = 300;
const PREV = lucide('<path d="m15 18-6-6 6-6"/>');
const NEXT = lucide('<path d="m9 18 6-6-6-6"/>');

interface Month {
  year: number;
  month: number;
}

const monthOf = (d: Date): Month => ({ year: d.getFullYear(), month: d.getMonth() });

const weekStartOf = (s: Settings) => (s.calendar.weekStart === "sunday" ? 0 : 1);

const sameDay = (a: Date, b: Date) =>
  a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();

function weeks(m: Month, weekStart: number): Date[][] {
  const offset = (new Date(m.year, m.month, 1).getDay() - weekStart + 7) % 7;
  return Array.from({ length: 6 }, (_, w) =>
    Array.from({ length: 7 }, (_, d) => new Date(m.year, m.month, 1 - offset + w * 7 + d)),
  );
}

const initial = (day: number) =>
  new Date(2024, 0, 7 + day).toLocaleDateString(undefined, { weekday: "narrow" });

const setText = (el: Element, text: string) => {
  if (el.textContent !== text) el.textContent = text;
};

export const calendar: Widget = (root) => {
  const cell = '<span class="cal-day"><span></span></span>';
  root.innerHTML =
    '<div class="cal-head"><button class="cal-title" type="button" title="Back to today"></button>' +
    `<button class="cal-step" type="button" data-step="-1" aria-label="Previous month">${PREV}</button>` +
    `<button class="cal-step" type="button" data-step="1" aria-label="Next month">${NEXT}</button></div>` +
    `<div class="cal-grid"><div class="cal-days">${"<span></span>".repeat(7)}</div>` +
    `<div class="cal-week">${cell.repeat(7)}</div>`.repeat(6) +
    "</div>";
  const title = root.querySelector<HTMLButtonElement>(".cal-title")!;
  const grid = root.querySelector<HTMLElement>(".cal-grid")!;
  const initials = [...root.querySelectorAll(".cal-days > span")];
  const rows = [...root.querySelectorAll<HTMLElement>(".cal-week")];
  const cells = rows.map((row) => [...row.querySelectorAll<HTMLElement>(".cal-day")]);

  let shown = monthOf(new Date());
  let visible = false;
  let midnight = 0;

  function render() {
    if (!visible) return;
    const today = new Date();
    const weekStart = weekStartOf(current());
    setText(
      title,
      new Date(shown.year, shown.month, 1).toLocaleDateString(undefined, { month: "long", year: "numeric" }),
    );
    initials.forEach((el, i) => setText(el, initial((weekStart + i) % 7)));
    weeks(shown, weekStart).forEach((week, w) => {
      rows[w].classList.toggle("current", week.some((d) => sameDay(d, today)));
      week.forEach((d, i) => {
        const el = cells[w][i];
        setText(el.firstElementChild!, String(d.getDate()));
        el.classList.toggle("out", d.getMonth() !== shown.month);
        el.classList.toggle("today", sameDay(d, today));
      });
    });
  }

  function step(months: number) {
    shown = monthOf(new Date(shown.year, shown.month + months, 1));
    render();
  }

  function armMidnight() {
    clearTimeout(midnight);
    const now = new Date();
    const next = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
    midnight = window.setTimeout(() => {
      if (shown.year === now.getFullYear() && shown.month === now.getMonth()) shown = monthOf(new Date());
      render();
      armMidnight();
    }, next.getTime() - now.getTime() + 500);
  }

  title.addEventListener("click", () => {
    shown = monthOf(new Date());
    render();
  });
  for (const btn of root.querySelectorAll<HTMLElement>(".cal-step")) {
    btn.addEventListener("click", () => step(Number(btn.dataset.step)));
  }
  const steps = wheelStepper(WHEEL_PX, (e) => e.deltaY);
  grid.addEventListener(
    "wheel",
    (e) => {
      e.preventDefault();
      const n = steps(e);
      if (n) step(n);
    },
    { passive: false },
  );
  onChange(render);

  return {
    open() {
      shown = monthOf(new Date());
    },
    show() {
      visible = true;
      render();
      armMidnight();
    },
    hide() {
      visible = false;
      clearTimeout(midnight);
    },
  };
};
