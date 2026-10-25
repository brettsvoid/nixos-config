import "./player.css";
import { animate, motionValue } from "motion";
import { call, on, type MediaState } from "../../ipc";
import { lucide, TRANSPORT } from "../../icons";
import { setLine } from "../../marquee";
import { SPRING } from "../../motion";
import { fadeIn, stepWave, swell } from "../../wave";
import type { Widget } from "../view";

const AREA = { w: 156, h: 138 } as const;
const C = { x: 78, y: 78 } as const;
const RING = {
  r: 70,
  amp: 2,
  wavelength: 26,
  line: 4,
  tick: { h: 10, gap: 3 },
} as const;
const SPIN_SEC = 8;

const MUSIC = lucide(
  '<path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>',
);

const TEMPLATE =
  '<div class="pl-art"></div>' +
  '<div class="pl-face">' +
  `<div class="pl-area"><div class="pl-disc"><img alt=""><span class="pl-glyph icon">${MUSIC}</span></div>` +
  `<svg class="pl-ring" viewBox="0 0 ${AREA.w} ${AREA.h}"><path class="pl-rest"/><path class="pl-played"/><path class="pl-head"/><path class="pl-hit"/></svg></div>` +
  '<div class="pl-lines"><div class="pl-title marquee"><span></span></div>' +
  '<div class="pl-album marquee"><span></span></div><div class="pl-artist marquee"><span></span></div></div>' +
  '<div class="pl-transport"><span class="pl-source"><img alt=""></span>' +
  `<button class="pl-btn pl-prev" type="button" aria-label="Previous">${TRANSPORT.previous}</button>` +
  '<button class="pl-btn pl-play" type="button" aria-label="Play or pause"></button>' +
  `<button class="pl-btn pl-next" type="button" aria-label="Next">${TRANSPORT.next}</button></div>` +
  '<div class="pl-time"></div>' +
  "</div>";

function linesOf(m: MediaState | null): string[] {
  if (!m) return ["Nothing playing", "", ""];
  if (!m.controls) return [m.app, "Playing", ""];
  return [m.title, m.album, m.artist];
}

const clockText = (seconds: number) => {
  const s = Math.max(0, Math.floor(seconds));
  const ss = String(s % 60).padStart(2, "0");
  if (s < 3600) return `${Math.floor(s / 60)}:${ss}`;
  return `${Math.floor(s / 3600)}:${String(Math.floor(s / 60) % 60).padStart(2, "0")}:${ss}`;
};

const pt = (theta: number, r: number) =>
  `${(C.x + r * Math.cos(theta)).toFixed(2)} ${(C.y + r * Math.sin(theta)).toFixed(2)}`;
const thetaOf = (fraction: number) => Math.PI * (1 + fraction);
const arcPath = (from: number, to: number) =>
  to > from ? `M${pt(from, RING.r)}A${RING.r} ${RING.r} 0 0 1 ${pt(to, RING.r)}` : "";

// A small copy of the cover: scaled up across the card it is a soft wash. A CSS
// blur would do the same, but WebKit clips a filtered layer to a square, so its
// corners escape the card.
async function washOf(url: string): Promise<string> {
  const img = new Image();
  img.src = url;
  await img.decode();
  const canvas = document.createElement("canvas");
  canvas.width = canvas.height = 8;
  const ctx = canvas.getContext("2d")!;
  ctx.imageSmoothingQuality = "high";
  ctx.drawImage(img, 0, 0, 8, 8);
  return canvas.toDataURL();
}

export const player: Widget = (root) => {
  root.innerHTML = TEMPLATE;
  const geometry = {
    "--pl-area-w": AREA.w,
    "--pl-area-h": AREA.h,
    "--pl-cx": C.x,
    "--pl-cy": C.y,
    "--pl-line": RING.line,
  };
  for (const [name, px] of Object.entries(geometry)) root.style.setProperty(name, `${px}px`);
  const $ = <T extends Element>(sel: string) => root.querySelector<T>(sel)!;
  const artEl = $<HTMLElement>(".pl-art");
  const face = $<HTMLElement>(".pl-face");
  const disc = $<HTMLElement>(".pl-disc");
  const discImg = $<HTMLImageElement>(".pl-disc img");
  const ring = $<SVGSVGElement>(".pl-ring");
  const rest = $<SVGPathElement>(".pl-rest");
  const played = $<SVGPathElement>(".pl-played");
  const head = $<SVGPathElement>(".pl-head");
  $<SVGPathElement>(".pl-hit").setAttribute("d", arcPath(Math.PI, 2 * Math.PI));
  const lines = [".pl-title", ".pl-album", ".pl-artist"].map((s) => $<HTMLElement>(s));
  const source = $<HTMLImageElement>(".pl-source img");
  const prev = $<HTMLButtonElement>(".pl-prev");
  const play = $<HTMLButtonElement>(".pl-play");
  const next = $<HTMLButtonElement>(".pl-next");
  const timeEl = $<HTMLElement>(".pl-time");

  let media: MediaState | null = null;
  let visible = false;
  let anchor = { position: 0, at: 0 };
  let scrub: number | null = null;
  let art = { key: "", url: "" };
  let linesShown = "";

  const track = () => (media?.controls ? media : null);
  const seekable = () => (track()?.duration ?? 0) > 0;
  const live = () => !!track()?.playing && seekable();
  function fraction(): number {
    const t = track();
    if (!t || t.duration <= 0) return 0;
    if (scrub !== null) return scrub;
    const elapsed = t.playing ? (performance.now() - anchor.at) / 1000 : 0;
    return Math.min(1, Math.max(0, (anchor.position + elapsed) / t.duration));
  }

  const wave = { amp: 0, phase: 0, last: 0, raf: 0 };

  function paint() {
    const f = fraction();
    const t = track();
    const time =
      t && t.duration > 0
        ? `${clockText(f * t.duration)} / ${clockText(t.duration)}`
        : "-:-- / -:--";
    if (timeEl.textContent !== time) timeEl.textContent = time;
    if (!seekable()) {
      rest.setAttribute("d", arcPath(Math.PI, 2 * Math.PI));
      played.setAttribute("d", "");
      head.setAttribute("d", "");
      return;
    }
    const theta = thetaOf(f);
    const clear = (RING.line / 2 + RING.tick.gap + RING.line / 2) / RING.r;
    rest.setAttribute("d", arcPath(theta + clear, 2 * Math.PI));
    head.setAttribute(
      "d",
      `M${pt(theta, RING.r - RING.tick.h / 2)}L${pt(theta, RING.r + RING.tick.h / 2)}`,
    );
    const len = (theta - clear - Math.PI) * RING.r;
    if (len <= 0) {
      played.setAttribute("d", "");
      return;
    }
    let d = "";
    for (let s = 0; ; s = Math.min(s + 2, len)) {
      const grow = swell(s);
      const r =
        RING.r + wave.amp * grow * Math.sin((2 * Math.PI * s) / RING.wavelength + wave.phase);
      d += (s === 0 ? "M" : "L") + pt(Math.PI + s / RING.r, r);
      if (s >= len) break;
    }
    played.setAttribute("d", d);
    played.style.opacity = String(fadeIn(len));
  }

  function frame(now: number) {
    wave.raf = 0;
    const moving = live();
    stepWave(wave, now, moving, RING.amp);
    paint();
    if (visible && (moving || wave.amp > 0)) wave.raf = requestAnimationFrame(frame);
  }

  function wake() {
    if (!visible || wave.raf) return;
    wave.last = 0;
    wave.raf = requestAnimationFrame(frame);
  }

  const spin = motionValue(0);
  spin.on("change", (deg) => (disc.style.transform = `rotate(${deg}deg)`));
  let turn: ReturnType<typeof animate> | null = null;
  let spinning = false;

  function turnDisc(on: boolean) {
    if (on && spinning) return;
    turn?.stop();
    spinning = on;
    const deg = ((spin.get() % 360) + 360) % 360;
    spin.jump(deg);
    if (on) {
      turn = animate(spin, [deg, deg + 360], {
        duration: SPIN_SEC,
        ease: "linear",
        repeat: Infinity,
      });
    } else {
      turn = deg ? animate(spin, deg > 180 ? 360 : 0, SPRING.drawer) : null;
    }
  }

  function freezeDisc() {
    turn?.stop();
    turn = null;
    spinning = false;
  }

  async function loadArt(key: string) {
    if (key === art.key) return;
    art = { key, url: "" };
    showArt("", "");
    if (!key) return;
    const url = await call("media_art", { key }).catch(() => "");
    if (art.key !== key || !url) return;
    const wash = await washOf(url).catch(() => "");
    if (art.key !== key) return;
    art.url = url;
    showArt(url, wash);
    render();
  }

  function showArt(url: string, wash: string) {
    root.classList.toggle("has-art", !!url);
    artEl.style.backgroundImage = url ? `url("${url}")` : "";
    face.style.setProperty("--pl-wash", wash ? `url("${wash}")` : "none");
  }

  function setSrc(img: HTMLImageElement, src: string) {
    if (img.getAttribute("src") !== src) img.setAttribute("src", src);
  }

  function render() {
    if (!visible) return;
    const text = linesOf(media);
    const t = track();
    void loadArt(t?.artKey ?? "");

    const discShows = t && art.url ? "cover" : media && !t && media.icon ? "app" : "glyph";
    disc.dataset.shows = discShows;
    setSrc(discImg, discShows === "cover" ? art.url : discShows === "app" ? media!.icon : "");
    setSrc(source, media?.icon ?? "");
    source.parentElement!.hidden = !media?.icon;

    const key = text.join("\n");
    if (key !== linesShown) {
      linesShown = key;
      text.forEach((line, i) => {
        setLine(lines[i], line);
        lines[i].title = line;
      });
    }

    for (const b of [prev, play, next]) b.disabled = !t;
    play.innerHTML = t?.playing ? TRANSPORT.pause : TRANSPORT.play;
    play.classList.toggle("playing", !!t?.playing);
    root.classList.toggle("seekable", seekable());
    root.classList.toggle("still", !media?.playing);

    turnDisc(!!t?.playing && discShows === "cover");
    paint();
    if (live() || wave.amp > 0) wake();
  }

  function update(next: MediaState | null) {
    media = next;
    if (scrub === null) anchor = { position: next?.position ?? 0, at: performance.now() };
    render();
  }

  play.addEventListener("click", () => {
    const t = track();
    if (!t) return;
    update({ ...t, position: fraction() * t.duration, playing: !t.playing });
    call("media_toggle").catch(() => {});
  });
  prev.addEventListener("click", () => call("media_previous").catch(() => {}));
  next.addEventListener("click", () => call("media_next").catch(() => {}));

  function fractionAt(e: PointerEvent): number {
    const box = ring.getBoundingClientRect();
    const x = e.clientX - box.left - C.x;
    const y = e.clientY - box.top - C.y;
    const theta = Math.atan2(y, x);
    if (theta > 0) return x < 0 ? 0 : 1;
    return (theta + Math.PI) / Math.PI;
  }

  ring.addEventListener("pointerdown", (e) => {
    if (!seekable()) return;
    ring.setPointerCapture(e.pointerId);
    scrub = fractionAt(e);
    paint();
  });
  ring.addEventListener("pointermove", (e) => {
    if (scrub === null) return;
    scrub = fractionAt(e);
    paint();
  });
  ring.addEventListener("pointerup", (e) => {
    if (scrub === null) return;
    scrub = null;
    const t = track();
    if (t) {
      const f = fractionAt(e);
      anchor = { position: f * t.duration, at: performance.now() };
      call("media_seek", { fraction: f }).catch(() => {});
    }
    paint();
  });
  ring.addEventListener("pointercancel", () => {
    scrub = null;
    paint();
  });

  on("media", update);
  call("media_state").then(update).catch(() => {});

  return {
    show() {
      visible = true;
      render();
    },
    hide() {
      visible = false;
      cancelAnimationFrame(wave.raf);
      wave.raf = 0;
      freezeDisc();
      root.classList.add("still");
    },
  };
};
