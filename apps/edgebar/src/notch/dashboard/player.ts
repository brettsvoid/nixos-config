import "./player.css";
import { animate, motionValue } from "motion";
import { call, on, type MediaState } from "../../ipc";
import { lucide, TRANSPORT } from "../../icons";
import { setLine } from "../../marquee";
import { SPRING } from "../../motion";
import type { Widget } from "../view";

// The disc area, in px: the 120 px cover disc, with the seek ring over its top
// half. It is the ring SVG's viewBox, and its centre is the disc's (player.css).
const AREA = { w: 156, h: 138 } as const;
const C = { x: 78, y: 78 } as const;
// The ring, after the collapsed notch's playhead: a sine over the played part
// that flattens when paused, a flat rule for the rest, a radial tick for the
// head. `wavelength` and the tick are in px along the ring; `speed` is rad/s;
// `ease` is the per-frame approach to the target amplitude.
const RING = {
  r: 70,
  amp: 2,
  wavelength: 26,
  speed: 2.4,
  ease: 0.15,
  line: 4, // also the tick's width; keep in step with player.css
  tick: { h: 10, gap: 3 }, // `gap` clears it either side
  rampPx: 8, // px of played ring over which the wave swells to full amplitude
  fadeInPx: 3, // px over which a short played part fades up (its round caps pop otherwise)
} as const;
const SPIN_SEC = 8; // one turn of the disc while playing

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

// The three lines for each kind of source: nothing, an audible app that can
// only be named, or a track from a player edgebar can drive (Spotify, Music).
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

// A point on a circle about the disc's centre; angles run clockwise from 3
// o'clock, so the ring's top half is π (9 o'clock) to 2π.
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

// Column 1 (ambxst FullPlayer): the cover as a turning disc under a seek ring,
// the track's lines and the transport. It follows the `media` event, which
// carries the media slot whatever wins the collapsed notch.
export const player: Widget = (root) => {
  root.innerHTML = TEMPLATE;
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
  // Where the track was when Rust last said, and when that landed, so the head
  // advances between its 2 s reads. `scrub` is the fraction under a dragging
  // pointer, which wins until release.
  let anchor = { position: 0, at: 0 };
  let scrub: number | null = null;
  let art = { key: "", url: "" };
  let linesShown = ""; // the text setLine last measured, so a position tick doesn't restart the marquee

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

  // ---- the ring and the clock, painted per frame while the wave moves ----
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
    // The tick's half-width, its clearance and a round cap, as an angle.
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
      const grow = Math.min(1, s / RING.rampPx);
      const r =
        RING.r + wave.amp * grow * Math.sin((2 * Math.PI * s) / RING.wavelength + wave.phase);
      d += (s === 0 ? "M" : "L") + pt(Math.PI + s / RING.r, r);
      if (s >= len) break;
    }
    played.setAttribute("d", d);
    played.style.opacity = String(Math.min(1, len / RING.fadeInPx));
  }

  function frame(now: number) {
    wave.raf = 0;
    const dt = wave.last ? Math.min(0.05, (now - wave.last) / 1000) : 0;
    wave.last = now;
    const moving = live();
    wave.amp += ((moving ? RING.amp : 0) - wave.amp) * RING.ease;
    if (!moving && wave.amp < 0.05) wave.amp = 0; // settle, don't wobble
    if (moving) wave.phase += RING.speed * dt;
    paint();
    if (visible && (moving || wave.amp > 0)) wave.raf = requestAnimationFrame(frame);
  }

  function wake() {
    if (!visible || wave.raf) return;
    wave.last = 0;
    wave.raf = requestAnimationFrame(frame);
  }

  // ---- the disc: a turn every SPIN_SEC while playing, upright at rest ----
  const spin = motionValue(0);
  spin.on("change", (deg) => (disc.style.transform = `rotate(${deg}deg)`));
  let turn: ReturnType<typeof animate> | null = null;
  let spinning = false; // `turn` is the endless spin, not the settle after it

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
      // Back to the nearer upright, as ambxst's disc does.
      turn = deg ? animate(spin, deg > 180 ? 360 : 0, SPRING.drawer) : null;
    }
  }

  function freezeDisc() {
    turn?.stop();
    turn = null;
    spinning = false;
  }

  // ---- cover art: fetched once per key; the card's frame and wash ----
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

  // ---- render: all of it from `media`, while the view shows ----
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
    // Marquees run only while playing, like every other motion here.
    root.classList.toggle("still", !media?.playing);

    // Only a cover turns: a spinning glyph or app icon reads as broken.
    turnDisc(!!t?.playing && discShows === "cover");
    paint();
    // A wave left mid-swell by a hide still has to flatten.
    if (live() || wave.amp > 0) wake();
  }

  function update(next: MediaState | null) {
    media = next;
    if (scrub === null) anchor = { position: next?.position ?? 0, at: performance.now() };
    render();
  }

  // ---- input ----
  play.addEventListener("click", () => {
    const t = track();
    if (!t) return;
    // Flip now so the button and the ring answer at once; Rust re-reads the
    // player straight after the command and publishes the real state.
    update({ ...t, position: fraction() * t.duration, playing: !t.playing });
    call("media_toggle").catch(() => {});
  });
  prev.addEventListener("click", () => call("media_previous").catch(() => {}));
  next.addEventListener("click", () => call("media_next").catch(() => {}));

  // Seeking: the pointer's angle about the disc's centre, over the top half.
  // Below the centre line it pins to the nearer end.
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
      linesShown = ""; // measure again: a hidden line measures 0
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
