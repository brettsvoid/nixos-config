//! The wallpaper folder, the OLED palette and Tint.
//!
//! Tint repaints the desktop picture in the theme's own colours, after
//! ambxst's `palette.frag`: each pixel is replaced by the average of the
//! palette colours weighted `exp(-K * distance^2)`, a soft snap to the nearest
//! colour. The palette comes from the ORIGINAL picture (matugen, as before);
//! the tinted copy only ever lands on the desktop. So the app has to tell the
//! two apart:
//!
//!   * a tinted copy sits in `~/.cache/edgebar/tinted/` beside a `.src` sidecar
//!     naming its original, and `original_of` undoes the swap wherever
//!     something asks "which wallpaper is this?";
//!   * `converge` is the one place that touches the desktop. It looks at what
//!     is on screen, works out what should be, and changes it only if they
//!     differ, so every trigger (a pick, a scheme or OLED change, the launchd
//!     watcher firing on our own change) can run it again harmlessly.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Mutex;

pub type Rgb = [u8; 3];

/// How sharply a pixel sticks to its nearest palette colour. ambxst uses 20 over
/// about 26 colours; this palette is a handful plus a neutral ramp, so the
/// same value gives the same posterised-but-smooth look.
const SHARPNESS: f32 = 20.0;

/// Bumped when the tint's look changes, so cached copies are rebuilt.
const TINT_VERSION: u8 = 1;

/// Picture types the wallpapers view lists. Tint decodes all but HEIC.
const IMAGE_KINDS: [&str; 5] = ["jpg", "jpeg", "png", "webp", "heic"];

// ───────────────────────── config ───────────────────────────────────

/// The `wallpaper` block of config.json. Defaults live in
/// config.default.json only; an absent key reads them from there.
#[derive(Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct WallpaperConfig {
    /// Where the pictures are, `~` allowed. Subfolders one level down are listed too.
    #[serde(default = "default_folder")]
    pub folder: String,
    /// Repaint the desktop picture in the theme's colours.
    #[serde(default = "default_tint")]
    pub tint: bool,
}

impl Default for WallpaperConfig {
    fn default() -> Self {
        Self {
            folder: default_folder(),
            tint: default_tint(),
        }
    }
}

/// A value from the bundled config.default.json, by JSON pointer. Read as raw
/// JSON, not through `Config`, so a missing key can't recurse into a default.
fn bundled(pointer: &str) -> Option<serde_json::Value> {
    let root: serde_json::Value =
        serde_json::from_str(include_str!("../config.default.json")).ok()?;
    root.pointer(pointer).cloned()
}

fn default_folder() -> String {
    bundled("/wallpaper/folder")
        .and_then(|v| v.as_str().map(str::to_owned))
        .unwrap_or_default()
}

fn default_tint() -> bool {
    bundled("/wallpaper/tint")
        .and_then(|v| v.as_bool())
        .unwrap_or(false)
}

pub fn default_oled() -> bool {
    bundled("/oled").and_then(|v| v.as_bool()).unwrap_or(false)
}

/// `~` and `~/x` against `home`; anything else is taken as it is.
fn expand_home(folder: &str, home: &Path) -> PathBuf {
    match folder.strip_prefix('~') {
        Some("") => home.to_path_buf(),
        Some(rest) if rest.starts_with('/') => home.join(rest.trim_start_matches('/')),
        _ => PathBuf::from(folder),
    }
}

/// The configured wallpaper folder, read fresh so a settings change shows on
/// the next listing.
pub fn folder() -> Option<PathBuf> {
    let home = PathBuf::from(std::env::var_os("HOME")?);
    Some(expand_home(&super::load_config().wallpaper.folder, &home))
}

/// Whether `wallpaper.tint` is on, read fresh like `folder`.
pub fn tint_on() -> bool {
    super::load_config().wallpaper.tint
}

// ───────────────────────── the folder ───────────────────────────────

/// One picture found under the wallpaper folder.
pub struct Found {
    pub path: PathBuf,
    pub name: String,
    /// The top-level subfolder it sits in, "" at the folder's root.
    pub folder: String,
    /// Lower-case file extension.
    pub kind: String,
}

fn image_kind(path: &Path) -> Option<String> {
    let ext = path.extension()?.to_str()?.to_ascii_lowercase();
    IMAGE_KINDS.contains(&ext.as_str()).then_some(ext)
}

fn is_hidden(path: &Path) -> bool {
    path.file_name()
        .and_then(|n| n.to_str())
        .is_none_or(|n| n.starts_with('.'))
}

/// The pictures in `root` and one level of subfolders, root first, then by
/// subfolder and name. Anything unreadable is skipped.
pub fn scan(root: &Path) -> Vec<Found> {
    let mut found = Vec::new();
    let mut collect = |dir: &Path, folder: &str| {
        let Ok(entries) = std::fs::read_dir(dir) else {
            return Vec::new();
        };
        let mut subdirs = Vec::new();
        for path in entries.filter_map(|e| e.ok().map(|e| e.path())) {
            if is_hidden(&path) {
                continue;
            }
            if path.is_dir() {
                subdirs.push(path);
                continue;
            }
            let (Some(kind), Some(name)) = (
                image_kind(&path),
                path.file_name().and_then(|n| n.to_str()).map(str::to_owned),
            ) else {
                continue;
            };
            found.push(Found {
                path,
                name,
                folder: folder.to_string(),
                kind,
            });
        }
        subdirs
    };
    for dir in collect(root, "") {
        let Some(name) = dir.file_name().and_then(|n| n.to_str()) else {
            continue;
        };
        collect(&dir, name);
    }
    found.sort_by(|a, b| (&a.folder, &a.name).cmp(&(&b.folder, &b.name)));
    found
}

// ───────────────────────── OLED ─────────────────────────────────────

/// The dark palette with its surface (`base`) pure black. Roles resolve from
/// the palette afterwards, so everything built on the surface follows.
pub fn blacken_base(palette: &HashMap<String, String>) -> HashMap<String, String> {
    let mut out = palette.clone();
    if let Some(base) = out.get_mut("base") {
        *base = "#000000".to_string();
    }
    out
}

// ───────────────────────── the tint ─────────────────────────────────

fn parse_hex(hex: &str) -> Option<Rgb> {
    let h = hex.trim().strip_prefix('#')?;
    if h.len() != 6 || !h.is_ascii() {
        return None;
    }
    let byte = |i: usize| u8::from_str_radix(&h[i..i + 2], 16).ok();
    Some([byte(0)?, byte(2)?, byte(4)?])
}

fn mix(a: Rgb, b: Rgb, t: f32) -> Rgb {
    std::array::from_fn(|i| (a[i] as f32 + (b[i] as f32 - a[i] as f32) * t).round() as u8)
}

/// The colours a picture is repainted with: the palette's own, plus a ramp from
/// its surface to its text colour so the picture keeps its light and dark. The
/// palette alone is about six colours, mostly accents, and would flatten every
/// mid-tone into one of them.
pub fn tint_colours(palette: &HashMap<String, String>) -> Vec<Rgb> {
    let mut colours: Vec<Rgb> = palette.values().filter_map(|v| parse_hex(v)).collect();
    if let (Some(base), Some(text)) = (
        palette.get("base").and_then(|v| parse_hex(v)),
        palette.get("text").and_then(|v| parse_hex(v)),
    ) {
        colours.extend([0.2, 0.4, 0.6, 0.8].map(|t| mix(base, text, t)));
    }
    colours.sort_unstable();
    colours.dedup();
    colours
}

/// Replace every pixel of an RGB8 buffer by the palette-weighted average of
/// `colours`. Split across the machine's cores: at 2880 px wide it is
/// millions of pixels times a dozen `exp` calls.
pub fn tint_rgb(buf: &mut [u8], colours: &[Rgb], sharpness: f32) {
    if colours.is_empty() {
        return;
    }
    let palette: Vec<[f32; 3]> = colours
        .iter()
        .map(|c| c.map(|v| v as f32 / 255.0))
        .collect();
    let threads = std::thread::available_parallelism().map_or(1, |n| n.get());
    let chunk = (buf.len() / 3).div_ceil(threads).max(1) * 3;
    std::thread::scope(|scope| {
        for part in buf.chunks_mut(chunk) {
            let palette = &palette;
            scope.spawn(move || {
                for px in part.chunks_exact_mut(3) {
                    let c = [
                        px[0] as f32 / 255.0,
                        px[1] as f32 / 255.0,
                        px[2] as f32 / 255.0,
                    ];
                    let mut sum = [0.0f32; 3];
                    let mut total = 0.0f32;
                    for p in palette {
                        let d = [c[0] - p[0], c[1] - p[1], c[2] - p[2]];
                        let w = (-sharpness * (d[0] * d[0] + d[1] * d[1] + d[2] * d[2])).exp();
                        sum[0] += p[0] * w;
                        sum[1] += p[1] * w;
                        sum[2] += p[2] * w;
                        total += w;
                    }
                    // The exp underflows to 0 for every colour on a pixel far from the
                    // whole palette; keep the pixel rather than divide by nothing.
                    if total > 1e-12 {
                        for i in 0..3 {
                            px[i] = (sum[i] / total * 255.0).round().clamp(0.0, 255.0) as u8;
                        }
                    }
                }
            });
        }
    });
}

/// The size to render a picture at: just enough to cover the largest screen,
/// and never an upscale. A 6400 px source needs no more pixels than the panel
/// has, and the tint's cost is per pixel.
fn cover_size(src: (u32, u32), screen: (u32, u32)) -> (u32, u32) {
    let scale = (screen.0 as f64 / src.0 as f64).max(screen.1 as f64 / src.1 as f64);
    if scale >= 1.0 {
        return src;
    }
    (
        ((src.0 as f64 * scale).round() as u32).max(1),
        ((src.1 as f64 * scale).round() as u32).max(1),
    )
}

/// 64-bit FNV-1a, stable across runs and Rust versions (unlike `DefaultHasher`),
/// so a copy made last session is found again.
fn fnv1a(parts: &[&[u8]]) -> u64 {
    let mut hash = 0xcbf29ce484222325u64;
    for part in parts {
        for byte in *part {
            hash ^= *byte as u64;
            hash = hash.wrapping_mul(0x100000001b3);
        }
        hash ^= 0xff; // keep ("ab", "c") apart from ("a", "bc")
        hash = hash.wrapping_mul(0x100000001b3);
    }
    hash
}

/// A name that changes with everything that changes the result: the picture
/// (path, mtime, size), the palette, the screen it is sized for and the
/// algorithm. macOS keeps a wallpaper it has already loaded for a path, so a
/// repainted copy must never reuse a name. It also means a copy already on disk
/// is found without decoding the picture again.
fn tinted_name(
    original: &Path,
    mtime: u64,
    len: u64,
    colours: &[Rgb],
    screen: (u32, u32),
) -> String {
    let flat: Vec<u8> = colours.iter().flatten().copied().collect();
    let hash = fnv1a(&[
        original.as_os_str().as_encoded_bytes(),
        &mtime.to_le_bytes(),
        &len.to_le_bytes(),
        &flat,
        &screen.0.to_le_bytes(),
        &screen.1.to_le_bytes(),
        &[TINT_VERSION],
    ]);
    format!("tint-{hash:016x}.png")
}

pub fn tinted_dir() -> Option<PathBuf> {
    std::env::var_os("HOME").map(|home| Path::new(&home).join(".cache/edgebar/tinted"))
}

fn sidecar(tinted: &Path) -> PathBuf {
    let mut name = tinted.as_os_str().to_owned();
    name.push(".src");
    PathBuf::from(name)
}

/// What a desktop picture really is: the original of a tinted copy in `dir`,
/// else the picture itself.
fn original_in(dir: &Path, picture: &str) -> String {
    let path = Path::new(picture);
    if path.parent() == Some(dir) {
        if let Ok(src) = std::fs::read_to_string(sidecar(path)) {
            let src = src.trim();
            if !src.is_empty() {
                return src.to_string();
            }
        }
    }
    picture.to_string()
}

/// `picture` with a tinted copy mapped back to its original. Everything that
/// asks which wallpaper is current (the grid's highlight, the matugen run for
/// a new scheme) goes through this, so none of them sees the tinted copy.
pub fn original_of(picture: &str) -> String {
    match tinted_dir() {
        Some(dir) => original_in(&dir, picture),
        None => picture.to_string(),
    }
}

/// Delete everything in `dir` except `keep` and its sidecar.
fn prune(dir: &Path, keep: Option<&Path>) {
    let Ok(entries) = std::fs::read_dir(dir) else {
        return;
    };
    let keep_sidecar = keep.map(sidecar);
    for path in entries.filter_map(|e| e.ok().map(|e| e.path())) {
        if Some(&path) != keep.map(Path::to_path_buf).as_ref()
            && Some(&path) != keep_sidecar.as_ref()
        {
            let _ = std::fs::remove_file(path);
        }
    }
}

fn mtime_secs(path: &Path) -> (u64, u64) {
    let Ok(meta) = std::fs::metadata(path) else {
        return (0, 0);
    };
    let secs = meta
        .modified()
        .ok()
        .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
        .map_or(0, |d| d.as_secs());
    (secs, meta.len())
}

/// Write the tinted copy of `original` into `dir` and return its path. A copy
/// already there for this picture and palette is reused. `Err` says why the
/// picture can't be tinted.
fn ensure_tinted(
    dir: &Path,
    original: &Path,
    colours: &[Rgb],
    screen: (u32, u32),
) -> Result<PathBuf, String> {
    use image::{DynamicImage, ImageDecoder, ImageEncoder, ImageReader};

    if image_kind(original).as_deref() == Some("heic") {
        return Err("HEIC can't be decoded here".to_string());
    }
    let (mtime, len) = mtime_secs(original);
    let target = dir.join(tinted_name(original, mtime, len, colours, screen));
    if target.exists() && sidecar(&target).exists() {
        return Ok(target);
    }

    let mut decoder = ImageReader::open(original)
        .and_then(|r| r.with_guessed_format())
        .map_err(|e| e.to_string())?
        .into_decoder()
        .map_err(|e| e.to_string())?;
    let orientation = decoder.orientation().map_err(|e| e.to_string())?;
    let mut img = DynamicImage::from_decoder(decoder).map_err(|e| e.to_string())?;
    img.apply_orientation(orientation);
    let size = cover_size((img.width(), img.height()), screen);
    let mut rgb = if size == (img.width(), img.height()) {
        img.into_rgb8()
    } else {
        img.resize_exact(size.0, size.1, image::imageops::FilterType::Triangle)
            .into_rgb8()
    };
    tint_rgb(&mut rgb, colours, SHARPNESS);

    std::fs::create_dir_all(dir).map_err(|e| e.to_string())?;
    let tmp = target.with_extension("png.tmp");
    let file = std::fs::File::create(&tmp).map_err(|e| e.to_string())?;
    image::codecs::png::PngEncoder::new_with_quality(
        std::io::BufWriter::new(file),
        image::codecs::png::CompressionType::Fast,
        image::codecs::png::FilterType::Sub,
    )
    .write_image(&rgb, size.0, size.1, image::ExtendedColorType::Rgb8)
    .map_err(|e| e.to_string())?;
    std::fs::write(sidecar(&target), original.as_os_str().as_encoded_bytes())
        .map_err(|e| e.to_string())?;
    std::fs::rename(&tmp, &target).map_err(|e| e.to_string())?;
    Ok(target)
}

// ───────────────────────── the desktop ──────────────────────────────

/// What to set on the desktop, if anything. `shown` is the picture on screen,
/// `original` the picture it stands for, `tinted` the copy to show when tint
/// is on (None when it couldn't be made). Pure, so the cases are testable.
fn desktop_target(
    tint: bool,
    shown: &str,
    original: &str,
    tinted: Option<&Path>,
) -> Option<PathBuf> {
    let want = match (tint, tinted) {
        (true, Some(copy)) => copy.to_path_buf(),
        _ => PathBuf::from(original),
    };
    (Path::new(shown) != want).then_some(want)
}

/// One desktop change at a time, so a pick and the re-tints that its own
/// palette change triggers can't interleave.
static DESKTOP: Mutex<()> = Mutex::new(());
/// A converge is already waiting for `DESKTOP`; another would find the same
/// state.
static QUEUED: AtomicBool = AtomicBool::new(false);

/// The pixel size of the largest screen. NSScreen is read on the main thread.
#[cfg(target_os = "macos")]
fn largest_screen<R: tauri::Runtime>(app: &tauri::AppHandle<R>) -> (u32, u32) {
    const FALLBACK: (u32, u32) = (3840, 2160);
    let (tx, rx) = std::sync::mpsc::channel();
    let sent = app.run_on_main_thread(move || {
        let Some(mtm) = objc2::MainThreadMarker::new() else {
            return;
        };
        let sizes: Vec<(u32, u32)> = objc2_app_kit::NSScreen::screens(mtm)
            .iter()
            .map(|s| {
                let (frame, scale) = (s.frame(), s.backingScaleFactor());
                (
                    (frame.size.width * scale).round() as u32,
                    (frame.size.height * scale).round() as u32,
                )
            })
            .collect();
        let _ = tx.send(sizes);
    });
    if sent.is_err() {
        return FALLBACK;
    }
    rx.recv_timeout(std::time::Duration::from_secs(2))
        .ok()
        .and_then(|sizes| sizes.into_iter().max_by_key(|(w, h)| *w as u64 * *h as u64))
        .unwrap_or(FALLBACK)
}

#[cfg(not(target_os = "macos"))]
fn largest_screen<R: tauri::Runtime>(_app: &tauri::AppHandle<R>) -> (u32, u32) {
    (3840, 2160)
}

/// Make the desktop show what config says: the tinted copy of the original
/// picture with `tint` on, the original with it off. `dir` holds the copies.
/// `pick` is a picture the user has just chosen, not yet on screen. Caller
/// holds `DESKTOP`.
fn converge<R: tauri::Runtime>(
    app: &tauri::AppHandle<R>,
    tint: bool,
    dir: &Path,
    pick: Option<&str>,
) {
    use tauri::Manager;

    // Tint off and none of our copies about: nothing on the desktop to undo.
    let has_copies = std::fs::read_dir(dir).is_ok_and(|mut d| d.next().is_some());
    if !tint && pick.is_none() && !has_copies {
        return;
    }
    let (command, colours) = {
        let state = app.state::<Mutex<super::ThemeState>>();
        let ts = state.lock().unwrap();
        (ts.wallpaper_command.clone(), tint_colours(&ts.palette()))
    };
    let shown = super::query_desktop_picture(&command);
    let original = pick.map_or_else(|| original_in(dir, &shown), str::to_owned);
    if original.is_empty() {
        return;
    }

    let tinted = if tint {
        match ensure_tinted(dir, Path::new(&original), &colours, largest_screen(app)) {
            Ok(path) => Some(path),
            Err(why) => {
                eprintln!("edgebar: tint skipped for {original}: {why}");
                None
            }
        }
    } else {
        None
    };
    if let Some(target) = desktop_target(tint, &shown, &original, tinted.as_deref()) {
        // The launchd watcher re-themes from whatever the desktop shows when its
        // plist changes; the marker tells it this change is ours.
        super::touch_inapp_marker();
        let set = std::process::Command::new(&command)
            .arg("all")
            .arg(&target)
            .status();
        // Still showing the old copy: keep it.
        if !set.is_ok_and(|s| s.success()) {
            return;
        }
    }
    prune(dir, tinted.as_deref());
}

/// Re-run `converge` in the background: the palette, `wallpaper.tint` or the
/// OLED switch may have changed. Cheap when nothing did.
pub fn spawn_converge(app: &tauri::AppHandle) {
    if QUEUED.swap(true, Ordering::SeqCst) {
        return;
    }
    let app = app.clone();
    tauri::async_runtime::spawn_blocking(move || {
        let _desktop = DESKTOP.lock().unwrap_or_else(|e| e.into_inner());
        QUEUED.store(false, Ordering::SeqCst);
        if let Some(dir) = tinted_dir() {
            converge(&app, tint_on(), &dir, None);
        }
    });
}

/// Pick `path` with tint on: take its palette first, so the copy is painted
/// from the colours this picture gets, then put the tinted copy on the
/// desktop. The original is never shown, so the desktop doesn't flash it.
pub fn spawn_pick(app: &tauri::AppHandle, theme_command: String, path: String) {
    let app = app.clone();
    tauri::async_runtime::spawn_blocking(move || {
        let _desktop = DESKTOP.lock().unwrap_or_else(|e| e.into_inner());
        super::theme_from_wallpaper(&app, &theme_command, &path, true);
        if let Some(dir) = tinted_dir() {
            converge(&app, true, &dir, Some(&path));
        }
    });
}

#[cfg(test)]
mod tests {
    use super::*;

    fn palette(pairs: &[(&str, &str)]) -> HashMap<String, String> {
        pairs
            .iter()
            .map(|(k, v)| (k.to_string(), v.to_string()))
            .collect()
    }

    fn scratch(name: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!(
            "edgebar-wallpapers-{name}-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn home_is_expanded_only_as_a_leading_tilde() {
        let home = Path::new("/Users/brett");
        assert_eq!(
            expand_home("~/Pictures/Wallpapers", home),
            PathBuf::from("/Users/brett/Pictures/Wallpapers")
        );
        assert_eq!(expand_home("~", home), PathBuf::from("/Users/brett"));
        assert_eq!(expand_home("/srv/walls", home), PathBuf::from("/srv/walls"));
        assert_eq!(
            expand_home("~brett/walls", home),
            PathBuf::from("~brett/walls")
        );
    }

    #[test]
    fn an_absent_key_takes_its_default_from_the_bundled_file_and_a_present_one_wins() {
        let bundled: serde_json::Value =
            serde_json::from_str(include_str!("../config.default.json")).unwrap();
        let from = |json: &str| -> serde_json::Value {
            serde_json::to_value(serde_json::from_str::<WallpaperConfig>(json).unwrap()).unwrap()
        };
        assert_eq!(from("{}"), bundled["wallpaper"]);
        assert_eq!(
            from(r#"{"folder": "/srv/walls"}"#),
            serde_json::json!({"folder": "/srv/walls", "tint": bundled["wallpaper"]["tint"]})
        );
        assert_eq!(
            from(r#"{"tint": true}"#),
            serde_json::json!({"folder": bundled["wallpaper"]["folder"], "tint": true})
        );
    }

    #[test]
    fn scan_lists_the_root_and_one_level_down() {
        let root = scratch("scan");
        for file in [
            "b.PNG",
            "a.jpg",
            "notes.txt",
            ".hidden.jpg",
            "anime/z.webp",
            "anime/deep/never.jpg",
            "anime/readme.md",
            ".git/x.jpg",
            "city/m.heic",
        ] {
            let path = root.join(file);
            std::fs::create_dir_all(path.parent().unwrap()).unwrap();
            std::fs::write(path, b"x").unwrap();
        }
        let got: Vec<(String, String, String)> = scan(&root)
            .into_iter()
            .map(|f| (f.folder, f.name, f.kind))
            .collect();
        std::fs::remove_dir_all(&root).unwrap();
        let row = |a: &str, b: &str, c: &str| (a.to_string(), b.to_string(), c.to_string());
        assert_eq!(
            got,
            vec![
                row("", "a.jpg", "jpg"),
                row("", "b.PNG", "png"),
                row("anime", "z.webp", "webp"),
                row("city", "m.heic", "heic"),
            ]
        );
    }

    #[test]
    fn scan_of_a_missing_folder_is_empty() {
        assert!(scan(Path::new("/nonexistent/edgebar/walls")).is_empty());
    }

    #[test]
    fn oled_blackens_only_the_surface() {
        let dark = palette(&[("base", "#131318"), ("text", "#e4e1e9")]);
        assert_eq!(
            blacken_base(&dark),
            palette(&[("base", "#000000"), ("text", "#e4e1e9")])
        );
    }

    /// The bundled config and palette, as `setup` would load them.
    fn theme_state(oled: bool, scheme: super::super::Scheme) -> super::super::ThemeState {
        let config: super::super::Config =
            serde_json::from_str(include_str!("../config.default.json")).unwrap();
        super::super::ThemeState {
            colors: config.colors,
            geometry: config.geometry,
            palettes: serde_json::from_str(include_str!("../palette.default.json")).unwrap(),
            appearance: super::super::Appearance::Auto,
            scheme,
            theme_command: String::new(),
            wallpaper_command: String::new(),
            notch_idle: String::new(),
            ink: Default::default(),
            oled,
        }
    }

    #[test]
    fn oled_turns_the_dark_surface_black_through_every_role_built_on_it() {
        use super::super::Scheme::{Dark, Light};
        // `base` is the on-pill ink in the bundled role map, taken from the palette's surface
        assert_eq!(theme_state(false, Dark).resolve().0.base, "#1e1e2e");
        assert_eq!(theme_state(true, Dark).resolve().0.base, "#000000");
        assert_eq!(
            theme_state(true, Light).resolve().0.base,
            theme_state(false, Light).resolve().0.base
        );
        assert_eq!(theme_state(true, Dark).palette()["base"], "#000000");
        assert_eq!(theme_state(true, Light).palette()["base"], "#eff1f5");
    }

    #[test]
    fn tint_colours_are_the_palette_plus_a_ramp_from_surface_to_text() {
        let p = palette(&[
            ("base", "#000000"),
            ("text", "#ffffff"),
            ("rosewater", "#ff0000"),
            ("surface1", "#808080"),
            ("overlay0", "#808080"),
            ("broken", "red"),
        ]);
        assert_eq!(
            tint_colours(&p),
            vec![
                [0, 0, 0],
                [51, 51, 51],
                [102, 102, 102],
                [128, 128, 128],
                [153, 153, 153],
                [204, 204, 204],
                [255, 0, 0],
                [255, 255, 255],
            ]
        );
    }

    #[test]
    fn a_pixel_snaps_to_its_nearest_palette_colour() {
        let mut px = [0u8, 0, 0, 64, 64, 64, 191, 191, 191, 255, 255, 255];
        tint_rgb(&mut px, &[[0, 0, 0], [255, 255, 255]], 20.0);
        assert_eq!(px, [0, 0, 0, 0, 0, 0, 255, 255, 255, 255, 255, 255]);
    }

    #[test]
    fn a_pixel_between_two_colours_blends_them_by_distance() {
        // 128 is a hair nearer white, so white takes a 55.9 % share: 0.559 * 255 = 142
        let mut px = [128u8, 128, 128];
        tint_rgb(&mut px, &[[0, 0, 0], [255, 255, 255]], 20.0);
        assert_eq!(px, [142, 142, 142]);
    }

    #[test]
    fn a_pixel_far_from_the_whole_palette_is_kept() {
        // distance^2 to both is above 3, so every weight underflows to 0
        let mut px = [255u8, 0, 0];
        tint_rgb(&mut px, &[[0, 255, 255]], 1000.0);
        assert_eq!(px, [255, 0, 0]);
    }

    #[test]
    fn tinting_is_the_same_whichever_way_the_work_is_split() {
        let colours = [[19, 19, 24], [189, 194, 255], [228, 225, 233]];
        let src: Vec<u8> = (0..3 * 1000).map(|i| (i * 37 % 256) as u8).collect();
        let mut whole = src.clone();
        tint_rgb(&mut whole, &colours, 20.0);
        let mut by_pixel = src;
        for px in by_pixel.chunks_exact_mut(3) {
            tint_rgb(px, &colours, 20.0);
        }
        assert_eq!(whole, by_pixel);
    }

    #[test]
    fn cover_size_covers_the_screen_and_never_upscales() {
        assert_eq!(cover_size((3840, 2160), (2880, 1800)), (3200, 1800));
        assert_eq!(cover_size((6400, 3600), (2880, 1800)), (3200, 1800));
        assert_eq!(cover_size((1920, 1080), (2880, 1800)), (1920, 1080));
        assert_eq!(cover_size((2160, 3840), (2880, 1800)), (2160, 3840));
    }

    #[test]
    fn a_tinted_name_follows_everything_that_changes_the_result() {
        let a = Path::new("/w/a.jpg");
        let base = tinted_name(a, 10, 500, &[[1, 2, 3]], (100, 50));
        assert_eq!(base, tinted_name(a, 10, 500, &[[1, 2, 3]], (100, 50)));
        assert!(base.starts_with("tint-") && base.ends_with(".png"));
        for other in [
            tinted_name(Path::new("/w/b.jpg"), 10, 500, &[[1, 2, 3]], (100, 50)),
            tinted_name(a, 11, 500, &[[1, 2, 3]], (100, 50)),
            tinted_name(a, 10, 501, &[[1, 2, 3]], (100, 50)),
            tinted_name(a, 10, 500, &[[1, 2, 4]], (100, 50)),
            tinted_name(a, 10, 500, &[[1, 2, 3]], (100, 51)),
        ] {
            assert_ne!(base, other);
        }
    }

    #[test]
    fn a_tinted_copy_is_traced_back_to_its_original() {
        let dir = scratch("sidecar");
        let copy = dir.join("tint-1.png");
        std::fs::write(&copy, b"png").unwrap();
        std::fs::write(sidecar(&copy), b"/w/a.jpg\n").unwrap();
        let stray = dir.join("tint-2.png");
        std::fs::write(&stray, b"png").unwrap();
        let got = (
            original_in(&dir, copy.to_str().unwrap()),
            original_in(&dir, stray.to_str().unwrap()),
            original_in(&dir, "/w/b.jpg"),
        );
        std::fs::remove_dir_all(&dir).unwrap();
        assert_eq!(
            got,
            (
                "/w/a.jpg".to_string(),
                stray.to_str().unwrap().to_string(),
                "/w/b.jpg".to_string()
            )
        );
    }

    #[test]
    fn prune_keeps_the_copy_in_use_and_its_sidecar() {
        let dir = scratch("prune");
        for f in [
            "tint-1.png",
            "tint-1.png.src",
            "tint-2.png",
            "tint-2.png.src",
            "tint-3.png.tmp",
        ] {
            std::fs::write(dir.join(f), b"x").unwrap();
        }
        prune(&dir, Some(&dir.join("tint-2.png")));
        let mut left: Vec<String> = std::fs::read_dir(&dir)
            .unwrap()
            .map(|e| e.unwrap().file_name().into_string().unwrap())
            .collect();
        left.sort();
        prune(&dir, None);
        let none_left = std::fs::read_dir(&dir).unwrap().count();
        std::fs::remove_dir_all(&dir).unwrap();
        assert_eq!(left, vec!["tint-2.png", "tint-2.png.src"]);
        assert_eq!(none_left, 0);
    }

    #[test]
    fn the_desktop_changes_only_when_it_differs_from_what_config_wants() {
        let copy = Path::new("/c/tint-1.png");
        let cases = [
            // tint on
            (true, "/w/a.jpg", Some(copy), Some("/c/tint-1.png")),
            (true, "/c/tint-1.png", Some(copy), None),
            (true, "/c/tint-0.png", Some(copy), Some("/c/tint-1.png")),
            // tint on but the picture can't be tinted: show the original
            (true, "/w/a.jpg", None, None),
            (true, "/c/tint-0.png", None, Some("/w/a.jpg")),
            // tint off
            (false, "/w/a.jpg", None, None),
            (false, "/c/tint-1.png", None, Some("/w/a.jpg")),
        ];
        for (tint, shown, tinted, want) in cases {
            assert_eq!(
                desktop_target(tint, shown, "/w/a.jpg", tinted),
                want.map(PathBuf::from),
                "tint={tint} shown={shown}"
            );
        }
    }

    /// Tints a real wallpaper with a real palette and prints the time. Set
    /// EDGEBAR_LIVE_IMAGE to the picture and EDGEBAR_LIVE_OUT to where the PNG goes.
    #[test]
    #[ignore = "live: reads a real wallpaper"]
    fn live_tint_a_real_wallpaper() {
        let image = std::env::var("EDGEBAR_LIVE_IMAGE").unwrap_or_else(|_| {
            format!(
                "{}/Pictures/Wallpapers/rem_demon.jpg",
                std::env::var("HOME").unwrap()
            )
        });
        let out = PathBuf::from(std::env::var("EDGEBAR_LIVE_OUT").unwrap_or_else(|_| {
            std::env::temp_dir()
                .join("edgebar-live-tint")
                .display()
                .to_string()
        }));
        let oled = std::env::var_os("EDGEBAR_LIVE_OLED").is_some();
        let mut dark = match std::env::var("EDGEBAR_LIVE_PALETTE") {
            Ok(file) => {
                let all: HashMap<String, HashMap<String, String>> =
                    serde_json::from_str(&std::fs::read_to_string(file).unwrap()).unwrap();
                all["dark"].clone()
            }
            Err(_) => palette(&[
                ("base", "#131318"),
                ("rosewater", "#bdc2ff"),
                ("text", "#e4e1e9"),
                ("subtext0", "#c7c5d0"),
                ("blue", "#e7b9d6"),
                ("peach", "#c4c4dd"),
                ("surface1", "#91909a"),
                ("overlay0", "#91909a"),
            ]),
        };
        if oled {
            dark = blacken_base(&dark);
        }
        let colours = tint_colours(&dark);
        let _ = std::fs::remove_dir_all(&out);
        let started = std::time::Instant::now();
        let path = ensure_tinted(&out, Path::new(&image), &colours, (2880, 1800)).unwrap();
        let took = started.elapsed();
        let (_, bytes) = mtime_secs(&path);
        let again = std::time::Instant::now();
        let reused = ensure_tinted(&out, Path::new(&image), &colours, (2880, 1800)).unwrap();
        println!(
            "tinted {image} with {} colours in {took:?} -> {} ({bytes} bytes); reuse took {:?}, same file: {}",
            colours.len(),
            path.display(),
            again.elapsed(),
            reused == path
        );
        println!(
            "original_in -> {}",
            original_in(&out, path.to_str().unwrap())
        );
    }

    /// Reads Brett's real config.json, which predates the `wallpaper` block, and
    /// lists his real folder: the bundled default has to fill the gap.
    #[test]
    #[ignore = "live: reads ~/.config/edgebar/config.json and the wallpaper folder"]
    fn live_scan_the_real_folder() {
        let dir = folder().unwrap();
        let found = scan(&dir);
        let mut kinds: Vec<&str> = found.iter().map(|f| f.kind.as_str()).collect();
        kinds.sort_unstable();
        kinds.dedup();
        let folders: Vec<&str> = found.iter().map(|f| f.folder.as_str()).collect();
        println!(
            "{} -> {} pictures, kinds {kinds:?}, subfolder names present: {}, tint {}",
            dir.display(),
            found.len(),
            folders.iter().any(|f| !f.is_empty()),
            tint_on()
        );
        assert!(!found.is_empty());
    }

    /// Runs `converge` on the real desktop against a mock app: tint on puts a
    /// copy of the current wallpaper on screen, a second run changes nothing, and
    /// tint off puts the original back and clears the copy. The guard restores the
    /// desktop even when an assertion fails.
    #[test]
    #[ignore = "live: changes the desktop picture and puts it back"]
    fn live_converge_follows_the_tint_setting() {
        use tauri::Manager;
        struct Restore(String);
        impl Drop for Restore {
            fn drop(&mut self) {
                crate::touch_inapp_marker();
                let _ = std::process::Command::new("desktoppr")
                    .args(["all", &self.0])
                    .status();
            }
        }
        let before = crate::query_desktop_picture("desktoppr");
        assert!(Path::new(&before).is_file(), "desktoppr said {before:?}");
        let _restore = Restore(before.clone());

        let app = tauri::test::mock_app();
        let mut state = theme_state(false, super::super::Scheme::Dark);
        state.wallpaper_command = "desktoppr".to_string();
        app.manage(Mutex::new(state));
        let handle = app.handle();
        let dir = scratch("converge");
        let shown = || crate::query_desktop_picture("desktoppr");
        let files = || std::fs::read_dir(&dir).unwrap().count();

        converge(handle, true, &dir, None);
        let tinted = shown();
        let on = (
            Path::new(&tinted).parent() == Some(dir.as_path()),
            original_in(&dir, &tinted) == before,
            files(),
        );

        converge(handle, true, &dir, None);
        let again = (shown() == tinted, files());

        converge(handle, false, &dir, None);
        let off = (shown() == before, files());
        std::fs::remove_dir_all(&dir).unwrap();
        println!("tint on {on:?}, a second run {again:?}, tint off {off:?}");
        assert_eq!(
            on,
            (true, true, 2),
            "a copy and its sidecar are on the desktop"
        );
        assert_eq!(again, (true, 2), "nothing changes the second time");
        assert_eq!(
            off,
            (true, 0),
            "the original is back and the copies are gone"
        );
    }

    /// Puts the current wallpaper's tinted copy on the real desktop with desktoppr,
    /// reads it back, maps it to its original, then puts the original back. The
    /// guard restores the desktop even when an assertion fails.
    #[test]
    #[ignore = "live: changes the desktop picture and puts it back"]
    fn live_desktop_round_trip() {
        struct Restore(String);
        impl Drop for Restore {
            fn drop(&mut self) {
                crate::touch_inapp_marker();
                let _ = std::process::Command::new("desktoppr")
                    .args(["all", &self.0])
                    .status();
            }
        }
        let log = || {
            std::fs::read_to_string("/tmp/edgebar-wallpaper-theme.log")
                .map_or(0, |t| t.lines().count())
        };
        let before = crate::query_desktop_picture("desktoppr");
        assert!(Path::new(&before).is_file(), "desktoppr said {before:?}");
        let _restore = Restore(before.clone());
        let log_before = log();

        let dir = scratch("desktop");
        let colours = tint_colours(&palette(&[
            ("base", "#131318"),
            ("rosewater", "#bdc2ff"),
            ("text", "#e4e1e9"),
            ("blue", "#e7b9d6"),
        ]));
        let tinted = ensure_tinted(&dir, Path::new(&before), &colours, (2560, 1600)).unwrap();

        crate::touch_inapp_marker();
        let status = std::process::Command::new("desktoppr")
            .args(["all"])
            .arg(&tinted)
            .status()
            .unwrap();
        assert!(status.success());
        std::thread::sleep(std::time::Duration::from_millis(1500));
        let shown = crate::query_desktop_picture("desktoppr");
        let original = original_in(&dir, &shown);
        println!("desktop showed {shown}");
        println!("which stands for {original}");
        let log_tinted = log();

        drop(_restore);
        std::thread::sleep(std::time::Duration::from_millis(1500));
        let after = crate::query_desktop_picture("desktoppr");
        let log_after = log();
        std::fs::remove_dir_all(&dir).unwrap();
        println!(
            "before {before}, after {after}; watcher log lines {log_before} -> {log_tinted} -> {log_after}"
        );
        assert_eq!(shown, tinted.to_str().unwrap());
        assert_eq!(original, before);
        assert_eq!(after, before);
    }
}
