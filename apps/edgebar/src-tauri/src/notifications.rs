//! Notification history for the dashboard.
//!
//! macOS keeps delivered notifications in a SQLite store inside the
//! `group.com.apple.usernoted` group container. Reading it needs Full Disk
//! Access, and writing it is out of bounds, so every read works on a private
//! copy of the store (`db`, `db-wal`, `db-shm`, copied together so the WAL is
//! consistent with the main file) opened read-only, and the copy is deleted
//! afterwards.
//!
//! "Dismiss" and "clear" therefore cannot remove anything from macOS. They
//! record what the user hid in `~/.cache/edgebar/notifications-hidden.json`,
//! which every read applies.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashMap};
use std::io::{self, Cursor};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Mutex;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

/// Newest entries the dashboard gets, after hiding.
const MAX_ITEMS: usize = 100;
/// How far back the history reaches.
const WINDOW_SECS: f64 = 7.0 * 24.0 * 3600.0;
/// Seconds between the Unix epoch and Cocoa's (2001-01-01), the epoch of the
/// store's `delivered_date`.
const COCOA_EPOCH_UNIX: f64 = 978_307_200.0;

// ───────────────────────── the wire shape (ipc.ts) ──────────────────

/// Access to the store, as ipc.ts spells it.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum Access {
    Granted,
    Denied,
    Unavailable,
}

#[derive(Debug, Serialize)]
pub struct NotificationEntry {
    id: String,
    app: String,
    icon: String,
    title: String,
    subtitle: String,
    body: String,
    time: String,
}

#[derive(Debug, Serialize)]
pub struct NotificationHistory {
    access: Access,
    items: Vec<NotificationEntry>,
}

// ───────────────────────── the domain ───────────────────────────────

/// One delivered notification, as read from a record.
#[derive(Clone, Debug, PartialEq)]
struct Record {
    /// The row's id in the store. Stable for as long as the row exists, which
    /// is all a hidden entry needs.
    id: String,
    bundle_id: String,
    title: String,
    subtitle: String,
    body: String,
    /// Delivery time, seconds since the Unix epoch.
    unix_secs: f64,
}

/// A row of the store before its plist is opened.
struct RawRow {
    id: i64,
    bundle_id: Option<String>,
    data: Option<Vec<u8>>,
    /// Seconds since the Cocoa epoch.
    delivered: f64,
}

/// What the user hid. `cleared_before` hides everything delivered up to that
/// time; `ids` hides single entries delivered after it.
#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
struct Hidden {
    ids: BTreeSet<String>,
    cleared_before: f64,
}

impl Hidden {
    fn hides(&self, r: &Record) -> bool {
        r.unix_secs <= self.cleared_before || self.ids.contains(&r.id)
    }
}

/// Open a record's plist. The notification lives under `req` (`titl`, `subt`,
/// `body`). The bundle id normally comes from the store's `app` table; the
/// plist's own `app` key stands in when that join found nothing. A blob that is
/// not a plist, or has no `req`, is skipped.
fn parse_row(row: RawRow) -> Option<Record> {
    let value = plist::Value::from_reader(Cursor::new(row.data?)).ok()?;
    let root = value.as_dictionary()?;
    let req = root.get("req")?.as_dictionary()?;
    let text = |key: &str| {
        req.get(key)
            .and_then(|v| v.as_string())
            .unwrap_or_default()
            .to_string()
    };
    let bundle_id = row
        .bundle_id
        .filter(|b| !b.is_empty())
        .or_else(|| root.get("app")?.as_string().map(str::to_string))
        .unwrap_or_default();
    Some(Record {
        id: row.id.to_string(),
        bundle_id,
        title: text("titl"),
        subtitle: text("subt"),
        body: text("body"),
        unix_secs: row.delivered + COCOA_EPOCH_UNIX,
    })
}

/// The entries to show: inside the window, not hidden, newest first, capped.
fn select(mut records: Vec<Record>, hidden: &Hidden, now: f64) -> Vec<Record> {
    records.retain(|r| r.unix_secs >= now - WINDOW_SECS && !hidden.hides(r));
    records.sort_by(|a, b| b.unix_secs.total_cmp(&a.unix_secs));
    records.truncate(MAX_ITEMS);
    records
}

/// RFC 3339 in UTC, to the whole second.
fn iso_utc(unix_secs: f64) -> String {
    let whole = Duration::from_secs(unix_secs.max(0.0).floor() as u64);
    plist::Date::from(UNIX_EPOCH + whole).to_xml_format()
}

fn now_unix() -> f64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0.0, |d| d.as_secs_f64())
}

/// The last dot-separated part of a bundle id, for an app that is no longer
/// installed: `com.example.Chat` shows as "Chat".
fn name_from_bundle_id(bundle_id: &str) -> String {
    bundle_id
        .rsplit('.')
        .next()
        .filter(|s| !s.is_empty())
        .unwrap_or(bundle_id)
        .to_string()
}

// ───────────────────────── reading the store ────────────────────────

/// The store's directory.
fn store_dir() -> Option<PathBuf> {
    let home = std::env::var_os("HOME")?;
    Some(Path::new(&home).join("Library/Group Containers/group.com.apple.usernoted/db2"))
}

fn access_for(e: &io::Error) -> Access {
    match e.kind() {
        io::ErrorKind::PermissionDenied => Access::Denied,
        _ => Access::Unavailable,
    }
}

/// A private, owner-only copy of the store, removed on drop.
struct Snapshot {
    dir: PathBuf,
}

impl Snapshot {
    /// Copy `db`, then its `-wal` and `-shm` if they exist. A missing `db` is
    /// "unavailable"; any permission refusal is "denied".
    fn take(src: &Path) -> Result<Snapshot, Access> {
        use std::os::unix::fs::DirBuilderExt;
        static SEQ: AtomicU64 = AtomicU64::new(0);
        let dir = std::env::temp_dir().join(format!(
            "edgebar-notifications-{}-{}",
            std::process::id(),
            SEQ.fetch_add(1, Ordering::Relaxed)
        ));
        std::fs::DirBuilder::new()
            .mode(0o700)
            .create(&dir)
            .map_err(|e| access_for(&e))?;
        let snap = Snapshot { dir };
        for (name, required) in [("db", true), ("db-wal", false), ("db-shm", false)] {
            match std::fs::copy(src.join(name), snap.dir.join(name)) {
                Ok(_) => {}
                Err(e) if e.kind() == io::ErrorKind::NotFound && !required => {}
                Err(e) => return Err(access_for(&e)),
            }
        }
        Ok(snap)
    }

    fn db(&self) -> PathBuf {
        self.dir.join("db")
    }
}

impl Drop for Snapshot {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.dir);
    }
}

/// Tables and their columns, no rows: what to print when the store's layout is
/// not the one this module reads.
fn schema_summary(conn: &rusqlite::Connection) -> String {
    let tables = conn
        .prepare("SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name")
        .and_then(|mut s| {
            s.query_map([], |r| r.get::<_, String>(0))?
                .collect::<Result<Vec<_>, _>>()
        })
        .unwrap_or_default();
    tables
        .iter()
        .map(|t| {
            let cols = conn
                .prepare(&format!("SELECT name FROM pragma_table_info('{t}')"))
                .and_then(|mut s| {
                    s.query_map([], |r| r.get::<_, String>(0))?
                        .collect::<Result<Vec<_>, _>>()
                })
                .unwrap_or_default();
            format!("{t}({})", cols.join(","))
        })
        .collect::<Vec<_>>()
        .join(" ")
}

/// What one read of the store produced.
struct Read {
    records: Vec<Record>,
    /// Rows in the window whose plist could not be opened.
    unparsed: usize,
}

const QUERY: &str = "SELECT r.rowid, a.identifier, r.data, r.delivered_date \
                     FROM record r JOIN app a ON a.app_id = r.app_id \
                     WHERE r.delivered_date >= ?1 \
                     ORDER BY r.delivered_date DESC";

fn query_rows(conn: &rusqlite::Connection, since_cocoa: f64) -> rusqlite::Result<Vec<RawRow>> {
    let mut stmt = conn.prepare(QUERY)?;
    let rows = stmt.query_map([since_cocoa], |r| {
        Ok(RawRow {
            id: r.get(0)?,
            bundle_id: r.get(1)?,
            data: r.get(2)?,
            delivered: r.get(3)?,
        })
    })?;
    rows.collect()
}

/// Read every record delivered in the last `WINDOW_SECS` from a copy of the
/// store in `src`.
fn read_records(src: &Path, now: f64) -> Result<Read, Access> {
    use rusqlite::{Connection, OpenFlags};

    let snap = Snapshot::take(src)?;
    let conn = Connection::open_with_flags(
        snap.db(),
        OpenFlags::SQLITE_OPEN_READ_ONLY | OpenFlags::SQLITE_OPEN_NO_MUTEX,
    )
    .map_err(|e| {
        eprintln!("notifications: cannot open the copy: {e}");
        Access::Unavailable
    })?;
    let since_cocoa = now - WINDOW_SECS - COCOA_EPOCH_UNIX;
    let rows = query_rows(&conn, since_cocoa).map_err(|e| {
        eprintln!(
            "notifications: query failed: {e}; store layout: {}",
            schema_summary(&conn)
        );
        Access::Unavailable
    })?;
    let total = rows.len();
    let records: Vec<Record> = rows.into_iter().filter_map(parse_row).collect();
    Ok(Read {
        unparsed: total - records.len(),
        records,
    })
}

// ───────────────────────── what was hidden ──────────────────────────

/// Serialises read-modify-write of the hidden file across command threads.
static HIDDEN_LOCK: Mutex<()> = Mutex::new(());

fn hidden_path() -> Option<PathBuf> {
    let home = std::env::var_os("HOME")?;
    Some(Path::new(&home).join(".cache/edgebar/notifications-hidden.json"))
}

/// A missing or unreadable file hides nothing.
fn load_hidden(path: &Path) -> Hidden {
    std::fs::read(path)
        .ok()
        .and_then(|b| serde_json::from_slice(&b).ok())
        .unwrap_or_default()
}

/// Write to a sibling file and rename it over `path`, so a reader never sees a
/// half-written file.
fn save_hidden(path: &Path, hidden: &Hidden) -> io::Result<()> {
    if let Some(dir) = path.parent() {
        std::fs::create_dir_all(dir)?;
    }
    let tmp = path.with_extension("json.tmp");
    std::fs::write(&tmp, serde_json::to_vec(hidden)?)?;
    std::fs::rename(&tmp, path)
}

fn update_hidden(path: &Path, change: impl FnOnce(&mut Hidden)) {
    let _guard = HIDDEN_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let mut hidden = load_hidden(path);
    change(&mut hidden);
    if let Err(e) = save_hidden(path, &hidden) {
        eprintln!("notifications: cannot save the hidden list: {e}");
    }
}

fn dismiss_in(path: &Path, ids: Vec<String>) {
    update_hidden(path, |h| h.ids.extend(ids));
}

/// Everything delivered up to `now` is hidden, so the single ids are no longer
/// needed.
fn clear_in(path: &Path, now: f64) {
    update_hidden(path, |h| {
        h.ids.clear();
        h.cleared_before = now;
    });
}

// ───────────────────────── app names and icons ──────────────────────

/// The path of the installed app with this bundle id.
#[cfg(target_os = "macos")]
fn app_path(bundle_id: &str) -> Option<objc2::rc::Retained<objc2_foundation::NSString>> {
    use objc2_app_kit::NSWorkspace;
    use objc2_foundation::NSString;

    let url = NSWorkspace::sharedWorkspace()
        .URLForApplicationWithBundleIdentifier(&NSString::from_str(bundle_id))?;
    url.path()
}

/// The installed app's name: its bundle's file name without `.app`.
#[cfg(target_os = "macos")]
fn installed_app_name(bundle_id: &str) -> Option<String> {
    let path = app_path(bundle_id)?.to_string();
    Path::new(&path)
        .file_stem()
        .map(|s| s.to_string_lossy().into_owned())
}

#[cfg(not(target_os = "macos"))]
fn installed_app_name(_bundle_id: &str) -> Option<String> {
    None
}

/// The installed app's icon as a PNG data URL, installed or not running (the
/// workspace dots only know running apps). Main thread.
#[cfg(target_os = "macos")]
fn installed_app_icon(bundle_id: &str) -> Option<String> {
    use objc2_app_kit::NSWorkspace;

    let path = app_path(bundle_id)?;
    let image = NSWorkspace::sharedWorkspace().iconForFile(&path);
    crate::icon_png_data_url(&image)
}

/// Icons for these bundle ids, through the same cache as the workspace dots.
/// One hop to the main thread for all the misses; an app with no icon is not
/// cached, so the dots can still fill it in once the app runs.
#[cfg(target_os = "macos")]
fn icons_for(app: &tauri::AppHandle, bundle_ids: &BTreeSet<String>) -> HashMap<String, String> {
    use tauri::Manager;

    let mut icons = HashMap::new();
    let mut missing = Vec::new();
    {
        let state = app.state::<crate::AppState>();
        let cache = state.icon_cache.lock().unwrap();
        for id in bundle_ids {
            match cache.get(id) {
                Some(icon) if !icon.is_empty() => {
                    icons.insert(id.clone(), icon.clone());
                }
                _ => missing.push(id.clone()),
            }
        }
    }
    if missing.is_empty() {
        return icons;
    }
    let (tx, rx) = std::sync::mpsc::channel();
    let handle = app.clone();
    let hop = app.run_on_main_thread(move || {
        let state = handle.state::<crate::AppState>();
        let found: Vec<(String, String)> = missing
            .into_iter()
            .filter_map(|id| installed_app_icon(&id).map(|icon| (id, icon)))
            .collect();
        let mut cache = state.icon_cache.lock().unwrap();
        for (id, icon) in &found {
            cache.insert(id.clone(), icon.clone());
        }
        let _ = tx.send(found);
    });
    if hop.is_ok() {
        if let Ok(found) = rx.recv() {
            icons.extend(found);
        }
    }
    icons
}

#[cfg(not(target_os = "macos"))]
fn icons_for(_app: &tauri::AppHandle, _bundle_ids: &BTreeSet<String>) -> HashMap<String, String> {
    HashMap::new()
}

// ───────────────────────── commands ─────────────────────────────────

fn history(app: &tauri::AppHandle) -> NotificationHistory {
    let denied = |access| NotificationHistory {
        access,
        items: Vec::new(),
    };
    let Some(dir) = store_dir() else {
        return denied(Access::Unavailable);
    };
    let now = now_unix();
    let read = match read_records(&dir, now) {
        Ok(read) => read,
        Err(access) => return denied(access),
    };
    if read.unparsed > 0 {
        eprintln!(
            "notifications: {} rows had no readable plist",
            read.unparsed
        );
    }
    let hidden = hidden_path().map(|p| load_hidden(&p)).unwrap_or_default();
    let records = select(read.records, &hidden, now);

    let bundle_ids: BTreeSet<String> = records.iter().map(|r| r.bundle_id.clone()).collect();
    let icons = icons_for(app, &bundle_ids);
    let names: HashMap<&String, String> = bundle_ids
        .iter()
        .map(|id| {
            let name = installed_app_name(id).unwrap_or_else(|| name_from_bundle_id(id));
            (id, name)
        })
        .collect();

    let items = records
        .into_iter()
        .map(|r| NotificationEntry {
            app: names.get(&r.bundle_id).cloned().unwrap_or_default(),
            icon: icons.get(&r.bundle_id).cloned().unwrap_or_default(),
            time: iso_utc(r.unix_secs),
            id: r.id,
            title: r.title,
            subtitle: r.subtitle,
            body: r.body,
        })
        .collect();
    NotificationHistory {
        access: Access::Granted,
        items,
    }
}

/// Reads and copies a file, so it runs off the main thread.
#[tauri::command]
pub async fn notification_history(app: tauri::AppHandle) -> NotificationHistory {
    tauri::async_runtime::spawn_blocking(move || history(&app))
        .await
        .unwrap_or(NotificationHistory {
            access: Access::Unavailable,
            items: Vec::new(),
        })
}

#[tauri::command]
pub async fn notification_dismiss(ids: Vec<String>) {
    let Some(path) = hidden_path() else { return };
    let _ = tauri::async_runtime::spawn_blocking(move || dismiss_in(&path, ids)).await;
}

#[tauri::command]
pub async fn notification_clear() {
    let Some(path) = hidden_path() else { return };
    let _ = tauri::async_runtime::spawn_blocking(move || clear_in(&path, now_unix())).await;
}

// ───────────────────────── tests ────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use rusqlite::Connection;

    fn plist_blob(root: plist::Dictionary) -> Vec<u8> {
        let mut out = Vec::new();
        plist::Value::Dictionary(root)
            .to_writer_binary(&mut out)
            .unwrap();
        out
    }

    fn request(titl: Option<&str>, subt: Option<&str>, body: Option<&str>) -> plist::Dictionary {
        let mut req = plist::Dictionary::new();
        for (key, val) in [("titl", titl), ("subt", subt), ("body", body)] {
            if let Some(v) = val {
                req.insert(key.into(), plist::Value::String(v.into()));
            }
        }
        let mut root = plist::Dictionary::new();
        root.insert("req".into(), plist::Value::Dictionary(req));
        root
    }

    fn record(id: &str, unix_secs: f64) -> Record {
        Record {
            id: id.into(),
            bundle_id: "com.example.app".into(),
            title: String::new(),
            subtitle: String::new(),
            body: String::new(),
            unix_secs,
        }
    }

    fn row(bundle_id: Option<&str>, data: Option<Vec<u8>>) -> RawRow {
        RawRow {
            id: 42,
            bundle_id: bundle_id.map(str::to_string),
            data,
            delivered: 100.0,
        }
    }

    #[test]
    fn parse_row_reads_the_request_fields() {
        let blob = plist_blob(request(Some("Title"), Some("Sub"), Some("Body text")));
        let rec = parse_row(row(Some("com.example.chat"), Some(blob))).unwrap();
        assert_eq!(
            rec,
            Record {
                id: "42".into(),
                bundle_id: "com.example.chat".into(),
                title: "Title".into(),
                subtitle: "Sub".into(),
                body: "Body text".into(),
                unix_secs: 100.0 + 978_307_200.0,
            }
        );
    }

    #[test]
    fn parse_row_leaves_absent_fields_empty() {
        let blob = plist_blob(request(None, None, Some("only a body")));
        let rec = parse_row(row(Some("a.b"), Some(blob))).unwrap();
        assert_eq!(
            (rec.title.as_str(), rec.subtitle.as_str(), rec.body.as_str()),
            ("", "", "only a body")
        );
    }

    #[test]
    fn parse_row_falls_back_to_the_plist_bundle_id() {
        let mut root = request(Some("t"), None, None);
        root.insert(
            "app".into(),
            plist::Value::String("com.example.inplist".into()),
        );
        let blob = plist_blob(root);
        let rec = parse_row(row(None, Some(blob.clone()))).unwrap();
        assert_eq!(rec.bundle_id, "com.example.inplist");
        let rec = parse_row(row(Some(""), Some(blob))).unwrap();
        assert_eq!(rec.bundle_id, "com.example.inplist");
    }

    #[test]
    fn parse_row_skips_what_is_not_a_notification() {
        assert!(parse_row(row(Some("a.b"), None)).is_none());
        assert!(parse_row(row(Some("a.b"), Some(b"not a plist".to_vec()))).is_none());
        let no_req = plist_blob(plist::Dictionary::new());
        assert!(parse_row(row(Some("a.b"), Some(no_req))).is_none());
    }

    #[test]
    fn iso_utc_counts_from_the_unix_epoch_to_the_whole_second() {
        assert_eq!(iso_utc(0.0), "1970-01-01T00:00:00Z");
        assert_eq!(iso_utc(COCOA_EPOCH_UNIX), "2001-01-01T00:00:00Z");
        assert_eq!(iso_utc(1_761_300_000.9), "2025-10-24T10:00:00Z");
    }

    #[test]
    fn name_from_bundle_id_takes_the_last_part() {
        assert_eq!(name_from_bundle_id("com.example.Chat"), "Chat");
        assert_eq!(name_from_bundle_id("Standalone"), "Standalone");
        assert_eq!(name_from_bundle_id("trailing."), "trailing.");
    }

    #[test]
    fn select_keeps_the_window_newest_first() {
        let now = 1_000_000_000.0;
        let day = 24.0 * 3600.0;
        let kept = select(
            vec![
                record("old", now - 8.0 * day),
                record("edge", now - 7.0 * day),
                record("new", now - 10.0),
                record("mid", now - day),
            ],
            &Hidden::default(),
            now,
        );
        let ids: Vec<&str> = kept.iter().map(|r| r.id.as_str()).collect();
        assert_eq!(ids, ["new", "mid", "edge"]);
    }

    #[test]
    fn select_applies_hidden_ids_and_the_clear_time() {
        let now = 1_000_000_000.0;
        let records = vec![
            record("a", now - 300.0),
            record("b", now - 200.0),
            record("c", now - 100.0),
        ];
        let hidden = Hidden {
            ids: BTreeSet::from(["c".to_string()]),
            cleared_before: now - 250.0,
        };
        let ids: Vec<String> = select(records, &hidden, now)
            .into_iter()
            .map(|r| r.id)
            .collect();
        assert_eq!(ids, ["b"]);
    }

    #[test]
    fn select_caps_at_a_hundred() {
        let now = 1_000_000_000.0;
        let records = (0..150)
            .map(|i| record(&i.to_string(), now - f64::from(i)))
            .collect();
        let kept = select(records, &Hidden::default(), now);
        assert_eq!(kept.len(), 100);
        assert_eq!((kept[0].id.as_str(), kept[99].id.as_str()), ("0", "99"));
    }

    fn scratch(name: &str) -> PathBuf {
        let dir =
            std::env::temp_dir().join(format!("edgebar-notif-test-{}-{name}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn hidden_file_round_trips_dismiss_then_clear() {
        let dir = scratch("hidden");
        let path = dir.join("notifications-hidden.json");
        assert_eq!(load_hidden(&path), Hidden::default());

        dismiss_in(&path, vec!["7".into(), "3".into()]);
        dismiss_in(&path, vec!["7".into(), "9".into()]);
        assert_eq!(
            std::fs::read_to_string(&path).unwrap(),
            r#"{"ids":["3","7","9"],"clearedBefore":0.0}"#
        );

        clear_in(&path, 1234.5);
        assert_eq!(
            std::fs::read_to_string(&path).unwrap(),
            r#"{"ids":[],"clearedBefore":1234.5}"#
        );
        assert!(!dir.join("notifications-hidden.json.tmp").exists());
        std::fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn a_corrupt_hidden_file_hides_nothing() {
        let dir = scratch("corrupt");
        let path = dir.join("notifications-hidden.json");
        std::fs::write(&path, b"{ not json").unwrap();
        assert_eq!(load_hidden(&path), Hidden::default());
        std::fs::remove_dir_all(dir).unwrap();
    }

    /// A store in WAL mode with the writer still open, so the rows sit in
    /// `db-wal` and not in `db`: the state the real store is in while macOS runs.
    fn fake_store(dir: &Path, now: f64) -> Connection {
        let conn = Connection::open(dir.join("db")).unwrap();
        conn.pragma_update(None, "journal_mode", "WAL").unwrap();
        conn.execute_batch(
            "CREATE TABLE app (app_id INTEGER PRIMARY KEY, identifier TEXT);
             CREATE TABLE record (rec_id INTEGER PRIMARY KEY, app_id INTEGER,
                                  data BLOB, delivered_date REAL);
             INSERT INTO app VALUES (1, 'com.example.chat'), (2, 'com.example.mail');",
        )
        .unwrap();
        let add = |app: i64, blob: Option<Vec<u8>>, age_secs: f64| {
            conn.execute(
                "INSERT INTO record (app_id, data, delivered_date) VALUES (?1, ?2, ?3)",
                rusqlite::params![app, blob, now - age_secs - COCOA_EPOCH_UNIX],
            )
            .unwrap();
        };
        let day = 24.0 * 3600.0;
        add(
            1,
            Some(plist_blob(request(Some("older"), None, Some("first body")))),
            100.0,
        );
        add(
            2,
            Some(plist_blob(request(Some("newer"), Some("sub"), None))),
            10.0,
        );
        add(1, Some(b"garbage".to_vec()), 50.0);
        add(
            1,
            Some(plist_blob(request(Some("ancient"), None, None))),
            9.0 * day,
        );
        conn
    }

    #[test]
    fn read_records_copies_the_wal_and_reads_the_rows_in_the_window() {
        let src = scratch("store");
        let now = 1_800_000_000.0;
        let _writer = fake_store(&src, now);
        assert!(
            src.join("db-wal").metadata().unwrap().len() > 0,
            "rows must be in the WAL"
        );

        let read = read_records(&src, now).unwrap();
        let mut got: Vec<(String, String, String, String)> = read
            .records
            .iter()
            .map(|r| {
                (
                    r.id.clone(),
                    r.bundle_id.clone(),
                    r.title.clone(),
                    r.body.clone(),
                )
            })
            .collect();
        got.sort();
        assert_eq!(
            got,
            [
                (
                    "1".to_string(),
                    "com.example.chat".to_string(),
                    "older".to_string(),
                    "first body".to_string()
                ),
                (
                    "2".to_string(),
                    "com.example.mail".to_string(),
                    "newer".to_string(),
                    String::new()
                ),
            ]
        );
        assert_eq!(read.unparsed, 1);
        drop(_writer);
        std::fs::remove_dir_all(src).unwrap();
    }

    #[test]
    fn a_snapshot_is_a_private_copy_that_goes_away() {
        use std::os::unix::fs::PermissionsExt;
        let src = scratch("snapshot");
        let _writer = fake_store(&src, 1_800_000_000.0);
        let snap = Snapshot::take(&src).unwrap();
        let dir = snap.dir.clone();
        for name in ["db", "db-wal", "db-shm"] {
            assert!(dir.join(name).is_file(), "{name} copied");
        }
        assert_eq!(dir.metadata().unwrap().permissions().mode() & 0o777, 0o700);
        drop(snap);
        assert!(!dir.exists());
        drop(_writer);
        std::fs::remove_dir_all(src).unwrap();
    }

    #[test]
    fn a_missing_store_is_unavailable() {
        let src = scratch("missing");
        let err = read_records(&src.join("nope"), 0.0).err().unwrap();
        assert_eq!(err, Access::Unavailable);
        std::fs::remove_dir_all(src).unwrap();
    }

    #[test]
    fn an_unreadable_store_is_denied() {
        use std::os::unix::fs::PermissionsExt;
        let src = scratch("denied");
        let now = 1_800_000_000.0;
        drop(fake_store(&src, now));
        std::fs::set_permissions(src.join("db"), std::fs::Permissions::from_mode(0o000)).unwrap();
        let err = read_records(&src, now).err().unwrap();
        assert_eq!(err, Access::Denied);
        std::fs::remove_dir_all(src).unwrap();
    }

    #[test]
    fn a_store_with_another_layout_is_unavailable() {
        let src = scratch("layout");
        let conn = Connection::open(src.join("db")).unwrap();
        conn.execute_batch("CREATE TABLE unrelated (x INTEGER);")
            .unwrap();
        drop(conn);
        let err = read_records(&src, 0.0).err().unwrap();
        assert_eq!(err, Access::Unavailable);
        let check = Connection::open(src.join("db")).unwrap();
        assert_eq!(schema_summary(&check), "unrelated(x)");
        std::fs::remove_dir_all(src).unwrap();
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn installed_app_name_is_the_bundle_file_name() {
        assert_eq!(
            installed_app_name("com.apple.finder").as_deref(),
            Some("Finder")
        );
        assert_eq!(installed_app_name("com.example.not.installed"), None);
    }

    /// The real store on this Mac. Prints counts and which fields parsed, never
    /// a notification's text. Run with:
    /// `cargo test notifications -- --ignored --nocapture`
    #[test]
    #[ignore = "reads the real notification store (needs Full Disk Access)"]
    fn live_store_summary() {
        let dir = store_dir().expect("HOME is set");
        let now = now_unix();
        let started = std::time::Instant::now();
        let read = match read_records(&dir, now) {
            Ok(read) => read,
            Err(access) => panic!("store not readable: {access:?}"),
        };
        let elapsed = started.elapsed();

        let count = |f: &dyn Fn(&Record) -> bool| read.records.iter().filter(|r| f(r)).count();
        let apps: BTreeSet<&str> = read.records.iter().map(|r| r.bundle_id.as_str()).collect();
        let resolvable = apps
            .iter()
            .filter(|a| installed_app_name(a).is_some())
            .count();
        let times = read.records.iter().map(|r| r.unix_secs);
        let hours = |secs: f64| (now - secs) / 3600.0;
        println!("copy + open + query + parse: {elapsed:?}");
        println!(
            "rows in the 7-day window: {}, parsed: {}, unparsed: {}",
            read.records.len() + read.unparsed,
            read.records.len(),
            read.unparsed
        );
        println!(
            "fields present: bundle id {}, title {}, subtitle {}, body {}",
            count(&|r| !r.bundle_id.is_empty()),
            count(&|r| !r.title.is_empty()),
            count(&|r| !r.subtitle.is_empty()),
            count(&|r| !r.body.is_empty()),
        );
        println!(
            "distinct apps: {}, with an installed app: {resolvable}",
            apps.len()
        );
        println!(
            "age in hours: newest {:.1}, oldest {:.1}",
            hours(times.clone().fold(f64::MIN, f64::max)),
            hours(times.fold(f64::MAX, f64::min)),
        );
        let shown = select(read.records, &Hidden::default(), now);
        println!("entries after select (cap {MAX_ITEMS}): {}", shown.len());
        let snap = Snapshot::take(&dir).unwrap();
        let conn = rusqlite::Connection::open_with_flags(
            snap.db(),
            rusqlite::OpenFlags::SQLITE_OPEN_READ_ONLY,
        )
        .unwrap();
        println!("store layout: {}", schema_summary(&conn));
    }
}
