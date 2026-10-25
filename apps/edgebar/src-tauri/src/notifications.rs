use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashMap};
use std::io::{self, Cursor};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Mutex;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

const MAX_ITEMS: usize = 100;
const WINDOW_SECS: f64 = 7.0 * 24.0 * 3600.0;
const COCOA_EPOCH_UNIX: f64 = 978_307_200.0;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum Access {
    Granted,
    Denied,
    Unavailable,
    Off,
}

#[derive(Clone, PartialEq, Deserialize, Serialize)]
pub struct NotificationsConfig {
    pub history: bool,
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

#[derive(Clone, Debug, PartialEq)]
struct Record {
    id: String,
    bundle_id: String,
    title: String,
    subtitle: String,
    body: String,
    unix_secs: f64,
}

struct RawRow {
    id: i64,
    bundle_id: Option<String>,
    data: Option<Vec<u8>>,
    delivered_cocoa_secs: f64,
}

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
        unix_secs: row.delivered_cocoa_secs + COCOA_EPOCH_UNIX,
    })
}

fn select(mut records: Vec<Record>, hidden: &Hidden, now: f64) -> Vec<Record> {
    records.retain(|r| r.unix_secs >= now - WINDOW_SECS && !hidden.hides(r));
    records.sort_by(|a, b| b.unix_secs.total_cmp(&a.unix_secs));
    records.truncate(MAX_ITEMS);
    records
}

fn iso_utc(unix_secs: f64) -> String {
    let whole = Duration::from_secs(unix_secs.max(0.0).floor() as u64);
    plist::Date::from(UNIX_EPOCH + whole).to_xml_format()
}

fn now_unix() -> f64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0.0, |d| d.as_secs_f64())
}

fn name_from_bundle_id(bundle_id: &str) -> String {
    bundle_id
        .rsplit('.')
        .next()
        .filter(|s| !s.is_empty())
        .unwrap_or(bundle_id)
        .to_string()
}

pub fn store_dir() -> Option<PathBuf> {
    let home = std::env::var_os("HOME")?;
    Some(Path::new(&home).join("Library/Group Containers/group.com.apple.usernoted/db2"))
}

fn access_for(e: &io::Error) -> Access {
    match e.kind() {
        io::ErrorKind::PermissionDenied => Access::Denied,
        _ => Access::Unavailable,
    }
}

struct Snapshot {
    dir: PathBuf,
}

impl Snapshot {
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

struct Read {
    records: Vec<Record>,
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
            delivered_cocoa_secs: r.get(3)?,
        })
    })?;
    rows.collect()
}

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

static HIDDEN_LOCK: Mutex<()> = Mutex::new(());

fn hidden_path() -> Option<PathBuf> {
    Some(crate::settings::cache_dir()?.join("notifications-hidden.json"))
}

fn load_hidden(path: &Path) -> Hidden {
    std::fs::read(path)
        .ok()
        .and_then(|b| serde_json::from_slice(&b).ok())
        .unwrap_or_default()
}

fn update_hidden(path: &Path, change: impl FnOnce(&mut Hidden)) {
    let _guard = HIDDEN_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let mut hidden = load_hidden(path);
    change(&mut hidden);
    if let Err(e) = crate::settings::write_atomic(path, &hidden) {
        eprintln!("notifications: cannot save the hidden list: {e}");
    }
}

fn hide_in(path: &Path, ids: Vec<String>) {
    update_hidden(path, |h| h.ids.extend(ids));
}

fn hide_all_in(path: &Path, now: f64) {
    update_hidden(path, |h| {
        h.ids.clear();
        h.cleared_before = now;
    });
}

#[cfg(target_os = "macos")]
fn app_path(bundle_id: &str) -> Option<objc2::rc::Retained<objc2_foundation::NSString>> {
    use objc2_app_kit::NSWorkspace;
    use objc2_foundation::NSString;

    let url = NSWorkspace::sharedWorkspace()
        .URLForApplicationWithBundleIdentifier(&NSString::from_str(bundle_id))?;
    url.path()
}

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

#[cfg(target_os = "macos")]
fn installed_app_icon(_main_thread: objc2::MainThreadMarker, bundle_id: &str) -> Option<String> {
    use objc2_app_kit::NSWorkspace;

    let path = app_path(bundle_id)?;
    let image = NSWorkspace::sharedWorkspace().iconForFile(&path);
    crate::icon_png_data_url(&image)
}

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
        let Some(main_thread) = objc2::MainThreadMarker::new() else {
            let _ = tx.send(Vec::new());
            return;
        };
        let state = handle.state::<crate::AppState>();
        let found: Vec<(String, String)> = missing
            .into_iter()
            .filter_map(|id| installed_app_icon(main_thread, &id).map(|icon| (id, icon)))
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

#[tauri::command]
pub async fn notification_history(app: tauri::AppHandle) -> NotificationHistory {
    tauri::async_runtime::spawn_blocking(move || {
        if !crate::settings::current(&app).notifications.history {
            return NotificationHistory {
                access: Access::Off,
                items: Vec::new(),
            };
        }
        history(&app)
    })
        .await
        .unwrap_or(NotificationHistory {
            access: Access::Unavailable,
            items: Vec::new(),
        })
}

#[tauri::command]
pub async fn notification_hide(ids: Vec<String>) {
    let Some(path) = hidden_path() else { return };
    let _ = tauri::async_runtime::spawn_blocking(move || hide_in(&path, ids)).await;
}

#[tauri::command]
pub async fn notification_hide_all() {
    let Some(path) = hidden_path() else { return };
    let _ = tauri::async_runtime::spawn_blocking(move || hide_all_in(&path, now_unix())).await;
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::scratch::Scratch;
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
            delivered_cocoa_secs: 100.0,
        }
    }

    #[test]
    fn the_bundled_config_keeps_history_off() {
        let config: crate::Config =
            serde_json::from_str(include_str!("../config.default.json")).unwrap();
        assert!(!config.notifications.history);
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

    #[test]
    fn hidden_file_round_trips_hide_then_hide_all() {
        let dir = Scratch::new("hidden");
        let path = dir.path().join("notifications-hidden.json");
        assert_eq!(load_hidden(&path), Hidden::default());

        hide_in(&path, vec!["7".into(), "3".into()]);
        hide_in(&path, vec!["7".into(), "9".into()]);
        assert_eq!(
            std::fs::read_to_string(&path).unwrap(),
            "{\n  \"ids\": [\n    \"3\",\n    \"7\",\n    \"9\"\n  ],\n  \"clearedBefore\": 0.0\n}\n"
        );

        hide_all_in(&path, 1234.5);
        assert_eq!(
            std::fs::read_to_string(&path).unwrap(),
            "{\n  \"ids\": [],\n  \"clearedBefore\": 1234.5\n}\n"
        );
        assert!(!dir.path().join("notifications-hidden.json.tmp").exists());
    }

    #[test]
    fn a_corrupt_hidden_file_hides_nothing() {
        let dir = Scratch::new("corrupt");
        let path = dir.write("notifications-hidden.json", b"{ not json");
        assert_eq!(load_hidden(&path), Hidden::default());
    }

    /// Holds the fake store's writer open: closing it would checkpoint the WAL
    /// the tests read into the main file.
    struct OpenWriter {
        _conn: Connection,
    }

    fn fake_store(dir: &Path, now: f64) -> OpenWriter {
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
        OpenWriter { _conn: conn }
    }

    #[test]
    fn read_records_copies_the_wal_and_reads_the_rows_in_the_window() {
        let src = Scratch::new("store");
        let now = 1_800_000_000.0;
        let _writer = fake_store(src.path(), now);
        assert!(
            src.path().join("db-wal").metadata().unwrap().len() > 0,
            "rows must be in the WAL"
        );

        let read = read_records(src.path(), now).unwrap();
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
    }

    #[test]
    fn a_snapshot_is_a_private_copy_that_goes_away() {
        use std::os::unix::fs::PermissionsExt;
        let src = Scratch::new("snapshot");
        let _writer = fake_store(src.path(), 1_800_000_000.0);
        let snap = Snapshot::take(src.path()).unwrap();
        let dir = snap.dir.clone();
        for name in ["db", "db-wal", "db-shm"] {
            assert!(dir.join(name).is_file(), "{name} copied");
        }
        assert_eq!(dir.metadata().unwrap().permissions().mode() & 0o777, 0o700);
        drop(snap);
        assert!(!dir.exists());
    }

    #[test]
    fn a_missing_store_is_unavailable() {
        let src = Scratch::new("missing");
        let err = read_records(&src.path().join("nope"), 0.0).err().unwrap();
        assert_eq!(err, Access::Unavailable);
    }

    #[test]
    fn an_unreadable_store_is_denied() {
        use std::os::unix::fs::PermissionsExt;
        let src = Scratch::new("denied");
        let now = 1_800_000_000.0;
        drop(fake_store(src.path(), now));
        std::fs::set_permissions(
            src.path().join("db"),
            std::fs::Permissions::from_mode(0o000),
        )
        .unwrap();
        let err = read_records(src.path(), now).err().unwrap();
        assert_eq!(err, Access::Denied);
    }

    #[test]
    fn a_store_with_another_layout_is_unavailable() {
        let src = Scratch::new("layout");
        let conn = Connection::open(src.path().join("db")).unwrap();
        conn.execute_batch("CREATE TABLE unrelated (x INTEGER);")
            .unwrap();
        drop(conn);
        let err = read_records(src.path(), 0.0).err().unwrap();
        assert_eq!(err, Access::Unavailable);
        let check = Connection::open(src.path().join("db")).unwrap();
        assert_eq!(schema_summary(&check), "unrelated(x)");
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
