//! Dynamic notch content: one slot, several providers, a fixed priority ladder.
//!
//! The collapsed notch shows the highest-priority provider with something to
//! say: an OSD flash beats per-workspace context, which beats whatever is making
//! noise. When all are silent the store emits `null` and the WebView draws its
//! own idle look (handle, clock or fixed text), so a ticking clock costs no
//! events.
//!
//! MediaRemote (behind macOS's own Now Playing) has been gated to entitled
//! processes since macOS 15.4, so the media provider uses two public sources:
//!
//!   * CoreAudio process objects (`kAudioHardwarePropertyProcessObjectList`,
//!     public since 14.4) say *who* is emitting sound, browser tabs included.
//!   * AppleScript says *what* is playing, for the two players that publish a
//!     dictionary (Spotify, Music).
//!
//! So Spotify and Music get the full media pill (art, playhead, transport);
//! any other audible app shows its name and icon over "playing".

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Mutex;
use std::time::{Duration, Instant};
use tauri::{Emitter, Manager};

/// How often the audible-app scan runs. Process objects come and go as apps
/// open audio units, so per-process listeners would need constant re-adding; a
/// slow poll of a few property reads is simpler. Matches `CPU_POLL` in lib.rs.
const MEDIA_POLL: Duration = Duration::from_secs(2);
/// Ticker for `everyMs` command rules. Rules are due-checked once per tick, so
/// `everyMs` effectively rounds up to a whole number of ticks.
const RULE_TICK: Duration = Duration::from_secs(1);
/// Longest a `command` rule may run before it is killed (whatever it printed by
/// then is used), so a wedged rule can't wedge the bar.
const COMMAND_TIMEOUT: Duration = Duration::from_secs(2);
/// How long an OSD flash holds the slot when the config doesn't say.
const DEFAULT_TRANSIENT_MS: u64 = 1600;

// ───────────────────────── config ───────────────────────────────────

/// The `notch` block of the settings.
// Serialize rides along because the whole `Config` is serializable.
#[derive(Clone, PartialEq, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct NotchConfig {
    /// Per-workspace rules keyed by AeroSpace workspace name. `"*"` is the
    /// fallback for any workspace without its own entry.
    pub workspaces: HashMap<String, Rule>,
    /// What the WebView draws when no provider has anything: `"handle"`,
    /// `"clock"`, `"userHost"`, or a literal string.
    pub idle: Option<String>,
    /// How long an OSD flash (volume, mic, brightness) holds the slot, in ms.
    pub transient_ms: Option<u64>,
}

/// Where a workspace's context line comes from.
#[derive(Clone, PartialEq, Deserialize, Serialize)]
#[serde(tag = "source", rename_all = "camelCase")]
pub enum Rule {
    /// The title of that workspace's focused window, app name beneath it.
    FocusedWindow,
    /// stdout of a shell command: first line is the headline, second (optional)
    /// the dim line under it. Re-run on every workspace or focus change, and on
    /// `everyMs` while that workspace is focused.
    #[serde(rename_all = "camelCase")]
    Command {
        run: String,
        #[serde(default)]
        every_ms: Option<u64>,
        /// A key of `NOTCH_GLYPH` in main.ts; defaults to "terminal". Unknown
        /// names draw no icon.
        #[serde(default)]
        glyph: Option<String>,
    },
    /// Nothing — this workspace falls through to the media readout.
    None,
}

// ───────────────────────── the item ─────────────────────────────────

/// Which provider owns the slot, lowest priority first. `winner()` is what
/// actually applies the ladder.
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
    /// Album art as a data URL, or "". The media pill's backdrop; `icon` still
    /// shows alongside it.
    pub art: String,
    pub primary: String,
    pub secondary: String,
    /// 0..1: the media pill's playhead, or the text layout's hairline (e.g. a
    /// volume flash).
    pub progress: Option<f64>,
    /// Track length in seconds, 0 when unknown. Lets the WebView advance the
    /// playhead between polls instead of stepping every 2s.
    pub duration: f64,
    /// Whether transport commands reach this source: only the scriptable
    /// players. An audible browser tab can be named but not driven, so it keeps
    /// the text layout.
    pub controls: bool,
    /// False for a paused player: the media pill flattens its wave, the text
    /// layout dims.
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

struct Media {
    state: MediaState,
    item: NotchItem,
}

#[derive(Default)]
struct Slots {
    media: Option<Media>,
    workspace: Option<NotchItem>,
    transient: Option<NotchItem>,
    /// Bumped on every flash so a stale expiry timer can't clear a newer one.
    transient_gen: u64,
    /// Last winner emitted, so an unchanged recompute stays off the wire.
    emitted: Option<NotchItem>,
    emitted_media: Option<MediaState>,
}

/// Managed state: the published slots plus the config the providers read.
pub struct NotchState {
    slots: Mutex<Slots>,
    config: Mutex<NotchConfig>,
    /// Workspace the rules are currently resolved against, and when its
    /// `everyMs` command last ran.
    current: Mutex<(String, Option<Instant>)>,
    covers: Mutex<CoverCache>,
    /// Bundle id currently owning the media slot — where transport commands go.
    media_bundle: Mutex<String>,
}

impl NotchState {
    pub fn new(config: NotchConfig) -> Self {
        Self {
            slots: Mutex::new(Slots::default()),
            config: Mutex::new(config),
            current: Mutex::new((String::new(), None)),
            covers: Mutex::new(CoverCache::default()),
            media_bundle: Mutex::new(String::new()),
        }
    }

    pub fn set_config(&self, app: &tauri::AppHandle, config: NotchConfig) {
        *self.config.lock().unwrap() = config;
        refresh_workspace(app);
    }
}

fn winner(s: &Slots) -> Option<NotchItem> {
    s.transient
        .clone()
        .or_else(|| s.workspace.clone())
        .or_else(|| s.media.as_ref().map(|m| m.item.clone()))
}

/// Recompute the winner and push it, only if it changed, so a media scan that
/// finds the same track stays silent.
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

fn set_workspace(app: &tauri::AppHandle, item: Option<NotchItem>) {
    {
        let state = app.state::<NotchState>();
        state.slots.lock().unwrap().workspace = item;
    }
    publish(app);
}

fn set_media(app: &tauri::AppHandle, read: Option<MediaState>) {
    let media = read.map(|state| {
        let art = artwork(app, &state.art_key);
        Media {
            item: state.notch_item(art),
            state,
        }
    });
    {
        let state = app.state::<NotchState>();
        state.slots.lock().unwrap().media = media;
    }
    publish(app);
    publish_media(app);
}

fn publish_media(app: &tauri::AppHandle) {
    let state = app.state::<NotchState>();
    let next = {
        let mut s = state.slots.lock().unwrap();
        let next = s.media.as_ref().map(|m| m.state.clone());
        if next == s.emitted_media {
            return;
        }
        s.emitted_media.clone_from(&next);
        next
    };
    let _ = app.emit("media", next);
}

/// Take the slot for a moment, then hand it back. Used by the volume, mic and
/// brightness commands.
pub fn flash(app: &tauri::AppHandle, glyph: &str, primary: String, progress: Option<f64>) {
    let mut item = NotchItem::new(Tier::Transient, glyph, primary);
    item.progress = progress;

    let (gen, hold) = {
        let state = app.state::<NotchState>();
        let hold = state
            .config
            .lock()
            .unwrap()
            .transient_ms
            .unwrap_or(DEFAULT_TRANSIENT_MS);
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
        let config = state.config.lock().unwrap();
        config
            .workspaces
            .get(&ws)
            .or_else(|| config.workspaces.get("*"))
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
    set_workspace(app, item);
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
    let mut cmd = std::process::Command::new("/bin/sh");
    cmd.arg("-c").arg(run).env("EDGEBAR_WORKSPACE", workspace);
    let text = crate::output_within(cmd, COMMAND_TIMEOUT)?.stdout();
    let mut lines = text.lines().map(str::trim).filter(|l| !l.is_empty());
    let primary = lines.next()?.to_string();
    Some((primary, lines.next().unwrap_or_default().to_string()))
}

/// Re-run the focused workspace's rule when its `everyMs` comes due. Only the
/// focused rule can be due, so one ticker serves them all.
pub fn install_rule_ticker(app: tauri::AppHandle) {
    std::thread::spawn(move || loop {
        std::thread::sleep(RULE_TICK);
        let due = {
            let state = app.state::<NotchState>();
            let cur = state.current.lock().unwrap();
            let config = state.config.lock().unwrap();
            let every = match config
                .workspaces
                .get(&cur.0)
                .or_else(|| config.workspaces.get("*"))
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

pub(crate) struct Player {
    pub(crate) bundle_id: &'static str,
    pub(crate) name: &'static str,
    /// Whether `duration` is in milliseconds. Spotify's sdef says seconds, but the
    /// running app answers 373333 for a 6 min 13 s track.
    duration_ms: bool,
    cover_key: &'static str,
    next: &'static str,
    /// Music's `back track` is its own back button (restart the track, or go
    /// back if already at the start); Spotify's sdef has `previous track` only.
    previous: &'static str,
}

pub(crate) const PLAYERS: [Player; 2] = [
    Player {
        bundle_id: "com.spotify.client",
        name: "Spotify",
        duration_ms: true,
        cover_key: "artwork url of current track",
        next: "next track",
        previous: "previous track",
    },
    Player {
        bundle_id: "com.apple.Music",
        name: "Music",
        duration_ms: false,
        cover_key: r#""music:" & (persistent ID of current track)"#,
        next: "next track",
        previous: "back track",
    },
];

/// The scriptable player a bundle id refers to, if it is one.
fn player(bundle_id: &str) -> Option<&'static Player> {
    PLAYERS.iter().find(|p| p.bundle_id == bundle_id)
}

#[derive(Clone, Debug, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MediaState {
    pub app: String,
    pub icon: String,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub art_key: String,
    pub position: f64,
    pub duration: f64,
    pub playing: bool,
    pub controls: bool,
}

impl MediaState {
    fn new(app: String, icon: String, track: Option<Track>) -> Self {
        let Some(t) = track else {
            return Self {
                app,
                icon,
                title: String::new(),
                artist: String::new(),
                album: String::new(),
                art_key: String::new(),
                position: 0.0,
                duration: 0.0,
                playing: true,
                controls: false,
            };
        };
        Self {
            app,
            icon,
            title: t.title,
            artist: t.artist,
            album: t.album,
            art_key: t.cover_key,
            position: t.position,
            duration: t.duration,
            playing: t.playing,
            controls: true,
        }
    }

    fn notch_item(&self, art: String) -> NotchItem {
        let mut item = NotchItem::new(Tier::Media, "music", self.title.clone());
        item.icon.clone_from(&self.icon);
        item.art = art;
        item.duration = self.duration;
        item.controls = self.controls;
        item.active = self.playing;
        if self.title.is_empty() {
            item.primary.clone_from(&self.app);
            item.secondary = "playing".to_string();
        } else {
            item.secondary = if self.artist.is_empty() {
                self.app.clone()
            } else {
                self.artist.clone()
            };
            item.progress =
                (self.duration > 0.0).then(|| (self.position / self.duration).clamp(0.0, 1.0));
        }
        item
    }
}

#[tauri::command]
pub fn media_state(app: tauri::AppHandle) -> Option<MediaState> {
    let state = app.state::<NotchState>();
    let s = state.slots.lock().unwrap();
    s.media.as_ref().map(|m| m.state.clone())
}

const ALLOWED_ART_PREFIX: &str = "https://i.scdn.co/image/";

/// Poll for the app currently writing to an output device and describe it.
pub fn install_media_watcher(app: tauri::AppHandle) {
    std::thread::spawn(move || loop {
        set_media(&app, read_media(&app));
        std::thread::sleep(MEDIA_POLL);
    });
}

struct Track {
    title: String,
    artist: String,
    album: String,
    playing: bool,
    position: f64,
    duration: f64,
    cover_key: String,
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
fn read_media(app: &tauri::AppHandle) -> Option<MediaState> {
    // Several apps are often audible at once (an audio bridge such as SonoBus
    // beside a player), and CoreAudio's list order means nothing, so rank them.
    let mut candidates: Vec<Candidate> = audio::output_pids()
        .into_iter()
        .filter_map(|pid| {
            // Audio usually comes from a helper process; this walks up to the app.
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

    // A paused player soon releases its output stream and drops out of
    // CoreAudio's list, which would empty the slot seconds after pause. Keep the
    // current holder as a last-resort candidate while it has a track loaded;
    // `start: 0` ranks it below anything actually audible.
    let incumbent = current_bundle(app);
    if let Some(p) = player(&incumbent) {
        if !candidates.iter().any(|c| c.bundle_id == incumbent) {
            if let Some(track) = track_metadata(&incumbent) {
                candidates.push(Candidate {
                    start: 0,
                    icon: crate::icon_for_bundle(app, &incumbent),
                    bundle_id: incumbent,
                    name: p.name.to_string(),
                    track: Some(track),
                });
            }
        }
    }

    if candidates.is_empty() {
        return None;
    }
    // Most recently started stream first: that's the one you mean.
    candidates.sort_by_key(|c| std::cmp::Reverse(c.start));

    // A player that says it's playing wins; otherwise the newest stream. Don't
    // skip paused players: an always-open audio bridge holds a running stream
    // even when silent, and would take the notch (and the transport) the moment
    // you paused. Its old start time keeps it behind the player until the
    // player's own stream goes away.
    let i = candidates.iter().position(is_playing).unwrap_or(0);
    let chosen = candidates.swap_remove(i);

    // Record the transport target even if it isn't scriptable; a stale bundle
    // would aim play/pause at the wrong app.
    {
        let state = app.state::<NotchState>();
        let mut bundle = state.media_bundle.lock().unwrap();
        bundle.clone_from(&chosen.bundle_id);
    }

    Some(MediaState::new(chosen.name, chosen.icon, chosen.track))
}

fn is_playing(c: &Candidate) -> bool {
    c.track.as_ref().is_some_and(|t| t.playing)
}

#[cfg(not(target_os = "macos"))]
fn read_media(_app: &tauri::AppHandle) -> Option<MediaState> {
    None
}

fn current_bundle(app: &tauri::AppHandle) -> String {
    let state = app.state::<NotchState>();
    let bundle = state.media_bundle.lock().unwrap();
    bundle.clone()
}

const FIELD_SEP: char = '\u{1f}';

/// The AppleScript expression behind each field `parse_track` reads, in order.
const TRACK_FIELDS: [&str; 7] = [
    "(player state as text)",
    "t",
    "a",
    "al",
    "(player position as text)",
    "(d as text)",
    "k",
];

/// Ask a scriptable player for the current track. Guarded by `is running` so
/// the query never launches the app. Needs Automation permission for that app;
/// if denied this returns None and the readout falls back to the CoreAudio one.
fn track_metadata(bundle_id: &str) -> Option<Track> {
    let player = player(bundle_id)?;
    let out = crate::run_osa(&metadata_script(player))?;
    parse_track(player, &out)
}

fn metadata_script(player: &Player) -> String {
    let (name, cover_key) = (player.name, player.cover_key);
    let sep = FIELD_SEP as u32;
    let fields = TRACK_FIELDS.join(" & s & ");
    format!(
        r#"if application "{name}" is running then
             tell application "{name}"
               if player state is stopped then return ""
               set t to name of current track
               set a to artist of current track
               set d to duration of current track
               set al to ""
               set k to ""
               try
                 set al to (album of current track) as text
               end try
               try
                 set k to ({cover_key}) as text
               end try
               set s to (ASCII character {sep})
               return {fields}
             end tell
           end if"#
    )
}

fn parse_track(player: &Player, out: &str) -> Option<Track> {
    let mut parts = out.split(FIELD_SEP).map(str::trim);
    let fields: [&str; TRACK_FIELDS.len()] =
        std::array::from_fn(|_| parts.next().unwrap_or_default());
    let [state, title, artist, album, position, duration, cover_key] = fields;
    if state.is_empty() || title.is_empty() {
        return None;
    }
    let duration = duration
        .parse::<f64>()
        .map(|d| if player.duration_ms { d / 1000.0 } else { d })
        .unwrap_or(0.0);
    Some(Track {
        title: title.to_string(),
        artist: artist.to_string(),
        album: album.to_string(),
        playing: state == "playing",
        position: position.parse().unwrap_or(0.0),
        duration,
        cover_key: if parse_cover_key(cover_key).is_some() {
            cover_key.to_string()
        } else {
            String::new()
        },
    })
}

/// Send one transport command to the player that owns the media slot, then
/// re-read it so the bar updates now rather than at the next poll. No-op for a
/// non-scriptable app.
fn transport(app: &tauri::AppHandle, command: impl FnOnce(&Player) -> String) {
    let Some(p) = player(&current_bundle(app)) else {
        return;
    };
    let name = p.name;
    let command = command(p);
    crate::run_osa(&format!(
        r#"if application "{name}" is running then tell application "{name}" to {command}"#
    ));
    set_media(app, read_media(app));
}

/// Play/pause the current player, from the notch's transport button.
#[tauri::command]
pub async fn media_toggle(app: tauri::AppHandle) {
    let _ =
        tauri::async_runtime::spawn_blocking(move || transport(&app, |_| "playpause".to_string()))
            .await;
}

#[tauri::command]
pub async fn media_next(app: tauri::AppHandle) {
    let _ =
        tauri::async_runtime::spawn_blocking(move || transport(&app, |p| p.next.to_string())).await;
}

#[tauri::command]
pub async fn media_previous(app: tauri::AppHandle) {
    let _ =
        tauri::async_runtime::spawn_blocking(move || transport(&app, |p| p.previous.to_string()))
            .await;
}

/// Seek to a fraction (0..1) of the current track, from a scrub on the notch's
/// playhead.
#[tauri::command]
pub async fn media_seek(app: tauri::AppHandle, fraction: f64) {
    let f = fraction.clamp(0.0, 1.0);
    let _ =
        tauri::async_runtime::spawn_blocking(move || transport(&app, |p| seek_command(p, f))).await;
}

fn seek_command(player: &Player, fraction: f64) -> String {
    let unit = if player.duration_ms { 1000.0 } else { 1.0 };
    format!("set player position to (duration of current track) * {fraction} / {unit}")
}

const COVER_PX: u32 = 300;
const COVER_CACHE_MAX: usize = 8;
/// Spotify image ids that name the 640, 300 and 64 px sizes of one cover.
const SPOTIFY_640: &str = "ab67616d0000b273";
const SPOTIFY_300: &str = "ab67616d00001e02";
const SPOTIFY_64: &str = "ab67616d00004851";

#[derive(Debug, PartialEq)]
enum CoverSource<'a> {
    Spotify(&'a str),
    Music(&'a str),
}

fn parse_cover_key(key: &str) -> Option<CoverSource<'_>> {
    if let Some(id) = key.strip_prefix(ALLOWED_ART_PREFIX) {
        return (!id.is_empty() && id.bytes().all(|b| b.is_ascii_alphanumeric()))
            .then_some(CoverSource::Spotify(key));
    }
    let id = key.strip_prefix("music:")?;
    (!id.is_empty() && id.bytes().all(|b| b.is_ascii_hexdigit())).then_some(CoverSource::Music(id))
}

#[derive(Default)]
struct CoverCache(Vec<(String, String)>);

impl CoverCache {
    fn get(&self, key: &str) -> Option<&str> {
        self.0
            .iter()
            .find(|(k, _)| k == key)
            .map(|(_, v)| v.as_str())
    }

    fn insert(&mut self, key: String, data_url: String) {
        if self.get(&key).is_some() {
            return;
        }
        if self.0.len() >= COVER_CACHE_MAX {
            self.0.remove(0);
        }
        self.0.push((key, data_url));
    }
}

#[tauri::command]
pub async fn media_art(app: tauri::AppHandle, key: String) -> String {
    tauri::async_runtime::spawn_blocking(move || cover(&app, &key))
        .await
        .unwrap_or_default()
}

/// The player view's cover, 300 px for either player.
fn cover(app: &tauri::AppHandle, key: &str) -> String {
    match parse_cover_key(key) {
        Some(CoverSource::Spotify(url)) => {
            cached_cover(app, sized_spotify_url(url, SPOTIFY_300), || {
                spotify_image(url, SPOTIFY_300)
            })
        }
        Some(CoverSource::Music(id)) => cached_cover(app, key.to_string(), || music_cover(id)),
        None => String::new(),
    }
}

/// The notch's backdrop: Spotify's 64 px cover, which is plenty there and far
/// smaller over IPC.
fn artwork(app: &tauri::AppHandle, key: &str) -> String {
    match parse_cover_key(key) {
        Some(CoverSource::Spotify(url)) => {
            cached_cover(app, sized_spotify_url(url, SPOTIFY_64), || {
                spotify_image(url, SPOTIFY_64)
            })
        }
        _ => String::new(),
    }
}

/// A JPEG cover as a `data:` URL, so the page stays offline.
fn cached_cover(
    app: &tauri::AppHandle,
    key: String,
    fetch: impl FnOnce() -> Option<Vec<u8>>,
) -> String {
    let state = app.state::<NotchState>();
    if let Some(url) = state.covers.lock().unwrap().get(&key) {
        return url.to_string();
    }
    let Some(bytes) = fetch() else {
        return String::new();
    };
    let url = format!("data:image/jpeg;base64,{}", crate::base64_encode(&bytes));
    state.covers.lock().unwrap().insert(key, url.clone());
    url
}

fn sized_spotify_url(url: &str, size_id: &str) -> String {
    url.replace(SPOTIFY_640, size_id)
}

/// The size id is a convention, not a contract, so the URL as the player gave
/// it is the fallback.
fn spotify_image(url: &str, size_id: &str) -> Option<Vec<u8>> {
    let sized = sized_spotify_url(url, size_id);
    let original = (sized != url).then_some(url);
    std::iter::once(sized.as_str())
        .chain(original)
        .find_map(|u| {
            std::process::Command::new("/usr/bin/curl")
                .args(["-sfL", "--max-time", "3", u])
                .output()
                .ok()
                .filter(|o| o.status.success() && !o.stdout.is_empty())
                .map(|o| o.stdout)
        })
}

fn music_cover(id: &str) -> Option<Vec<u8>> {
    let dir = std::env::temp_dir();
    let raw = dir.join(format!("edgebar-cover-{id}.bin"));
    let small = dir.join(format!("edgebar-cover-{id}.jpg"));
    let bytes = (|| {
        let raw_path = raw.to_str().filter(|p| !p.contains(['"', '\\']))?;
        let reply = crate::run_osa(&music_cover_script(id, raw_path))?;
        if reply != "ok" {
            return None;
        }
        scale_cover(&raw, &small)
    })();
    let _ = std::fs::remove_file(&raw);
    let _ = std::fs::remove_file(&small);
    bytes
}

fn scale_cover(raw: &std::path::Path, small: &std::path::Path) -> Option<Vec<u8>> {
    let scaled = std::process::Command::new("/usr/bin/sips")
        .args(["-Z", &COVER_PX.to_string(), "-s", "format", "jpeg"])
        .arg(raw)
        .arg("--out")
        .arg(small)
        .output()
        .ok()?;
    scaled.status.success().then_some(())?;
    std::fs::read(small).ok().filter(|b| !b.is_empty())
}

fn music_cover_script(id: &str, path: &str) -> String {
    format!(
        r#"try
             if application "Music" is running then
               tell application "Music"
                 if (persistent ID of current track) is not "{id}" then return "moved"
                 set raw to raw data of artwork 1 of current track
               end tell
               set f to open for access (POSIX file "{path}") with write permission
               try
                 set eof f to 0
                 write raw to f
                 close access f
               on error m
                 close access f
                 error m
               end try
               return "ok"
             end if
           on error
             return "failed"
           end try"#
    )
}

/// CoreAudio's per-process audio objects: who is writing to an output device.
/// Public since macOS 14.4; unlike MediaRemote, no entitlement or permission.
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

#[cfg(test)]
mod tests {
    use super::*;

    const SPOTIFY_ID: &str = "com.spotify.client";
    const MUSIC_ID: &str = "com.apple.Music";
    const COVER_640: &str = "https://i.scdn.co/image/ab67616d0000b27321e3ac688cf52673a7d501a0";

    fn track(app: &str, fields: &[&str]) -> Option<Track> {
        parse_track(player(app).unwrap(), &fields.join("\u{1f}"))
    }

    #[test]
    fn spotify_reply_is_parsed_with_milliseconds_scaled() {
        let t = track(
            SPOTIFY_ID,
            &["paused", "Nocturne", "Ada", "Sonata", "99.057998657227", "373333", COVER_640],
        )
        .unwrap();
        assert_eq!(t.title, "Nocturne");
        assert_eq!(t.artist, "Ada");
        assert_eq!(t.album, "Sonata");
        assert!(!t.playing);
        assert_eq!(t.position, 99.057998657227);
        assert_eq!(t.duration, 373.333);
        assert_eq!(t.cover_key, COVER_640);
    }

    #[test]
    fn music_reply_keeps_seconds_and_keys_the_cover_by_track() {
        let t = track(
            MUSIC_ID,
            &["playing", "Etude", "Bo", "Studies", "12.5", "215.4", "music:0A1B2C3D4E5F6071"],
        )
        .unwrap();
        assert!(t.playing);
        assert_eq!(t.position, 12.5);
        assert_eq!(t.duration, 215.4);
        assert_eq!(t.cover_key, "music:0A1B2C3D4E5F6071");
    }

    #[test]
    fn a_newline_in_the_title_does_not_shift_the_fields() {
        let t = track(
            SPOTIFY_ID,
            &["playing", "One\nTwo", "Ada", "Sonata", "1", "2000", ""],
        )
        .unwrap();
        assert_eq!(t.title, "One\nTwo");
        assert_eq!(t.album, "Sonata");
        assert_eq!(t.duration, 2.0);
        assert_eq!(t.cover_key, "");
    }

    #[test]
    fn no_track_means_no_state() {
        let p = player(SPOTIFY_ID).unwrap();
        assert!(parse_track(p, "").is_none());
        assert!(track(SPOTIFY_ID, &["playing", "", "Ada", "Sonata", "1", "2000", ""]).is_none());
    }

    #[test]
    fn a_cover_key_the_fetchers_could_misuse_is_dropped() {
        let cover = |app, raw: &str| {
            track(app, &["playing", "T", "A", "B", "0", "1000", raw])
                .unwrap()
                .cover_key
        };
        assert_eq!(cover(SPOTIFY_ID, "https://example.com/image/abc"), "");
        assert_eq!(
            cover(SPOTIFY_ID, "https://i.scdn.co/image/abc'; touch /tmp/x; '"),
            ""
        );
        assert_eq!(cover(MUSIC_ID, "music:not-hex"), "");
        assert_eq!(cover(MUSIC_ID, "music:"), "");
    }

    #[test]
    fn cover_keys_parse_to_their_source() {
        assert_eq!(
            parse_cover_key(COVER_640),
            Some(CoverSource::Spotify(COVER_640))
        );
        assert_eq!(
            parse_cover_key("music:0A1B2C3D4E5F6071"),
            Some(CoverSource::Music("0A1B2C3D4E5F6071"))
        );
        assert_eq!(parse_cover_key(""), None);
        assert_eq!(parse_cover_key("https://i.scdn.co/image/"), None);
        assert_eq!(parse_cover_key("http://i.scdn.co/image/abc"), None);
        assert_eq!(parse_cover_key("music:0A1B\"; do shell script \"x"), None);
    }

    #[test]
    fn a_spotify_640_url_is_resized_by_its_image_id() {
        assert_eq!(
            sized_spotify_url(COVER_640, SPOTIFY_300),
            "https://i.scdn.co/image/ab67616d00001e0221e3ac688cf52673a7d501a0"
        );
        assert_eq!(
            sized_spotify_url(COVER_640, SPOTIFY_64),
            "https://i.scdn.co/image/ab67616d0000485121e3ac688cf52673a7d501a0"
        );
        let other = "https://i.scdn.co/image/ab6761610000e5eb21e3ac";
        assert_eq!(sized_spotify_url(other, SPOTIFY_300), other);
    }

    #[test]
    fn seek_divides_by_the_players_duration_unit() {
        let target = |app, f| seek_command(player(app).unwrap(), f);
        assert_eq!(
            target(SPOTIFY_ID, 0.5),
            "set player position to (duration of current track) * 0.5 / 1000"
        );
        assert_eq!(
            target(MUSIC_ID, 0.25),
            "set player position to (duration of current track) * 0.25 / 1"
        );
    }

    fn playing_track() -> Track {
        Track {
            title: "Nocturne".into(),
            artist: "Ada".into(),
            album: "Sonata".into(),
            playing: true,
            position: 50.0,
            duration: 200.0,
            cover_key: COVER_640.into(),
        }
    }

    #[test]
    fn a_track_fills_the_state_and_the_notch_line() {
        let state = MediaState::new("Spotify".into(), "icon".into(), Some(playing_track()));
        assert_eq!(state.album, "Sonata");
        assert_eq!(state.art_key, COVER_640);
        assert!(state.controls && state.playing);

        let item = state.notch_item("art".into());
        assert!(item.tier == Tier::Media);
        assert_eq!(item.primary, "Nocturne");
        assert_eq!(item.secondary, "Ada");
        assert_eq!(item.icon, "icon");
        assert_eq!(item.art, "art");
        assert_eq!(item.progress, Some(0.25));
        assert_eq!(item.duration, 200.0);
        assert!(item.controls && item.active);
    }

    #[test]
    fn a_track_without_an_artist_shows_the_app_and_a_paused_one_dims() {
        let mut t = playing_track();
        t.artist.clear();
        t.playing = false;
        t.position = 500.0;
        let item =
            MediaState::new("Music".into(), String::new(), Some(t)).notch_item(String::new());
        assert_eq!(item.secondary, "Music");
        assert_eq!(item.progress, Some(1.0));
        assert!(!item.active);
    }

    #[test]
    fn an_unscriptable_app_is_named_with_empty_track_fields() {
        let state = MediaState::new("Firefox".into(), "icon".into(), None);
        assert_eq!(
            state,
            MediaState {
                app: "Firefox".into(),
                icon: "icon".into(),
                title: String::new(),
                artist: String::new(),
                album: String::new(),
                art_key: String::new(),
                position: 0.0,
                duration: 0.0,
                playing: true,
                controls: false,
            }
        );
        let item = state.notch_item(String::new());
        assert_eq!(item.primary, "Firefox");
        assert_eq!(item.secondary, "playing");
        assert_eq!(item.progress, None);
        assert!(!item.controls);
    }

    #[test]
    fn media_state_serialises_to_the_shape_in_ipc_ts() {
        let state = MediaState::new("Spotify".into(), "icon".into(), Some(playing_track()));
        assert_eq!(
            serde_json::to_value(&state).unwrap(),
            serde_json::json!({
                "app": "Spotify",
                "icon": "icon",
                "title": "Nocturne",
                "artist": "Ada",
                "album": "Sonata",
                "artKey": COVER_640,
                "position": 50.0,
                "duration": 200.0,
                "playing": true,
                "controls": true,
            })
        );
    }

    #[test]
    fn the_cover_cache_holds_a_few_and_drops_the_oldest() {
        let mut cache = CoverCache::default();
        for i in 0..=COVER_CACHE_MAX {
            cache.insert(format!("k{i}"), format!("v{i}"));
        }
        assert_eq!(cache.get("k0"), None);
        assert_eq!(cache.get("k1"), Some("v1"));
        let newest = format!("k{COVER_CACHE_MAX}");
        assert_eq!(
            cache.get(&newest),
            Some(format!("v{COVER_CACHE_MAX}").as_str())
        );
        cache.insert("k1".into(), "replaced".into());
        assert_eq!(cache.get("k1"), Some("v1"));
    }

    fn temp(name: &str) -> std::path::PathBuf {
        std::env::temp_dir().join(format!("edgebar-media-test-{name}"))
    }

    fn dimensions(path: &std::path::Path) -> (u32, u32) {
        let out = std::process::Command::new("/usr/bin/sips")
            .args(["-g", "pixelWidth", "-g", "pixelHeight"])
            .arg(path)
            .output()
            .unwrap();
        let text = String::from_utf8_lossy(&out.stdout);
        let value = |key: &str| -> u32 {
            text.lines()
                .find_map(|l| l.trim().strip_prefix(key))
                .and_then(|v| v.trim_start_matches(':').trim().parse().ok())
                .unwrap()
        };
        (value("pixelWidth"), value("pixelHeight"))
    }

    #[test]
    #[ignore = "live: reads the running Spotify and Music, and the network"]
    fn live_players_and_covers() {
        println!("audible output pids: {}", audio::output_pids().len());
        for p in &PLAYERS {
            let started = Instant::now();
            let read = track_metadata(p.bundle_id);
            let took = started.elapsed();
            let Some(t) = read else {
                println!(
                    "{}: no track (not running, stopped or Automation denied) in {took:?}",
                    p.name
                );
                continue;
            };
            println!(
                "{}: read in {took:?}: playing={} title={}ch artist={}ch album={}ch position={:.1}s duration={:.1}s cover_key={}",
                p.name,
                t.playing,
                t.title.chars().count(),
                t.artist.chars().count(),
                t.album.chars().count(),
                t.position,
                t.duration,
                if t.cover_key.is_empty() { "(none)" } else { &t.cover_key },
            );
            let state = MediaState::new(p.name.into(), String::new(), Some(t));
            assert!(!state.title.is_empty());
            assert!(state.duration > 0.0 && state.duration < 6.0 * 3600.0);
            assert!(state.position >= 0.0 && state.position <= state.duration);
            let Some(CoverSource::Spotify(url)) = parse_cover_key(&state.art_key) else {
                continue;
            };
            let started = Instant::now();
            let bytes = spotify_image(url, SPOTIFY_300).expect("a 300 px cover");
            let took = started.elapsed();
            let file = temp("spotify-300.jpg");
            std::fs::write(&file, &bytes).unwrap();
            let (w, h) = dimensions(&file);
            println!("spotify cover: {} bytes, {w}x{h}, fetched in {took:?}", bytes.len());
            assert_eq!((w, h), (300, 300));
            let _ = std::fs::remove_file(&file);
        }
    }

    #[test]
    #[ignore = "live: fetches a Spotify cover and runs sips"]
    fn live_scale_cover_shrinks_a_640_px_image() {
        let raw = temp("640.bin");
        let small = temp("640-scaled.jpg");
        let big = std::process::Command::new("/usr/bin/curl")
            .args(["-sfL", "--max-time", "5", COVER_640])
            .output()
            .unwrap()
            .stdout;
        std::fs::write(&raw, &big).unwrap();
        assert_eq!(dimensions(&raw), (640, 640));
        let scaled = scale_cover(&raw, &small).expect("a scaled cover");
        std::fs::write(&small, &scaled).unwrap();
        println!(
            "640 px cover {} bytes -> {} bytes, {:?}",
            big.len(),
            scaled.len(),
            dimensions(&small)
        );
        assert_eq!(dimensions(&small), (COVER_PX, COVER_PX));
        assert_eq!(&scaled[..2], &[0xff, 0xd8], "a JPEG");
        let _ = std::fs::remove_file(&raw);
        let _ = std::fs::remove_file(&small);
    }

    #[test]
    #[ignore = "live: compiles the scripts against the installed apps' dictionaries"]
    fn live_scripts_compile() {
        let scripts = [
            metadata_script(player(SPOTIFY_ID).unwrap()),
            metadata_script(player(MUSIC_ID).unwrap()),
            music_cover_script("0A1B2C3D4E5F6071", "/tmp/edgebar-cover.bin"),
            format!(
                "tell application \"Spotify\" to {}",
                seek_command(player(SPOTIFY_ID).unwrap(), 0.5)
            ),
        ];
        for (i, source) in scripts.iter().enumerate() {
            let out = std::process::Command::new("/usr/bin/osacompile")
                .arg("-o")
                .arg(temp(&format!("script-{i}.scpt")))
                .arg("-e")
                .arg(source)
                .output()
                .unwrap();
            println!("script {i}: compiled={}", out.status.success());
            assert!(
                out.status.success(),
                "script {i}: {}",
                String::from_utf8_lossy(&out.stderr)
            );
            let _ = std::fs::remove_file(temp(&format!("script-{i}.scpt")));
        }
    }

    #[test]
    #[ignore = "live: reads the installed apps' scripting dictionaries"]
    fn live_sdef_names_every_verb_we_send() {
        let sdefs = [
            (
                SPOTIFY_ID,
                "/Applications/Spotify.app/Contents/Resources/Spotify.sdef",
            ),
            (
                MUSIC_ID,
                "/System/Applications/Music.app/Contents/Resources/com.apple.Music.sdef",
            ),
        ];
        for p in &PLAYERS {
            let (_, path) = sdefs.iter().find(|(b, _)| *b == p.bundle_id).unwrap();
            let sdef = std::fs::read_to_string(path).unwrap();
            for verb in [p.next, p.previous, "playpause"] {
                let found = sdef.contains(&format!("<command name=\"{verb}\""));
                println!("{}: command {verb:?} in sdef: {found}", p.name);
                assert!(found, "{} has no `{verb}` command", p.name);
            }
            for property in ["album", "duration", "player position"] {
                assert!(
                    sdef.contains(&format!("<property name=\"{property}\"")),
                    "{} has no `{property}` property",
                    p.name
                );
            }
        }
    }
}
