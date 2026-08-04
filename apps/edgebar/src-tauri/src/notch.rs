//! Dynamic notch content — one slot, several providers, a fixed priority ladder.
//!
//! The collapsed notch shows whatever the highest-priority provider with
//! something to say has published: a transient OSD flash outranks per-workspace
//! context, which outranks whatever is currently making noise. When every
//! provider is silent the store emits `null` and the WebView falls back to the
//! idle look (the plain handle bar, a clock, or a fixed string — its choice,
//! since idle content ticks and shouldn't cost an event stream).
//!
//! Why the media provider is shaped the way it is: MediaRemote — the private
//! framework behind macOS's own Now Playing — has been gated to entitled
//! processes since macOS 15.4, so there is no system-wide "what is playing"
//! read left. Two public sources replace it:
//!
//!   * CoreAudio process objects (`kAudioHardwarePropertyProcessObjectList`,
//!     public since 14.4) answer *who is emitting sound* — including a YouTube
//!     tab, which no metadata API would have covered anyway.
//!   * AppleScript answers *what* they're playing, for the two local players
//!     that publish a dictionary (Spotify, Music).
//!
//! So a Spotify track reads "Artist — Title" with a progress hairline, and
//! anything else reads "<app> · playing" with the app's icon. Both are honest;
//! only the detail differs.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Mutex;
use std::time::{Duration, Instant};
use tauri::{Emitter, Manager};

/// How often the audible-app scan runs. CoreAudio process objects have no
/// usable change notification per process (objects come and go as apps open
/// audio units, so listeners would have to be added and removed constantly);
/// the scan is a handful of in-process property reads, so a slow poll is both
/// simpler and cheap. Matches the CPU sampler's cadence.
const MEDIA_POLL: Duration = Duration::from_secs(2);
/// Ticker for `everyMs` command rules. Rules are due-checked against this, so
/// an interval finer than this is rounded up to it.
const RULE_TICK: Duration = Duration::from_secs(1);
/// Longest a `command` rule may run before its output is dropped. Mirrors the
/// deadline on the AeroSpace helper — a wedged rule must not wedge the bar.
const COMMAND_TIMEOUT: Duration = Duration::from_secs(2);
/// How long an OSD flash holds the slot when the config doesn't say.
const DEFAULT_TRANSIENT_MS: u64 = 1600;

// ───────────────────────── config ───────────────────────────────────

/// The `notch` block of config.json. Absent = every default, which is the
/// current behaviour plus the media readout.
// Serialize rides along because the whole `Config` is serializable.
#[derive(Clone, Default, Deserialize, Serialize)]
#[serde(rename_all = "camelCase", default)]
pub struct NotchConfig {
    /// Per-workspace rules keyed by AeroSpace workspace name. `"*"` is the
    /// fallback for any workspace without its own entry.
    pub workspaces: HashMap<String, Rule>,
    /// What the WebView draws when no provider has anything: `"handle"` (the
    /// bar at rest, as before), `"clock"`, `"userHost"`, or a literal string.
    pub idle: Option<String>,
    /// How long an OSD flash (volume, brightness) holds the slot, in ms.
    pub transient_ms: Option<u64>,
}

/// Where a workspace's context line comes from.
#[derive(Clone, Deserialize, Serialize)]
#[serde(tag = "source", rename_all = "camelCase")]
pub enum Rule {
    /// The title of that workspace's focused window, app name beneath it.
    FocusedWindow,
    /// stdout of a shell command: first line is the headline, second (optional)
    /// the dim line under it. Re-run on every workspace change, and on
    /// `everyMs` while that workspace is focused.
    #[serde(rename_all = "camelCase")]
    Command {
        run: String,
        #[serde(default)]
        every_ms: Option<u64>,
        /// Icon hint for the WebView ("terminal", "git", "mail", …).
        #[serde(default)]
        glyph: Option<String>,
    },
    /// Nothing — this workspace falls through to the media readout.
    None,
}

// ───────────────────────── the item ─────────────────────────────────

/// Which provider owns the slot. Declaration order *is* the priority ladder
/// (`Ord` is derived from it), highest last.
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum Tier {
    Media,
    Workspace,
    Transient,
}

/// One line of notch content, whoever produced it.
#[derive(Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct NotchItem {
    pub tier: Tier,
    /// Icon name the WebView maps to an inline SVG, when there's no app icon.
    pub glyph: String,
    /// App icon as a PNG data URL, or "" — wins over `glyph` when set.
    pub icon: String,
    /// Album art as a data URL, or "". Drawn as the media pill's backdrop, not
    /// as a thumbnail, so it stays distinct from `icon` (which identifies the
    /// app, and still shows alongside it).
    pub art: String,
    pub primary: String,
    pub secondary: String,
    /// 0..1 hairline fill under the text (track position, volume level).
    pub progress: Option<f64>,
    /// Track length in seconds, 0 when unknown. Lets the WebView advance the
    /// playhead between polls instead of stepping every 2s.
    pub duration: f64,
    /// Whether transport commands will reach this source. Only true for the
    /// scriptable players — an audible Chrome tab can be reported but not
    /// driven, so it keeps the plain text readout.
    pub controls: bool,
    /// False dims the item — a paused player, a muted output.
    pub active: bool,
}

impl NotchItem {
    fn new(tier: Tier, glyph: &str, primary: String) -> Self {
        Self {
            tier,
            glyph: glyph.to_string(),
            icon: String::new(),
            art: String::new(),
            primary,
            secondary: String::new(),
            progress: None,
            duration: 0.0,
            controls: false,
            active: true,
        }
    }
}

// ───────────────────────── the store ────────────────────────────────

#[derive(Default)]
struct Slots {
    media: Option<NotchItem>,
    workspace: Option<NotchItem>,
    transient: Option<NotchItem>,
    /// Bumped on every flash so a stale expiry timer can't clear a newer one.
    transient_gen: u64,
    /// Last winner emitted, so an unchanged recompute stays off the wire.
    emitted: Option<NotchItem>,
}

/// Managed state: the published slots plus the config the providers read.
pub struct NotchState {
    slots: Mutex<Slots>,
    config: NotchConfig,
    /// Workspace the rules are currently resolved against, and when its
    /// `everyMs` command last ran.
    current: Mutex<(String, Option<Instant>)>,
    /// Cover art data URLs, keyed by the player's artwork URL.
    art: Mutex<HashMap<String, String>>,
    /// Bundle id currently owning the media slot — where transport commands go.
    media_bundle: Mutex<String>,
}

impl NotchState {
    pub fn new(config: NotchConfig) -> Self {
        Self {
            slots: Mutex::new(Slots::default()),
            config,
            current: Mutex::new((String::new(), None)),
            art: Mutex::new(HashMap::new()),
            media_bundle: Mutex::new(String::new()),
        }
    }
}

fn winner(s: &Slots) -> Option<NotchItem> {
    s.transient
        .clone()
        .or_else(|| s.workspace.clone())
        .or_else(|| s.media.clone())
}

/// Recompute the winner and push it — but only when it actually changed, so a
/// 2s media scan that finds the same track stays silent.
fn publish(app: &tauri::AppHandle) {
    let state = app.state::<NotchState>();
    let next = {
        let mut s = state.slots.lock().unwrap();
        let next = winner(&s);
        if next == s.emitted {
            return;
        }
        s.emitted.clone_from(&next);
        next
    };
    let _ = app.emit("notch", next);
}

fn set_slot(app: &tauri::AppHandle, tier: Tier, item: Option<NotchItem>) {
    {
        let state = app.state::<NotchState>();
        let mut s = state.slots.lock().unwrap();
        match tier {
            Tier::Media => s.media = item,
            Tier::Workspace => s.workspace = item,
            Tier::Transient => s.transient = item,
        }
    }
    publish(app);
}

/// Take the slot for a moment, then hand it back to whoever had it. Used by the
/// volume/brightness commands so hardware-ish changes surface where you're
/// already looking.
pub fn flash(app: &tauri::AppHandle, glyph: &str, primary: String, progress: Option<f64>) {
    let mut item = NotchItem::new(Tier::Transient, glyph, primary);
    item.progress = progress;

    let (gen, hold) = {
        let state = app.state::<NotchState>();
        let hold = state.config.transient_ms.unwrap_or(DEFAULT_TRANSIENT_MS);
        let mut s = state.slots.lock().unwrap();
        s.transient = Some(item);
        s.transient_gen += 1;
        (s.transient_gen, hold)
    };
    publish(app);

    let app = app.clone();
    std::thread::spawn(move || {
        std::thread::sleep(Duration::from_millis(hold));
        {
            let state = app.state::<NotchState>();
            let mut s = state.slots.lock().unwrap();
            // A newer flash landed while we slept — it owns the expiry now.
            if s.transient_gen != gen {
                return;
            }
            s.transient = None;
        }
        publish(&app);
    });
}

/// Current winner, for a bar that just loaded (or was rebuilt by a display
/// change) and would otherwise wait out a poll for its first content.
#[tauri::command]
pub fn notch_state(app: tauri::AppHandle) -> Option<NotchItem> {
    let state = app.state::<NotchState>();
    let s = state.slots.lock().unwrap();
    winner(&s)
}

// ───────────────────────── workspace provider ───────────────────────

/// Re-resolve the focused workspace's rule. Called from the same places that
/// push a `workspaces` event (the AeroSpace socket worker and the app-activation
/// observer), so context tracks focus without a poll of its own.
pub fn refresh_workspace(app: &tauri::AppHandle) {
    let focused = crate::aerospace(&[
        "list-windows",
        "--focused",
        "--format",
        "%{workspace}|%{app-name}|%{app-bundle-id}|%{window-title}",
    ])
    .into_iter()
    .next();

    // No focused window (an empty workspace) still has a focused workspace.
    let (ws, win) = match focused.as_deref().and_then(parse_focused) {
        Some((ws, win)) => (ws, Some(win)),
        None => (
            crate::aerospace(&["list-workspaces", "--focused"])
                .into_iter()
                .next()
                .unwrap_or_default(),
            None,
        ),
    };

    let rule = {
        let state = app.state::<NotchState>();
        state
            .config
            .workspaces
            .get(&ws)
            .or_else(|| state.config.workspaces.get("*"))
            .cloned()
    };

    {
        let state = app.state::<NotchState>();
        let mut cur = state.current.lock().unwrap();
        if cur.0 != ws {
            *cur = (ws.clone(), None); // new workspace: `everyMs` starts fresh
        }
    }

    let item = match rule {
        None | Some(Rule::None) => None,
        Some(Rule::FocusedWindow) => win.map(|w| {
            let mut item = NotchItem::new(Tier::Workspace, "window", w.title);
            item.secondary = w.app;
            item.icon = crate::icon_for_bundle(app, &w.bundle_id);
            item
        }),
        Some(Rule::Command { run, glyph, .. }) => {
            let out = run_rule(&run, &ws);
            {
                let state = app.state::<NotchState>();
                state.current.lock().unwrap().1 = Some(Instant::now());
            }
            out.map(|(primary, secondary)| {
                let mut item = NotchItem::new(
                    Tier::Workspace,
                    glyph.as_deref().unwrap_or("terminal"),
                    primary,
                );
                item.secondary = secondary;
                item
            })
        }
    };
    set_slot(app, Tier::Workspace, item);
}

struct FocusedWin {
    app: String,
    bundle_id: String,
    title: String,
}

/// Parse a `workspace|app-name|app-bundle-id|window-title` row. The title is
/// taken as the remainder, since titles routinely contain `|`.
fn parse_focused(line: &str) -> Option<(String, FocusedWin)> {
    let mut p = line.splitn(4, '|');
    let ws = p.next()?.to_string();
    let app = p.next()?.to_string();
    let bundle_id = p.next()?.to_string();
    let title = p.next().unwrap_or_default().trim().to_string();
    if ws.is_empty() {
        return None;
    }
    Some((
        ws,
        FocusedWin {
            app,
            bundle_id,
            title,
        },
    ))
}

/// Run a `command` rule and split its stdout into headline + dim line. The
/// workspace is exported so one rule can serve several workspaces.
fn run_rule(run: &str, workspace: &str) -> Option<(String, String)> {
    use std::io::Read;
    use std::process::{Command, Stdio};

    let mut child = Command::new("/bin/sh")
        .arg("-c")
        .arg(run)
        .env("EDGEBAR_WORKSPACE", workspace)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .ok()?;

    // Same shape as the AeroSpace helper: drain on a side thread so a full pipe
    // can't wedge the child, and kill on deadline to force the reader to EOF.
    let mut stdout = child.stdout.take();
    let (tx, rx) = std::sync::mpsc::channel();
    std::thread::spawn(move || {
        let mut text = String::new();
        if let Some(out) = stdout.as_mut() {
            let _ = out.read_to_string(&mut text);
        }
        let _ = tx.send(text);
    });
    let text = match rx.recv_timeout(COMMAND_TIMEOUT) {
        Ok(text) => text,
        Err(_) => {
            let _ = child.kill();
            rx.recv().unwrap_or_default()
        }
    };
    let _ = child.wait();

    let mut lines = text.lines().map(str::trim).filter(|l| !l.is_empty());
    let primary = lines.next()?.to_string();
    Some((primary, lines.next().unwrap_or_default().to_string()))
}

/// Re-run the focused workspace's rule when its `everyMs` comes due. One ticker
/// for all rules; only the focused workspace's rule can be due, so this is a
/// single timer regardless of how many rules exist.
pub fn install_rule_ticker(app: tauri::AppHandle) {
    std::thread::spawn(move || loop {
        std::thread::sleep(RULE_TICK);
        let due = {
            let state = app.state::<NotchState>();
            let cur = state.current.lock().unwrap();
            let every = match state
                .config
                .workspaces
                .get(&cur.0)
                .or_else(|| state.config.workspaces.get("*"))
            {
                Some(Rule::Command {
                    every_ms: Some(ms), ..
                }) => *ms,
                _ => continue,
            };
            cur.1
                .is_none_or(|last| last.elapsed() >= Duration::from_millis(every))
        };
        if due {
            refresh_workspace(&app);
        }
    });
}

// ───────────────────────── media provider ───────────────────────────

/// Bundle ids whose AppleScript dictionary we can read for track metadata.
/// Everything else degrades to "<app> · playing", which is all CoreAudio knows.
const SPOTIFY: &str = "com.spotify.client";
const MUSIC: &str = "com.apple.Music";

struct Track {
    title: String,
    artist: String,
    playing: bool,
    progress: Option<f64>,
    /// Track length in seconds.
    duration: f64,
    /// Album art as a `data:` URL, when the player publishes one.
    art: String,
}

/// Host Spotify serves cover art from. The URL goes into a shell command, so
/// only this exact prefix is ever fetched — an AppleScript reply is not a
/// trusted string.
const ART_HOST: &str = "https://i.scdn.co/image/";
/// Cover art cache cap. Each entry is a base64 JPEG (tens of KB); a listening
/// session shouldn't accumulate them without bound.
const ART_CACHE_MAX: usize = 32;

/// Poll for the app currently writing to an output device and describe it.
pub fn install_media_watcher(app: tauri::AppHandle) {
    std::thread::spawn(move || loop {
        set_slot(&app, Tier::Media, read_media(&app));
        std::thread::sleep(MEDIA_POLL);
    });
}

/// One audible app, with whatever it will tell us about what it's playing.
struct Candidate {
    /// Unix seconds the *audio-emitting* process started — not the app's, so a
    /// browser that has been open all day still ranks by when its audio began.
    start: u64,
    bundle_id: String,
    name: String,
    icon: String,
    track: Option<Track>,
}

#[cfg(target_os = "macos")]
fn read_media(app: &tauri::AppHandle) -> Option<NotchItem> {
    // Several apps are routinely audible at once — a long-running bridge
    // (SonoBus, a conferencing app) alongside whatever you just hit play on —
    // and CoreAudio's list order means nothing. So rank them.
    let mut candidates: Vec<Candidate> = audio::output_pids()
        .into_iter()
        .filter_map(|pid| {
            // Audio usually comes out of a helper process (Chrome's audio
            // service, a WebKit GPU process); walk up to the app you'd name.
            let (bundle_id, name, icon) = crate::app_info_for_pid(app, pid)?;
            Some(Candidate {
                start: crate::proc_start_secs(pid),
                track: track_metadata(&bundle_id),
                bundle_id,
                name,
                icon,
            })
        })
        .collect();

    // Pausing a player usually makes it release its output stream, so CoreAudio
    // stops reporting it a moment later and the slot would empty out mid-track
    // — the pill vanishing, transport and all, seconds after you pressed pause.
    // Keep whoever currently holds the slot as a last-resort candidate for as
    // long as they still have a track loaded. `start: 0` ranks them below
    // anything genuinely audible, so this only shows a paused player when
    // nothing else is making sound.
    let incumbent = {
        let state = app.state::<NotchState>();
        let bundle = state.media_bundle.lock().unwrap();
        bundle.clone()
    };
    if let Some(name) = player_app(&incumbent) {
        if !candidates.iter().any(|c| c.bundle_id == incumbent) {
            if let Some(track) = track_metadata(&incumbent) {
                candidates.push(Candidate {
                    start: 0,
                    icon: crate::icon_for_bundle(app, &incumbent),
                    bundle_id: incumbent,
                    name: name.to_string(),
                    track: Some(track),
                });
            }
        }
    }

    if candidates.is_empty() {
        return None;
    }
    // Most recently started first: the stream you began last is the one you
    // mean. A four-hour-old audio bridge shouldn't outrank the track you just
    // played.
    candidates.sort_by_key(|c| std::cmp::Reverse(c.start));

    // A player that says it's playing is the definitive answer; otherwise the
    // newest stream, which is already the head of the list.
    //
    // Deliberately NOT "skip anything that says it's paused": a permanently
    // open audio bridge holds a running output stream whether or not sound is
    // coming out of it, so demoting a paused player handed the notch to
    // SonoBus the moment you hit pause — taking the transport controls with it.
    // Recency settles it instead: the bridge started hours ago, so it only wins
    // once the player it's competing with has actually gone away.
    let i = candidates.iter().position(is_playing).unwrap_or(0);
    let chosen = candidates.swap_remove(i);

    // Remember who to send transport commands to, whether or not it turns out
    // to be scriptable — a stale bundle here would aim play/pause at the wrong
    // app entirely.
    {
        let state = app.state::<NotchState>();
        let mut bundle = state.media_bundle.lock().unwrap();
        bundle.clone_from(&chosen.bundle_id);
    }

    let mut item = NotchItem::new(Tier::Media, "music", chosen.name.clone());
    item.icon = chosen.icon;
    item.secondary = "playing".to_string();
    if let Some(t) = chosen.track {
        item.primary = t.title;
        item.secondary = if t.artist.is_empty() {
            chosen.name
        } else {
            t.artist
        };
        item.progress = t.progress;
        item.duration = t.duration;
        item.active = t.playing;
        item.controls = player_app(&chosen.bundle_id).is_some();
        item.art = artwork(app, &t.art);
    }
    Some(item)
}

fn is_playing(c: &Candidate) -> bool {
    c.track.as_ref().is_some_and(|t| t.playing)
}

#[cfg(not(target_os = "macos"))]
fn read_media(_app: &tauri::AppHandle) -> Option<NotchItem> {
    None
}

/// Ask a player for the current track. Guarded by `is running` so the query can
/// never launch the app it's asking about, and only ever sent to a player we
/// know publishes a dictionary — an unscripted app just keeps the CoreAudio
/// readout. Requires Automation permission for that app the first time; denied,
/// this returns None and the readout degrades rather than breaking.
fn track_metadata(bundle_id: &str) -> Option<Track> {
    let app_name = match bundle_id {
        SPOTIFY => "Spotify",
        MUSIC => "Music",
        _ => return None,
    };
    // Spotify reports track duration in ms, Music in seconds; both report
    // position in seconds.
    let duration_scale = if bundle_id == SPOTIFY { 1000.0 } else { 1.0 };
    // Only Spotify exposes cover art as a URL — Music's `artwork` is raw image
    // data, which osascript can't hand back as text. Wrapped in `try` because
    // ads and local files have no artwork.
    let art_clause = if bundle_id == SPOTIFY {
        "try
                 set u to artwork url of current track
               end try"
    } else {
        ""
    };
    let script = format!(
        r#"if application "{app_name}" is running then
             tell application "{app_name}"
               if player state is stopped then return ""
               set t to name of current track
               set a to artist of current track
               set d to duration of current track
               set u to ""
               {art_clause}
               return (player state as text) & "\n" & t & "\n" & a & "\n" & (player position as text) & "\n" & (d as text) & "\n" & u
             end tell
           end if"#
    );
    let out = crate::run_osa(&script)?;
    let mut lines = out.lines();
    let state = lines.next()?;
    if state.is_empty() {
        return None;
    }
    let title = lines.next().unwrap_or_default().trim().to_string();
    let artist = lines.next().unwrap_or_default().trim().to_string();
    let position: f64 = lines.next().and_then(|s| s.trim().parse().ok()).unwrap_or(0.0);
    let duration: f64 = lines
        .next()
        .and_then(|s| s.trim().parse::<f64>().ok())
        .map(|d| d / duration_scale)
        .unwrap_or(0.0);
    if title.is_empty() {
        return None;
    }
    Some(Track {
        title,
        artist,
        playing: state == "playing",
        progress: (duration > 0.0).then(|| (position / duration).clamp(0.0, 1.0)),
        duration,
        art: lines.next().unwrap_or_default().trim().to_string(),
    })
}

/// The scriptable player a bundle id refers to, if it is one.
fn player_app(bundle_id: &str) -> Option<&'static str> {
    match bundle_id {
        SPOTIFY => Some("Spotify"),
        MUSIC => Some("Music"),
        _ => None,
    }
}

/// Send one transport command to whichever player currently owns the media
/// slot, then re-read it so the bar reflects the change now rather than at the
/// next poll. No-ops when the audible app isn't scriptable.
fn transport(app: &tauri::AppHandle, body: &str) {
    let bundle = {
        let state = app.state::<NotchState>();
        let bundle = state.media_bundle.lock().unwrap();
        bundle.clone()
    };
    let Some(name) = player_app(&bundle) else {
        return;
    };
    crate::run_osa(&format!(
        r#"if application "{name}" is running then tell application "{name}" to {body}"#
    ));
    set_slot(app, Tier::Media, read_media(app));
}

/// Play/pause the current player, from the notch's transport button.
#[tauri::command]
pub async fn media_toggle(app: tauri::AppHandle) {
    let _ = tauri::async_runtime::spawn_blocking(move || transport(&app, "playpause")).await;
}

/// Seek to a fraction (0..1) of the current track — the notch's wave is
/// clickable, and this is where that lands.
#[tauri::command]
pub async fn media_seek(app: tauri::AppHandle, fraction: f64) {
    let f = fraction.clamp(0.0, 1.0);
    let _ = tauri::async_runtime::spawn_blocking(move || {
        // The player knows the track length; asking it to compute the target
        // avoids trusting a duration the WebView may have held since the last
        // track.
        transport(
            &app,
            &format!("set player position to (duration of current track) * {f} / {}",
                // Spotify's duration is milliseconds, Music's is seconds.
                if is_ms_duration(&app) { 1000.0 } else { 1.0 }),
        )
    })
    .await;
}

/// Whether the current player reports track duration in milliseconds.
fn is_ms_duration(app: &tauri::AppHandle) -> bool {
    let state = app.state::<NotchState>();
    let bundle = state.media_bundle.lock().unwrap();
    *bundle == SPOTIFY
}

/// Fetch cover art and hand it to the WebView as a `data:` URL — keeping the
/// bar's page entirely offline, and letting the same art survive a repaint
/// without a second round trip. Cached by URL.
fn artwork(app: &tauri::AppHandle, url: &str) -> String {
    if !url.starts_with(ART_HOST) {
        return String::new();
    }
    {
        let state = app.state::<NotchState>();
        let cache = state.art.lock().unwrap();
        if let Some(hit) = cache.get(url) {
            return hit.clone();
        }
    }
    // Spotify encodes the size in the image id: `…0000b273…` is the 300px art
    // it hands out, `…00004851…` the 64px one. At a 22px cell that's 2KB over
    // IPC instead of 86KB — but the naming is convention, not contract, so the
    // original URL stays as the fallback.
    let small = url.replace("ab67616d0000b273", "ab67616d00004851");
    let out = [small.as_str(), url]
        .into_iter()
        .find_map(|u| {
            std::process::Command::new("/bin/sh")
                .arg("-c")
                .arg(format!("curl -sfL --max-time 3 '{u}' | base64"))
                .output()
                .ok()
                .filter(|o| o.status.success())
                .map(|o| String::from_utf8_lossy(&o.stdout).replace('\n', ""))
                .filter(|b64| !b64.is_empty())
        })
        .map(|b64| format!("data:image/jpeg;base64,{b64}"))
        .unwrap_or_default();
    if !out.is_empty() {
        let state = app.state::<NotchState>();
        let mut cache = state.art.lock().unwrap();
        // Cheap bound: a full cache is dropped rather than evicted one by one —
        // the cost of a miss is one curl, so LRU bookkeeping isn't worth it.
        if cache.len() >= ART_CACHE_MAX {
            cache.clear();
        }
        cache.insert(url.to_string(), out.clone());
    }
    out
}

/// CoreAudio's per-process audio objects: who is currently writing to an output
/// device. Public API since macOS 14.4, and — unlike MediaRemote — it needs no
/// entitlement and prompts for no permission.
#[cfg(target_os = "macos")]
mod audio {
    use std::ffi::c_void;

    type AudioObjectID = u32;
    const SYSTEM_OBJECT: AudioObjectID = 1;

    const fn fourcc(s: &[u8; 4]) -> u32 {
        ((s[0] as u32) << 24) | ((s[1] as u32) << 16) | ((s[2] as u32) << 8) | s[3] as u32
    }
    // Selectors, verbatim from CoreAudio/AudioHardware.h.
    const PROCESS_OBJECT_LIST: u32 = fourcc(b"prs#");
    const PROP_PID: u32 = fourcc(b"ppid");
    const PROP_IS_RUNNING_OUTPUT: u32 = fourcc(b"piro");
    const SCOPE_GLOBAL: u32 = fourcc(b"glob");

    #[repr(C)]
    struct Address {
        selector: u32,
        scope: u32,
        element: u32,
    }

    extern "C" {
        fn AudioObjectGetPropertyDataSize(
            id: AudioObjectID,
            address: *const Address,
            qualifier_size: u32,
            qualifier: *const c_void,
            out_size: *mut u32,
        ) -> i32;
        fn AudioObjectGetPropertyData(
            id: AudioObjectID,
            address: *const Address,
            qualifier_size: u32,
            qualifier: *const c_void,
            io_size: *mut u32,
            out_data: *mut c_void,
        ) -> i32;
    }

    fn address(selector: u32) -> Address {
        Address {
            selector,
            scope: SCOPE_GLOBAL,
            element: 0, // kAudioObjectPropertyElementMain
        }
    }

    /// Read a fixed-size scalar property off one audio object.
    fn scalar<T: Default>(id: AudioObjectID, selector: u32) -> Option<T> {
        let addr = address(selector);
        let mut value = T::default();
        let mut size = std::mem::size_of::<T>() as u32;
        // SAFETY: `value` is a live T and `size` is exactly its size, which is
        // what CoreAudio writes for these scalar selectors.
        let status = unsafe {
            AudioObjectGetPropertyData(
                id,
                &addr,
                0,
                std::ptr::null(),
                &mut size,
                &mut value as *mut T as *mut c_void,
            )
        };
        (status == 0).then_some(value)
    }

    /// pids of every process currently writing to an output device.
    pub fn output_pids() -> Vec<i32> {
        let addr = address(PROCESS_OBJECT_LIST);
        let mut size: u32 = 0;
        // SAFETY: querying the size of a system-object property; no qualifier.
        let status =
            unsafe { AudioObjectGetPropertyDataSize(SYSTEM_OBJECT, &addr, 0, std::ptr::null(), &mut size) };
        if status != 0 || size == 0 {
            return Vec::new();
        }
        let count = size as usize / std::mem::size_of::<AudioObjectID>();
        let mut ids: Vec<AudioObjectID> = vec![0; count];
        // SAFETY: `ids` holds exactly `size` bytes, the size just reported.
        let status = unsafe {
            AudioObjectGetPropertyData(
                SYSTEM_OBJECT,
                &addr,
                0,
                std::ptr::null(),
                &mut size,
                ids.as_mut_ptr() as *mut c_void,
            )
        };
        if status != 0 {
            return Vec::new();
        }
        ids.truncate(size as usize / std::mem::size_of::<AudioObjectID>());
        ids.into_iter()
            .filter(|id| scalar::<u32>(*id, PROP_IS_RUNNING_OUTPUT).unwrap_or(0) != 0)
            .filter_map(|id| scalar::<i32>(id, PROP_PID))
            .filter(|pid| *pid > 0)
            .collect()
    }
}
